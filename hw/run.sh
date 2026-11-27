#!/usr/bin/env bash
set -euo pipefail

IMAGE=seminar8-jupyter
CONTAINER=seminar8
CONTEXT="$(pwd)/окружение"

echo "=== Сборка образа ==="
docker build -t "$IMAGE" "$CONTEXT"

echo "=== Остановка старого контейнера (если был) ==="
docker rm -f "$CONTAINER" 2>/dev/null || true

echo "=== Запуск контейнера ==="
docker run -d --name "$CONTAINER" \
  -p 8888:8888 \
  -p 5432:5432 \
  -v "$(pwd):/home/student/work" \
  "$IMAGE"

echo "Готово!"
echo "Jupyter: http://localhost:8888 (пароль: student)"
echo "PostgreSQL: localhost:5432 (db=demo, user=postgres, без пароля)"