from __future__ import annotations

import asyncio
import logging
import os
import re
from collections import deque
from datetime import timedelta
from decimal import Decimal, InvalidOperation
from typing import Any

from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, generate_latest

from app.kubernetes_client import KubernetesReader
from app.models import (
    ClusterSummary,
    HistoryPoint,
    MonitorEvent,
    MonitorSnapshot,
    NodeInfo,
    PodInfo,
    utc_now,
)

logger = logging.getLogger(__name__)

CPU_RE = re.compile(r"^([+-]?(?:\d+(?:\.\d*)?|\.\d+))([num]?)$")
MEMORY_RE = re.compile(r"^([+-]?(?:\d+(?:\.\d*)?|\.\d+))([KMGTPE]i?|m?)$")

NODE_COUNT = Gauge("kubernetes_monitor_node_count", "Total Kubernetes node count")
READY_NODE_COUNT = Gauge("kubernetes_monitor_ready_node_count", "Ready Kubernetes node count")
RUNNING_POD_COUNT = Gauge("kubernetes_monitor_running_pod_count", "Running pod count")
PENDING_POD_COUNT = Gauge("kubernetes_monitor_pending_pod_count", "Pending pod count")
CLUSTER_CPU = Gauge("kubernetes_monitor_cluster_cpu_usage_cores", "Cluster CPU usage in cores")
CLUSTER_MEMORY = Gauge("kubernetes_monitor_cluster_memory_usage_bytes", "Cluster memory usage in bytes")
NAMEMASTER_CPU = Gauge("kubernetes_monitor_namemaster_cpu_usage_cores", "namemaster CPU usage in cores")
NAMEMASTER_MEMORY = Gauge("kubernetes_monitor_namemaster_memory_usage_bytes", "namemaster memory usage in bytes")
COLLECTION_ERRORS = Counter("kubernetes_monitor_collection_errors_total", "Collection errors")
NODE_CPU = Gauge("kubernetes_monitor_node_cpu_usage_cores", "Node CPU usage in cores", ["node"])
NODE_MEMORY = Gauge("kubernetes_monitor_node_memory_usage_bytes", "Node memory usage in bytes", ["node"])
NODE_READY = Gauge("kubernetes_monitor_node_ready", "Node Ready condition as 1 or 0", ["node"])


def parse_cpu_quantity(value: str | int | float | None) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    match = CPU_RE.match(text)
    if not match:
        raise ValueError(f"Unsupported CPU quantity: {value!r}")
    number = Decimal(match.group(1))
    suffix = match.group(2)
    multiplier = {
        "": Decimal("1"),
        "n": Decimal("0.000000001"),
        "u": Decimal("0.000001"),
        "m": Decimal("0.001"),
    }[suffix]
    return float(number * multiplier)


def parse_memory_quantity(value: str | int | float | None) -> float | None:
    if value is None:
        return None
    text = str(value).strip()
    match = MEMORY_RE.match(text)
    if not match:
        raise ValueError(f"Unsupported memory quantity: {value!r}")

    number = Decimal(match.group(1))
    suffix = match.group(2)
    binary = {
        "Ki": Decimal(1024),
        "Mi": Decimal(1024) ** 2,
        "Gi": Decimal(1024) ** 3,
        "Ti": Decimal(1024) ** 4,
        "Pi": Decimal(1024) ** 5,
        "Ei": Decimal(1024) ** 6,
    }
    decimal = {
        "": Decimal(1),
        "m": Decimal("0.001"),
        "K": Decimal(1000),
        "M": Decimal(1000) ** 2,
        "G": Decimal(1000) ** 3,
        "T": Decimal(1000) ** 4,
        "P": Decimal(1000) ** 5,
        "E": Decimal(1000) ** 6,
    }
    multiplier = binary.get(suffix) or decimal.get(suffix)
    if multiplier is None:
        raise ValueError(f"Unsupported memory suffix: {suffix!r}")
    return float(number * multiplier)


def _iso(value: Any) -> str | None:
    if value is None:
        return None
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _node_ready(node: Any) -> bool:
    for condition in node.status.conditions or []:
        if condition.type == "Ready":
            return condition.status == "True"
    return False


def _pod_restarts(pod: Any) -> int:
    statuses = pod.status.container_statuses or []
    return sum(status.restart_count or 0 for status in statuses)


