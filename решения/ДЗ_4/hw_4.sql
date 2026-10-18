-- ДЗ 4. Advanced SQL и оптимизация запросов
-- База demo (demo-medium-en-20170815.sql).

SET timezone = 'UTC';   -- даты в UTC, как на семинаре
SET track_io_timing = on;


-- Запросы с семинара

-- 1.1. Выполненные рейсы из московских аэропортов за август 2017.
-- Московские аэропорты беру из справочника, а не перечисляю коды руками.
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND f.departure_airport IN (SELECT a.airport_code FROM airports a WHERE a.city = 'Moscow')
  AND f.actual_departure >= '2017-08-01'
  AND f.actual_departure <  '2017-09-01'
ORDER BY f.actual_departure;

SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND f.departure_airport IN (SELECT a.airport_code FROM airports a WHERE a.city = 'Moscow')
  AND f.actual_departure >= '2017-08-01'
  AND f.actual_departure <  '2017-09-01'
ORDER BY f.actual_departure;

-- 1.2. Рейсы с опозданием прибытия больше 2 часов.
-- У отменённых и ещё не прилетевших рейсов actual_arrival = NULL, сравнение даёт NULL,
-- и такие строки отсекаются сами.
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_no,
       f.scheduled_arrival,
       f.actual_arrival,
       ROUND(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_arrival)) / 60) AS delay_min
FROM flights f
WHERE f.actual_arrival > f.scheduled_arrival + INTERVAL '2 hours'
ORDER BY delay_min DESC, f.flight_no;

SELECT f.flight_no,
       f.scheduled_arrival,
       f.actual_arrival,
       ROUND(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_arrival)) / 60) AS delay_min
FROM flights f
WHERE f.actual_arrival > f.scheduled_arrival + INTERVAL '2 hours'
ORDER BY delay_min DESC, f.flight_no;

-- 1.3. Номера PG0400-PG0499: сколько рейсов у каждого номера.
-- Отдельно считаю, сколько из них уже выполнено (Arrived).
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_no,
       COUNT(*)                                     AS flights_cnt,
       COUNT(*) FILTER (WHERE f.status = 'Arrived') AS arrived_cnt
FROM flights f
WHERE f.flight_no LIKE 'PG04%'
GROUP BY f.flight_no
ORDER BY f.flight_no;

SELECT f.flight_no,
       COUNT(*)                                     AS flights_cnt,
       COUNT(*) FILTER (WHERE f.status = 'Arrived') AS arrived_cnt
FROM flights f
WHERE f.flight_no LIKE 'PG04%'
GROUP BY f.flight_no
ORDER BY f.flight_no;

-- 2.1. Аэропорты вылета с числом рейсов > 500 и средним опозданием прибытия.
-- Считаю только прилетевшие рейсы: у остальных опоздание не определено.
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.departure_airport,
       COUNT(*) AS flights_cnt,
       ROUND(AVG(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_arrival)) / 60), 1) AS avg_delay_min
FROM flights f
WHERE f.actual_arrival IS NOT NULL
GROUP BY f.departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_min DESC;

SELECT f.departure_airport,
       COUNT(*) AS flights_cnt,
       ROUND(AVG(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_arrival)) / 60), 1) AS avg_delay_min
FROM flights f
WHERE f.actual_arrival IS NOT NULL
GROUP BY f.departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_min DESC;

-- 3.1. Топ-10 самых дорогих билетов (перелётов) с городами.
-- airports подключаю дважды: для вылета и для прилёта.
-- ticket_no во втором ключе сортировки нужен, чтобы при равных суммах порядок не прыгал.
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_name,
       tf.amount,
       f.flight_no,
       dep.city AS departure_city,
       arr.city AS arrival_city
FROM ticket_flights tf
JOIN tickets  t   ON t.ticket_no = tf.ticket_no
JOIN flights  f   ON f.flight_id = tf.flight_id
JOIN airports dep ON dep.airport_code = f.departure_airport
JOIN airports arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC, tf.ticket_no
LIMIT 10;

SELECT t.passenger_name,
       tf.amount,
       f.flight_no,
       dep.city AS departure_city,
       arr.city AS arrival_city
FROM ticket_flights tf
JOIN tickets  t   ON t.ticket_no = tf.ticket_no
JOIN flights  f   ON f.flight_id = tf.flight_id
JOIN airports dep ON dep.airport_code = f.departure_airport
JOIN airports arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC, tf.ticket_no
LIMIT 10;

-- 3.2. Все аэропорты с числом вылетов, включая аэропорты без рейсов.
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code,
       a.airport_name,
       a.city,
       COUNT(f.flight_id) AS departures_cnt
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name, a.city
ORDER BY departures_cnt, a.airport_code;

SELECT a.airport_code,
       a.airport_name,
       a.city,
       COUNT(f.flight_id) AS departures_cnt
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name, a.city
ORDER BY departures_cnt, a.airport_code;

