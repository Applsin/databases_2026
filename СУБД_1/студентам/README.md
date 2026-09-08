# СУБД_1 — Материалы для студентов

**Тема:** Реляционная модель и моделирование данных. DDL, ограничения, нормальные формы.

## Структура

| Папка/файл | Назначение |
|---|---|
| `семинар_1/` | Семинар №1 (моделирование данных): `конспект_лекции_1.md`, `конспект_семинара_1.md`, `ДЗ_1.md`, `seminar1_setup.sql` / `seminar1_cleanup.sql` (схема `seminar1`) |
| `семинар_2/` | Семинар №2 (DDL, ограничения, НФ): `конспект_семинара_2.md`, `ДЗ_2.md`, `seminar2_setup.sql` / `seminar2_cleanup.sql` (схема `seminar2`), `data/` — CSV для упражнения по загрузке |
| `тест_СУБД_1.md` | Общий тест модуля (семинары №1 и №2, без ответов) |
| `Установка Postgresql на машине.md` | Инструкция по Docker + PostgreSQL 16 |

## Запуск окружения (Git Bash)

Команды выполняются **из папки конкретного семинара** (например, `студентам/семинар_1/`):

```bash
# 1. Поднять контейнер (если ещё не поднят)
docker start pg16_check 2>/dev/null || \
  docker run -d --name pg16_check -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16

# 2. Скопировать setup-скрипт в контейнер и выполнить (пример — семинар 1)
MSYS_NO_PATHCONV=1 docker cp seminar1_setup.sql pg16_check:/tmp/seminar1_setup.sql
MSYS_NO_PATHCONV=1 docker exec -i pg16_check \
  psql -U postgres -d postgres -f /tmp/seminar1_setup.sql

# 3. Подключиться
MSYS_NO_PATHCONV=1 docker exec -it pg16_check psql -U postgres -d postgres

# 4. После занятия — очистка
MSYS_NO_PATHCONV=1 docker cp seminar1_cleanup.sql pg16_check:/tmp/seminar1_cleanup.sql
MSYS_NO_PATHCONV=1 docker exec -i pg16_check \
  psql -U postgres -d postgres -f /tmp/seminar1_cleanup.sql
```

Для семинара 2 те же команды с `seminar2_setup.sql` / `seminar2_cleanup.sql` из папки `студентам/семинар_2/`.
