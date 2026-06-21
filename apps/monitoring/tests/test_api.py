import asyncio

import app.main as main_module


def test_expected_routes_are_registered():
    routes = {route.path for route in main_module.app.routes}
    assert "/" in routes
    assert "/healthz" in routes
    assert "/readyz" in routes
    assert "/api/snapshot" in routes
    assert "/api/events" in routes
    assert "/metrics" in routes


def test_healthz_handler():
    assert asyncio.run(main_module.healthz()) == {"status": "ok"}


def test_metrics_handler():
    response = asyncio.run(main_module.metrics())
    assert response.status_code == 200
    assert b"kubernetes_monitor_node_count" in response.body
