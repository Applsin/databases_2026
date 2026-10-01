#!/usr/bin/env bash
# seminar5_setup.sh (студенческий контекст)
# Создаёт базу demo, загружает демо-дамп и настраивает роли семинара №5.
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
POST_SETUP_LOCAL="${SCRIPT_DIR}/seminar5_post_setup.sql"
POST_SETUP_REMOTE="/tmp/seminar5_post_setup.sql"

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

# шаг 3: копируем файлы в контейнер
docker cp "$(cygpath -w "${DUMP_SQL}")" "${CONTAINER}:${DUMP_REMOTE}"
docker cp "$(cygpath -w "${POST_SETUP_LOCAL}")" "${CONTAINER}:${POST_SETUP_REMOTE}"

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

# шаг 6: роли и права
echo "-- post-setup: roles and grants"
docker exec -i "${CONTAINER}" \
  psql -U postgres -d demo -q -f "${POST_SETUP_REMOTE}"

echo "-- seminar5 setup done"
