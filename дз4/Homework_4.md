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