def _metric_key(namespace: str, name: str) -> str:
    return f"{namespace}/{name}"


def _container_usage(containers: list[dict[str, Any]]) -> tuple[float, float]:
    cpu = 0.0
    memory = 0.0
    for container in containers:
        usage = container.get("usage", {})
        cpu_value = parse_cpu_quantity(usage.get("cpu"))
        memory_value = parse_memory_quantity(usage.get("memory"))
        cpu += cpu_value or 0.0
        memory += memory_value or 0.0
    return cpu, memory


def _percent(used: float | None, total: float | None) -> float | None:
    if used is None or total is None or total <= 0:
        return None
    return round((used / total) * 100, 2)


def _pod_matches_name(pod: Any) -> bool:
    return "namemaster" in (pod.metadata.name or "")


class MonitorCollector:
    def __init__(self, reader: KubernetesReader, poll_interval: float) -> None:
        self.reader = reader
        self.poll_interval = poll_interval
        self._snapshot = MonitorSnapshot(errors=["No data collected yet"])
        self._lock = asyncio.Lock()
        self._condition = asyncio.Condition()
        self._task: asyncio.Task[None] | None = None
        self._version = 0
        self._history: deque[HistoryPoint] = deque()
        self._events: deque[MonitorEvent] = deque(maxlen=100)
        self._previous_nodes: dict[str, bool] = {}
        self._prometheus_nodes: set[str] = set()

    async def start(self) -> None:
        if self._task is None:
            self._task = asyncio.create_task(self._run(), name="monitor-collector")

    async def stop(self) -> None:
        if self._task is None:
            return
        self._task.cancel()
        try:
            await self._task
        except asyncio.CancelledError:
            pass
        self._task = None

    async def snapshot(self) -> tuple[int, MonitorSnapshot]:
        async with self._lock:
            return self._version, self._snapshot

    async def wait_for_update(self, version: int, timeout: float = 30.0) -> tuple[int, MonitorSnapshot]:
        async with self._condition:
            try:
                await asyncio.wait_for(
                    self._condition.wait_for(lambda: self._version > version),
                    timeout=timeout,
                )
            except asyncio.TimeoutError:
                pass
        return await self.snapshot()

    async def _run(self) -> None:
        while True:
            try:
                snapshot = await asyncio.to_thread(self.collect_once)
                await self._publish(snapshot)
            except asyncio.CancelledError:
                raise
            except Exception as exc:  # noqa: BLE001
                COLLECTION_ERRORS.inc()
                logger.exception("Collector loop failed")
                snapshot = MonitorSnapshot(errors=[str(exc)])
                await self._publish(snapshot)
            await asyncio.sleep(self.poll_interval)

    async def _publish(self, snapshot: MonitorSnapshot) -> None:
        async with self._lock:
            self._snapshot = snapshot
            self._version += 1
        async with self._condition:
            self._condition.notify_all()

    def collect_once(self) -> MonitorSnapshot:
        errors: list[str] = []
        if not self.reader.is_configured():
            errors.append("Kubernetes client is not configured")
            COLLECTION_ERRORS.inc()
            snapshot = MonitorSnapshot(errors=errors, recent_events=list(self._events), history=list(self._history))
            self._update_prometheus(snapshot)
            return snapshot

        nodes = []
        pods = []
        node_metrics: dict[str, Any] = {"items": []}
        pod_metrics: dict[str, Any] = {"items": []}

        try:
            nodes = self.reader.list_nodes().items
        except Exception as exc:  # noqa: BLE001
            logger.exception("Unable to list nodes")
            COLLECTION_ERRORS.inc()
            errors.append(f"Unable to list nodes: {exc}")

        selector = os.getenv("MONITORED_POD_SELECTOR")
        try:
            pods = self.reader.list_pods(label_selector=selector).items
        except Exception as exc:  # noqa: BLE001
            logger.exception("Unable to list pods")
            COLLECTION_ERRORS.inc()
            errors.append(f"Unable to list pods: {exc}")

        try:
            node_metrics = self.reader.list_node_metrics()
        except Exception as exc:  # noqa: BLE001
            logger.exception("Unable to read node metrics")
            COLLECTION_ERRORS.inc()
            errors.append(f"Unable to read node metrics: {exc}")

        try:
            pod_metrics = self.reader.list_pod_metrics()
        except Exception as exc:  # noqa: BLE001
            logger.exception("Unable to read pod metrics")
            COLLECTION_ERRORS.inc()
            errors.append(f"Unable to read pod metrics: {exc}")

        node_metric_map = {
            item.get("metadata", {}).get("name"): item
            for item in node_metrics.get("items", [])
        }
        pod_metric_map = {
            _metric_key(item.get("metadata", {}).get("namespace", ""), item.get("metadata", {}).get("name", "")): item
            for item in pod_metrics.get("items", [])
        }

        pod_counts_by_node: dict[str, int] = {}
        running = pending = failed = 0
        for pod in pods:
            phase = pod.status.phase or "Unknown"
            running += int(phase == "Running")
            pending += int(phase == "Pending")
            failed += int(phase == "Failed")
            if pod.spec.node_name:
                pod_counts_by_node[pod.spec.node_name] = pod_counts_by_node.get(pod.spec.node_name, 0) + 1

        node_infos: list[NodeInfo] = []
        cluster_cpu = 0.0
        cluster_memory = 0.0
        current_nodes: dict[str, bool] = {}
        for node in nodes:
            name = node.metadata.name
            labels = node.metadata.labels or {}
            ready = _node_ready(node)
            current_nodes[name] = ready
            metric = node_metric_map.get(name, {})
            usage = metric.get("usage", {})

            cpu_usage = self._safe_parse(parse_cpu_quantity, usage.get("cpu"), errors)
            memory_usage = self._safe_parse(parse_memory_quantity, usage.get("memory"), errors)
            cpu_allocatable = self._safe_parse(parse_cpu_quantity, (node.status.allocatable or {}).get("cpu"), errors)
            memory_allocatable = self._safe_parse(
                parse_memory_quantity,
                (node.status.allocatable or {}).get("memory"),
                errors,
            )
            cluster_cpu += cpu_usage or 0.0
            cluster_memory += memory_usage or 0.0

            node_infos.append(
                NodeInfo(
                    name=name,
                    ready=ready,
                    cpu_usage_cores=cpu_usage,
                    cpu_allocatable_cores=cpu_allocatable,
                    cpu_usage_percent=_percent(cpu_usage, cpu_allocatable),
                    memory_usage_bytes=memory_usage,
                    memory_allocatable_bytes=memory_allocatable,
                    memory_usage_percent=_percent(memory_usage, memory_allocatable),
                    pod_count=pod_counts_by_node.get(name, 0),
                    created_at=_iso(node.metadata.creation_timestamp),
                    instance_type=labels.get("node.kubernetes.io/instance-type")
                    or labels.get("beta.kubernetes.io/instance-type"),
                    zone=labels.get("topology.kubernetes.io/zone")
                    or labels.get("failure-domain.beta.kubernetes.io/zone"),
                )
            )

        self._record_node_events(current_nodes)

        namemaster_pods: list[PodInfo] = []
        namemaster_cpu = 0.0
        namemaster_memory = 0.0
        monitored_pods = pods if selector else [pod for pod in pods if _pod_matches_name(pod)]
        for pod in monitored_pods:
            key = _metric_key(pod.metadata.namespace, pod.metadata.name)
            metric = pod_metric_map.get(key)
            cpu_usage = memory_usage = None
            if metric is not None:
                cpu_usage, memory_usage = _container_usage(metric.get("containers", []))
                namemaster_cpu += cpu_usage
                namemaster_memory += memory_usage

            namemaster_pods.append(
                PodInfo(
                    namespace=pod.metadata.namespace,
                    name=pod.metadata.name,
                    node=pod.spec.node_name,
                    phase=pod.status.phase or "Unknown",
                    cpu_usage_cores=cpu_usage,
                    memory_usage_bytes=memory_usage,
                    restarts=_pod_restarts(pod),
                    created_at=_iso(pod.metadata.creation_timestamp),
                )
            )

        summary = ClusterSummary(
            node_count=len(node_infos),
            ready_node_count=sum(1 for node in node_infos if node.ready),
            running_pod_count=running,
            pending_pod_count=pending,
            failed_pod_count=failed,
            cluster_cpu_usage_cores=cluster_cpu,
            cluster_memory_usage_bytes=cluster_memory,
            namemaster_cpu_usage_cores=namemaster_cpu,
            namemaster_memory_usage_bytes=namemaster_memory,
        )
        self._record_pending_events(pending)
        history = self._append_history(summary)
        snapshot = MonitorSnapshot(
            summary=summary,
            namemaster_pods=sorted(namemaster_pods, key=lambda pod: (pod.namespace, pod.name)),
            nodes=sorted(node_infos, key=lambda node: node.name),
            history=history,
            recent_events=list(self._events),
            errors=errors,
        )
        self._update_prometheus(snapshot)
        return snapshot

    def _safe_parse(self, parser: Any, value: Any, errors: list[str]) -> float | None:
        try:
            return parser(value)
        except (ValueError, InvalidOperation) as exc:
            errors.append(str(exc))
            logger.warning("Unable to parse Kubernetes quantity %r: %s", value, exc)
            return None

    def _append_history(self, summary: ClusterSummary) -> list[HistoryPoint]:
        now = utc_now()
        cutoff = now - timedelta(minutes=30)
        self._history.append(
            HistoryPoint(
                timestamp=now.isoformat(),
                node_count=summary.node_count,
                ready_node_count=summary.ready_node_count,
                cluster_cpu_usage_cores=summary.cluster_cpu_usage_cores,
                cluster_memory_usage_bytes=summary.cluster_memory_usage_bytes,
                namemaster_cpu_usage_cores=summary.namemaster_cpu_usage_cores,
                namemaster_memory_usage_bytes=summary.namemaster_memory_usage_bytes,
                pending_pod_count=summary.pending_pod_count,
            )
        )
        while self._history and self._history[0].timestamp < cutoff.isoformat():
            self._history.popleft()
        return list(self._history)

    def _record_node_events(self, current_nodes: dict[str, bool]) -> None:
        now = utc_now().isoformat()
        previous_names = set(self._previous_nodes)
        current_names = set(current_nodes)
        for name in sorted(current_names - previous_names):
            self._events.append(MonitorEvent(timestamp=now, message=f"Node added: {name}"))
        for name in sorted(previous_names - current_names):
            self._events.append(MonitorEvent(timestamp=now, message=f"Node removed: {name}", severity="warning"))
        for name in sorted(current_names & previous_names):
            previous_ready = self._previous_nodes[name]
            current_ready = current_nodes[name]
            if not previous_ready and current_ready:
                self._events.append(MonitorEvent(timestamp=now, message=f"Node became Ready: {name}"))
            if previous_ready and not current_ready:
                self._events.append(MonitorEvent(timestamp=now, message=f"Node became NotReady: {name}", severity="warning"))
        self._previous_nodes = current_nodes

    def _record_pending_events(self, pending: int) -> None:
        if pending > 0:
            self._events.append(
                MonitorEvent(
                    timestamp=utc_now().isoformat(),
                    message=f"Pending pods: {pending}",
                    severity="warning",
                )
            )

    def _update_prometheus(self, snapshot: MonitorSnapshot) -> None:
        summary = snapshot.summary
        NODE_COUNT.set(summary.node_count)
        READY_NODE_COUNT.set(summary.ready_node_count)
        RUNNING_POD_COUNT.set(summary.running_pod_count)
        PENDING_POD_COUNT.set(summary.pending_pod_count)
        CLUSTER_CPU.set(summary.cluster_cpu_usage_cores)
        CLUSTER_MEMORY.set(summary.cluster_memory_usage_bytes)
        NAMEMASTER_CPU.set(summary.namemaster_cpu_usage_cores)
        NAMEMASTER_MEMORY.set(summary.namemaster_memory_usage_bytes)

        current = {node.name for node in snapshot.nodes}
        for stale_node in self._prometheus_nodes - current:
            NODE_CPU.remove(stale_node)
            NODE_MEMORY.remove(stale_node)
            NODE_READY.remove(stale_node)
        self._prometheus_nodes = current

        for node in snapshot.nodes:
            NODE_CPU.labels(node=node.name).set(node.cpu_usage_cores or 0)
            NODE_MEMORY.labels(node=node.name).set(node.memory_usage_bytes or 0)
            NODE_READY.labels(node=node.name).set(1 if node.ready else 0)


def prometheus_response() -> tuple[bytes, str]:
    return generate_latest(), CONTENT_TYPE_LATEST
