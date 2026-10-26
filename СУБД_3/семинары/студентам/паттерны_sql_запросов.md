# Паттерны написания SQL-запросов для реляционных таблиц в PostgreSQL

Паттерны написания эффективных и корректных запросов к **реляционным таблицам** (строки/колонки, без JSONB- и массиво-специфики). За основу взят `query-patterns.md` из репозитория damusix/skills, дополнено практиками из сообщества (keyset-пагинация, RETURNING, MERGE, очереди на SKIP LOCKED, покрывающие индексы и др.).

---

## Чтение данных

### 1. SARGability: не оборачивайте колонку в функцию

**Когда применять:** любой предикат по проиндексированной колонке.

**Суть.** Предикат SARGable, если индекс по колонке может быть использован напрямую. Функция, применённая к колонке, отключает индекс.

```sql
-- ПЛОХО: сканирует все строки, чтобы вычислить EXTRACT
SELECT * FROM orders WHERE EXTRACT(YEAR FROM ordered_at) = 2026;

-- ХОРОШО: index seek по (ordered_at)
SELECT * FROM orders
WHERE ordered_at >= '2026-01-01'
  AND ordered_at <  '2027-01-01';
```

**Правило:** функции применяйте к *параметрам*, а не к *колонкам*.

Запасной выход — **индекс по выражению**, но он фиксирует конкретную трансформацию и занимает место:

```sql
CREATE INDEX orders_year_idx ON orders ((EXTRACT(YEAR FROM ordered_at)));
```

**Недостатки/ловушки:** неочевидные случаи — `lower(email) = ...`, `created_at::date = ...`, `col LIKE '%abc'` (внутренний якорь ломает B-Tree; нужен `pg_trgm`). Всегда проверяйте `EXPLAIN`: Seq Scan по большой таблице в точечном запросе — сигнал non-sargable предиката.

---

### 2. Keyset-пагинация вместо OFFSET

**Когда применять:** ленты, бесконечный скролл, постраничный обход больших таблиц.

**Суть.** `OFFSET n` заставляет PostgreSQL **прочитать и отбросить** n строк на каждой странице — глубокие страницы работают всё медленнее (O(n)). Keyset-пагинация запоминает значение ключа последней строки предыдущей страницы и продолжает с него — каждая страница стоит O(page size).

```sql
-- ПЛОХО: страница 1000 = прочитать 10 000 строк
SELECT * FROM orders ORDER BY ordered_at DESC, order_id DESC
LIMIT 10 OFFSET 9990;

-- ХОРОШО: курсор = (ordered_at, order_id) последней строки прошлой страницы
SELECT * FROM orders
WHERE (ordered_at, order_id) < (:last_ordered_at, :last_order_id)
ORDER BY ordered_at DESC, order_id DESC
LIMIT 10;
```

**Схема работы:**

```
стр.1: WHERE ... LIMIT 10  ──► последняя строка: (2026-09-20, 4812) = курсор
стр.2: WHERE (ordered_at, order_id) < (2026-09-20, 4812) LIMIT 10 ──► новый курсор
...    каждая страница — один index seek, скорость не зависит от глубины
```

**Решаемые проблемы:** стабильное время ответа на любой глубине; нет пропусков/дубликатов при вставках между страницами (OFFSET «съезжает»).

**Недостатки:** нельзя «перепрыгнуть на страницу №500» (только next/prev); требует индекса по ключу сортировки и детерминированной сортировки (добавляйте PK в ORDER BY как тай-брейкер).

---

### 3. EXISTS / NOT EXISTS вместо IN / NOT IN

**Когда применять:** полусоединения («клиенты, у которых есть заказы»), антисоединения.

**Суть.** `NOT IN` с подзапросом возвращает **пустой результат**, если в подзапросе есть хоть один NULL — баг трёхзначной логики. `NOT EXISTS` NULL-безопасен и обычно планируется лучше (hash anti-join).

```sql
-- ПЛОХО: вернёт 0 строк, если user_id в disabled_user содержит NULL
SELECT * FROM customer
WHERE user_id NOT IN (SELECT user_id FROM disabled_user);

-- ХОРОШО: NULL-безопасно
SELECT * FROM customer c
WHERE NOT EXISTS (
    SELECT 1 FROM disabled_user d WHERE d.user_id = c.user_id
);
```

