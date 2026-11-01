#!/usr/bin/env python
# coding: utf-8

# # Семинар №8. Программный доступ к БД из Python
# 
# ## Как устроен ноутбук
# 
# 1. Каждая тема идёт по схеме: **теория → демо → упражнение**.
# 2. Ячейки с комментарием `# УПРАЖНЕНИЕ N` — для самостоятельной работы; там стоят `TODO`.
# 3. Полные решения собраны в разделе «Решения» в самом конце. Старайтесь сначала решить сами.
# 4. Выполняйте ячейки **по порядку**: состояние таблиц в БД важно (мы переиспользуем одни и те же таблицы).
# 5. Сброс: `Kernel → Restart & Run All`.
# 
# ## Окружение
# 
# - PostgreSQL 16 слушает `localhost:5432` **внутри контейнера**.
# - Учётные данные БД: пользователь `postgres`, **пароль не требуется** (trust auth для локальных подключений), база `demo`.
# - Jupyter-пароль: `student`.
# 
# ## План
# 
# 1. `psycopg` (DB-API): соединения, курсоры, параметризация.
# 2. Транзакции и `with conn:`.
# 3. SQL-инъекции и почему f-string в SQL — зло.
# 4. Батчевая вставка (`executemany`).
# 5. SQLAlchemy Core (`text()`).
# 6. Pandas: `read_sql` и `chunksize`.
# 7. ORM: модели, M:N, каскады.
# 8. Проблема N+1 и `selectinload`.
# 

# In[2]:


# Проверка окружения и общая конфигурация
import sys
print("Python:", sys.version.split()[0])

import psycopg, sqlalchemy, pandas, numpy
print("psycopg     :", psycopg.__version__)
print("sqlalchemy  :", sqlalchemy.__version__)
print("pandas      :", pandas.__version__)
print("numpy       :", numpy.__version__)

# Параметры подключения (внутри контейнера localhost = этот же контейнер).
# PostgreSQL настроен с trust-аутентификацией для локальных подключений,
# поэтому пароль НЕ требуется и НЕ передаётся.
DB = {
    "host":   "localhost",
    "port":   5432,
    "dbname": "demo",
    "user":   "postgres",
}

PSYCOPG_CONN = (
    f"host={DB['host']} port={DB['port']} dbname={DB['dbname']} "
    f"user={DB['user']}"
)
SQLALCHEMY_URL = (
    f"postgresql+psycopg://{DB['user']}@{DB['host']}:{DB['port']}/{DB['dbname']}"
)

print("\npsycopg DSN      :", PSYCOPG_CONN)
print("SQLAlchemy URL   :", SQLALCHEMY_URL)


# ## 1. Основы `psycopg` (DB-API)
# 
# **DB-API** (PEP 249) — стандарт Python для работы с реляционными БД: `connect()`, `cursor()`, `execute()`, `fetch*()`. У каждого драйвера свой диалект, но интерфейс общий.
# 
# Пакет `psycopg` (v3) — современный драйвер PostgreSQL. Что важно знать:
# 
# - **Соединение** открывается через `psycopg.connect(conn_string)`; его **обязательно** закрывать. Лучший способ — менеджер контекста `with psycopg.connect(...) as conn`.
# - **Курсор** — объект, через который выполняются запросы; тоже умеет `with`.
# - `cur.execute(sql, params)` — два аргумента: SQL-шаблон и кортеж/список параметров. Драйвер сам корректно экранирует и передаёт значения по бинарному протоколу. **Никогда не склеивайте SQL строками**.
# - `cur.fetchone()` / `cur.fetchall()` / итерация по `cur` — способы получить результат.
# - `psycopg.connect(..., row_factory=dict_row)` — строки как словари вместо кортежей.
# - `psycopg.connect(...)` при выходе из `with` вызывает `close()`. Обратите внимание: `commit/rollback` на этом уровне **не** делается — это уже часть транзакций (см. тему 2).
# - В реальных веб-приложениях напрямую `connect` почти не используют — берут пул (`psycopg_pool.ConnectionPool` или `QueuePool` в SQLAlchemy), потому что открытие нового TCP-соединения и форк бэкенд-процесса PG — дорого.
# 

# In[3]:


import psycopg
from psycopg.rows import dict_row

# --- 1. Версия сервера и типичный SELECT ---
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT version()")
        print("PG version:", cur.fetchone()[0].split(" on ")[0])

