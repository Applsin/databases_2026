"""Модели контракта. Предметные поля своей темы студент добавляет сам."""

from pydantic import BaseModel, Field


class HealthOut(BaseModel):
    status: str
    service: str
    version: str


class CommandIn(BaseModel):
    idempotency_key: str = Field(min_length=1, description="Ключ повтора из паспорта темы")
    subject_id: str = Field(min_length=1, description="Учебный идентификатор владельца ресурса")


class ErrorDetail(BaseModel):
    code: str
    message: str
    request_id: str


class ErrorOut(BaseModel):
    error: ErrorDetail
