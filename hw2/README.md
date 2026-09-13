# Домашнее задание №2. Онлайн-курсы (EdTech)

## Что сделано

### Часть 1. Дополнение схемы
Добавлены две новые таблицы:
- **LessonProgress** — прогресс студента по каждому уроку (закрывает запрос «история обучения студента»).
- **Payment** — платежи студентов за курсы (закрывает запрос «рассчитать выплаты преподавателю»).

Для обеих таблиц созданы FK, CHECK, UNIQUE, NOT NULL и индексы на внешние ключи.

### Часть 2. Демонстрация нарушений
Скрипт `hw2_demo_violations.sql` содержит 5 блоков `DO $$ ... EXCEPTION ... END $$`:
1. Нарушение CHECK — рейтинг вне диапазона 1–5.
2. Нарушение FOREIGN KEY — запись на несуществующий курс.
3. Нарушение UNIQUE — повторная запись на тот же курс.
4. Нарушение NOT NULL — курс без названия.
5. Нарушение FOREIGN KEY (RESTRICT) — удаление преподавателя с курсами.

Каждый блок перехватывает ошибку и выводит понятное сообщение + технический текст `SQLERRM`.

### Часть 3. Документирование
Таблица нарушений в `hw2_violations_table.md`.

## Как запустить

1. Запустить PostgreSQL:
   docker run --name pg-edtech -e POSTGRES_PASSWORD=secret -p 5432:5432 -d postgres:16

2. Применить схему из ДЗ №1:
   docker exec -i pg-edtech psql -U postgres < hw1/schema.sql

3. Добавить новые таблицы:
   docker exec -i pg-edtech psql -U postgres < hw2/hw2_add_tables.sql

4. Запустить демонстрацию нарушений:
   docker exec -i pg-edtech psql -U postgres < hw2/hw2_demo_violations.sql

## Файлы
- `hw2_add_tables.sql` — две новые таблицы.
- `hw2_demo_violations.sql` — демонстрация 5 нарушений.
- `hw2_violations_table.md` — таблица нарушений и выводы.