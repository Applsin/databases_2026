-- задача 1.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_no,
       f.departure_airport,
       f.actual_departure
FROM flights f
JOIN airports_data a ON a.airport_code = f.departure_airport
WHERE f.status = 'Arrived'
  AND a.city->>'en' = 'Moscow'
  AND f.actual_departure >= '2017-08-01'
  AND f.actual_departure <  '2017-09-01'
ORDER BY f.actual_departure;

-- Результат (без EXPLAIN):
SELECT f.flight_no,
       f.departure_airport,
       f.actual_departure
FROM flights f
JOIN airports_data a ON a.airport_code = f.departure_airport
WHERE f.status = 'Arrived'
  AND a.city->>'en' = 'Moscow'
  AND f.actual_departure >= '2017-08-01'
  AND f.actual_departure <  '2017-09-01'
ORDER BY f.actual_departure;


--Задача 1.2
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no,
       scheduled_arrival,
       actual_arrival,
       EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60 AS delay_min
FROM flights
WHERE status = 'Arrived'
  AND actual_arrival IS NOT NULL
  AND actual_arrival - scheduled_arrival > INTERVAL '2 hours'
ORDER BY delay_min DESC;

-- Результат:
SELECT flight_no,
       scheduled_arrival,
       actual_arrival,
       EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60 AS delay_min
FROM flights
WHERE status = 'Arrived'
  AND actual_arrival IS NOT NULL
  AND actual_arrival - scheduled_arrival > INTERVAL '2 hours'
ORDER BY delay_min DESC;


--Задача 1.3
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no,
       COUNT(*) AS arrived_cnt
FROM flights
WHERE flight_no::text LIKE 'PG04%'
  AND status = 'Arrived'
GROUP BY flight_no
ORDER BY flight_no;

-- Результат:
SELECT flight_no,
       COUNT(*) AS arrived_cnt
FROM flights
WHERE flight_no::text LIKE 'PG04%'
  AND status = 'Arrived'
GROUP BY flight_no
ORDER BY flight_no;


--Задача 2.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT departure_airport,
       COUNT(*) AS flights_cnt,
       AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS avg_delay_min
FROM flights
WHERE actual_arrival IS NOT NULL
GROUP BY departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_min DESC;

-- Результат:
SELECT departure_airport,
       COUNT(*) AS flights_cnt,
       AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS avg_delay_min
FROM flights
WHERE actual_arrival IS NOT NULL
GROUP BY departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_min DESC;


--Задача 3.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name,
       tf.amount                 AS ticket_price,
       f.flight_no,
       dep.city->>'en'           AS departure_city,
       arr.city->>'en'           AS arrival_city
FROM tickets t
JOIN ticket_flights tf  ON tf.ticket_no = t.ticket_no
JOIN flights        f   ON f.flight_id  = tf.flight_id
JOIN airports_data  dep ON dep.airport_code = f.departure_airport
JOIN airports_data  arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC
LIMIT 10;

-- Результат:
SELECT t.passenger_name,
       tf.amount                 AS ticket_price,
       f.flight_no,
       dep.city->>'en'           AS departure_city,
       arr.city->>'en'           AS arrival_city
FROM tickets t
JOIN ticket_flights tf  ON tf.ticket_no = t.ticket_no
JOIN flights        f   ON f.flight_id  = tf.flight_id
JOIN airports_data  dep ON dep.airport_code = f.departure_airport
JOIN airports_data  arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC
LIMIT 10;


--Задача 3.2
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code,
       a.airport_name->>'en' AS airport_name,
       COUNT(f.flight_id)    AS departures_cnt
FROM airports_data a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name
ORDER BY departures_cnt DESC;

-- Результат:
SELECT a.airport_code,
       a.airport_name->>'en' AS airport_name,
       COUNT(f.flight_id)    AS departures_cnt
FROM airports_data a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name
ORDER BY departures_cnt DESC;


