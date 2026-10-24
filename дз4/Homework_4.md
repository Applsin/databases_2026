## Задача 1.1. 
-- EXPLAIN(analyse,BUFFERS)
SELECT flight_no, departure_airport, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND departure_airport IN ('SVO', 'DME', 'VKO')
  AND actual_departure >= '2017-08-01'
  AND actual_departure <  '2017-09-01'
ORDER BY actual_departure;

## Задача 1.2.
-- EXPLAIN(ANALYZE,BUFFERS)
SELECT flight_no,scheduled_arrival,actual_arrival, EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60 AS delay_min
FROM flights
WHERE actual_arrival > scheduled_arrival + INTERVAL '2 hours'
ORDER BY delay_min DESC;

## Задача 1.3.
-- EXPLAIN(ANALYZE,BUFFERS)
SELECT flight_no, COUNT(*) AS flights_cnt
FROM flights
WHERE flight_no LIKE 'PG04%'
GROUP BY flight_no
ORDER BY flight_no;

## Задача 2.1
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT 
	DATE_TRUNC('day', scheduled_departure ) AS flight_date, 
	COUNT(*) AS flight_count
FROM flights
GROUP BY flight_date
ORDER BY flight_date ASC

## Задача 2.2
--EXPLAIN (ANALYZE, BUFFERS)
SELECT 
    ROUND(AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival))) / 60, 2) AS avg_delay,
	departure_airport
FROM flights
WHERE actual_arrival IS NOT NULL AND status = 'Arrived'
GROUP BY departure_airport
ORDER BY avg_delay DESC;

## Задача 3.1
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name, tf.amount, f.flight_no,
       dep.city AS departure_city, arr.city AS arrival_city
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
JOIN flights f         ON f.flight_id = tf.flight_id
JOIN airports dep      ON dep.airport_code = f.departure_airport
JOIN airports arr      ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC
LIMIT 10;

##Задача 3.2
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code, a.airport_name, COUNT(f.flight_id) AS flights_cnt
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name
ORDER BY flights_cnt;

##Задача 3.3
-- EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_id, t.passenger_name, COUNT(*) AS flights_cnt, SUM(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;

--ДЗ
EXPLAIN (ANALYZE, BUFFERS)
SELECT SUM(amount) AS total_amount
FROM ticket_flights, 
WHERE scheduled_departure >= '2017-01-01' AND < '2018-01-01'
GROUP BY ROLLUP (1)
HAVING (amount) OR GROUPING (1)

-- Посчитать прибывшие рейсы (status = 'Arrived') для каждого аэропорта, включая те, куда рейсов нет (0)
SELECT airport_code, airport_name, COUNT(flight_id) AS flights_cnt
FROM airports_data AS a
LEFT JOIN flights as f ON departure_airport AND 
GROUP BY airport_code, airport_name
ORDER BY flights_cnt

--Найти выполненные рейсы (status = 'Arrived') в выходные (суббота, воскресенье) августа 2017.
SELECT flight_no, scheduled_departure, status
FROM flights
WHERE status = 'Arrived'
  AND (
      (scheduled_departure >= '2017-08-05' AND scheduled_departure < '2017-08-07') OR
      (scheduled_departure >= '2017-08-12' AND scheduled_departure < '2017-08-14') OR
      (scheduled_departure >= '2017-08-19' AND scheduled_departure < '2017-08-21') OR
      (scheduled_departure >= '2017-08-26' AND scheduled_departure < '2017-08-28')
  );

--Найти все рейсы, на которые не был продан ни один билет бизнес-класса (fare_conditions = 'Business').
SELECT flight_no, scheduled_departure
FROM flights
WHERE flight_id NOT IN (
    SELECT flight_id 
    FROM ticket_flights 
    WHERE fare_conditions = 'Business'
);



WITH FlightStats AS MATERIALIZED (
    SELECT flight_id, 
           COUNT(ticket_no) AS tickets_sold, 
           SUM(amount) AS total_revenue
    FROM ticket_flights
    GROUP BY flight_id
)
SELECT f.flight_no, 
       f.scheduled_departure, 
       fs.tickets_sold, 
       fs.total_revenue
FROM flights f
JOIN FlightStats fs ON f.flight_id = fs.flight_id
WHERE f.status = 'Arrived'
  AND f.scheduled_departure >= '2017-08-01' 
  AND f.scheduled_departure < '2017-09-01';


