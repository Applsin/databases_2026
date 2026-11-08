

-------- Задача 1.1
SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM flights f
JOIN airports a ON a.airport_code = f.departure_airport
WHERE f.status = 'Arrived' AND a.city = 'Moscow'
  AND f.actual_departure >= '2017-08-01' AND f.actual_departure < '2017-09-01'
ORDER BY f.actual_departure;

-----EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM flights f
JOIN airports a ON a.airport_code = f.departure_airport
WHERE f.status = 'Arrived' AND a.city = 'Moscow'
  AND f.actual_departure >= '2017-08-01' AND f.actual_departure < '2017-09-01'
ORDER BY f.actual_departure;

------- Задача 1.2
SELECT flight_no, scheduled_arrival, actual_arrival,
       EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60 AS delay_minutes
FROM flights
WHERE status = 'Arrived'
  AND actual_arrival - scheduled_arrival > INTERVAL '2 hours'
ORDER BY delay_minutes DESC;

-------EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, scheduled_arrival, actual_arrival,
       EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60 AS delay_minutes
FROM flights
WHERE status = 'Arrived'
  AND actual_arrival - scheduled_arrival > INTERVAL '2 hours'
ORDER BY delay_minutes DESC;

-------- Задача 1.3
SELECT flight_no, COUNT(*) AS arrived_flights
FROM flights
WHERE flight_no LIKE 'PG04%' AND status = 'Arrived'
GROUP BY flight_no ORDER BY flight_no;

----------EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, COUNT(*) AS arrived_flights
FROM flights
WHERE flight_no LIKE 'PG04%' AND status = 'Arrived'
GROUP BY flight_no ORDER BY flight_no;

---------- Задача 2.1 
SELECT departure_airport, COUNT(*) AS flights_count,
       AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS avg_delay_minutes
FROM flights
WHERE status = 'Arrived'
GROUP BY departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_minutes DESC;

---------EXPLAIN (ANALYZE, BUFFERS)
SELECT departure_airport, COUNT(*) AS flights_count,
       AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS avg_delay_minutes
FROM flights
WHERE status = 'Arrived'
GROUP BY departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_minutes DESC;

-------- Задача 3.1
SELECT t.passenger_name, tf.amount, f.flight_no,
       a_dep.city AS departure_city, a_arr.city AS arrival_city
FROM ticket_flights tf
JOIN tickets  t     ON t.ticket_no  = tf.ticket_no
JOIN flights  f     ON f.flight_id  = tf.flight_id
JOIN airports a_dep ON a_dep.airport_code = f.departure_airport
JOIN airports a_arr ON a_arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC LIMIT 10;

--------EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name, tf.amount, f.flight_no,
       a_dep.city AS departure_city, a_arr.city AS arrival_city
FROM ticket_flights tf
JOIN tickets  t     ON t.ticket_no  = tf.ticket_no
JOIN flights  f     ON f.flight_id  = tf.flight_id
JOIN airports a_dep ON a_dep.airport_code = f.departure_airport
JOIN airports a_arr ON a_arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC LIMIT 10;

------- Задача 3.2
SELECT a.airport_code, a.airport_name, a.city,
       COUNT(f.flight_id) AS departures_count
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name, a.city
ORDER BY departures_count DESC;

------EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, a.city,
       COUNT(f.flight_id) AS departures_count
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name, a.city
ORDER BY departures_count DESC;

------- Задача 3.3
SELECT t.passenger_id, t.passenger_name,
       COUNT(tf.flight_id) AS flights_count, SUM(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC LIMIT 5;

-------EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_id, t.passenger_name,
       COUNT(tf.flight_id) AS flights_count, SUM(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC LIMIT 5;

----- ROLLUP: помесячная выручка за 2017 с итогом
SELECT EXTRACT(MONTH FROM book_date) AS month, SUM(total_amount) AS revenue
FROM bookings
WHERE book_date >= DATE '2017-01-01' AND book_date < DATE '2018-01-01'
GROUP BY ROLLUP (EXTRACT(MONTH FROM book_date))
HAVING SUM(total_amount) > 10000000000
    OR EXTRACT(MONTH FROM book_date) IS NULL
ORDER BY month NULLS LAST;

---------EXPLAIN (ANALYZE, BUFFERS)
SELECT EXTRACT(MONTH FROM book_date) AS month, SUM(total_amount) AS revenue
FROM bookings
WHERE book_date >= DATE '2017-01-01' AND book_date < DATE '2018-01-01'
GROUP BY ROLLUP (EXTRACT(MONTH FROM book_date))
HAVING SUM(total_amount) > 10000000000
    OR EXTRACT(MONTH FROM book_date) IS NULL
ORDER BY month NULLS LAST;

------ LEFT JOIN: условие в ON (правильно)
SELECT a.airport_code, a.airport_name, COUNT(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f
       ON f.arrival_airport = a.airport_code AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC;

------- Контрольный запуск: условие в WHERE
SELECT a.airport_code, a.airport_name, COUNT(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC;

------EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, COUNT(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f
       ON f.arrival_airport = a.airport_code AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC;

------- Sargability ----------
CREATE INDEX IF NOT EXISTS idx_flights_sched_dep ON flights(scheduled_departure);
VACUUM ANALYZE flights;

--------- Неоптимизированный (несаргабельный предикат)
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, scheduled_departure, status
FROM flights
WHERE status = 'Arrived'
  AND EXTRACT(DOW FROM scheduled_departure) IN (6, 0)
  AND scheduled_departure >= '2017-08-01' AND scheduled_departure < '2017-09-01';

--------Оптимизированный (диапазоны дат)
EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, scheduled_departure, status
FROM flights
WHERE status = 'Arrived'
  AND (   (scheduled_departure >= '2017-08-05' AND scheduled_departure < '2017-08-07')
       OR (scheduled_departure >= '2017-08-12' AND scheduled_departure < '2017-08-14')
       OR (scheduled_departure >= '2017-08-19' AND scheduled_departure < '2017-08-21')
       OR (scheduled_departure >= '2017-08-26' AND scheduled_departure < '2017-08-28') );

------ANTI-JOIN
------- NOT IN
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.scheduled_departure
FROM flights f
WHERE f.flight_id NOT IN (
      SELECT tf.flight_id FROM ticket_flights tf
      WHERE tf.fare_conditions = 'Business');

-------NOT EXISTS
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.scheduled_departure
FROM flights f
WHERE NOT EXISTS (
      SELECT 1 FROM ticket_flights tf
      WHERE tf.flight_id = f.flight_id AND tf.fare_conditions = 'Business');

---- Index Only Scan
----- ДО создания индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*) FROM flights GROUP BY status;

CREATE INDEX idx_flights_status ON flights(status);
VACUUM ANALYZE flights;

-------- ПОСЛЕ создания индекса
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*) FROM flights GROUP BY status;