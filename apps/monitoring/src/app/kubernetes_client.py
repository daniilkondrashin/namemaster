from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any

from kubernetes import client, config
from kubernetes.config.config_exception import ConfigException

logger = logging.getLogger(__name__)


@dataclass
class KubernetesClients:
    core: client.CoreV1Api
    custom: client.CustomObjectsApi


class KubernetesClientFactory:
    def __init__(self) -> None:
        self.loaded_from: str | None = None
        self.error: str | None = None
        self.clients: KubernetesClients | None = None

    def load(self) -> KubernetesClients | None:
        if self.clients is not None:
            return self.clients

        try:
            config.load_incluster_config()
            self.loaded_from = "incluster"
            logger.info("Loaded in-cluster Kubernetes configuration")
        except ConfigException:
            try:
                config.load_kube_config()
                self.loaded_from = "kubeconfig"
                logger.info("Loaded local kubeconfig")
            except Exception as exc:  # noqa: BLE001 - surface config errors in readiness.
                self.error = f"Unable to load Kubernetes configuration: {exc}"
                logger.exception(self.error)
                return None
        except Exception as exc:  # noqa: BLE001
            self.error = f"Unable to load in-cluster Kubernetes configuration: {exc}"
            logger.exception(self.error)
            return None

        self.clients = KubernetesClients(
            core=client.CoreV1Api(),
            custom=client.CustomObjectsApi(),
        )
        self.error = None
        return self.clients

    def ready(self) -> tuple[bool, str]:
        clients = self.load()
        if clients is None:
            return False, self.error or "Kubernetes client is not configured"

        try:
            clients.core.list_node(limit=1, _request_timeout=5)
            return True, "ok"
        except Exception as exc:  # noqa: BLE001
            logger.exception("Kubernetes readiness check failed")
            return False, str(exc)


class KubernetesReader:
    def __init__(self, clients: KubernetesClients | None) -> None:
        self.clients = clients

    def is_configured(self) -> bool:
        return self.clients is not None

    def list_nodes(self) -> Any:
        if self.clients is None:
            raise RuntimeError("Kubernetes client is not configured")
        return self.clients.core.list_node(_request_timeout=10)

    def list_pods(self, label_selector: str | None = None) -> Any:
        if self.clients is None:
            raise RuntimeError("Kubernetes client is not configured")
        return self.clients.core.list_pod_for_all_namespaces(
            label_selector=label_selector,
            _request_timeout=10,
        )

    def list_node_metrics(self) -> dict[str, Any]:
        if self.clients is None:
            raise RuntimeError("Kubernetes client is not configured")
        return self.clients.custom.list_cluster_custom_object(
            group="metrics.k8s.io",
            version="v1beta1",
            plural="nodes",
            _request_timeout=10,
        )

    def list_pod_metrics(self) -> dict[str, Any]:
        if self.clients is None:
            raise RuntimeError("Kubernetes client is not configured")
        return self.clients.custom.list_cluster_custom_object(
            group="metrics.k8s.io",
            version="v1beta1",
            plural="pods",
            _request_timeout=10,
        )
