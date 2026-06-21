import pytest
from main import app

@pytest.fixture
def client():
    app.config.update({"TESTING": True})

    with app.test_client() as client:
        yield client

def test_main_page(client):
    response = client.get("/")
    assert response.status_code == 200
    assert b"Check out the project on github: " in response.data

def test_healthz(client):
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json == {"status": "ok"}

def test_load_cpu_disabled_without_token(client, monkeypatch):
    monkeypatch.delenv("LOAD_TEST_TOKEN", raising=False)
    response = client.post("/load/cpu")
    assert response.status_code == 404

def test_load_cpu_with_token(client, monkeypatch):
    monkeypatch.setenv("LOAD_TEST_TOKEN", "test-token")
    response = client.post("/load/cpu?duration_ms=1", headers={"X-Load-Test-Token": "test-token"})
    assert response.status_code == 200
    assert response.json["status"] == "ok"
    assert response.json["duration_ms"] == 1
    assert response.json["loops"] > 0