# --- 2. DDL + DML + чтение в одной транзакции ---
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS demo_items")
        cur.execute("CREATE TABLE demo_items (id INT PRIMARY KEY, name TEXT, qty INT)")
        cur.execute(
            "INSERT INTO demo_items (id, name, qty) VALUES (%s, %s, %s), (%s, %s, %s)",
            (1, "apple", 10, 2, "banana", 20),
        )
    conn.commit()

    with conn.cursor() as cur:
        cur.execute("SELECT id, name, qty FROM demo_items ORDER BY id")
        print("\nrows (tuples):")
        for row in cur.fetchall():
            print(" ", row)

# --- 3. То же самое, но со словарями ---
with psycopg.connect(PSYCOPG_CONN, row_factory=dict_row) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT id, name, qty FROM demo_items ORDER BY id")
        print("\nrows (dict_row):")
        for row in cur.fetchall():
            print(" ", row)


# ### Упражнение 1. Параметризованный поиск
# 
# **Задание.** В таблице `demo_items` найдите запись, где `name` совпадает с `target_name`, и выведите `id, name, qty`.
# 
# **Шаги.**
# 1. Откройте соединение `psycopg.connect(PSYCOPG_CONN)` и курсор.
# 2. Выполните `SELECT id, name, qty FROM demo_items WHERE name = %s` с параметром `(target_name,)`.
# 3. Напечатайте результат.
# 4. Дополнительно: поменяйте `target_name` на `"apple' OR '1'='1"` и убедитесь, что запрос вернул 0 строк — инъекция не сработала.
# 
# **Критерий успеха.** При `target_name = 'apple'` печатается `(1, 'apple', 10)`; при «инъекционном» вводе — пусто.
# 

# In[4]:


# УПРАЖНЕНИЕ 1

target_name = "apple"  # затем попробуйте: "apple' OR '1'='1"

# TODO: with psycopg.connect(PSYCOPG_CONN) as conn:
# TODO:     with conn.cursor() as cur:
# TODO:         cur.execute("SELECT id, name, qty FROM demo_items WHERE name = %s", (target_name,))
# TODO:         for row in cur.fetchall():
# TODO:             print(row)


# ## 2. Транзакции и `with conn:`
# 
# - В PostgreSQL транзакция начинается с первого SQL-запроса.
# - В psycopg3 у соединения есть метод `conn.transaction()`, но проще — **менеджер контекста `with conn:`**. Он делает `commit()` при успешном выходе и `rollback()` при любом исключении.
# - **DDL транзакционен** (в отличие, например, от MySQL). Если вы упадёте после `CREATE TABLE` — таблица откатится.
# - **Долгие транзакции — зло.** Пока транзакция открыта, PG не может почистить старые версии строк через `autovacuum` (MVCC, семинар 5). Отсюда bloat. Правило: транзакция должна длиться миллисекунды, а не минуты. Не держите транзакцию, пока ждёте ответа от медленного API.
# 

# In[5]:


from psycopg.errors import UniqueViolation

# Готовим таблицу ВНЕ проблемной транзакции
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS tx_demo")
        cur.execute("CREATE TABLE tx_demo (id INT PRIMARY KEY, name TEXT)")
    conn.commit()

try:
    with psycopg.connect(PSYCOPG_CONN) as conn:
        with conn.cursor() as cur:
            # Дубликат PK -> вторая строка упадёт
            cur.executemany("INSERT INTO tx_demo VALUES (%s, %s)", [(1, "a"), (1, "b")])
        conn.commit()
except UniqueViolation as e:
    print("Поймали UniqueViolation:", str(e).splitlines()[0])
    # with conn: автоматически сделает rollback

# Проверяем: в таблице 0 строк (вставка откатилась целиком)
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM tx_demo")
        print("rows after rollback:", cur.fetchone()[0])


# ### Упражнение 2. Атомарность при ошибке
# 
# **Задание.** Смоделируйте ситуацию, где часть строк вставляется успешно, а затем происходит ошибка, и убедитесь, что откатилось всё.
# 
# **Шаги.**
# 1. В отдельной транзакции создайте таблицу `ex2 (id INT PRIMARY KEY, name TEXT)` — без дубликатов.
# 2. В следующей транзакции выполните `executemany` со списком `[(1,'a'), (2,'b'), (1,'dup')]`.
# 3. Оберните в `try/except UniqueViolation`.
# 4. Проверьте `SELECT count(*) FROM ex2` — должно быть 0 (откатились даже успешные вставки).
# 
# **Критерий успеха.** Счётчик 0, в консоли — сообщение об ошибке.
# 

# In[ ]:


# УПРАЖНЕНИЕ 2

