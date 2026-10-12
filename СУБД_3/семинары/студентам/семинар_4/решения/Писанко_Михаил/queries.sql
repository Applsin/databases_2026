-- ДЗ к семинару 4, база project_db
-- Запускать по одному запросу: курсор в запрос и Ctrl+Enter


-- Задача 1.1
-- Выполненные рейсы из московских аэропортов за август 2017
SELECT flight_no, departure_airport, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND departure_airport IN (SELECT airport_code FROM airports WHERE city = 'Moscow')
  AND actual_departure >= '2017-08-01' AND actual_departure < '2017-09-01'
ORDER BY actual_departure;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, departure_airport, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND departure_airport IN (SELECT airport_code FROM airports WHERE city = 'Moscow')
  AND actual_departure >= '2017-08-01' AND actual_departure < '2017-09-01'
ORDER BY actual_departure;


-- Задача 1.2
-- Рейсы, которые прилетели с опозданием больше 2 часов
SELECT flight_no, scheduled_arrival, actual_arrival,
       ROUND(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS delay_minutes
FROM flights
WHERE actual_arrival - scheduled_arrival > INTERVAL '2 hours'
ORDER BY delay_minutes DESC;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, scheduled_arrival, actual_arrival,
       ROUND(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) AS delay_minutes
FROM flights
WHERE actual_arrival - scheduled_arrival > INTERVAL '2 hours'
ORDER BY delay_minutes DESC;


-- Задача 1.3
-- Сколько выполнено рейсов с каждым номером PG04..
SELECT flight_no, COUNT(*) AS flights_count
FROM flights
WHERE flight_no LIKE 'PG04%'
  AND status = 'Arrived'
GROUP BY flight_no
ORDER BY flight_no;

EXPLAIN (ANALYZE, BUFFERS)
SELECT flight_no, COUNT(*) AS flights_count
FROM flights
WHERE flight_no LIKE 'PG04%'
  AND status = 'Arrived'
GROUP BY flight_no
ORDER BY flight_no;


-- Задача 2.1
-- Для каждого аэропорта вылета: число рейсов и среднее опоздание в минутах
SELECT departure_airport,
       COUNT(*) AS flights_count,
       ROUND(AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60), 2) AS avg_delay_minutes
FROM flights
WHERE status = 'Arrived'
GROUP BY departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_minutes DESC;

EXPLAIN (ANALYZE, BUFFERS)
SELECT departure_airport,
       COUNT(*) AS flights_count,
       ROUND(AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60), 2) AS avg_delay_minutes
FROM flights
WHERE status = 'Arrived'
GROUP BY departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_minutes DESC;


-- Задача 3.1
-- Топ-10 самых дорогих билетов
SELECT tickets.passenger_name, ticket_flights.amount, flights.flight_no,
       (SELECT city FROM airports WHERE airport_code = flights.departure_airport) AS city_from,
       (SELECT city FROM airports WHERE airport_code = flights.arrival_airport) AS city_to
FROM ticket_flights
JOIN tickets ON ticket_flights.ticket_no = tickets.ticket_no
JOIN flights ON ticket_flights.flight_id = flights.flight_id
ORDER BY ticket_flights.amount DESC
LIMIT 10;

EXPLAIN (ANALYZE, BUFFERS)
SELECT tickets.passenger_name, ticket_flights.amount, flights.flight_no,
       (SELECT city FROM airports WHERE airport_code = flights.departure_airport) AS city_from,
       (SELECT city FROM airports WHERE airport_code = flights.arrival_airport) AS city_to
FROM ticket_flights
JOIN tickets ON ticket_flights.ticket_no = tickets.ticket_no
JOIN flights ON ticket_flights.flight_id = flights.flight_id
ORDER BY ticket_flights.amount DESC
LIMIT 10;


-- Задача 3.2
-- Все аэропорты и сколько из них вылетает рейсов (даже если 0)
SELECT airports.airport_code, airports.airport_name, COUNT(flights.flight_id) AS flights_count
FROM airports
LEFT JOIN flights ON airports.airport_code = flights.departure_airport
GROUP BY airports.airport_code, airports.airport_name
ORDER BY flights_count DESC;

EXPLAIN (ANALYZE, BUFFERS)
SELECT airports.airport_code, airports.airport_name, COUNT(flights.flight_id) AS flights_count
FROM airports
LEFT JOIN flights ON airports.airport_code = flights.departure_airport
GROUP BY airports.airport_code, airports.airport_name
ORDER BY flights_count DESC;


-- Задача 3.3
-- Топ-5 пассажиров по сумме потраченных денег
SELECT tickets.passenger_id, tickets.passenger_name, COUNT(*) AS flights_count, SUM(ticket_flights.amount) AS total
FROM tickets
JOIN ticket_flights ON tickets.ticket_no = ticket_flights.ticket_no
GROUP BY tickets.passenger_id, tickets.passenger_name
ORDER BY total DESC
LIMIT 5;

