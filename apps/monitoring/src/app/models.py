from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from typing import Any


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


@dataclass
class PodInfo:
    namespace: str
    name: str
    node: str | None
    phase: str
    cpu_usage_cores: float | None
    memory_usage_bytes: float | None
    restarts: int
    created_at: str | None


@dataclass
class NodeInfo:
    name: str
    ready: bool
    cpu_usage_cores: float | None
    cpu_allocatable_cores: float | None
    cpu_usage_percent: float | None
    memory_usage_bytes: float | None
    memory_allocatable_bytes: float | None
    memory_usage_percent: float | None
    pod_count: int
    created_at: str | None
    instance_type: str | None
    zone: str | None


@dataclass
class ClusterSummary:
    node_count: int = 0
    ready_node_count: int = 0
    running_pod_count: int = 0
    pending_pod_count: int = 0
    failed_pod_count: int = 0
    cluster_cpu_usage_cores: float = 0.0
    cluster_memory_usage_bytes: float = 0.0
    namemaster_cpu_usage_cores: float = 0.0
    namemaster_memory_usage_bytes: float = 0.0


@dataclass
class HistoryPoint:
    timestamp: str
    node_count: int
    ready_node_count: int
    cluster_cpu_usage_cores: float
    cluster_memory_usage_bytes: float
    namemaster_cpu_usage_cores: float
    namemaster_memory_usage_bytes: float
    pending_pod_count: int


@dataclass
class MonitorEvent:
    timestamp: str
    message: str
    severity: str = "info"


@dataclass
class MonitorSnapshot:
    generated_at: str = field(default_factory=lambda: utc_now().isoformat())
    summary: ClusterSummary = field(default_factory=ClusterSummary)
    namemaster_pods: list[PodInfo] = field(default_factory=list)
    nodes: list[NodeInfo] = field(default_factory=list)
    history: list[HistoryPoint] = field(default_factory=list)
    recent_events: list[MonitorEvent] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
