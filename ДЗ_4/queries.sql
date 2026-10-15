-- 1.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_no, a.airport_name ->> 'ru', f.actual_departure
FROM bookings.flights f
JOIN bookings.airports_data a
    ON f.departure_airport = a.airport_code
WHERE f.status = 'Arrived'
  AND a.city ->> 'ru' = 'Москва'
  AND f.actual_departure >= '2017-08-01'
  AND f.actual_departure < '2017-09-01'
ORDER BY f.actual_departure;

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.


-- 1.2
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no,
       scheduled_arrival,
       actual_arrival,
       EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60 AS delay_minutes
FROM bookings.flights
WHERE status = 'Arrived'
  AND actual_arrival > scheduled_arrival + INTERVAL '2 hours'
ORDER BY delay_minutes DESC;

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.


-- 1.3
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, COUNT(*) AS flights_count
FROM bookings.flights
WHERE flight_no LIKE 'PG04%'
  AND status = 'Arrived'
GROUP BY flight_no
ORDER BY flight_no;

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.


-- 2.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT departure_airport,
       COUNT(*) AS flights_count,
       AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS avg_delay_minutes
FROM bookings.flights
GROUP BY departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_minutes DESC;

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.


-- 3.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name,
       tf.amount,
       f.flight_no,
       dep.city ->> 'ru' AS departure_city,
       arr.city ->> 'ru' AS arrival_city
FROM bookings.ticket_flights tf
JOIN bookings.tickets t ON tf.ticket_no = t.ticket_no
JOIN bookings.flights f ON tf.flight_id = f.flight_id
JOIN bookings.airports_data dep ON f.departure_airport = dep.airport_code
JOIN bookings.airports_data arr ON f.arrival_airport = arr.airport_code
ORDER BY tf.amount DESC
LIMIT 10;

-- Диск: чтение с диска было.
-- Кеш: данные также читались из кеша.
-- Индекс: не использовался.


-- 3.2
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name ->> 'ru', COUNT(f.flight_id)
FROM bookings.airports_data a
LEFT JOIN bookings.flights f
    ON a.airport_code = f.departure_airport
GROUP BY a.airport_code, a.airport_name
ORDER BY a.airport_code;

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.


-- 3.3
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_id,
       t.passenger_name,
       COUNT(tf.flight_id) AS flights_count,
       SUM(tf.amount) AS total_spent
FROM bookings.tickets t
JOIN bookings.ticket_flights tf
    ON t.ticket_no = tf.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;

-- Диск: чтение с диска было, также временные данные записывались на диск.
-- Кеш: данные частично читались из кеша.
-- Индекс: не использовался.


-- 1
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    DATE_TRUNC('month', b.book_date) AS month,
    SUM(tf.amount) AS revenue
FROM bookings.bookings b
JOIN bookings.tickets t
    ON b.book_ref = t.book_ref
JOIN bookings.ticket_flights tf
    ON t.ticket_no = tf.ticket_no
WHERE b.book_date >= DATE '2017-01-01'
  AND b.book_date < DATE '2018-01-01'
GROUP BY ROLLUP (DATE_TRUNC('month', b.book_date))
HAVING SUM(tf.amount) > 10000000000
    OR DATE_TRUNC('month', b.book_date) IS NULL
ORDER BY month;

-- Диск: чтение с диска и запись временных данных на диск были.
-- Кеш: данные частично читались из кеша.
-- Индекс: не использовался.

-- HAVING фильтрует месяцы по выручке, а условие IS NULL сохраняет общий итог ROLLUP.
-- В итоговой строке месяц равен NULL, поэтому она проходит фильтр независимо от выручки.


-- 2
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code,
       a.airport_name ->> 'ru',
       COUNT(f.flight_id)
FROM bookings.airports_data a
LEFT JOIN bookings.flights f
    ON a.airport_code = f.arrival_airport
   AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY a.airport_code;

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.

-- COUNT(f.flight_id) считает только найденные рейсы, а COUNT(*) посчитает и строки без совпадений.
-- Hash Right Join сохраняет все строки из airports_data, включая аэропорты без прибывших рейсов.


-- 3 Неоптимизированный запрос
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM bookings.flights
WHERE status = 'Arrived'
  AND actual_departure >= TIMESTAMP '2017-08-01'
  AND actual_departure < TIMESTAMP '2017-09-01'
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6);

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.

-- 3 Запрос с диапазонами дат
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM bookings.flights
WHERE status = 'Arrived'
  AND (
      (actual_departure >= TIMESTAMP '2017-08-05' AND actual_departure < TIMESTAMP '2017-08-07')
      OR (actual_departure >= TIMESTAMP '2017-08-12' AND actual_departure < TIMESTAMP '2017-08-14')
      OR (actual_departure >= TIMESTAMP '2017-08-19' AND actual_departure < TIMESTAMP '2017-08-21')
      OR (actual_departure >= TIMESTAMP '2017-08-26' AND actual_departure < TIMESTAMP '2017-08-28')
  );

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.

-- 3.1: 5,810 мс
-- 3.2: 8,110 мс
-- Оба запроса использовали Seq Scan — последовательное чтение таблицы. В обоих случаях прочитано 832 страницы из кеша, чтения с диска не было.
-- Второй запрос оказался медленнее, потому что PostgreSQL проверял несколько диапазонов дат через OR. Индекс не использовался ни в одном запросе.


-- 4 NOT IN
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no
FROM bookings.flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id
    FROM bookings.ticket_flights tf
    WHERE tf.fare_conditions = 'Business'
);

-- Диск: чтение с диска было.
-- Кеш: данные также читались из кеша.
-- Индекс: не использовался.

-- 4 NOT EXISTS
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no
FROM bookings.flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM bookings.ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
);

-- Диск: чтение с диска было.
-- Кеш: данные также читались из кеша.
-- Индекс: не использовался.

-- NOT EXISTS выполнился быстрее: 160,422 мс против 223,251 мс у NOT IN.
-- Hash Right Anti Join находит рейсы, для которых нет билетов бизнес-класса.
-- NOT IN может некорректно отфильтровать строки, если подзапрос содержит NULL.


-- 5 До создания индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*)
FROM bookings.flights
GROUP BY status;

-- Диск: чтения с диска не было.
-- Кеш: данные читались из кеша.
-- Индекс: не использовался.

-- 5 Создание индекса
CREATE INDEX idx_flights_status ON bookings.flights(status);
VACUUM bookings.flights;

-- 5 После создания индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*)
FROM bookings.flights
GROUP BY status;

-- Диск: чтение с диска было.
-- Кеш: данные также читались из кеша.
-- Индекс: использовался Index Only Scan.

-- Вывод: покрывающий индекс по status ускорил подсчёт рейсов по статусам. Index Only Scan прочитал индекс вместо всей таблицы, хотя часть страниц индекса пришлось прочитать с диска.