**Недостатки:** у `IN` с коротким списком литералов проблем нет — замена нужна именно для подзапросов; `EXISTS` коррелирован с внешним запросом, при отсутствии индекса на соединяемой колонке получится перебор.

---

### 4. LATERAL: подзапрос «на каждую строку»

**Когда применять:** «N последних/лучших объектов на каждого родителя» (3 последних заказа клиента, последний платёж по договору).

**Суть.** `LATERAL` позволяет правой стороне JOIN ссылаться на колонки левой — подзапрос выполняется для каждой строки внешней таблицы, с индексом по FK это дёшево.

```sql
-- Для каждого клиента — 3 последних заказа
SELECT c.customer_no, c.full_name, o.order_no, o.ordered_at
FROM customer c
LEFT JOIN LATERAL (
    SELECT order_no, ordered_at
    FROM orders
    WHERE customer_no = c.customer_no
    ORDER BY ordered_at DESC
    LIMIT 3
) o ON TRUE;
```

`LEFT JOIN LATERAL ... ON TRUE` сохраняет клиентов без заказов; `JOIN LATERAL` — отбрасывает.

**Недостатки:** правый подзапрос выполняется per-row — без индекса `(customer_no, ordered_at)` на большой таблице будет дорого; альтернатива для «одна строка на группу» — `DISTINCT ON` (следующий паттерн).

---

### 5. DISTINCT ON: «первая строка каждой группы»

**Суть.** Идиома PostgreSQL: выбрать одну строку на группу по заданной сортировке. Чище и быстрее, чем `ROW_NUMBER() ... = 1`.

```sql
-- Последний снапшот баланса по каждому счёту
SELECT DISTINCT ON (account_no)
    account_no, snapshot_at, balance
FROM account_balance_snapshot
ORDER BY account_no, snapshot_at DESC;
```

Колонки `DISTINCT ON` должны быть лидирующими в `ORDER BY`. Идеальный индекс: `(account_no, snapshot_at DESC)`.

**Когда НЕ применять:** нужно больше одной строки на группу — используйте `ROW_NUMBER()` или `LATERAL`:

```sql
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY account_no ORDER BY snapshot_at DESC) AS rn
    FROM account_balance_snapshot
) ranked
WHERE rn <= 3;
```

---

### 6. Оконные функции и FILTER

**Суть.** Стандартные оконные функции для нарастающих итогов, ранжирования, сравнения с соседями; плюс `FILTER (WHERE ...)` — чище, чем `CASE WHEN` в агрегатах.

```sql
-- Нарастающий остаток
SELECT account_no, posted_at, amount,
       SUM(amount) OVER (PARTITION BY account_no ORDER BY posted_at) AS running_balance
FROM ledger_entry;

-- Дельта от предыдущей строки
SELECT account_no, posted_at, balance,
       balance - LAG(balance) OVER (PARTITION BY account_no ORDER BY posted_at) AS delta
FROM account_balance_snapshot;

-- Условная агрегация через FILTER
SELECT customer_no,
       COUNT(*) FILTER (WHERE status = 'completed') AS completed_count,
       COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled_count
FROM orders
GROUP BY customer_no;
```

**Ловушка:** рамка по умолчанию `RANGE UNBOUNDED PRECEDING AND CURRENT ROW` включает всех «равных» по ORDER BY (peers) — для точного нарастающего итога указывайте `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` и уникальный ORDER BY.

---

### 7. Рекурсивные CTE для иерархий

**Когда применять:** дерево категорий, оргструктура, BOM (состав изделия), обход графа в реляционной таблице `parent_id`.

```sql
WITH RECURSIVE subordinates AS (
    SELECT employee_id, manager_id, full_name, 1 AS lvl
    FROM employee WHERE employee_id = :root_id
    UNION ALL
    SELECT e.employee_id, e.manager_id, e.full_name, s.lvl + 1
    FROM employee e
    JOIN subordinates s ON e.manager_id = s.employee_id
    WHERE s.lvl < 20                       -- защита от циклов/глубины
)
SELECT * FROM subordinates;
```

