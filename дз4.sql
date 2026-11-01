--1.1
select flight_no, departure_airport, actual_departure        
FROM flights
WHERE status = 'Arrived'                       
  AND departure_airport IN ('SVO', 'DME', 'VKO') 
  AND actual_departure >= '2017-08-01'         
  AND actual_departure <  '2017-09-01'        
ORDER BY actual_departure;                  

--1.2
select flight_no, scheduled_arrival, actual_arrival,                                              
    EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60 AS delay_minutes 
FROM flights
WHERE status = 'Arrived'
  AND actual_arrival IS NOT NULL                                   
  AND actual_arrival - scheduled_arrival > INTERVAL '2 hours'       
ORDER BY delay_minutes DESC;   

--1.3
select flight_no, COUNT(*) AS arrived_count   
FROM flights
WHERE status = 'Arrived'
  AND flight_no LIKE 'PG04%'    
GROUP BY flight_no
ORDER BY flight_no;

--2.1
select departure_airport, COUNT(*) AS flights_count, AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS avg_delay_min 
FROM flights
WHERE actual_arrival IS NOT NULL   
GROUP BY departure_airport
HAVING COUNT(*) > 500              
ORDER BY avg_delay_min DESC;   

--3.1
select t.passenger_name, tf.amount, f.flight_no, dep.city AS from_city, arr.city AS to_city      
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no     
JOIN flights f ON f.flight_id = tf.flight_id      
JOIN airports dep ON dep.airport_code = f.departure_airport  
JOIN airports arr ON arr.airport_code = f.arrival_airport    
ORDER BY tf.amount DESC   
LIMIT 10;    

--3.2
select a.airport_code, a.airport_name, COUNT(f.flight_id) AS departures_count  
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name
ORDER BY departures_count DESC;

--3.3
select t.passenger_id, t.passenger_name, COUNT(*) AS flights_count, SUM(tf.amount) AS total_spent     
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;

--№1
select EXTRACT(MONTH FROM book_date) AS month, SUM(total_amount) AS revenue 
FROM bookings
WHERE book_date >= '2017-01-01'
  AND book_date <  '2018-01-01'
GROUP BY ROLLUP (EXTRACT(MONTH FROM book_date))
HAVING SUM(total_amount) > 10000000000        
    OR EXTRACT(MONTH FROM book_date) IS NULL  
ORDER BY month NULLS LAST;                    

--№2
select a.airport_code, a.airport_name, COUNT(f.flight_id) AS arrived_count  
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code AND f.status = 'Arrived'            
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_count DESC;

--№3
SELECT *
FROM flights
WHERE status = 'Arrived'
  AND actual_departure >= '2017-08-01'
  AND actual_departure <  '2017-09-01'
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6);

--№4
SELECT *
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
);

--№5
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*)
FROM flights
GROUP BY status;

CREATE INDEX idx_flights_status ON flights(status);
VACUUM flights;

EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*)
FROM flights
GROUP BY status;
