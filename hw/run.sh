#!/usr/bin/env bash
set -euo pipefail

IMAGE=seminar8-jupyter
CONTAINER=seminar8

PROJECT_DIR="$(pwd -W)"
CONTEXT="$PROJECT_DIR/окружение"

echo "=== Сборка образа ==="
MSYS_NO_PATHCONV=1 docker build -t "$IMAGE" "$CONTEXT"

echo "=== Остановка старого контейнера (если был) ==="
docker rm -f "$CONTAINER" 2>/dev/null || true

echo "=== Запуск контейнера ==="
MSYS_NO_PATHCONV=1 docker run -d --name "$CONTAINER" \
  -p 8888:8888 \
  -p 5432:5432 \
  -v "$PROJECT_DIR:/home/student/work" \
  "$IMAGE"

echo "Готово!"
echo "Jupyter: http://localhost:8888 (пароль: student)"
echo "PostgreSQL: localhost:5432 (db=demo, user=postgres, без пароля)"