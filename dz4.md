Задача 1.1
EXPLAIN (ANALYZE, BUFFERS)
select flight_no, departure_airport, actual_departure
from flights f join airports_data ad on f.arrival_airport = ad.airport_code
where 1=1
and status = 'Arrived'
and ad.city::text like '%Moscow%'
and to_date(f.actual_departure::text, 'YYYY-MM') = to_date('2017-08', 'YYYY-MM')
order by actual_departure;
 
Запрос не использовал индексы, оба обращения к таблицам выполнены через Seq Scan . Запрос работал с кешем и с диском: shared hit=1669 shared read=833 
 
задача 1.2
EXPLAIN (ANALYZE, BUFFERS)
select flight_no, departure_airport, actual_departure, EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60 delay_minutes
from flights f
where 1=1
and actual_arrival - scheduled_arrival > INTERVAL '2 hours'
order by delay_minutes DESC
результат
 
 
Запрос не использовал индекс только Seq Scan. Работал с кешем (shared hit=792), с диском не работал ни одного read 
задание 1.3
EXPLAIN (ANALYZE, BUFFERS)
select flight_no, count(*) flight_count
from flights
where flight_no between 'PG0400' and 'PG0499'
GROUP BY flight_no
 
 
Запрос использовал индекс, Index Only Scan по flights_flight_no_scheduled_departure_key. Работал с кешем и с диском (shared hit=1 read=40). Heap Fetches: 0  к таблице не обращался

