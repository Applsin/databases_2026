# Памятка: VIEW и MATERIALIZED VIEW в PostgreSQL

## Что это такое

**VIEW (представление)** — виртуальная таблица. Данные **не хранятся**: при каждом обращении выполняется запрос `SELECT`, заданный в определении. Имя представления можно использовать в запросах везде, где можно имя таблицы.

**MATERIALIZED VIEW (материализованное представление)** — хранится в базе **как таблица**, но его содержимое определяется запросом. Это «замороженный» результат запроса: читается мгновенно, но может устаревать.

## Зачем нужны

| VIEW | MATERIALIZED VIEW |
|---|---|
| Инкапсуляция сложных запросов (аналог функции для SQL) | Кэш тяжёлых агрегатов и соединений (витрины данных, отчёты) |
| Единый формат данных для потребителей без изменения схемы | Ускорение повторяющихся аналитических запросов |
| Разграничение доступа: права на VIEW без прав на таблицы | На MV можно строить индексы |
| Всегда актуальные данные | Данные обновляются только через REFRESH |

## Создание

```sql
-- Обычное представление
CREATE OR REPLACE VIEW v_dme_flights AS
SELECT flight_id, flight_no, departure_airport, scheduled_departure
FROM flights
WHERE departure_airport = 'DME'
WITH CHECK OPTION;   -- запрещает INSERT/UPDATE строк, не проходящих WHERE

-- Материализованное представление
CREATE MATERIALIZED VIEW mv_flight_revenue AS
SELECT f.flight_id, f.flight_no,
       COUNT(tf.ticket_no) AS tickets,
       COALESCE(SUM(tf.amount), 0) AS revenue
FROM flights f
LEFT JOIN ticket_flights tf ON f.flight_id = tf.flight_id
GROUP BY f.flight_id, f.flight_no;

-- На MV можно (и нужно) создавать индексы
CREATE UNIQUE INDEX idx_mv_flight_revenue_pk ON mv_flight_revenue(flight_id);
```

## Обновление данных

**Через VIEW:** простые представления (одна таблица, без агрегации/JOIN/GROUP BY) обновляемы автоматически — `INSERT`/`UPDATE`/`DELETE` проходят в базовую таблицу. Неуказанные столбцы получают значения по умолчанию (например, `SERIAL`).

```sql
INSERT INTO v_dme_flights (flight_no, departure_airport, scheduled_departure)
VALUES ('SU9999', 'DME', '2025-06-15 10:00:00');  -- OK, CHECK OPTION соблюдён
```

**MATERIALIZED VIEW напрямую обновлять нельзя** — только пересчитать целиком:

```sql
REFRESH MATERIALIZED VIEW mv_flight_revenue;               -- блокирует чтение
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_flight_revenue;  -- читать можно, нужен уникальный индекс
```

`REFRESH` обычно запускают по расписанию (cron, pg_cron) в часы минимальной нагрузки. Применять MV можно, только если устаревшие данные допустимы требованиями (например, отчёты «на вчера»).

## Триггеры INSTEAD OF для необновляемых VIEW

Сложное VIEW (с JOIN, GROUP BY, агрегатами) обновлять нельзя: по строке представления нельзя однозначно вычислить строку базовой таблицы. Решение — триггер `INSTEAD OF`, который сам описывает, что делать:

```sql
CREATE OR REPLACE FUNCTION trg_update_flight_revenue()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        UPDATE flights SET flight_no = NEW.flight_no WHERE flight_id = NEW.flight_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        DELETE FROM flights WHERE flight_id = OLD.flight_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_v_flight_revenue
INSTEAD OF UPDATE OR DELETE ON v_flight_revenue
FOR EACH ROW EXECUTE FUNCTION trg_update_flight_revenue();

UPDATE v_flight_revenue SET flight_no = 'SU1234NEW' WHERE flight_id = 1;  -- теперь работает
```

**Правила:**
- Триггер `INSTEAD OF` создаётся только на представлениях, всегда `FOR EACH ROW`.
- Функция возвращает `NEW` (для UPDATE/INSERT) или `OLD` (для DELETE).
- Триггер переносит операцию, но **не отменяет ограничения целостности**: FK, CHECK и т.д. продолжают работать на базовых таблицах.
- Для каждой операции (INSERT/UPDATE/DELETE) нужен свой обработчик `TG_OP` в функции (или свой триггер).

## Шпаргалка «что выбрать»

- Нужен просто короткий синоним сложного запроса → **VIEW**.
- Нужно давать доступ к части данных без прав на таблицы → **VIEW** (+ права).
- Тяжёлый отчёт дёргают сто раз в день, данные могут отставать → **MATERIALIZED VIEW** + `REFRESH` по расписанию + уникальный индекс.
- Нужно обновлять данные через сложное представление → **VIEW + INSTEAD OF TRIGGER**.