EXPLAIN (ANALYZE, BUFFERS)
SELECT tickets.passenger_id, tickets.passenger_name, COUNT(*) AS flights_count, SUM(ticket_flights.amount) AS total
FROM tickets
JOIN ticket_flights ON tickets.ticket_no = ticket_flights.ticket_no
GROUP BY tickets.passenger_id, tickets.passenger_name
ORDER BY total DESC
LIMIT 5;


-- Задание 1. ROLLUP
-- Выручка по месяцам 2017 года + общий итог, только месяцы больше 10 млрд
-- Строка итога имеет month = NULL, условие OR ... IS NULL нужно, чтобы она не пропала
SELECT EXTRACT(MONTH FROM book_date) AS month, SUM(total_amount) AS revenue
FROM bookings
WHERE EXTRACT(YEAR FROM book_date) = 2017
GROUP BY ROLLUP (EXTRACT(MONTH FROM book_date))
HAVING SUM(total_amount) > 10000000000
    OR EXTRACT(MONTH FROM book_date) IS NULL
ORDER BY month;

EXPLAIN (ANALYZE, BUFFERS)
SELECT EXTRACT(MONTH FROM book_date) AS month, SUM(total_amount) AS revenue
FROM bookings
WHERE EXTRACT(YEAR FROM book_date) = 2017
GROUP BY ROLLUP (EXTRACT(MONTH FROM book_date))
HAVING SUM(total_amount) > 10000000000
    OR EXTRACT(MONTH FROM book_date) IS NULL
ORDER BY month;

-- Для сравнения: все месяцы без HAVING
SELECT EXTRACT(MONTH FROM book_date) AS month, SUM(total_amount) AS revenue
FROM bookings
WHERE EXTRACT(YEAR FROM book_date) = 2017
GROUP BY ROLLUP (EXTRACT(MONTH FROM book_date))
ORDER BY month;


-- Задание 2. LEFT JOIN
-- Сколько рейсов прилетело в каждый аэропорт (условие по статусу в ON)
SELECT airports.airport_code, airports.airport_name, COUNT(flights.flight_id) AS arrived_count
FROM airports
LEFT JOIN flights ON airports.airport_code = flights.arrival_airport AND flights.status = 'Arrived'
GROUP BY airports.airport_code, airports.airport_name
ORDER BY arrived_count;

EXPLAIN (ANALYZE, BUFFERS)
SELECT airports.airport_code, airports.airport_name, COUNT(flights.flight_id) AS arrived_count
FROM airports
LEFT JOIN flights ON airports.airport_code = flights.arrival_airport AND flights.status = 'Arrived'
GROUP BY airports.airport_code, airports.airport_name
ORDER BY arrived_count;

-- Контрольный запуск: то же условие в WHERE
SELECT airports.airport_code, airports.airport_name, COUNT(flights.flight_id) AS arrived_count
FROM airports
LEFT JOIN flights ON airports.airport_code = flights.arrival_airport
WHERE flights.status = 'Arrived'
GROUP BY airports.airport_code, airports.airport_name
ORDER BY arrived_count;

EXPLAIN (ANALYZE, BUFFERS)
SELECT airports.airport_code, airports.airport_name, COUNT(flights.flight_id) AS arrived_count
FROM airports
LEFT JOIN flights ON airports.airport_code = flights.arrival_airport
WHERE flights.status = 'Arrived'
GROUP BY airports.airport_code, airports.airport_name
ORDER BY arrived_count;

-- В Arrived разницы не видно (рейсы прилетали во все аэропорты),
-- поэтому проверим на отменённых рейсах.
-- Условие в ON: 104 строки, рядом COUNT(*) для сравнения
SELECT airports.airport_code, COUNT(flights.flight_id) AS cancelled_count, COUNT(*) AS count_all
FROM airports
LEFT JOIN flights ON airports.airport_code = flights.arrival_airport AND flights.status = 'Cancelled'
GROUP BY airports.airport_code
ORDER BY cancelled_count;

-- Условие в WHERE: 102 строки, аэропорты с нулём пропали
SELECT airports.airport_code, COUNT(flights.flight_id) AS cancelled_count
FROM airports
LEFT JOIN flights ON airports.airport_code = flights.arrival_airport
WHERE flights.status = 'Cancelled'
GROUP BY airports.airport_code
ORDER BY cancelled_count;


-- Задание 3. Выходные дни в августе 2017
-- Неоптимизированный вариант (EXTRACT)
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

-- Оптимизированный вариант (диапазоны дат)
-- выходные августа 2017: 5-6, 12-13, 19-20, 26-27
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

-- Индекса по actual_departure нет, поэтому оба запроса читают всю таблицу.
-- Создадим индекс и посмотрим планы ещё раз
CREATE INDEX idx_flights_actual_departure ON flights(actual_departure);

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

-- Удаляем индекс, чтобы он не мешал остальным заданиям
DROP INDEX idx_flights_actual_departure;