**Недостатки:** нет встроенной защиты от циклов (кроме `UNION` вместо `UNION ALL` или ручного массива пути / лимита глубины); на очень глубоких графах уступает специализированным моделям (ltree, closure table).

---

### 8. Иерархическая сборка результата за один round-trip

**Суть.** Для read-эндпоинтов с фиксированной вложенной формой (профиль пользователя с телефонами и адресами) собирайте результат на сервере через составные типы + `array_agg(row(...)::T)` + финальный `to_jsonb`. Это убирает и N+1 запросов, и построчный `json_build_object`.

```sql
CREATE TYPE phone_record AS (phone_no bigint, number text, type text);
CREATE TYPE user_profile_record AS (
    user_no bigint, username text, full_name text, phones phone_record[]
);

CREATE OR REPLACE FUNCTION fn_user_profile(p_user_no bigint)
RETURNS jsonb LANGUAGE sql STABLE AS $$
    SELECT to_jsonb(
        ROW(
            u.user_no, u.username, u.full_name,
            COALESCE((SELECT array_agg(ROW(p.phone_no, p.number, p.type)::phone_record)
                      FROM phone p WHERE p.user_no = u.user_no),
                     ARRAY[]::phone_record[])
        )::user_profile_record
    )
    FROM app_user u WHERE u.user_no = p_user_no;
$$;
```

**Когда НЕ применять:** форма зависит от роли (делайте отдельные view на проекцию); иерархия неограничена/рекурсивна (пагинируйте); вызывающим нужно фильтровать результат (возвращайте строки, а не JSON-блоб). Составные типы — это API-контракт: версионируйте их (`user_profile_v1_record`), ломающие изменения вводите новым типом.

---

## Изменение данных

### 9. INSERT ... ON CONFLICT (идиоматичный UPSERT)

**Суть** при заливке данных задача может частично выполниться, частично нет. Часть данных может залить другой процесс, данные оказались неправильные. Нужно их исправить.

```sql
INSERT INTO customer(email, full_name, updated_at)
VALUES ('alice@example.com', 'Alice Smith', clock_timestamp())
ON CONFLICT (email) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    updated_at = EXCLUDED.updated_at
WHERE customer.full_name IS DISTINCT FROM EXCLUDED.full_name;  -- обновлять только при изменении
```

`EXCLUDED` — строка, которая *была бы* вставлена. Требуется уникальный constraint по колонке конфликта. `DO NOTHING` — вариант «вставь, если нет» (идемпотентные загрузки).

**Почему это паттерн надёжности:** один оператор атомарен — нет гонки «SELECT → INSERT → unique violation», характерной для ручного upsert.

**Недостатки:** `DO UPDATE` пишет новую версию строки даже при фиктивном обновлении (bloat) — поэтому добавляйте `WHERE ... IS DISTINCT FROM`; генерирует WAL на обе ветки.

### 10. MERGE (PostgreSQL 15+): декларативная синхронизация таблиц

**Когда применять:** загрузка справочника/витрины из источника: «обнови совпавшее, вставь новое, удали лишнее» одним оператором.

```sql
MERGE INTO product_stock t
USING staging_stock s ON s.sku = t.sku
WHEN MATCHED THEN
    UPDATE SET qty = s.qty, updated_at = now()
WHEN NOT MATCHED THEN
    INSERT (sku, qty, updated_at) VALUES (s.sku, s.qty, now())
WHEN NOT MATCHED BY SOURCE THEN
    DELETE;
```

**Недостатки:** при конкурентных вставках возможны `unique_violation` (MERGE не является полной заменой ON CONFLICT под гонками); план может быть тяжёлым на больших сторонах — проверяйте `EXPLAIN`.

### 11. RETURNING: результат изменения без второго запроса

**Суть.** `INSERT/UPDATE/DELETE ... RETURNING` возвращает затронутые строки в том же round-trip — убирает SELECT после записи и даёт атомарный ответ «что именно изменилось».

