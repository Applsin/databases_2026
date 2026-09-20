#!/usr/bin/env bash
# Запускает все SQL-скрипты по порядку в контейнере PostgreSQL.
# Использование:  bash run_all.sh [имя_контейнера]
# По умолчанию контейнер называется pg-homework, база — food_delivery.
set -euo pipefail

CONTAINER="${1:-pg-homework}"
DB="food_delivery"
DB_USER="postgres"

# запускаем из папки, где лежит этот скрипт, чтобы пути к файлам были верными
cd "$(dirname "$0")"

FILES=(
  "hw1/03_physical_model.sql"
  "hw2/01_schema_additions.sql"
  "hw2/02_seed_data.sql"
  "hw2/03_constraint_violations_demo.sql"
)

for f in "${FILES[@]}"; do
  echo
  echo ">>> $f"
  docker exec -i "$CONTAINER" psql -U "$DB_USER" -d "$DB" -v ON_ERROR_STOP=1 < "$f"
done

echo
echo "Готово: все скрипты выполнены."