-- 3.3. Топ-5 пассажиров по сумме трат.
-- Группирую по passenger_id: по одному имени склеились бы разные люди.
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.passenger_id,
       t.passenger_name,
       COUNT(*)       AS flights_cnt,
       SUM(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC, t.passenger_id
LIMIT 5;

SELECT t.passenger_id,
       t.passenger_name,
       COUNT(*)       AS flights_cnt,
       SUM(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC, t.passenger_id
LIMIT 5;


-- Задание 1. ROLLUP: выручка по месяцам 2017 года и общий итог
-- Месяц считаю по плановой дате вылета рейса, как на семинаре.
-- Условие GROUPING(...) = 1 оставляет итоговую строку при любом пороге.
EXPLAIN (ANALYZE, BUFFERS)
SELECT date_trunc('month', f.scheduled_departure)::date AS month,
       SUM(tf.amount) AS revenue
FROM flights f
JOIN ticket_flights tf ON tf.flight_id = f.flight_id
WHERE f.scheduled_departure >= '2017-01-01'
  AND f.scheduled_departure <  '2018-01-01'
GROUP BY ROLLUP (date_trunc('month', f.scheduled_departure))
HAVING SUM(tf.amount) > 10000000000   -- 10 млрд
    OR GROUPING(date_trunc('month', f.scheduled_departure)) = 1
ORDER BY month;

SELECT date_trunc('month', f.scheduled_departure)::date AS month,
       SUM(tf.amount) AS revenue
FROM flights f
JOIN ticket_flights tf ON tf.flight_id = f.flight_id
WHERE f.scheduled_departure >= '2017-01-01'
  AND f.scheduled_departure <  '2018-01-01'
GROUP BY ROLLUP (date_trunc('month', f.scheduled_departure))
HAVING SUM(tf.amount) > 10000000000   -- 10 млрд
    OR GROUPING(date_trunc('month', f.scheduled_departure)) = 1
ORDER BY month;

-- Контроль: все месяцы без HAVING, чтобы видеть, какие строки отсеялись.
SELECT date_trunc('month', f.scheduled_departure)::date AS month,
       SUM(tf.amount) AS revenue
FROM flights f
JOIN ticket_flights tf ON tf.flight_id = f.flight_id
WHERE f.scheduled_departure >= '2017-01-01'
  AND f.scheduled_departure <  '2018-01-01'
GROUP BY ROLLUP (date_trunc('month', f.scheduled_departure))
ORDER BY month;

-- Контроль: порог 50 млрд без GROUPING. Итог 47 млрд не проходит, и строка пропадает.
SELECT date_trunc('month', f.scheduled_departure)::date AS month,
       SUM(tf.amount) AS revenue
FROM flights f
JOIN ticket_flights tf ON tf.flight_id = f.flight_id
WHERE f.scheduled_departure >= '2017-01-01'
  AND f.scheduled_departure <  '2018-01-01'
GROUP BY ROLLUP (date_trunc('month', f.scheduled_departure))
HAVING SUM(tf.amount) > 50000000000
ORDER BY month;


-- Задание 2. LEFT JOIN: прибывшие рейсы по аэропортам прибытия
-- Условие на статус стоит в ON, поэтому аэропорт без прибытий остаётся с нулём.
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code,
       a.airport_name,
       COUNT(f.flight_id) AS arrived_cnt
FROM airports a
LEFT JOIN flights f
       ON f.arrival_airport = a.airport_code
      AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt, a.airport_code;

SELECT a.airport_code,
       a.airport_name,
       COUNT(f.flight_id) AS arrived_cnt
FROM airports a
LEFT JOIN flights f
       ON f.arrival_airport = a.airport_code
      AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt, a.airport_code;

-- Контроль: то же условие в WHERE.
EXPLAIN (ANALYZE, BUFFERS)
SELECT a.airport_code,
       a.airport_name,
       COUNT(f.flight_id) AS arrived_cnt
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt, a.airport_code;

SELECT a.airport_code,
       a.airport_name,
       COUNT(f.flight_id) AS arrived_cnt
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt, a.airport_code;

-- Контроль на одном дне (15.08.2017), где у части аэропортов прибытий нет.
-- Рядом с COUNT(f.flight_id) вывожу COUNT(*): для аэропорта без прибытий он даёт 1 вместо 0.
SELECT a.airport_code,
       a.airport_name,
       COUNT(f.flight_id) AS arrived_cnt,
       COUNT(*)           AS count_star
FROM airports a
LEFT JOIN flights f
       ON f.arrival_airport = a.airport_code
      AND f.status = 'Arrived'
      AND f.actual_arrival >= '2017-08-15'
      AND f.actual_arrival <  '2017-08-16'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt, a.airport_code;

SELECT a.airport_code,
       a.airport_name,
       COUNT(f.flight_id) AS arrived_cnt
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
  AND f.actual_arrival >= '2017-08-15'
  AND f.actual_arrival <  '2017-08-16'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt, a.airport_code;


-- Задание 3. Sargability: рейсы, выполненные в выходные августа 2017
-- Дату выполнения беру по фактическому вылету.
-- Выходные августа 2017: 5-6, 12-13, 19-20, 26-27.

-- 3а. Без индекса по actual_departure.
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND EXTRACT(YEAR  FROM f.actual_departure) = 2017
  AND EXTRACT(MONTH FROM f.actual_departure) = 8
  AND EXTRACT(DOW   FROM f.actual_departure) IN (0, 6)   -- 0 воскресенье, 6 суббота
ORDER BY f.actual_departure;

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND (   (f.actual_departure >= '2017-08-05' AND f.actual_departure < '2017-08-07')
       OR (f.actual_departure >= '2017-08-12' AND f.actual_departure < '2017-08-14')
       OR (f.actual_departure >= '2017-08-19' AND f.actual_departure < '2017-08-21')
       OR (f.actual_departure >= '2017-08-26' AND f.actual_departure < '2017-08-28'))
ORDER BY f.actual_departure;

-- 3б. С индексом по actual_departure. Без индекса диапазон читать нечем,
-- поэтому разница в способе доступа видна только с ним.
CREATE INDEX idx_flights_actual_departure ON flights (actual_departure);

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND EXTRACT(YEAR  FROM f.actual_departure) = 2017
  AND EXTRACT(MONTH FROM f.actual_departure) = 8
  AND EXTRACT(DOW   FROM f.actual_departure) IN (0, 6)
ORDER BY f.actual_departure;

SELECT f.flight_id, f.flight_no, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND EXTRACT(YEAR  FROM f.actual_departure) = 2017
  AND EXTRACT(MONTH FROM f.actual_departure) = 8
  AND EXTRACT(DOW   FROM f.actual_departure) IN (0, 6)
ORDER BY f.actual_departure;

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND (   (f.actual_departure >= '2017-08-05' AND f.actual_departure < '2017-08-07')
       OR (f.actual_departure >= '2017-08-12' AND f.actual_departure < '2017-08-14')
       OR (f.actual_departure >= '2017-08-19' AND f.actual_departure < '2017-08-21')
       OR (f.actual_departure >= '2017-08-26' AND f.actual_departure < '2017-08-28'))
ORDER BY f.actual_departure;

SELECT f.flight_id, f.flight_no, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND (   (f.actual_departure >= '2017-08-05' AND f.actual_departure < '2017-08-07')
       OR (f.actual_departure >= '2017-08-12' AND f.actual_departure < '2017-08-14')
       OR (f.actual_departure >= '2017-08-19' AND f.actual_departure < '2017-08-21')
       OR (f.actual_departure >= '2017-08-26' AND f.actual_departure < '2017-08-28'))
ORDER BY f.actual_departure;

DROP INDEX idx_flights_actual_departure;


-- Задание 7. ANTI-JOIN: рейсы без проданных билетов бизнес-класса
EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.status
FROM flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id
    FROM ticket_flights tf
    WHERE tf.fare_conditions = 'Business'
)
ORDER BY f.flight_id;

SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.status
FROM flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id
    FROM ticket_flights tf
    WHERE tf.fare_conditions = 'Business'
)
ORDER BY f.flight_id;

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.status
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
)
ORDER BY f.flight_id;

SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.status
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
)
ORDER BY f.flight_id;

-- Контроль: один NULL в подзапросе, и NOT IN возвращает пустой результат.
SELECT COUNT(*) AS not_in_with_null
FROM flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id FROM ticket_flights tf WHERE tf.fare_conditions = 'Business'
    UNION ALL
    SELECT NULL
);

-- Контроль: мало памяти. Хеш из 242 тыс. id не влезает в work_mem,
-- и NOT IN перебирает весь подзапрос для каждой строки. Беру только 500 рейсов,
-- на всех 65 тыс. запрос шёл бы больше 15 минут. NOT EXISTS гоняю на всех рейсах.
SET work_mem = '1MB';

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no
FROM flights f
WHERE f.flight_id <= 500
  AND f.flight_id NOT IN (
    SELECT tf.flight_id
    FROM ticket_flights tf
    WHERE tf.fare_conditions = 'Business'
);

EXPLAIN (ANALYZE, BUFFERS)
SELECT f.flight_id, f.flight_no
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
);
RESET work_mem;


-- Задание 8. Index Only Scan: число рейсов по статусам
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*) FROM flights GROUP BY status;

SELECT status, COUNT(*) FROM flights GROUP BY status;

CREATE INDEX idx_flights_status ON flights (status);
-- VACUUM обновляет Visibility Map: страницы без старых версий строк
-- помечаются как all-visible, и Index Only Scan не читает их из таблицы.
VACUUM flights;

EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*) FROM flights GROUP BY status;

SELECT status, COUNT(*) FROM flights GROUP BY status;

DROP INDEX idx_flights_status;