# TODO: создайте таблицу ex2 в отдельной транзакции
# TODO: в следующей транзакции выполните executemany с дубликатом
# TODO: поймайте UniqueViolation
# TODO: напечатайте count(*) из ex2


# ## 3. SQL-инъекции и параметризация
# 
# **SQL-инъекция** — это когда пользовательский ввод попадает в строку SQL и интерпретируется как код.
# 
# - ❌ **Уязвимо:** `cur.execute(f"... WHERE name = '{name}'")`. Если `name = "' OR '1'='1"`, запрос вернёт все строки; если `name = "'; DROP TABLE ...; --"` — таблица исчезнет.
# - ✅ **Безопасно:** `cur.execute("... WHERE name = %s", (name,))`. Данные и SQL идут раздельно, значения передаются по бинарному протоколу и **не могут быть интерпретированы как код**.
# - То же в SQLAlchemy Core: `text("... WHERE name = :name")` + `{"name": ...}`. **Никогда** не подставляйте значения внутрь `text()` через f-строку.
# 

# In[6]:


def unsafe_search(name):
    with psycopg.connect(PSYCOPG_CONN) as conn:
        with conn.cursor() as cur:
            # ❌ f-string — SQL-инъекция
            cur.execute(f"SELECT id, name, qty FROM demo_items WHERE name = '{name}'")
            return cur.fetchall()

def safe_search(name):
    with psycopg.connect(PSYCOPG_CONN) as conn:
        with conn.cursor() as cur:
            # ✅ параметризация
            cur.execute("SELECT id, name, qty FROM demo_items WHERE name = %s", (name,))
            return cur.fetchall()

malicious = "' OR '1'='1' --"
print("unsafe :", unsafe_search(malicious))
print("safe   :", safe_search(malicious))


# ### Упражнение 3. Почините уязвимый запрос
# 
# **Задание.** Дана функция `broken(code)` — она ищет пилота по коду через f-string. Перепишите её безопасно.
# 
# **Шаги.**
# 1. Скопируйте функцию, замените f-string на `%s` + параметр.
# 2. Проверьте: при `code = "' OR '1'='1"` результат должен быть пустым.
# 3. Дополнительно: добавьте `LIMIT 5` в SQL.
# 
# **Критерий успеха.** `broken("' OR '1'='1")` (старая версия) вернёт всё, `fixed("' OR '1'='1")` — пусто.
# 

# In[10]:


# УПРАЖНЕНИЕ 3

def broken(code):
    with psycopg.connect(PSYCOPG_CONN) as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT id, name FROM demo_items WHERE name = '{code}'")
            return cur.fetchall()
def fixed (code): # обьявили функцию fixed с параметром code 
    with psycopg.connect(PSYCOPG_CONN) as conn: #подключились к базе 
        with conn.cursor() as cur: # взяли курсор 
            cur.execute("SELECT id, name FROM demo_items WHERE name = %s LIMIT 5", (code,)) #передаем значения по отдельности 
            return cur.fetchall() #отдали все значения 
attack = "' OR '1'='1"
print("broken:", broken(attack))
print("fixed:", fixed(attack))

# TODO: напишите безопасную версию fixed(code)
# TODO: проверьте на "' OR '1'='1"


# ## 4. Батчевая вставка: `executemany`
# 
# - Цикл `for row in rows: cur.execute("INSERT ...", row)` — это **N сетевых round-trip'ов** и N записей в WAL. Медленно.
# - `cur.executemany(sql, list_of_tuples)` — один вызов, драйвер группирует строки в пакеты.
# - В `psycopg3` (≥3.1) `executemany` дополнительно объединяет несколько `INSERT` в один `pipeline`-пакет.
# - Для по-настоящему больших объёмов (миллионы строк) есть отдельный, ещё более быстрый протокол — `COPY` (`cur.copy()`), но `executemany` — уже огромный шаг вперёд по сравнению с циклом.
# 

# In[ ]:


import time, random

N = 3000
rows = [(i, f"item_{i}", random.randint(1, 100)) for i in range(1, N + 1)]

# Готовим таблицу
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS bench")
        cur.execute("CREATE TABLE bench (id INT PRIMARY KEY, name TEXT, val INT)")
    conn.commit()

# 1) Цикл
t0 = time.perf_counter()
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        for r in rows:
            cur.execute("INSERT INTO bench VALUES (%s, %s, %s)", r)
    conn.commit()
t_loop = time.perf_counter() - t0
print(f"цикл         : {t_loop:.2f}s")

