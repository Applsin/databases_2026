-- Задача 1.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM bookings.flights f
JOIN bookings.airports_data a ON f.departure_airport = a.airport_code
WHERE f.status = 'Arrived'
  AND a.city ->> 'ru' = 'Москва'
  AND f.actual_departure >= '2017-08-01'
  AND f.actual_departure <  '2017-09-01'
ORDER BY f.actual_departure ASC;

-- Задача 1.2
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, scheduled_arrival, actual_arrival,
       ROUND(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS delay_minutes
FROM bookings.flights
WHERE actual_arrival > scheduled_arrival + INTERVAL '2 hours'
ORDER BY delay_minutes DESC;


-- Задача 1.3
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, COUNT(*) AS flights_count
FROM bookings.flights
WHERE flight_no LIKE 'PG04%'
  AND status = 'Arrived'
GROUP BY flight_no
ORDER BY flight_no;


-- Задача 2.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT departure_airport, COUNT(*) AS total_flights,
       ROUND(AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60), 1) AS avg_delay_minutes
FROM bookings.flights
WHERE actual_arrival IS NOT NULL
GROUP BY departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_minutes DESC;


-- Задача 3.1
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name, tf.amount, f.flight_no,
       dep.city ->> 'ru' AS departure_city,
       arr.city ->> 'ru' AS arrival_city
FROM bookings.tickets t
JOIN bookings.ticket_flights tf ON t.ticket_no = tf.ticket_no
JOIN bookings.flights f         ON f.flight_id = tf.flight_id
JOIN bookings.airports_data dep ON f.departure_airport = dep.airport_code
JOIN bookings.airports_data arr ON f.arrival_airport = arr.airport_code
ORDER BY tf.amount DESC
LIMIT 10;


-- Задача 3.2
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, COUNT(f.flight_id) AS flights_count
FROM bookings.airports_data a
LEFT JOIN bookings.flights f ON a.airport_code = f.departure_airport
GROUP BY a.airport_code, a.airport_name
ORDER BY flights_count DESC;


-- Задача 3.3
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_id, t.passenger_name, COUNT(tf.flight_id) AS flights_count,
       SUM(tf.amount) AS total_spent
FROM bookings.tickets t
JOIN bookings.ticket_flights tf ON t.ticket_no = tf.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;

--Группировки и многоуровневые итоги (ROLLUP)
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', f.scheduled_departure)::date AS month,
       SUM(tf.amount) AS revenue
FROM bookings.flights f
JOIN bookings.ticket_flights tf ON tf.flight_id = f.flight_id
WHERE f.scheduled_departure >= '2017-01-01'
  AND f.scheduled_departure <  '2018-01-01'
GROUP BY ROLLUP (date_trunc('month', f.scheduled_departure)::date)
HAVING SUM(tf.amount) > 10000000000
    OR GROUPING(date_trunc('month', f.scheduled_departure)::date) = 1
ORDER BY month;

--LEFT JOIN и условная агрегация
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, COUNT(f.flight_id) AS arrived_cnt
FROM bookings.airports_data a
LEFT JOIN bookings.flights f
       ON f.arrival_airport = a.airport_code
      AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt;

--EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, COUNT(f.flight_id) AS arrived_cnt
FROM bookings.airports_data a
LEFT JOIN bookings.flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt;

SELECT COUNT(*) FROM (
    SELECT a.airport_code, a.airport_name, COUNT(f.flight_id) AS arrived_cnt
    FROM bookings.airports_data a
    LEFT JOIN bookings.flights f ON f.arrival_airport = a.airport_code
    WHERE f.status = 'Arrived'
    GROUP BY a.airport_code, a.airport_name
) sub;

--Sargability (Оптимизация предикатов)
--1 неоптимизированный запрос
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, actual_departure
FROM bookings.flights
WHERE status = 'Arrived'
  AND actual_departure >= '2017-08-01'
  AND actual_departure <  '2017-09-01'
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6);
--2 оптимизированный запрос
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, actual_departure
FROM bookings.flights
WHERE status = 'Arrived'
  AND (   (actual_departure >= '2017-08-05' AND actual_departure < '2017-08-07')
       OR (actual_departure >= '2017-08-12' AND actual_departure < '2017-08-14')
       OR (actual_departure >= '2017-08-19' AND actual_departure < '2017-08-21')
       OR (actual_departure >= '2017-08-26' AND actual_departure < '2017-08-28') );

--ANTI-JOIN (Оптимизация отрицания): Найдите все рейсы, на которые не был продан ни один билет бизнес-класса (fare_conditions = 'Business').
--NOT IN
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no
FROM bookings.flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id
    FROM bookings.ticket_flights tf
    WHERE tf.fare_conditions = 'Business'
);
--NOT EXISTS
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no
FROM bookings.flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM bookings.ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
);

--Индексное сканирование (Index Only Scan): 
--До индекса:
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*) FROM bookings.flights GROUP BY status;
--индекс + VACUUM
CREATE INDEX idx_flights_status ON bookings.flights(status);
VACUUM bookings.flights;