```sql
UPDATE orders
SET status = 'paid'
WHERE order_id = 42
RETURNING order_id, status, updated_at;

DELETE FROM session WHERE expires_at < now()
RETURNING session_id;   -- что реально удалили
```

Связка `WITH ... RETURNING` позволяет строить пайплайны и получать внятную обратную связь от процесса: результат CTE-записи сразу читается дальше.

```sql
WITH moved AS (
    DELETE FROM queue WHERE id = 7 RETURNING payload
)
INSERT INTO archive SELECT * FROM moved;
```

### 12. Батчевые операции вместо построчных циклов

**Суть.** Массовые вставки — `INSERT ... SELECT` или `COPY`; массовые UPDATE/DELETE на огромных таблицах — чанками, чтобы не держать длинные блокировки и не генерировать гигантский WAL одной транзакцией.

```sql
-- Массовая вставка из таблицы
INSERT INTO customer_archive(customer_no, archived_at)
SELECT customer_no, clock_timestamp()
FROM customer
WHERE last_active_at < clock_timestamp() - INTERVAL '2 years';

-- Массовое удаление чанками (цикл до 0 затронутых строк)
DELETE FROM old_logs
WHERE id IN (
    SELECT id FROM old_logs
    WHERE created_at < clock_timestamp() - INTERVAL '90 days'
    LIMIT 10000
);
```

При загрузке из файла — `COPY table FROM ... CSV HEADER` (на порядки быстрее построчных INSERT). Практика из бенчмарков ingest: на больших загрузках создавайте индексы и constraints **после** заливки, потом `ANALYZE`.

**Недостатки:** чанкование = неатомарность всей операции (нужна идемпотентность и возможность докатить); между батчами полезна пауза/throttle, чтобы не душить боевой трафик.

---

## Конкурентный доступ

### 13. Очередь на таблице: SELECT ... FOR UPDATE SKIP LOCKED

**Суть.** Таблица как очередь задач: воркеры захватывают пачку свободных задач без взаимных блокировок — `SKIP LOCKED` пропускает строки, уже захваченные другими.

```sql
BEGIN;
SELECT task_id, payload
FROM task_queue
WHERE status = 'pending'
ORDER BY task_id
LIMIT 10
FOR UPDATE SKIP LOCKED;
-- обработка...
UPDATE task_queue SET status = 'done' WHERE task_id = ANY(:ids);
COMMIT;
```

**Решаемые проблемы:** не нужен отдельный брокер для умеренных нагрузок; атомарность «взял задачу» в одной БД с бизнес-данными (см. Transactional Outbox в файле о переливке).

**Недостатки:** долгая транзакция воркера держит строки и мешает VACUUM; при высоком RPS таблица-очередь становится hotspot — тогда выделенный брокер.

### 14. Безопасное чтение-изменение: изоляция и повторы

**Суть.** Для критичных «прочитал → проверил → записал» используйте `SERIALIZABLE` (или явные блокировки) и повторяйте транзакцию при `40001/40P01` с экспоненциальной задержкой — см. Retry with Backoff в файле о переливке. `SELECT ... FOR UPDATE NOWAIT` позволяет падать быстро вместо ожидания блокировки.

---

## Диагностика и планирование

### 15. Читайте план: EXPLAIN (ANALYZE, BUFFERS)

**Суть.** Паттерн «сначала измерь» перед любой оптимизацией:

```sql
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT ... ;
```

На что смотреть: `Seq Scan` на большой таблице в точечном запросе (non-sargable предикат или нет индекса), расхождение `rows` оценки и факта (устаревшая статистика → `ANALYZE`), `Buffers: ... read` (чтение с диска) vs `hit` (кэш), `Rows Removed by Filter` (предикат отбрасывает почти всё — нужен более точный индекс).

### 16. Покрывающие и частичные индексы

```sql
-- Покрывающий: запрос обслуживается только индексом (index-only scan)
CREATE INDEX orders_customer_idx ON orders (customer_no, ordered_at DESC)
INCLUDE (total, status);

-- Частичный: индекс только по «горячему» подмножеству — меньше и быстрее
CREATE INDEX orders_open_idx ON orders (ordered_at) WHERE status = 'open';
```

