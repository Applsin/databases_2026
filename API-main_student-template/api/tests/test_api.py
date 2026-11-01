"""Проверки заготовки. Успешная предметная команда здесь появляться не должна."""

import httpx
from fastapi.testclient import TestClient

from src.app.main import app
from src.client.api_client import ApiClient, ApiClientError

client = TestClient(app)


def test_health_ok() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.headers["X-Request-ID"]


def test_command_rejects_bad_body() -> None:
    response = client.post("/api/v1/commands", json={"idempotency_key": ""})
    body = response.json()
    assert response.status_code == 422
    assert body["error"]["code"] == "validation_error"
    assert body["error"]["request_id"]


def test_valid_command_is_not_a_fake_success() -> None:
    payload = {"idempotency_key": "same-key", "subject_id": "owner-1"}
    response = client.post("/api/v1/commands", json=payload)
    assert response.status_code == 501
    assert response.json()["error"]["code"] == "not_implemented"


def test_unknown_command_is_404() -> None:
    response = client.get("/api/v1/commands/missing")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"


def test_client_reads_health_and_surfaces_not_implemented() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/health":
            return httpx.Response(200, json={"status": "ok", "service": "demo", "version": "0"})
        return httpx.Response(
            501,
            json={"error": {"code": "not_implemented", "message": "прогноз не подключён"}},
        )

    api = ApiClient("http://test", transport=httpx.MockTransport(handler))
    try:
        assert api.health()["status"] == "ok"
        try:
            api.create_command({"idempotency_key": "same-key", "subject_id": "owner-1"})
        except ApiClientError as exc:
            assert exc.status_code == 501
            assert exc.code == "not_implemented"
        else:
            raise AssertionError("клиент не должен принимать заглушку за выполненную команду")
    finally:
        api.close()