# 2) executemany
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("TRUNCATE bench")
    conn.commit()

t0 = time.perf_counter()
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.executemany("INSERT INTO bench VALUES (%s, %s, %s)", rows)
    conn.commit()
t_batch = time.perf_counter() - t0
print(f"executemany  : {t_batch:.2f}s")
print(f"ускорение    : x{t_loop / max(t_batch, 1e-9):.1f}")


# ### Упражнение 4. Батч на 10 000 строк
# 
# **Задание.** Сравните цикл и `executemany` на 10 000 строк и найдите порог, на котором `executemany` стабильно быстрее.
# 
# **Шаги.**
# 1. Сгенерируйте 10 000 кортежей `(id, name, val)`.
# 2. Замерьте цикл, замерьте `executemany`.
# 3. Напечатайте `speedup = t_loop / t_batch`.
# 4. **Вопрос на подумать:** почему `executemany` не «в N раз быстрее» линейно?
# 
# **Критерий успеха.** `speedup > 5`. В комментарии — 1–2 строки объяснения.
# 

# In[20]:


# УПРАЖНЕНИЕ 4
import time, random # подключаем инструменты 
N = 10000
rows = [(i, f"item_{i}", random.randint(1, 100)) for i in range (1, N + 1)] #создаем данные и кладем в них значение 10 000
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur: # создаем пустую таблицу 
        cur.execute("DROP TABLE IF EXISTS bench10k")
        cur.execute("CREATE TABLE bench10k( id INT PRIMARY KEY, name TEXT, val INT)")
        conn.commit()
t0 = time.perf_counter() #первый способ это цикл 
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        for r in rows:
            cur.execute("INSERT INTO bench10k VALUES (%s, %s, %s)", r)
    conn.commit()
t_loop = time.perf_counter() - t0
print(f" цикл      : {t_loop:.2f}s")
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("TRUNCATE bench10k")
    conn.commit()
t0 = time.perf_counter() # второй способ executemany
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.executemany("INSERT INTO bench10k VALUES (%s, %s, %s)", rows)
    conn.commit()
t_batch = time.perf_counter() - t0
print(f"executemany  : {t_batch:.2f}s")
print(f"ускорение    : x{t_loop / max(t_batch, 1e-9):.1f}") # сравниваем 



# ## 5. SQLAlchemy Core
# 
# **Core** — это слой выражений SQL поверх DB-API. Даёт:
# 
# - **Пул соединений** из коробки (`QueuePool`).
# - **Параметризацию:** `text("WHERE x = :x")` + `[{...}, {...}]` — автоматически превращается в `executemany`.
# - Единый интерфейс к PostgreSQL / SQLite / MySQL.
# 
# Ключевые вещи:
# - `create_engine(url, echo=False)` — движок, управляет пулом. `echo=True` печатает SQL в консоль (обязательно при отладке ORM).
# - `text("SELECT ... :param")` — обёртка над строкой SQL. Параметры — именованные `:name`. **f-строки внутрь `text()` нельзя.**
# - `engine.connect()` → `conn.execute(stmt, params)` → `conn.commit()`.
# - Если второй аргумент `execute` — список словарей, Core сам выполнит `executemany`.
# 

# In[25]:


from sqlalchemy import create_engine, text

engine = create_engine(SQLALCHEMY_URL, echo=False)

# --- DDL + батчевая вставка через Core ---
with engine.connect() as conn:
    conn.execute(text("DROP TABLE IF EXISTS core_demo"))
    conn.execute(text("CREATE TABLE core_demo (id INT PRIMARY KEY, sensor TEXT, val NUMERIC)"))
    conn.commit()

    records = [
        {"id": i, "s": f"SENSOR_{i % 7}", "v": round((i * 0.37) % 100, 2)}
        for i in range(1, 501)
    ]
    # список dict -> автоматически executemany
    conn.execute(
        text("INSERT INTO core_demo (id, sensor, val) VALUES (:id, :s, :v)"),
        records,
    )
    conn.commit()
    print(f"Вставлено {len(records)} строк через Core.executemany")

    # Простой агрегат через Core
    row = conn.execute(
        text("SELECT count(*), max(val) FROM core_demo WHERE val > :threshold"),
        {"threshold": 50},
    ).one()
    print(f"Строк с val > 50: {row[0]}, максимум: {row[1]}")


