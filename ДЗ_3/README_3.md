ДЗ №3. Базовый SQL, DDL/блокировки и Edge Cases

Q1. Уникальные рейсы и сортировка

1. DISTINCT и GROUP BY

```sql
SELECT DISTINCT flight_no
FROM flights
ORDER BY flight_no;
```

```sql
SELECT flight_no
FROM flights
GROUP BY flight_no
ORDER BY flight_no;
```

В данном случае оба запроса дадут одинаковый итоговый набор данных — уникальные номера рейсов в отсортированном виде.

Физический план `EXPLAIN` может отличаться, так как PostgreSQL может выбрать разные способы выполнения запроса.

```sql
EXPLAIN
SELECT DISTINCT flight_no
FROM flights
ORDER BY flight_no;
```

```sql
EXPLAIN
SELECT flight_no
FROM flights
GROUP BY flight_no
ORDER BY flight_no;
```

2. Сортировка

```sql
SELECT flight_no
FROM flights
ORDER BY flight_no;
```

`ASC` можно не указывать, потому что сортировка по возрастанию используется по умолчанию.

При обычной сортировке PostgreSQL учитывает регистр, поэтому значения вроде `PG0001` и `pg0001` могут иметь разный порядок.





Q2. Аэропорты и выручка за билеты

1. Выручка и количество пассажиров

```sql
SELECT
    f.flight_id,
    f.flight_no,
    SUM(tf.amount) AS total_revenue,
    COUNT(DISTINCT t.passenger_id) AS passenger_count
FROM flights f
JOIN ticket_flights tf
    ON tf.flight_id = f.flight_id
JOIN tickets t
    ON t.ticket_no = tf.ticket_no
GROUP BY f.flight_id, f.flight_no
ORDER BY f.flight_id;
```

`SUM(tf.amount)` считает общую стоимость билетов.

`COUNT(DISTINCT t.passenger_id)` считает уникальных пассажиров. Поэтому если один пассажир купил два билета на один рейс, он не будет посчитан дважды.

2. Рейсы без проданных билетов

```sql
SELECT
    f.flight_id,
    f.flight_no,
    COALESCE(SUM(tf.amount), 0) AS total_revenue,
    COUNT(DISTINCT t.passenger_id) AS passenger_count
FROM flights f
LEFT JOIN ticket_flights tf
    ON tf.flight_id = f.flight_id
LEFT JOIN tickets t
    ON t.ticket_no = tf.ticket_no
GROUP BY f.flight_id, f.flight_no
ORDER BY f.flight_id;
```

Используется `LEFT JOIN`, потому что он сохраняет рейсы, даже если для них нет билетов.

`COALESCE` заменяет `NULL` на `0`.





Q3. Отмененные рейсы и города

1. Города без отмененных рейсов

```sql
SELECT DISTINCT a.city
FROM airports a
WHERE NOT EXISTS (
    SELECT 1
    FROM flights f
    WHERE f.departure_airport = a.airport_code
      AND f.status = 'Cancelled'
)
ORDER BY a.city;
```

`NOT EXISTS` позволяет включить в результат город, который есть в `airports`, но вообще не встречается в `flights`.

2. NULL и NOT IN

Для этого запроса лучше использовать `NOT EXISTS`.

`NOT IN` может дать неправильный результат, если подзапрос содержит `NULL`. Сравнение с `NULL` не даёт `TRUE`, поэтому строки могут не попасть в результат.

`NOT EXISTS` такой проблемы не имеет.





Q4. Места на борту и дубликаты

1. Уникальные пассажиры

```sql
SELECT DISTINCT
    b.flight_id,
    b.passenger_id
FROM boardings b
ORDER BY b.flight_id, b.passenger_id;
```

Для подсчёта уникальных пассажиров:

```sql
SELECT
    flight_id,
    COUNT(DISTINCT passenger_id) AS passenger_count
FROM boardings
GROUP BY flight_id
ORDER BY flight_id;
```

`DISTINCT` и `GROUP BY` в простых случаях могут выполняться похожим образом. Точный способ выполнения можно посмотреть через `EXPLAIN`.

2. Посадочный талон без билета

Если использовать `INNER JOIN`, пассажир без соответствующего билета в результат не попадёт.

```sql
SELECT DISTINCT
    b.flight_id,
    t.passenger_id
FROM boardings b
JOIN ticket_flights tf
    ON tf.flight_id = b.flight_id
JOIN tickets t
    ON t.ticket_no = tf.ticket_no
   AND t.passenger_id = b.passenger_id
ORDER BY b.flight_id, t.passenger_id;
```





Q5. DDL и блокировки

1. Добавление колонки

```sql
ALTER TABLE flights
ADD COLUMN weather_data JSONB;
```

`ALTER TABLE` пытается получить блокировку `ACCESS EXCLUSIVE`.

Если другая транзакция выполняет:

```sql
BEGIN;

SELECT COUNT(*)
FROM flights;
```

то `ALTER TABLE` будет ждать завершения этой транзакции.

    2. DEFAULT без переписывания таблицы

```sql
ALTER TABLE flights
ADD COLUMN is_delayed BOOLEAN DEFAULT false;
```

В PostgreSQL 11+ добавление колонки с постоянным значением `DEFAULT` выполняется без полного переписывания таблицы.

Изменение значения по умолчанию:

```sql
ALTER TABLE flights
ALTER COLUMN is_delayed SET DEFAULT true;
```

После этого новые `INSERT`, в которых значение `is_delayed` не указано, будут получать `true`.

3. Создание индекса

Обычный вариант:

```sql
CREATE INDEX idx_flights_status
ON flights(status);
```

Чтобы таблица могла продолжать принимать записи:

```sql
CREATE INDEX CONCURRENTLY idx_flights_status
ON flights(status);
```

Компромисс: `CONCURRENTLY` строит индекс дольше и использует больше ресурсов.





Q6. Агрегация и NULL

1. Средняя задержка

```sql
SELECT
    AVG(actual_departure - scheduled_departure) AS average_delay
FROM flights;
```

Если `actual_departure` равен `NULL`, результат вычитания также будет `NULL`.

`AVG()` не учитывает `NULL`, поэтому такие рейсы не попадут в расчёт среднего значения.

Можно явно исключить такие строки:

```sql
SELECT
    AVG(actual_departure - scheduled_departure) AS average_delay
FROM flights
WHERE actual_departure IS NOT NULL;
```

    2. COUNT и NULL

```sql
SELECT COUNT(aircraft_code)
FROM flights;
```

считает только строки, где `aircraft_code` не равен `NULL`.

А:

```sql
SELECT COUNT(*)
FROM flights;
```

считает все строки.

Для сравнения:

```sql
SELECT
    COUNT(aircraft_code) AS count_aircraft_code,
    COUNT(*) AS count_all
FROM flights;
```

Если `aircraft_code` допускает `NULL`, результаты могут различаться.

Если на уровне схемы установлено `NOT NULL`, результаты будут одинаковыми.
