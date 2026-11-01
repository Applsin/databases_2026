"""Настройки локального запуска. Боевых секретов здесь нет."""

import os


def service_version() -> str:
    return os.getenv("APP_VERSION", "0.1.0")


def service_name() -> str:
    return os.getenv("APP_NAME", "api-tech-student")