# ### Упражнение 5. Core: создать таблицу и залить батч
# 
# **Задание.** Через `text()` и `engine.connect()` создайте таблицу `ex5_measurements (id, sensor, value)` и вставьте 200 строк списком словарей.
# 
# **Шаги.**
# 1. `DROP TABLE IF EXISTS ex5_measurements` и `CREATE TABLE ...`.
# 2. Сгенерируйте `records` — список словарей `{"id", "sensor", "value"}` на 200 элементов.
# 3. Один вызов `conn.execute(text("INSERT ..."), records)`.
# 4. Проверьте: `SELECT count(*) FROM ex5_measurements WHERE value > 50`.
# 
# **Критерий успеха.** В консоли: `count > 0`. В логах — один `INSERT` (executemany), не 200.
# 

# In[28]:


# УПРАЖНЕНИЕ 5
with engine.connect() as conn:
    conn.execute(text("DROP TABLE IF EXISTS ex5_measurements")) # создаем таблицу
    conn.execute(text("CREATE TABLE ex5_measurements (id INT PRIMARY KEY, sensor TEXT, value NUMERIC)"))
    conn.commit()

    records = [ # готовим данные
        {"id": i, "sensor": f"S{i % 4}", "value": i * 0.7}
        for i in range(1, 201)
    ]

    conn.execute( # вставляем все одним вызовом
        text("INSERT INTO ex5_measurements (id, sensor, value) VALUES (:id, :sensor, :value)"),
        records,
    )
    conn.commit()

    row = conn.execute( # считаем строки
        text("SELECT count(*) FROM ex5_measurements WHERE value > :t"),
        {"t": 50},
    ).one()
    print("count > 50:", row[0])


# ## 6. Pandas + `chunksize`
# 
# `pandas` — in-memory аналитика. **DataFrame** — это таблица в RAM.
# 
# - `pd.read_sql(query, engine, chunksize=500)` возвращает **итератор** по чанкам. Так вы не выгрузите 10 ГБ в 8 ГБ RAM.
# - `np.where(cond, a, b)` — векторизованный `CASE WHEN`. Работает на C, а не в Python-цикле.
# - `chunk[chunk['col'] > 0]` — фильтрация тоже векторизована.
# 
# **Разделение труда:** PostgreSQL — для OLTP и сложных `JOIN`. Pandas — для математических трансформаций, feature engineering, агрегатов «в памяти».
# 

# In[29]:


import pandas as pd
import numpy as np

total = {"HIGH": 0, "LOW": 0}
for chunk in pd.read_sql("SELECT * FROM core_demo", engine, chunksize=200):
    chunk["level"] = np.where(chunk["val"] > 50, "HIGH", "LOW")
    vc = chunk["level"].value_counts()
    for k in total:
        total[k] += int(vc.get(k, 0))
print("По всей таблице:", total)
print("Строк всего   :", sum(total.values()))


# ### Упражнение 6. Агрегат по сенсорам
# 
# **Задание.** Читая `ex5_measurements` чанками по 50, посчитайте среднее `value` и количество замеров по каждому `sensor`.
# 
# **Шаги.**
# 1. Итерируйтесь `pd.read_sql(..., engine, chunksize=50)`.
# 2. Для каждого чанка считайте `groupby("sensor").agg(mean=("value","mean"), n=("value","size"))`.
# 3. Соберите результаты в словарь `{sensor: {"sum": ..., "n": ...}}` (агрегируйте среднее, пересчитывая взвешенно).
# 4. Напечатайте итоговую таблицу.
# 
# **Критерий успеха.** Сумма `n` по всем сенсорам == общее число строк в `ex5_measurements`.
# 

# In[ ]:


# УПРАЖНЕНИЕ 6

# TODO: читайте чанки и агрегируйте по sensor
# TODO: напечатайте (sensor, mean, count)


# ## 7. SQLAlchemy ORM
# 
# ORM мапит таблицы на Python-классы. Удобно для CRUD, но требует дисциплины.
# 
# - Наследуемся от `DeclarativeBase`; колонки описываем через `Mapped[T] = mapped_column(...)`.
# - **M:N** — через ассоциативную `Table`, в `relationship(secondary=assoc)`.
# - **Каскад** — `ondelete='CASCADE'` **на уровне БД** (в `ForeignKey`). Это быстрее, чем ORM-каскад: PG удалит сам, без выборки всех дочерних строк в память.
# - `with Session(engine) as s:` — сессия. `s.add(obj)`, `s.commit()`, `s.delete(obj)`, `s.scalars(select(...))`.
# - `engine.echo = True` — печатать SQL в консоль (включайте при отладке!).
# 

# In[ ]:


from sqlalchemy import ForeignKey, String, Table, Column, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session

class Base(DeclarativeBase):
    pass

