#!/usr/bin/env bash
# seminar7_setup.sh (студенческий контекст)
# Создаёт базу demo и загружает демо-дамп авиаперелётов для семинара №7.
# Все пути — относительно папки студентам/.

set -euo pipefail

export MSYS_NO_PATHCONV=1

CONTAINER="pg16_check"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
DUMP_ZIP="${DATA_DIR}/demo-medium.zip"
DUMP_SQL="${DATA_DIR}/demo-medium-20170815.sql"
DUMP_URL="https://edu.postgrespro.ru/demo-medium.zip"
DUMP_REMOTE="/tmp/demo-medium-20170815.sql"

# шаг 1: контейнер
docker start "${CONTAINER}" 2>/dev/null || \
  docker run -d --name "${CONTAINER}" -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16

# шаг 2: дамп
if [ ! -f "${DUMP_SQL}" ] && [ ! -f "${DUMP_ZIP}" ]; then
  echo "-- download dump from ${DUMP_URL}"
  mkdir -p "${DATA_DIR}"
  TMP_ZIP="/tmp/demo-medium-en-dl.zip"
  TMP_ZIP_WIN="$(cygpath -w "${TMP_ZIP}")"
  curl -L -o "${TMP_ZIP_WIN}" "${DUMP_URL}"
  mv "${TMP_ZIP}" "${DUMP_ZIP}"
fi

if [ ! -f "${DUMP_SQL}" ]; then
  echo "-- unzip dump"
  unzip -p "${DUMP_ZIP}" > "${DUMP_SQL}"
fi

# шаг 3: копируем дамп в контейнер
docker cp "$(cygpath -w "${DUMP_SQL}")" "${CONTAINER}:${DUMP_REMOTE}"

# шаг 4: пересоздаём базу demo
docker exec -i "${CONTAINER}" \
  psql -U postgres -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='demo' AND pid <> pg_backend_pid();"

docker exec -i "${CONTAINER}" \
  psql -U postgres -d postgres -c "DROP DATABASE IF EXISTS demo;"

docker exec -i "${CONTAINER}" \
  psql -U postgres -d postgres -c "CREATE DATABASE demo;"

# шаг 5: загружаем дамп
echo "-- load dump"
docker exec -i "${CONTAINER}" \
  psql -U postgres -d demo -q -f "${DUMP_REMOTE}"

echo "-- seminar7 setup done"