--Задача 3.3
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_id,
       t.passenger_name,
       COUNT(*)       AS flights_cnt,
       SUM(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;

-- Результат:
SELECT t.passenger_id,
       t.passenger_name,
       COUNT(*)       AS flights_cnt,
       SUM(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;


-- ROLLUP + HAVING
EXPLAIN (ANALYZE, BUFFERS)
SELECT DATE_TRUNC('month', b.book_date) AS month,
       SUM(b.total_amount) AS revenue
FROM bookings b
WHERE b.book_date >= '2017-01-01'
  AND b.book_date <  '2018-01-01'
GROUP BY ROLLUP (DATE_TRUNC('month', b.book_date))
HAVING SUM(b.total_amount) > 10000000000
    OR DATE_TRUNC('month', b.book_date) IS NULL
ORDER BY month NULLS LAST;

-- Результат:
SELECT DATE_TRUNC('month', b.book_date) AS month,
       SUM(b.total_amount) AS revenue
FROM bookings b
WHERE b.book_date >= '2017-01-01'
  AND b.book_date <  '2018-01-01'
GROUP BY ROLLUP (DATE_TRUNC('month', b.book_date))
HAVING SUM(b.total_amount) > 10000000000
    OR DATE_TRUNC('month', b.book_date) IS NULL
ORDER BY month NULLS LAST;


-- LEFT JOIN + УСЛОВНАЯ АГРЕГАЦИЯ (правильный вариант)
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code,
       a.airport_name->>'en' AS airport_name,
       COUNT(f.flight_id)    AS arrived_cnt
FROM airports_data a
LEFT JOIN flights f
       ON f.arrival_airport = a.airport_code
      AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt DESC;

-- Результат:
SELECT a.airport_code,
       a.airport_name->>'en' AS airport_name,
       COUNT(f.flight_id)    AS arrived_cnt
FROM airports_data a
LEFT JOIN flights f
       ON f.arrival_airport = a.airport_code
      AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt DESC;


-- LEFT JOIN + УСЛОВНАЯ АГРЕГАЦИЯ (контрольный, НЕПРАВИЛЬНЫЙ вариант)
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code,
       a.airport_name->>'en' AS airport_name,
       COUNT(f.flight_id)    AS arrived_cnt
FROM airports_data a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt DESC;

-- Результат:
SELECT a.airport_code,
       a.airport_name->>'en' AS airport_name,
       COUNT(f.flight_id)    AS arrived_cnt
FROM airports_data a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt DESC;


-- SARGABILITY (неоптимизированный)

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM flights
WHERE status = 'Arrived'
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6)
  AND actual_departure >= '2017-08-01'
  AND actual_departure <  '2017-09-01';

-- Результат:
SELECT *
FROM flights
WHERE status = 'Arrived'
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6)
  AND actual_departure >= '2017-08-01'
  AND actual_departure <  '2017-09-01';



-- SARGABILITY (оптимизированный)

EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM flights
WHERE status = 'Arrived'
  AND (
        (actual_departure >= '2017-08-05' AND actual_departure < '2017-08-07')
     OR (actual_departure >= '2017-08-12' AND actual_departure < '2017-08-14')
     OR (actual_departure >= '2017-08-19' AND actual_departure < '2017-08-21')
     OR (actual_departure >= '2017-08-26' AND actual_departure < '2017-08-28')
      );

-- Результат:
SELECT *
FROM flights
WHERE status = 'Arrived'
  AND (
        (actual_departure >= '2017-08-05' AND actual_departure < '2017-08-07')
     OR (actual_departure >= '2017-08-12' AND actual_departure < '2017-08-14')
     OR (actual_departure >= '2017-08-19' AND actual_departure < '2017-08-21')
     OR (actual_departure >= '2017-08-26' AND actual_departure < '2017-08-28')
      );


-- ANTI-JOIN через NOT IN (потенциально опасный вариант)
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id
    FROM ticket_flights tf
    WHERE tf.fare_conditions = 'Business'
);

-- Результат:
SELECT *
FROM flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id
    FROM ticket_flights tf
    WHERE tf.fare_conditions = 'Business'
);


-- ANTI-JOIN через NOT EXISTS (правильный вариант)
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
);

-- Результат:
SELECT *
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
);


-- INDEX ONLY SCAN

EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*)
FROM flights
GROUP BY status;

-- Результат:
SELECT status, COUNT(*)
FROM flights
GROUP BY status;


-- Шаг 2: создаём покрывающий индекс и обновляем visibility map (VACUUM).
CREATE INDEX idx_flights_status ON flights(status);


-- Шаг 3: замер ПОСЛЕ создания индекса. Ожидаем Index Only Scan + GroupAggregate,

EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*)
FROM flights
GROUP BY status;

-- Результат:
SELECT status, COUNT(*)
FROM flights
GROUP BY status;
