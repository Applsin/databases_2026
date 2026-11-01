"""Учебный каркас FastAPI.

Маршрут /health готов. Остальные обязательные маршруты проверяют контракт
и отвечают отказом, пока студент не закроет соответствующий плейбук.
"""

from __future__ import annotations

from fastapi import FastAPI

from src.app.errors import AppError, RequestIdMiddleware, install_error_handlers
from src.app.models import CommandIn, HealthOut
from src.app.settings import service_name, service_version

app = FastAPI(
    title="Учебный API-сервис",
    version=service_version(),
    description="Заготовка курса «API-технологии». Маршруты своей темы студент добавляет сам.",
)
app.add_middleware(RequestIdMiddleware)
install_error_handlers(app)


@app.get("/health", response_model=HealthOut)
def health() -> HealthOut:
    return HealthOut(status="ok", service=service_name(), version=service_version())


@app.post("/api/v1/commands", responses={422: {"description": "Ошибка полей"}, 501: {"description": "Ещё не реализовано"}})
def create_command(body: CommandIn) -> None:
    # Тело уже проверено. Свою команду и правило темы студент ставит вместо этой заглушки.
    raise AppError(
        501,
        "not_implemented",
        f"Команда для subject_id={body.subject_id} ещё не реализована",
    )


@app.get("/api/v1/commands/{command_id}")
def read_command(command_id: str) -> None:
    raise AppError(404, "not_found", f"Команда {command_id} не найдена")