pilot_aircraft = Table(
    "pilot_aircraft", Base.metadata,
    Column("pilot_id", ForeignKey("pilots.id", ondelete="CASCADE"), primary_key=True),
    Column("aircraft_code", ForeignKey("aircrafts_orm.aircraft_code", ondelete="CASCADE"), primary_key=True),
)

class Aircraft(Base):
    __tablename__ = "aircrafts_orm"
    aircraft_code: Mapped[str] = mapped_column(String(3), primary_key=True)
    model:         Mapped[str] = mapped_column(String(50))
    pilots: Mapped[list["Pilot"]] = relationship(secondary=pilot_aircraft, back_populates="aircrafts")

class Pilot(Base):
    __tablename__ = "pilots"
    id:   Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    aircrafts: Mapped[list["Aircraft"]] = relationship(secondary=pilot_aircraft, back_populates="pilots")

Base.metadata.drop_all(engine)
Base.metadata.create_all(engine)

with Session(engine) as s:
    boeing = Aircraft(aircraft_code="773", model="Boeing 777-300")
    p1 = Pilot(name="Иван", aircrafts=[boeing])
    s.add(p1)
    s.commit()

    # Каскадное удаление
    to_del = s.query(Pilot).filter_by(name="Иван").first()
    s.delete(to_del)
    s.commit()

    # Связей не осталось?
    links = s.execute(select(pilot_aircraft)).fetchall()
    print("Связей после каскада:", len(links))   # 0


# ### Упражнение 7. Своя M:N-модель
# 
# **Задание.** Опишите M:N между `Author` и `Book` через ассоциативную `author_book`.
# 
# **Шаги.**
# 1. Объявите `Author` (id, name) и `Book` (id, title) и `author_book` через `Table`.
# 2. В `relationship` пропишите `secondary=author_book` и `back_populates` с обеих сторон.
# 3. `create_all`.
# 4. Добавьте 2 авторов и 3 книги (некоторые — с двумя авторами).
# 5. Удалите одного автора и проверьте, что связи в `author_book` для него исчезли, а книги, у которых были другие авторы, остались.
# 
# **Критерий успеха.** До удаления связей 3–4, после удаления — меньше на число связей удалённого автора.
# 

# In[ ]:


# УПРАЖНЕНИЕ 7

# TODO: Base2 = type("Base2", (DeclarativeBase,), {})
# TODO: author_book = Table(...)
# TODO: class Author(Base2): ...
# TODO: class Book(Base2): ...
# TODO: Base2.metadata.create_all(engine)
# TODO: добавьте данные и проверьте каскад


# ## 8. Проблема N+1 и `selectinload`
# 
# **N+1** — это когда вы делаете **1** запрос за родителями, а потом в цикле дёргаете `p.children` — и ORM делает ещё **N** запросов (по одному на родителя). Итого `N+1` сетевых обращений вместо двух.
# 
# Как поймать: `engine.echo=True` — в логах видно один `SELECT ... FROM parents` и N однотипных `SELECT ... FROM children WHERE parent_id = ...`.
# 
# Как лечить:
# - `selectinload(Parent.children)` — ровно **2** запроса: `SELECT parents` + `SELECT children WHERE parent_id IN (...)`. Часто рекомендуемый дефолт.
# - `joinedload(Parent.children)` — **1** запрос с `LEFT OUTER JOIN`, но с дублями родительских колонок. На широких таблицах — лишний трафик. Требует `.unique()` при использовании с `scalars().all()`.
# 

# In[ ]:


from sqlalchemy import event
from sqlalchemy.orm import selectinload

def count_queries(fn):
    """Считает SQL-запросы, которые выполнит fn()."""
    counter = {"n": 0}
    def before(conn, cursor, statement, params, ctx, many):
        counter["n"] += 1
    event.listen(engine, "before_cursor_execute", before)
    try:
        result = fn()
    finally:
        event.remove(engine, "before_cursor_execute", before)
    return result, counter["n"]

# Готовим данные: 5 пилотов, у каждого 2 самолёта
with Session(engine) as s:
    s.query(Pilot).delete()
    s.query(Aircraft).delete()
    s.commit()
    for i in range(5):
        a1 = Aircraft(aircraft_code=f"A{i}1", model=f"Model {i}-1")
        a2 = Aircraft(aircraft_code=f"A{i}2", model=f"Model {i}-2")
        s.add(Pilot(name=f"Pilot_{i}", aircrafts=[a1, a2]))
    s.commit()

