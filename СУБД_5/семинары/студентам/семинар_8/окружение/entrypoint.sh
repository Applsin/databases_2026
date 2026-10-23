#!/bin/bash
set -euo pipefail

DB_NAME="${POSTGRES_DB:-demo}"

echo "=== [1/3] Инициализация PostgreSQL ==="

# Создать кластер при первом запуске, иначе — стартовать
if [ ! -f /var/lib/postgresql/15/main/PG_VERSION ]; then
    pg_createcluster 15 main --start
else
    pg_ctlcluster 15 main status >/dev/null 2>&1 || pg_ctlcluster 15 main start
fi

# Ждём готовности
for i in $(seq 1 30); do
    pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1 && break
    sleep 1
done

if ! pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
    echo "PostgreSQL не запустился — выходим." >&2
    exit 1
fi

# --- Разрешаем ЛОКАЛЬНЫЕ подключения без пароля (trust) ---
# Правим pg_hba.conf и перечитываем конфиг (reload — без рестарта сервера).
PG_HBA=/etc/postgresql/15/main/pg_hba.conf
sed -i -E 's/^(local\s+all\s+all\s+).*/\1trust/'             "$PG_HBA"
sed -i -E 's/^(host\s+all\s+all\s+127\.0\.0\.1\/32\s+).*/\1trust/' "$PG_HBA"
sed -i -E 's/^(host\s+all\s+all\s+::1\/128\s+).*/\1trust/'         "$PG_HBA"
pg_ctlcluster 15 main reload
sleep 1

# --- База demo от имени postgres ---
su postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'\"" | grep -q 1 \
    || su postgres -c "createdb -O postgres ${DB_NAME}"

echo "=== [2/3] PostgreSQL готов: localhost:5432 (db=${DB_NAME}, user=postgres, БЕЗ ПАРОЛЯ) ==="

# --- Копируем ноутбук в рабочую папку ---
mkdir -p /home/student/work
if [ ! -f /home/student/work/seminar8.ipynb ]; then
    cp /opt/notebook/seminar8.ipynb /home/student/work/seminar8.ipynb
fi
chown -R student:student /home/student/work

echo "=== [3/3] Запуск JupyterLab на 0.0.0.0:${JUPYTER_PORT:-8888} ==="

HASH="$(python -c "from jupyter_server.auth import passwd; print(passwd('${JUPYTER_PASSWORD:-student}'))")"

exec jupyter lab \
    --ip=0.0.0.0 \
    --port="${JUPYTER_PORT:-8888}" \
    --no-browser \
    --allow-root \
    --ServerApp.password="$HASH" \
    --ServerApp.password_required=True \
    --ServerApp.allow_remote_access=True \
    --ServerApp.base_url=/ \
    --notebook-dir=/home/student/work