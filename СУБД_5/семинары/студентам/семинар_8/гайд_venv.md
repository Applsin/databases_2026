# Гайд: настройка Python-окружения (venv) для семинаров

Python нужен начиная с семинара 8 (доступ к БД через psycopg/SQLAlchemy) и далее (семинары 9, 11–13: ETL-пайплайны, pandas, Parquet). Все команды — в **Git Bash** (не в cmd/PowerShell).

## Вариант A. Готовый скрипт курса (рекомендуется)

Из корня проекта (папка `university`):

```bash
bash setup_venv.sh
```

Скрипт создаст `.venv/` в корне проекта и установит все библиотеки.

## Вариант B. Вручную

```bash
# из корня проекта
python -m venv .venv
source .venv/Scripts/activate        # активация (Git Bash, Windows)
python -m pip install --upgrade pip
pip install -r "СУБД_5/семинары/студентам/семинар_8/requirements.txt"
```

## Активация и проверка

```bash
source .venv/Scripts/activate
python -c "import psycopg, sqlalchemy, pandas; print('ок:', sqlalchemy.__version__)"
```

> В Git Bash путь активации — `.venv/Scripts/activate` (не `bin/activate` — это Linux).
> Активировать venv нужно **в каждом новом терминале**.

## Проверка связки с Docker

```bash
docker start pg16_check 2>/dev/null
python -c "import psycopg; print(psycopg.connect('host=localhost port=5432 dbname=postgres user=postgres password=postgres').execute('SELECT version()').fetchone()[0])"
```

Если видите версию PostgreSQL — окружение готово.

## Частые проблемы

| Симптом | Решение |
|---|---|
| `No module named 'psycopg'` | venv не активирован: `source .venv/Scripts/activate` |
| `python: command not found` | Python не в PATH; используйте полный путь `.venv/Scripts/python.exe` или переустановите Python с галочкой «Add to PATH» |
| `connection refused` на 5432 | контейнер не поднят: `docker start pg16_check` |
| кириллица в выводе `?????` | запускайте скрипты с `python -X utf8 script.py` |
| пути `/tmp/...` превращаются в Windows-пути | добавляйте `MSYS_NO_PATHCONV=1` перед `docker exec` |

## Какие библиотеки и зачем

- `psycopg[binary]` — драйвер PostgreSQL (DB-API): соединения, курсоры, COPY.
- `sqlalchemy` — Core (SQL-выражения) и ORM, пул соединений.
- `pandas` + `numpy` — чанкованная загрузка CSV, трансформации, выгрузка витрин.
- `pyarrow` — чтение/запись Parquet (семинар 12, CSV vs Parquet).