задача 2.1
EXPLAIN (ANALYZE, BUFFERS)
select departure_airport, AVG(extract(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60) delay_minutes
from flights
group by departure_airport
having count(*) > 500
order by DELAY_MINUTES
 
 
Запрос не использовал индекс, только Seq Scan. Работал с кешем (shared hit=792), с диском не работал 

задача 3.1
EXPLAIN (ANALYZE, BUFFERS)
select passenger_name, amount, flight_no, ad.city, ad2.city
from tickets t join ticket_flights tf on t.ticket_no = tf.ticket_no
	join flights f on tf.flight_id = f.flight_id
		join airports_data ad on f.departure_airport = ad.airport_code
			join airports_data ad2 on f.arrival_airport = ad2.airport_code
order by amount desc
limit 10;
 
 (в dbeavere слишком большой план, скопировал текст и приложил скриншот с блокнота)
Запрос не использовал индекс, только Seq Scan. Работал с кешем и диском (shared hit=2822 read=33366)

задача 3.2
EXPLAIN (ANALYZE, BUFFERS)
select departure_airport, count(actual_departure)
from airports_data ad left join flights f on airport_code = departure_airport
group by departure_airport;
  
 
Запрос не использовал индекс, только Seq Scan и Hash Right Join. Работал с кешем (shared hit=795), с диском не работал 

задача 3.3
EXPLAIN (ANALYZE, BUFFERS)
select passenger_id, passenger_name, count(t.ticket_no), SUM(amount) summ
from ticket_flights tf join tickets t on t.ticket_no = tf.ticket_no
group by passenger_id, passenger_name
order by summ desc
limit 5
 
 
 
Запрос не использовал индекс, только Seq Scan. Работал с кешем и диском (shared hit=149 read=33494) 

1.Группировки и многоуровневые итоги (ROLLUP) 
EXPLAIN (analyze)
select sum(amount), EXTRACT(MONTH FROM scheduled_departure) summ
from ticket_flights tf join flights f on tf.flight_id = f.flight_id
where 1=1
and to_date(f.scheduled_departure::text, 'YYYY') = to_date('2017', 'YYYY')
group by rollup(summ)
having sum(amount) > 10000000000
  
 
ROLLUP делает группировку, HAVING применяется по условию, итоговая строчка проходит фильтр, потому что она больше чем 10000000000, на null не смотрим.Запрос не использовал индекс, только Seq Scan и Hash Join. Работал с кешем (Buffers везде shared hit), с диском не работал

2.LEFT JOIN и условная агрегация
EXPLAIN (analyze)
select airport_code, airport_name, count(actual_arrival)
from airports_data ad left join flights f on arrival_airport = airport_code and status = 'Arrived'
group by airport_code, airport_name;

EXPLAIN (analyze)
select airport_code, airport_name, count(actual_arrival)
from airports_data ad left join flights f on arrival_airport = airport_code
where status = 'Arrived'
group by airport_code, airport_name
  для on
 
 
Запрос не использовал индекс, только Seq Scan и Hash Right Join. Работал с кешем, с диском не работал 
для where
 

 
Запрос не использовал индекс, только Seq Scan и Hash Join. Работал с кешем, с диском не работал 
ответы при разных запросах одинаковые, count(*) посчитает null как 1, а не 0, Hash Right Join  меняет таблицы местами и по кешу ищет совпадения
результат запроса с использованием on в from и с условием в where
 

3.Sargability (Оптимизация предикатов) 
EXPLAIN (analyze)
select flight_no
from flights f
where 1=1
and status = 'Arrived'
and EXTRACT(DOW from f.actual_arrival) in(0,6)
AND EXTRACT(MONTH FROM f.actual_arrival) = '08'
and EXTRACT(year from f.actual_arrival ) ='2017';

EXPLAIN (analyze)
select flight_no
from flights f
where 1=1
and status = 'Arrived'
AND (
     (scheduled_arrival >= '2017-08-05' AND scheduled_arrival < '2017-08-07')
  OR (scheduled_arrival >= '2017-08-12' AND scheduled_arrival < '2017-08-14')
  OR (scheduled_arrival >= '2017-08-19' AND scheduled_arrival < '2017-08-21')
  OR (scheduled_arrival >= '2017-08-26' AND scheduled_arrival < '2017-08-28')
 )
 неоптимизированный
 
 
оптимизированный
 
 
неоптимизированный использует 3 функции(EXTRACT(DOW), EXTRACT(MONTH), EXTRACT(YEAR)), работаем без индекса время выполнения 22мс
оптимизированный использует диапазоны, смотрим по индексу, поэтому время выполнения 5мс

4.ANTI-JOIN (Оптимизация отрицания)  
EXPLAIN (ANALYZE)
select flight_no
FROM flights
WHERE flight_id NOT IN (
   SELECT flight_id
   FROM ticket_flights
   WHERE fare_conditions = 'Business'
);
EXPLAIN (ANALYZE)
select flight_no
FROM flights
WHERE NOT EXISTS (
   SELECT 1
   FROM ticket_flights
   WHERE ticket_flights.flight_id = flights.flight_id
     AND ticket_flights.fare_conditions = 'Business'
not in
 
 
not exists
 
 
Разница между планами
NOT IN использует выполняется целиком, время 521 мс. NOT EXISTS использует останавливается при первом совпадении, время 142 мс.
Почему NOT EXISTS эффективнее
Anti Join операция, которая сразу находит несовпадения через хеш. NOT IN сначала строит всё множество значений, потом проверяет.
Почему NOT IN опасен с NULL
Если в flight_id есть NULL, то NOT IN вернёт пустой результат, потому что  NOT IN даёт UNKNOWN, а он не пропускает строку. Ошибки не будет, но результат неверный. NOT EXISTS от NULL не ломается

5. Индексное сканирование (Index Only Scan) 
EXPLAIN (analyze,BUFFERS)
SELECT status, COUNT(*)
FROM flights
GROUP BY status;
CREATE INDEX idx_flights_status
   ON flights (status);
VACUUM bookings.flights;
EXPLAIN (ANALYZE, BUFFERS)
SELECT status, COUNT(*)
FROM flights
GROUP BY status;
 

 
 
Разница между планами
Без индекса — Seq Scan, время 14 мс, работал с кешем. С индексом — Index Only Scan, время 7 мс, работал с кешем и диском. Heap Fetches: 0, к таблице не обращался
Данные берутся прямо из индекса, к таблице запрос не обращается. Heap Fetches: 0 это подтверждает
Почему это ускоряет — Visibility Map
Индекс не знает, живые ли строки в таблице, поэтому обычно ходит в таблицу проверять (Heap Fetches). Visibility Map отмечает страницы, где все строки видны, и тогда проверка не нужна. VACUUM обновляет карту и отсюда Heap Fetches: 0
