# Домашние задания №1–2 — Food Delivery

Вариант №2. Служба доставки еды.

## Структура
- `sql/01_create_tables.sql` — таблицы, ограничения, внешние ключи и индексы.
- `sql/02_insert_data.sql` — демонстрационные данные.
- `sql/03_queries.sql` — частые запросы из ДЗ №1 и дополнительные запросы для новых таблиц.
- `python/check_database.py` — проверка PostgreSQL через Python.
- `docker/docker-compose.yml` — PostgreSQL в Docker.
- `docs/homework_1.md` — отчёт по ДЗ №1.
- `docs/homework_2.md` — отчёт по ДЗ №2.

## Что добавлено в ДЗ №2

Добавлены две таблицы:
- `categories` — категории блюд;
- `dish_categories` — промежуточная таблица для связи M:N между `dishes` и `categories`.

Для `dish_categories` используется составной первичный ключ `(dish_id, category_id)`, поэтому одна и та же связь не может быть записана дважды.

Внешние ключи `dish_categories` используют `ON DELETE CASCADE`:
- удаление блюда удаляет его связи с категориями;
- удаление категории удаляет связи этой категории с блюдами;
- связанные блюда и категории сами при этом не удаляются.

Для поиска блюд по категории создан индекс `idx_dish_categories_category_id`.

Также добавлены составные индексы на `orders` для частых запросов из ДЗ №1:
- `idx_orders_created_at_status`;
- `idx_orders_restaurant_status_created_at`;
- `idx_orders_courier_status`.

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

Для ДЗ №2 рекомендуется отдельная ветка:

```bash
git checkout -b homework-2
git add .
git commit -m "Add homework 2 database extensions"
git push -u origin homework-2
```

## ДЗ №2

Добавлены `categories` и `dish_categories` для M:N между блюдами и категориями.

Для сдачи ДЗ №2:
- `sql/01_create_tables.sql` — схема, ограничения и индексы;
- `sql/03_constraint_violations.sql` — демонстрация нарушений;
- `docs/homework_2.md` — документация.

