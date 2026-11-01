"""Клиент учебного сервиса. Секреты в журнал не попадают."""

from __future__ import annotations

from typing import Any

import httpx


class ApiClientError(Exception):
    def __init__(self, message: str, status_code: int | None = None, code: str | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code


class ApiClient:
    def __init__(
        self,
        base_url: str,
        timeout: float = 5.0,
        api_key: str | None = None,
        transport: httpx.BaseTransport | None = None,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        headers = {}
        if api_key:
            headers["X-API-Key"] = api_key
        self._client = httpx.Client(
            base_url=self._base_url,
            timeout=timeout,
            headers=headers,
            transport=transport,
        )

    def close(self) -> None:
        self._client.close()

    def health(self) -> dict[str, Any]:
        return self._request("GET", "/health")

    def create_command(self, payload: dict[str, Any]) -> dict[str, Any]:
        return self._request("POST", "/api/v1/commands", json=payload)

    def _request(self, method: str, path: str, json: dict[str, Any] | None = None) -> dict[str, Any]:
        try:
            response = self._client.request(method, path, json=json)
        except httpx.TimeoutException as exc:
            raise ApiClientError("Таймаут запроса") from exc
        except httpx.TransportError as exc:
            raise ApiClientError("Нет соединения с сервисом") from exc
        return self._parse(response)

    @staticmethod
    def _parse(response: httpx.Response) -> dict[str, Any]:
        try:
            body = response.json()
        except ValueError:
            body = {"error": {"code": "invalid_json", "message": "Ответ не JSON"}}
        if response.status_code >= 400:
            error = body.get("error", {}) if isinstance(body, dict) else {}
            raise ApiClientError(
                str(error.get("message") or response.reason_phrase),
                status_code=response.status_code,
                code=error.get("code"),
            )
        if not isinstance(body, dict):
            raise ApiClientError("Ожидался JSON-объект", status_code=response.status_code)
        return body
