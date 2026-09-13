# Домашнее задание №1. Онлайн-курсы (EdTech)

## Что сделано
Спроектирована база данных для платформы онлайн-обучения.

### Сущности
- User — пользователь (студент, преподаватель, админ).
- Course — курс, созданный преподавателем.
- Lesson — урок внутри курса.
- Enrollment — запись студента на курс.
- Review — отзыв студента на курс.

### Файлы
- schema.sql — SQL-скрипт создания таблиц.
- queries.txt — 5 частых запросов.
- logical.md — логическая модель.

## Как запустить
1. Запустить PostgreSQL:
   docker run --name pg-edtech -e POSTGRES_PASSWORD=secret -p 5432:5432 -d postgres:16
2. Применить схему:
   docker exec -i pg-edtech psql -U postgres < schema.sql