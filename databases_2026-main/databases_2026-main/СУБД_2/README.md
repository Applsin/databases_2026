# СУБД_2 — Материалы для студентов

**ССЫЛКА НА ДАМП СУБД: https://edu.postgrespro.ru/demo-medium-en.zip**

**Тема:** Современный SQL: агрегации, подзапросы, оконные функции, CTE. Оптимизация запросов.

## Структура

| Папка | Назначение |
|---|---|
| `семинар_3/` | Семинар №3 (DDL/DML/DCL, блокировки): `конспект_лекции_2.md`, `конспект_семинара_3.md`, `ДЗ_семинар_3.md`, `тест_семинар_3.md`, `seminar3_setup.sh` / `seminar3_cleanup.sql`, `data/demo-medium-en.zip` (дамп демо-БД) |
| `контрольная_1/` | Контрольная работа №1 (без ответов) |

> Семинар №4 (EXPLAIN, sargability, оконные функции, CTE, LATERAL) перенесён в модуль **СУБД_3** — см. `СУБД_3/семинары/студентам/семинар_4/`.

## Запуск окружения (Git Bash)

Команды выполняются **из папки семинара** (например, `студентам/семинар_3/`).

```bash
# шаг 1: развернуть базу demo (распакует дамп из ./data, создаст БД, загрузит ~2-3 мин)
bash seminar3_setup.sh

# шаг 2: подключиться
MSYS_NO_PATHCONV=1 docker exec -it pg16_check psql -U postgres -d demo
```

> Если `семинар_3/data/demo-medium-en.zip` отсутствует, setup скачает дамп с edu.postgrespro.ru автоматически.

## Очистка окружения

```bash
MSYS_NO_PATHCONV=1 docker cp seminar3_cleanup.sql pg16_check:/tmp/seminar3_cleanup.sql
MSYS_NO_PATHCONV=1 docker exec -i pg16_check \
  psql -U postgres -d postgres -f /tmp/seminar3_cleanup.sql
```