**Недостатки:** каждый индекс замедляет запись и занимает место место; частичный индекс применим, только если предикат запроса **подразумевает** условие индекса (проверяйте план).

### 17. Parameter sniffing — в PostgreSQL почти не проблема

**Применять, только если очень уверены в себе** 

PostgreSQL перепланирует prepared statements по фактическим параметрам первые ~5 выполнений, затем может перейти на generic plan при схожей стоимости. Если подозреваете вредный generic plan:

```sql
SET plan_cache_mode = force_custom_plan;   -- на сессию
-- или не используйте prepared statement для конкретного запроса
```

Для большинства нагрузок поведение по умолчанию адекватно — не оптимизируйте преждевременно.

---

## Анти-паттерны (краткая сводка)

| Анти-паттерн | Чем плох | Замена |
| :--- | :--- | :--- |
| Функция на колонке в WHERE | отключает индекс | переписать диапазоном / expression index |
| OFFSET-пагинация на больших таблицах | O(n) на страницу, «съезжает» | keyset-пагинация |
| `NOT IN (subquery)` | NULL ломает результат молча | `NOT EXISTS` |
| N+1 запросов из приложения | round-trip на каждую строку | JOIN / LATERAL / иерархическая сборка |
| Ручной upsert (SELECT→INSERT) | гонка, unique violation | `ON CONFLICT` / `MERGE` |
| Построчные INSERT в цикле | медленно, WAL-шум | `INSERT ... SELECT` / `COPY` / батчи |
| SELECT после INSERT ради id | лишний round-trip | `RETURNING` |
| Один гигантский DELETE | долгая блокировка, раздувание WAL | чанки или `DETACH PARTITION` |

## Чек-лист ревью запроса

- [ ] Предикаты sargable (функции — на параметрах, не на колонках).
- [ ] Пагинация — keyset, с детерминированным ORDER BY (+PK тай-брейкер).
- [ ] `NOT EXISTS` вместо `NOT IN` с подзапросом.
- [ ] Upsert через `ON CONFLICT`; «что изменилось» — через `RETURNING`.
- [ ] Массовые операции — батчами с COMMIT между ними.
- [ ] План проверен: `EXPLAIN (ANALYZE, BUFFERS)`, нет неожиданных Seq Scan.
- [ ] Индексы соответствуют паттернам запросов (покрывающие/частичные где уместно).

## Ссылки

- Базовый источник: damusix/skills — query-patterns.md: https://github.com/damusix/skills/blob/main/postgres-writing-guidelines/references/query-patterns.md
- PostgreSQL Docs — SELECT: https://www.postgresql.org/docs/current/sql-select.html
- PostgreSQL Docs — INSERT ON CONFLICT: https://www.postgresql.org/docs/current/sql-insert.html
- PostgreSQL Docs — MERGE: https://www.postgresql.org/docs/current/sql-merge.html
- PostgreSQL Docs — Index-Only Scans и covering indexes: https://www.postgresql.org/docs/current/indexes-index-only-scans.html
- Supabase Postgres Best Practices (категории data-/query-: пагинация, upsert, N+1): https://github.com/supabase/agent-skills
- Use The Index, Luke — keyset pagination: https://use-the-index-luke.com/no-offset

## Книги

- Маркус Винанд, «SQL Performance Explained» (рус. «SQL-оптимизация. Просто и понятно», сайт Use The Index, Luke) — sargability, индексы, keyset-пагинация.
- Билл Карвин, «SQL. Антипаттерны» (SQL Antipatterns) — систематика типовых ошибок в запросах и моделях.
- Егор Рогов, «PostgreSQL изнутри» (PostgreSQL Internals) — как планировщик и исполнитель выполняют ваши запросы: сканы, соединения, статистика.
- Джон Виескас и др., «Эффективный SQL. 61 способ улучшить запрос» (Effective SQL) — практические приёмы написания запросов.
- Сильвия Мёстл Василик, «SQL. Задачи и решения» (SQL Practice Problems) — задачник для отработки паттернов на упражнениях.