def lazy_load():
    with Session(engine) as s:
        pilots = s.scalars(select(Pilot)).all()
        for p in pilots:
            _ = p.aircrafts
        return len(pilots)

def eager_load():
    with Session(engine) as s:
        stmt = select(Pilot).options(selectinload(Pilot.aircrafts))
        pilots = s.scalars(stmt).all()
        for p in pilots:
            _ = p.aircrafts
        return len(pilots)

_, n_lazy  = count_queries(lazy_load)
_, n_eager = count_queries(eager_load)
print(f"ленивая (N+1)     : {n_lazy} запросов")
print(f"selectinload      : {n_eager} запросов")


# ### Упражнение 8. `joinedload` и `.unique()`
# 
# **Задание.** Решите ту же задачу через `joinedload` и убедитесь, что запрос действительно один.
# 
# **Шаги.**
# 1. Импортируйте `joinedload` из `sqlalchemy.orm`.
# 2. Замените `selectinload(Pilot.aircrafts)` на `joinedload(Pilot.aircrafts)`.
# 3. Запустите `eager_load()` — получите `InvalidRequestError` (нужна дедупликация).
# 4. Исправьте: `s.scalars(stmt).unique().all()`.
# 5. Пересчитайте запросы через `count_queries`.
# 
# **Критерий успеха.** 1 запрос вместо 2. В комментарии — почему `selectinload` всё равно рекомендуют чаще.
# 

# In[ ]:


# УПРАЖНЕНИЕ 8

from sqlalchemy.orm import joinedload

# TODO: def eager_load_joined():
# TODO:     stmt = select(Pilot).options(joinedload(Pilot.aircrafts))
# TODO:     ... .unique().all()
# TODO: _, n = count_queries(eager_load_joined)
# TODO: print(n)


# ## Итоги семинара
# 
# 1. **psycopg:** соединения через `with`, курсоры через `with`, всегда параметризация `%s`.
# 2. **Транзакции:** `with conn:` → commit/rollback; короткие транзакции; DDL транзакционен.
# 3. **SQL-инъекции:** f-string в SQL — уязвимо; `%s` и `:name` — безопасно.
# 4. **executemany:** один вызов вместо N `execute`; для миллионов строк — `COPY`.
# 5. **SQLAlchemy Core:** `text()` + `engine.connect()` + `executemany` из списка словарей.
# 6. **Pandas:** `read_sql(chunksize=…)` и `np.where` — векторизация; PostgreSQL для JOIN, pandas — для фич.
# 7. **ORM:** `DeclarativeBase`, `relationship(secondary=…)`, `ondelete='CASCADE'` на уровне БД.
# 8. **N+1:** ловится `echo=True`, лечится `selectinload` (обычно) или `joinedload().unique()` (когда важна экономия на количестве запросов).
# 

# ---
# 
# # Решения
# 
# > Дальше — эталонные решения всех 8 упражнений. **Не подглядывайте, пока не попробовали.**
# 

# In[ ]:


# РЕШЕНИЕ 1
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT id, name, qty FROM demo_items WHERE name = %s", ("apple",))
        print("apple :", cur.fetchall())
        cur.execute("SELECT id, name, qty FROM demo_items WHERE name = %s", ("apple' OR '1'='1",))
        print("inject:", cur.fetchall())  # []


# In[ ]:


# РЕШЕНИЕ 2
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS ex2")
        cur.execute("CREATE TABLE ex2 (id INT PRIMARY KEY, name TEXT)")
    conn.commit()

try:
    with psycopg.connect(PSYCOPG_CONN) as conn:
        with conn.cursor() as cur:
            cur.executemany("INSERT INTO ex2 VALUES (%s, %s)", [(1, "a"), (2, "b"), (1, "dup")])
        conn.commit()
except UniqueViolation as e:
    print("caught:", str(e).splitlines()[0])

with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM ex2")
        print("rows after rollback:", cur.fetchone()[0])  # 0


# In[ ]:


# РЕШЕНИЕ 3
def fixed(code):
    with psycopg.connect(PSYCOPG_CONN) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, qty FROM demo_items WHERE name = %s LIMIT 5", (code,))
            return cur.fetchall()

print("broken:", broken("' OR '1'='1"))
print("fixed :", fixed("' OR '1'='1"))


# In[ ]:


# РЕШЕНИЕ 4
import time, random

N = 10_000
rows = [(i, f"item_{i}", random.randint(1, 100)) for i in range(1, N + 1)]

with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS bench10k")
        cur.execute("CREATE TABLE bench10k (id INT PRIMARY KEY, name TEXT, val INT)")
    conn.commit()

