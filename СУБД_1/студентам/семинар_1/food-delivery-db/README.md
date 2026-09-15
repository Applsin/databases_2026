# Домашнее задание №1 — Food Delivery

Вариант №2. Служба доставки еды.

## Структура
- `sql/01_create_tables.sql` — таблицы, ограничения и индексы.
- `sql/02_insert_data.sql` — демонстрационные данные.
- `sql/03_queries.sql` — 5 частых запросов.
- `python/check_database.py` — проверка PostgreSQL через Python.
- `docker/docker-compose.yml` — PostgreSQL в Docker.
- `docs/homework_1.md` — готовый текст отчёта.

## Запуск
```bash
docker compose -f docker/docker-compose.yml up -d
```

DBeaver:
- Host: `localhost`
- Port: `5432`
- Database: `food_delivery`
- User: `postgres`
- Password: `postgres`

В DBeaver последовательно выполнить:
1. `sql/01_create_tables.sql`
2. `sql/02_insert_data.sql`
3. `sql/03_queries.sql`

Python:
```bash
pip install psycopg2-binary
python python/check_database.py
```

## Git
```bash
git init
git add .
git commit -m "Create food delivery database"
git branch -M main
git remote add origin <URL_ВАШЕГО_РЕПОЗИТОРИЯ>
git push -u origin main
```
