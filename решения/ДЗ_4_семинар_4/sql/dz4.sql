-- ДЗ 4, семинар 4. База demo-medium-en
-- запуск: psql -U postgres -d demo -f dz4.sql

SET search_path = bookings, public;
SET timezone = 'Europe/Moscow';
SET track_io_timing = on;

-- удаляем индексы из заданий 3 и 8, если остались с прошлого запуска
DROP INDEX IF EXISTS idx_flights_actual_departure;
DROP INDEX IF EXISTS idx_flights_status;


-- ===== Запросы с семинара =====

-- 1.1 рейсы из Москвы за август 2017
SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM flights f
JOIN airports a ON a.airport_code = f.departure_airport
WHERE a.city = 'Moscow' AND f.status = 'Arrived'
  AND f.actual_departure >= '2017-08-01' AND f.actual_departure < '2017-09-01'
ORDER BY f.actual_departure;

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM flights f
JOIN airports a ON a.airport_code = f.departure_airport
WHERE a.city = 'Moscow' AND f.status = 'Arrived'
  AND f.actual_departure >= '2017-08-01' AND f.actual_departure < '2017-09-01'
ORDER BY f.actual_departure;

-- 1.2 опоздание больше 2 часов
SELECT flight_no, scheduled_arrival, actual_arrival,
  round(extract(epoch FROM actual_arrival - scheduled_arrival) / 60) AS delay_min
FROM flights
WHERE actual_arrival - scheduled_arrival > interval '2 hours'
ORDER BY delay_min DESC;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, scheduled_arrival, actual_arrival,
  round(extract(epoch FROM actual_arrival - scheduled_arrival) / 60) AS delay_min
FROM flights
WHERE actual_arrival - scheduled_arrival > interval '2 hours'
ORDER BY delay_min DESC;

-- 1.3 номера PG0400-PG0499, сколько выполнено рейсов
SELECT flight_no, count(*) FILTER (WHERE status = 'Arrived') AS completed
FROM flights
WHERE flight_no >= 'PG0400' AND flight_no < 'PG0500'
GROUP BY flight_no
ORDER BY flight_no;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, count(*) FILTER (WHERE status = 'Arrived') AS completed
FROM flights
WHERE flight_no >= 'PG0400' AND flight_no < 'PG0500'
GROUP BY flight_no
ORDER BY flight_no;

-- то же самое через LIKE, для сравнения
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, count(*) FILTER (WHERE status = 'Arrived') AS completed
FROM flights
WHERE flight_no LIKE 'PG04%'
GROUP BY flight_no
ORDER BY flight_no;

-- 2.1 аэропорты вылета: число рейсов и среднее опоздание
SELECT f.departure_airport, a.airport_name, count(*) AS flights,
  round(avg(extract(epoch FROM f.actual_arrival - f.scheduled_arrival) / 60), 1) AS avg_arrival_delay_min
FROM flights f
JOIN airports a ON a.airport_code = f.departure_airport
GROUP BY f.departure_airport, a.airport_name
HAVING count(*) > 500
ORDER BY avg_arrival_delay_min DESC;

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.departure_airport, a.airport_name, count(*) AS flights,
  round(avg(extract(epoch FROM f.actual_arrival - f.scheduled_arrival) / 60), 1) AS avg_arrival_delay_min
FROM flights f
JOIN airports a ON a.airport_code = f.departure_airport
GROUP BY f.departure_airport, a.airport_name
HAVING count(*) > 500
ORDER BY avg_arrival_delay_min DESC;

-- 3.1 топ-10 самых дорогих билетов
-- (ticket_no в сортировке, потому что у многих билетов одинаковая цена)
SELECT t.passenger_name, tf.amount, f.flight_no,
  dep.city AS departure_city, arr.city AS arrival_city
FROM ticket_flights tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports dep ON dep.airport_code = f.departure_airport
JOIN airports arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC, tf.ticket_no
LIMIT 10;

EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name, tf.amount, f.flight_no,
  dep.city AS departure_city, arr.city AS arrival_city
FROM ticket_flights tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports dep ON dep.airport_code = f.departure_airport
JOIN airports arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC, tf.ticket_no
LIMIT 10;

-- 3.1 быстрее: сначала берем 10 билетов, потом соединяем
SELECT t.passenger_name, tf.amount, f.flight_no,
  dep.city AS departure_city, arr.city AS arrival_city
FROM (SELECT ticket_no, flight_id, amount
      FROM ticket_flights
      ORDER BY amount DESC, ticket_no
      LIMIT 10) tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports dep ON dep.airport_code = f.departure_airport
JOIN airports arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC, tf.ticket_no;

EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name, tf.amount, f.flight_no,
  dep.city AS departure_city, arr.city AS arrival_city
FROM (SELECT ticket_no, flight_id, amount
      FROM ticket_flights
      ORDER BY amount DESC, ticket_no
      LIMIT 10) tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports dep ON dep.airport_code = f.departure_airport
JOIN airports arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC, tf.ticket_no;

-- 3.2 все аэропорты с числом вылетов, включая нулевые
SELECT a.airport_code, a.airport_name, a.city, count(f.flight_id) AS departures
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name, a.city
ORDER BY departures DESC, a.airport_code;

EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, a.city, count(f.flight_id) AS departures
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name, a.city
ORDER BY departures DESC, a.airport_code;

-- 3.3 топ-5 пассажиров по тратам
SELECT t.passenger_id, t.passenger_name, count(*) AS flights, sum(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;

EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_id, t.passenger_name, count(*) AS flights, sum(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;


-- ===== Основные задания =====

-- Задание 1. выручка по месяцам за 2017 + итог (ROLLUP)
SELECT date_trunc('month', book_date)::date AS month, sum(total_amount) AS revenue
FROM bookings
WHERE book_date >= '2017-01-01' AND book_date < '2018-01-01'
GROUP BY ROLLUP (date_trunc('month', book_date))
HAVING sum(total_amount) > 10000000000
  OR GROUPING(date_trunc('month', book_date)) = 1
ORDER BY month NULLS LAST;

EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', book_date)::date AS month, sum(total_amount) AS revenue
FROM bookings
WHERE book_date >= '2017-01-01' AND book_date < '2018-01-01'
GROUP BY ROLLUP (date_trunc('month', book_date))
HAVING sum(total_amount) > 10000000000
  OR GROUPING(date_trunc('month', book_date)) = 1
ORDER BY month NULLS LAST;

-- Задание 2. прибывшие рейсы по аэропортам, условие в ON
SELECT a.airport_code, a.airport_name, count(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC, a.airport_code;

EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, count(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC, a.airport_code;

-- Задание 2. контрольный запуск: условие в WHERE
SELECT a.airport_code, a.airport_name, count(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC, a.airport_code;

EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, count(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC, a.airport_code;

-- Задание 2. то же за один день 15.08.2017, ON и WHERE
SELECT 'ON' AS где_условие, count(*) AS строк, count(*) FILTER (WHERE n = 0) AS с_нулём
FROM (SELECT a.airport_code, count(f.flight_id) AS n
      FROM airports a
      LEFT JOIN flights f ON f.arrival_airport = a.airport_code AND f.status = 'Arrived'
        AND f.actual_arrival >= '2017-08-15' AND f.actual_arrival < '2017-08-16'
      GROUP BY a.airport_code) x
UNION ALL
SELECT 'WHERE', count(*), count(*) FILTER (WHERE n = 0)
FROM (SELECT a.airport_code, count(f.flight_id) AS n
      FROM airports a
      LEFT JOIN flights f ON f.arrival_airport = a.airport_code
      WHERE f.status = 'Arrived'
        AND f.actual_arrival >= '2017-08-15' AND f.actual_arrival < '2017-08-16'
      GROUP BY a.airport_code) x;

-- Задание 2. COUNT(*) и COUNT(f.flight_id) для аэропортов без прилетов
SELECT a.airport_code, count(*) AS "COUNT(*)", count(f.flight_id) AS "COUNT(f.flight_id)"
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code AND f.status = 'Arrived'
  AND f.actual_arrival >= '2017-08-15' AND f.actual_arrival < '2017-08-16'
GROUP BY a.airport_code
HAVING count(f.flight_id) = 0
ORDER BY 1;

-- Задание 3. неоптимизированный вариант (EXTRACT), пока без индекса
SELECT flight_id, flight_no, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND EXTRACT(YEAR FROM actual_departure) = 2017
  AND EXTRACT(MONTH FROM actual_departure) = 8
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6)
ORDER BY actual_departure;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_id, flight_no, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND EXTRACT(YEAR FROM actual_departure) = 2017
  AND EXTRACT(MONTH FROM actual_departure) = 8
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6)
ORDER BY actual_departure;

-- Задание 3. оптимизированный вариант (диапазоны дат)
SELECT flight_id, flight_no, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND ((actual_departure >= '2017-08-05' AND actual_departure < '2017-08-07')
    OR (actual_departure >= '2017-08-12' AND actual_departure < '2017-08-14')
    OR (actual_departure >= '2017-08-19' AND actual_departure < '2017-08-21')
    OR (actual_departure >= '2017-08-26' AND actual_departure < '2017-08-28'))
ORDER BY actual_departure;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_id, flight_no, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND ((actual_departure >= '2017-08-05' AND actual_departure < '2017-08-07')
    OR (actual_departure >= '2017-08-12' AND actual_departure < '2017-08-14')
    OR (actual_departure >= '2017-08-19' AND actual_departure < '2017-08-21')
    OR (actual_departure >= '2017-08-26' AND actual_departure < '2017-08-28'))
ORDER BY actual_departure;

-- Задание 3. создаем индекс по дате вылета и повторяем оба
CREATE INDEX idx_flights_actual_departure ON flights (actual_departure);
ANALYZE flights;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_id, flight_no, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND EXTRACT(YEAR FROM actual_departure) = 2017
  AND EXTRACT(MONTH FROM actual_departure) = 8
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6)
ORDER BY actual_departure;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_id, flight_no, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND ((actual_departure >= '2017-08-05' AND actual_departure < '2017-08-07')
    OR (actual_departure >= '2017-08-12' AND actual_departure < '2017-08-14')
    OR (actual_departure >= '2017-08-19' AND actual_departure < '2017-08-21')
    OR (actual_departure >= '2017-08-26' AND actual_departure < '2017-08-28'))
ORDER BY actual_departure;

DROP INDEX idx_flights_actual_departure;
ANALYZE flights;

-- Задание 7. NOT IN
SELECT f.flight_id, f.flight_no, f.status
FROM flights f
WHERE f.flight_id NOT IN (SELECT tf.flight_id FROM ticket_flights tf
                          WHERE tf.fare_conditions = 'Business');

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.status
FROM flights f
WHERE f.flight_id NOT IN (SELECT tf.flight_id FROM ticket_flights tf
                          WHERE tf.fare_conditions = 'Business');

-- Задание 7. NOT EXISTS
SELECT f.flight_id, f.flight_no, f.status
FROM flights f
WHERE NOT EXISTS (SELECT 1 FROM ticket_flights tf
                  WHERE tf.flight_id = f.flight_id AND tf.fare_conditions = 'Business');

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.status
FROM flights f
WHERE NOT EXISTS (SELECT 1 FROM ticket_flights tf
                  WHERE tf.flight_id = f.flight_id AND tf.fare_conditions = 'Business');

-- Задание 7. маленький work_mem: NOT IN на 50 рейсах и NOT EXISTS на всех
SET work_mem = '64kB';

EXPLAIN (ANALYZE)
SELECT f.flight_id FROM flights f
WHERE f.flight_id <= 50
  AND f.flight_id NOT IN (SELECT tf.flight_id FROM ticket_flights tf
                          WHERE tf.fare_conditions = 'Business');

EXPLAIN (ANALYZE)
SELECT f.flight_id FROM flights f
WHERE NOT EXISTS (SELECT 1 FROM ticket_flights tf
                  WHERE tf.flight_id = f.flight_id AND tf.fare_conditions = 'Business');

RESET work_mem;

-- Задание 7. проверка с NULL в подзапросе
SELECT count(*) AS "NOT IN без NULL"
FROM flights f
WHERE f.flight_id NOT IN (SELECT tf.flight_id FROM ticket_flights tf
                          WHERE tf.fare_conditions = 'Business');

SELECT count(*) AS "NOT IN + один NULL"
FROM flights f
WHERE f.flight_id NOT IN (SELECT tf.flight_id FROM ticket_flights tf
                          WHERE tf.fare_conditions = 'Business'
                          UNION ALL SELECT NULL);

SELECT count(*) AS "NOT EXISTS + тот же NULL"
FROM flights f
WHERE NOT EXISTS (SELECT 1
                  FROM (SELECT tf.flight_id FROM ticket_flights tf
                        WHERE tf.fare_conditions = 'Business'
                        UNION ALL SELECT NULL) s
                  WHERE s.flight_id = f.flight_id);

-- Задание 8. рейсы по статусам, без индекса
SELECT status, count(*)
FROM flights
GROUP BY status;

EXPLAIN (ANALYZE, BUFFERS)
SELECT status, count(*)
FROM flights
GROUP BY status;

-- Задание 8. индекс + VACUUM
CREATE INDEX idx_flights_status ON flights (status);
VACUUM flights;

EXPLAIN (ANALYZE, BUFFERS)
SELECT status, count(*)
FROM flights
GROUP BY status;

-- Задание 8. доп. опыт: после UPDATE и снова после VACUUM
-- UPDATE flights SET status = status WHERE flight_id % 10 = 0;
-- EXPLAIN (ANALYZE, BUFFERS) SELECT status, count(*) FROM flights GROUP BY status;
-- VACUUM flights;
-- EXPLAIN (ANALYZE, BUFFERS) SELECT status, count(*) FROM flights GROUP BY status;