t0 = time.perf_counter()
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        for r in rows:
            cur.execute("INSERT INTO bench10k VALUES (%s, %s, %s)", r)
    conn.commit()
t_loop = time.perf_counter() - t0

with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.execute("TRUNCATE bench10k")
    conn.commit()

t0 = time.perf_counter()
with psycopg.connect(PSYCOPG_CONN) as conn:
    with conn.cursor() as cur:
        cur.executemany("INSERT INTO bench10k VALUES (%s, %s, %s)", rows)
    conn.commit()
t_batch = time.perf_counter() - t0

print(f"loop={t_loop:.2f}s  batch={t_batch:.2f}s  speedup=x{t_loop/max(t_batch,1e-9):.1f}")
# Почему не «в N раз быстрее» линейно: часть времени уходит на commit/WAL,
# а с ростом батча растёт время на один пакет; executemany уже почти линейно-эффективен.


# In[ ]:


# РЕШЕНИЕ 5
with engine.connect() as conn:
    conn.execute(text("DROP TABLE IF EXISTS ex5_measurements"))
    conn.execute(text("CREATE TABLE ex5_measurements (id INT PRIMARY KEY, sensor TEXT, value NUMERIC)"))
    conn.commit()
    records = [{"id": i, "sensor": f"S{i%4}", "value": i * 0.7} for i in range(1, 201)]
    conn.execute(
        text("INSERT INTO ex5_measurements (id, sensor, value) VALUES (:id, :sensor, :value)"),
        records,
    )
    conn.commit()
    cnt = conn.execute(text("SELECT count(*) FROM ex5_measurements WHERE value > :t"), {"t": 50}).scalar()
    print("count > 50:", cnt)


# In[ ]:


# РЕШЕНИЕ 6
import pandas as pd

agg = {}
for chunk in pd.read_sql("SELECT sensor, value FROM ex5_measurements", engine, chunksize=50):
    g = chunk.groupby("sensor").agg(mean=("value", "mean"), n=("value", "size"))
    for sensor, row in g.iterrows():
        if sensor not in agg:
            agg[sensor] = {"sum": 0.0, "n": 0}
        agg[sensor]["sum"] += float(row["mean"]) * int(row["n"])
        agg[sensor]["n"]   += int(row["n"])

for s, a in sorted(agg.items()):
    print(f"{s}: mean={a['sum']/a['n']:.2f}, n={a['n']}")
print("total n:", sum(a["n"] for a in agg.values()))


# In[ ]:


# РЕШЕНИЕ 7
from sqlalchemy import ForeignKey, String, Table, Column, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session

class Base2(DeclarativeBase):
    pass

author_book = Table(
    "author_book", Base2.metadata,
    Column("author_id", ForeignKey("authors.id", ondelete="CASCADE"), primary_key=True),
    Column("book_id",   ForeignKey("books.id",   ondelete="CASCADE"), primary_key=True),
)

class Author(Base2):
    __tablename__ = "authors"
    id:   Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    books: Mapped[list["Book"]] = relationship(secondary=author_book, back_populates="authors")

class Book(Base2):
    __tablename__ = "books"
    id:    Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    authors: Mapped[list["Author"]] = relationship(secondary=author_book, back_populates="books")

Base2.metadata.drop_all(engine)
Base2.metadata.create_all(engine)

with Session(engine) as s:
    tolstoy = Author(name="Толстой", books=[Book(title="Война и мир"), Book(title="Анна Каренина")])
    dosto   = Author(name="Достоевский", books=[Book(title="Идиот"), Book(title="Война и мир")])
    s.add_all([tolstoy, dosto])
    s.commit()
    print("links before:", len(s.execute(select(author_book)).fetchall()))

    s.delete(s.query(Author).filter_by(name="Толстой").first())
    s.commit()
    print("links after :", len(s.execute(select(author_book)).fetchall()))
    print("books left  :", s.query(Book).count())


# In[ ]:


# РЕШЕНИЕ 8
from sqlalchemy.orm import joinedload

def eager_load_joined():
    with Session(engine) as s:
        stmt = select(Pilot).options(joinedload(Pilot.aircrafts))
        pilots = s.scalars(stmt).unique().all()
        for p in pilots:
            _ = p.aircrafts
        return len(pilots)

_, n_joined = count_queries(eager_load_joined)
print("joinedload queries:", n_joined)  # 1
# Комментарий: selectinload предпочтительнее для больших коллекций,
# потому что не дублирует родительские колонки в каждой строке JOIN.

