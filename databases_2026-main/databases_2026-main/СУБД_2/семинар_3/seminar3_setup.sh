#!/usr/bin/env bash
# seminar3_setup.sh
# Создаёт базу demo и загружает демо-дамп авиаперелётов (Postgres Pro, demo-medium-en).
# Дамп берётся из ./data (рядом со скриптом). Если файла нет — скачивается с edu.postgrespro.ru.
# Повторный прогон даёт тот же результат.

set -euo pipefail

export MSYS_NO_PATHCONV=1

CONTAINER="pg16_check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
DUMP_ZIP="${DATA_DIR}/demo-medium-en.zip"
DUMP_SQL="${DATA_DIR}/demo-medium-en-20170815.sql"
DUMP_URL="https://edu.postgrespro.ru/demo-medium-en.zip"
DUMP_REMOTE="/tmp/demo-medium-en-20170815.sql"

# шаг 1: убедиться, что контейнер запущен
docker start "${CONTAINER}" 2>/dev/null || \
  docker run -d --name "${CONTAINER}" -p 5432:5432 postgres:16

# шаг 2: получить дамп (локальный zip/sql, иначе скачать)
if [ ! -f "${DUMP_SQL}" ] && [ ! -f "${DUMP_ZIP}" ]; then
  echo "-- download dump from ${DUMP_URL}"
  mkdir -p "${DATA_DIR}"
  curl -L -o "${DUMP_ZIP}" "${DUMP_URL}"
fi

# шаг 3: распаковать zip во временный SQL, если нужно
if [ ! -f "${DUMP_SQL}" ]; then
  echo "-- unzip dump"
  unzip -p "${DUMP_ZIP}" > "${DUMP_SQL}"
fi

echo "-- copy dump into container"
docker cp "$(cygpath -w "${DUMP_SQL}")" "${CONTAINER}:${DUMP_REMOTE}"

echo "-- terminate connections to demo"
docker exec -i "${CONTAINER}" \
  psql -U postgres -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='demo' AND pid <> pg_backend_pid();"

echo "-- load dump (may take a few minutes; dump recreates database itself)"
docker exec -i "${CONTAINER}" \
  psql -U postgres -d postgres -q -f "${DUMP_REMOTE}"

echo "-- done"
