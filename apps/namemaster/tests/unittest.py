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