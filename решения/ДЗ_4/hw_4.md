# ДЗ 4. Advanced SQL и оптимизация запросов


# 1.1. Выполненные рейсы из Москвы за август 2017

```sql
SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND f.departure_airport IN (SELECT a.airport_code FROM airports a WHERE a.city = 'Moscow')
  AND f.actual_departure >= '2017-08-01'
  AND f.actual_departure <  '2017-09-01'
ORDER BY f.actual_departure;
```

Результат:

```
 flight_no | departure_airport |    actual_departure    
-----------+-------------------+------------------------
 PG0120    | SVO               | 2017-08-01 06:01:00+00
 PG0239    | DME               | 2017-08-01 06:08:00+00
 PG0509    | DME               | 2017-08-01 06:15:00+00
 PG0482    | DME               | 2017-08-01 06:24:00+00
 PG0269    | VKO               | 2017-08-01 06:28:00+00
...
(1913 rows)
```

План:

```
Sort  (cost=1990.00..1990.15 rows=58 width=19) (actual time=13.072..13.256 rows=1913 loops=1)
  Sort Key: f.actual_departure
  Sort Method: quicksort  Memory: 138kB
  Buffers: shared hit=815
  ->  Hash Join  (cost=30.57..1988.30 rows=58 width=19) (actual time=0.819..12.278 rows=1913 loops=1)
        Hash Cond: (f.departure_airport = ml.airport_code)
        Buffers: shared hit=812
        ->  Seq Scan on flights f  (cost=0.00..1941.12 rows=6082 width=19) (actual time=0.031..10.572 rows=8020 loops=1)
              Filter: ((actual_departure >= '2017-08-01 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-09-01 00:00:00+00'::timestamp with time zone) AND ((status)::text = 'Arrived'::text))
              Rows Removed by Filter: 57644
              Buffers: shared hit=792
        ->  Hash  (cost=30.56..30.56 rows=1 width=4) (actual time=0.721..0.723 rows=3 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=20
              ->  Seq Scan on airports_data ml  (cost=0.00..30.56 rows=1 width=4) (actual time=0.623..0.715 rows=3 loops=1)
                    Filter: ((city ->> lang()) = 'Moscow'::text)
                    Rows Removed by Filter: 101
                    Buffers: shared hit=20
Planning:
  Buffers: shared hit=231
Planning Time: 7.489 ms
Execution Time: 15.235 ms
```

Запрос работал только с кешем: все 815 страниц пришли как `shared hit`, чтений с диска нет. Индекс не использовался. Индексов по `status` и `actual_departure` нет, поэтому `flights` прочитана целиком (`Seq Scan`), фильтр отбросил 57 644 строки из 65 664. `airports` это представление над `airports_data`, по нему нашлись три московских аэропорта, и `Hash Join` оставил рейсы только из них.

### 1.2. Опоздание прибытия больше 2 часов

```sql
SELECT f.flight_no,
       f.scheduled_arrival,
       f.actual_arrival,
       ROUND(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_arrival)) / 60) AS delay_min
FROM flights f
WHERE f.actual_arrival > f.scheduled_arrival + INTERVAL '2 hours'
ORDER BY delay_min DESC, f.flight_no;
```

Результат:

```
 flight_no |   scheduled_arrival    |     actual_arrival     | delay_min 
-----------+------------------------+------------------------+-----------
 PG0132    | 2017-05-22 10:55:00+00 | 2017-05-22 15:36:00+00 |       281
 PG0531    | 2017-05-17 08:45:00+00 | 2017-05-17 13:26:00+00 |       281
 PG0589    | 2017-07-29 12:55:00+00 | 2017-07-29 17:32:00+00 |       277
 PG0364    | 2017-07-19 10:20:00+00 | 2017-07-19 14:49:00+00 |       269
 PG0151    | 2017-07-03 11:30:00+00 | 2017-07-03 15:57:00+00 |       267
...
(2394 rows)
```

План:

```
Sort  (cost=3573.73..3628.45 rows=21888 width=55) (actual time=11.499..11.621 rows=2394 loops=1)
  Sort Key: (round((EXTRACT(epoch FROM (actual_arrival - scheduled_arrival)) / '60'::numeric), 0)) DESC, flight_no
  Sort Method: quicksort  Memory: 227kB
  Buffers: shared hit=798
  ->  Seq Scan on flights f  (cost=0.00..1995.84 rows=21888 width=55) (actual time=0.049..8.480 rows=2394 loops=1)
        Filter: (actual_arrival > (scheduled_arrival + '02:00:00'::interval))
        Rows Removed by Filter: 63270
        Buffers: shared hit=792
Planning:
  Buffers: shared hit=19
Planning Time: 0.275 ms
Execution Time: 11.791 ms
```

Только кеш: `shared hit=798`, чтений нет. Индекс не использовался, и обычный индекс тут не помог бы: условие сравнивает две колонки одной строки, поэтому проверять приходится каждую строку. Ускорить такой поиск может только индекс по выражению `(actual_arrival - scheduled_arrival)`, если переписать условие как `actual_arrival - scheduled_arrival > INTERVAL '2 hours'`. Самое большое опоздание 281 минута, таких рейсов два.

### 1.3. Номера PG0400–PG0499

```sql
SELECT f.flight_no,
       COUNT(*)                                     AS flights_cnt,
       COUNT(*) FILTER (WHERE f.status = 'Arrived') AS arrived_cnt
FROM flights f
WHERE f.flight_no LIKE 'PG04%'
GROUP BY f.flight_no
ORDER BY f.flight_no;
```

Результат:

```
 flight_no | flights_cnt | arrived_cnt 
-----------+-------------+-------------
 PG0400    |         121 |          91
 PG0401    |         121 |          91
 PG0402    |         121 |          91
 PG0403    |         121 |          91
 PG0404    |         121 |          90
...
(100 rows)
```

План:

```
Sort  (cost=1753.68..1755.46 rows=710 width=23) (actual time=9.711..9.718 rows=100 loops=1)
  Sort Key: flight_no
  Sort Method: quicksort  Memory: 29kB
  Buffers: shared hit=792
  ->  HashAggregate  (cost=1712.96..1720.06 rows=710 width=23) (actual time=9.559..9.580 rows=100 loops=1)
        Group Key: flight_no
        Batches: 1  Memory Usage: 57kB
        Buffers: shared hit=792
        ->  Seq Scan on flights f  (cost=0.00..1612.80 rows=10016 width=15) (actual time=0.008..7.237 rows=9715 loops=1)
              Filter: (flight_no ~~ 'PG04%'::text)
              Rows Removed by Filter: 55949
              Buffers: shared hit=792
Planning:
  Buffers: shared hit=9
Planning Time: 0.367 ms
Execution Time: 9.760 ms
```

Все 792 страницы взяты из кеша (`shared hit`). Индекс `flights_flight_no_scheduled_departure_key` начинается с `flight_no`, но для `LIKE 'PG04%'` он не подходит. База создана с collation `en_US.utf8`, а префиксный `LIKE` идёт по B-tree только в collation `C` или с классом операторов `bpchar_pattern_ops` (у `flight_no` тип `char(6)`). Всего 100 номеров и 9 715 рейсов, из них выполнено 7 284.

### 2.1. Среднее опоздание по аэропортам вылета

```sql
SELECT f.departure_airport,
       COUNT(*) AS flights_cnt,
       ROUND(AVG(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_arrival)) / 60), 1) AS avg_delay_min
FROM flights f
WHERE f.actual_arrival IS NOT NULL
GROUP BY f.departure_airport
HAVING COUNT(*) > 500
ORDER BY avg_delay_min DESC;
```

Результат:

```
 departure_airport | flights_cnt | avg_delay_min 
-------------------+-------------+---------------
 CEK               |         610 |          15.9
 IKT               |         546 |          14.4
 HMA               |         766 |          14.1
 SVX               |        1027 |          13.9
 PES               |         531 |          13.7
...
(28 rows)
```

План:

```
Sort  (cost=2192.17..2192.26 rows=35 width=44) (actual time=27.921..27.924 rows=28 loops=1)
  Sort Key: (round(avg((EXTRACT(epoch FROM (actual_arrival - scheduled_arrival)) / '60'::numeric)), 1)) DESC
  Sort Method: quicksort  Memory: 26kB
  Buffers: shared hit=792
  ->  HashAggregate  (cost=2189.62..2191.27 rows=35 width=44) (actual time=27.858..27.899 rows=28 loops=1)
        Group Key: departure_airport
        Filter: (count(*) > 500)
        Batches: 1  Memory Usage: 80kB
        Rows Removed by Filter: 76
        Buffers: shared hit=792
        ->  Seq Scan on flights f  (cost=0.00..1448.64 rows=49399 width=20) (actual time=0.007..8.883 rows=49258 loops=1)
              Filter: (actual_arrival IS NOT NULL)
              Rows Removed by Filter: 16406
              Buffers: shared hit=792
Planning:
  Buffers: shared hit=9
Planning Time: 0.201 ms
Execution Time: 27.960 ms
```

Здесь тоже только кеш, 792 страницы `shared hit`. Индекс не нужен: агрегат строится по всем прилетевшим рейсам (49 258 строк из 65 664), их проще прочитать подряд. `HAVING COUNT(*) > 500` в плане стал строкой `Filter` у `HashAggregate` и отбросил 76 аэропортов из 104. Число рейсов считаю по тем же прилетевшим рейсам, что и среднее, иначе количество и среднее относились бы к разным наборам строк.

### 3.1. Топ-10 самых дорогих билетов

```sql
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
```

Результат:

```
  passenger_name   |  amount   | flight_no | departure_city | arrival_city  
-------------------+-----------+-----------+----------------+---------------
 PAVEL SCHERBAKOV  | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 ELENA STEPANOVA   | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 NADEZHDA BORISOVA | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 LILIYA KUZMINA    | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 YULIYA FADEEVA    | 203300.00 | PG0144    | Moscow         | Petropavlovsk
...
(10 rows)
```

План:

```
Limit  (cost=193470.50..193475.67 rows=10 width=107) (actual time=4260.874..4260.901 rows=10 loops=1)
  Buffers: shared hit=1697 read=32741, temp read=16196 written=16196
  I/O Timings: shared read=209.921, temp read=112.241 write=151.715
  ->  Result  (cost=193470.50..1414943.86 rows=2360335 width=107) (actual time=4239.393..4239.419 rows=10 loops=1)
        Buffers: shared hit=1697 read=32741, temp read=16196 written=16196
        I/O Timings: shared read=209.921, temp read=112.241 write=151.715
        ->  Sort  (cost=193470.50..199371.33 rows=2360335 width=141) (actual time=4239.181..4239.191 rows=10 loops=1)
              Sort Key: tf.amount DESC, tf.ticket_no
              Sort Method: top-N heapsort  Memory: 29kB
              Buffers: shared hit=1697 read=32741, temp read=16196 written=16196
              I/O Timings: shared read=209.921, temp read=112.241 write=151.715
              ->  Hash Join  (cost=40522.22..142464.50 rows=2360335 width=141) (actual time=399.982..3797.669 rows=2360335 loops=1)
                    Hash Cond: (f.arrival_airport = ml_1.airport_code)
                    Buffers: shared hit=1697 read=32741, temp read=16196 written=16196
                    I/O Timings: shared read=209.921, temp read=112.241 write=151.715
                    ->  Hash Join  (cost=40516.88..136010.79 rows=2360335 width=96) (actual time=399.836..3367.541 rows=2360335 loops=1)
                          Hash Cond: (f.departure_airport = ml.airport_code)
                          Buffers: shared hit=1694 read=32741, temp read=16196 written=16196
                          I/O Timings: shared read=209.921, temp read=112.241 write=151.715
                          ->  Hash Join  (cost=40511.54..129557.08 rows=2360335 width=51) (actual time=399.784..2929.851 rows=2360335 loops=1)
                                Hash Cond: (tf.flight_id = f.flight_id)
                                Buffers: shared hit=1691 read=32741, temp read=16196 written=16196
                                I/O Timings: shared read=209.921, temp read=112.241 write=151.715
                                ->  Hash Join  (cost=38242.10..121091.36 rows=2360335 width=40) (actual time=374.379..2204.995 rows=2360335 loops=1)
                                      Hash Cond: (tf.ticket_no = t.ticket_no)
                                      Buffers: shared hit=899 read=32741, temp read=16196 written=16196
                                      I/O Timings: shared read=209.921, temp read=112.241 write=151.715
                                      ->  Seq Scan on ticket_flights tf  (cost=0.00..43323.35 rows=2360335 width=24) (actual time=0.368..407.848 rows=2360335 loops=1)
                                            Buffers: shared hit=672 read=19048
                                            I/O Timings: shared read=130.744
                                      ->  Hash  (cost=22210.71..22210.71 rows=829071 width=30) (actual time=372.787..372.788 rows=829071 loops=1)
                                            Buckets: 131072  Batches: 8  Memory Usage: 7319kB
                                            Buffers: shared hit=227 read=13693, temp written=4434
                                            I/O Timings: shared read=79.177, temp write=40.494
                                            ->  Seq Scan on tickets t  (cost=0.00..22210.71 rows=829071 width=30) (actual time=0.092..186.171 rows=829071 loops=1)
                                                  Buffers: shared hit=227 read=13693
                                                  I/O Timings: shared read=79.177
                                ->  Hash  (cost=1448.64..1448.64 rows=65664 width=19) (actual time=24.646..24.648 rows=65664 loops=1)
                                      Buckets: 131072  Batches: 1  Memory Usage: 4359kB
                                      Buffers: shared hit=792
                                      ->  Seq Scan on flights f  (cost=0.00..1448.64 rows=65664 width=19) (actual time=0.013..8.642 rows=65664 loops=1)
                                            Buffers: shared hit=792
                          ->  Hash  (cost=4.04..4.04 rows=104 width=53) (actual time=0.035..0.036 rows=104 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 17kB
                                Buffers: shared hit=3
                                ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=53) (actual time=0.008..0.018 rows=104 loops=1)
                                      Buffers: shared hit=3
                    ->  Hash  (cost=4.04..4.04 rows=104 width=53) (actual time=0.103..0.104 rows=104 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 17kB
                          Buffers: shared hit=3
                          ->  Seq Scan on airports_data ml_1  (cost=0.00..4.04 rows=104 width=53) (actual time=0.049..0.071 rows=104 loops=1)
                                Buffers: shared hit=3
Planning:
  Buffers: shared hit=199
Planning Time: 1.425 ms
JIT:
  Functions: 37
  Options: Inlining false, Optimization false, Expressions true, Deforming true
  Timing: Generation 1.740 ms, Inlining 0.000 ms, Optimization 1.003 ms, Emission 20.680 ms, Total 23.423 ms
Execution Time: 4302.439 ms
```

Это самый тяжёлый запрос. `ticket_flights` и `tickets` прочитаны целиком, почти всё мимо кеша: `shared read=32741` (около 256 МБ) против `shared hit=1697`. Хеш-таблица по 829 тыс. билетам не поместилась в `work_mem` и была разбита на 8 частей (`Batches: 8`), отсюда `temp read/written=16196`, то есть запрос писал временные файлы. Индексы не использовались: планировщик соединил все 2,36 млн строк и только потом выбрал 10 (`top-N heapsort`). Блок `JIT` появился, потому что стоимость запроса выше порога `jit_above_cost`, компиляция заняла 23 мс.
Билетов с максимальной ценой 203 300 в базе 939, поэтому без второго ключа сортировки `ticket_no` состав топа мог бы меняться от запуска к запуску.

### 3.2. Все аэропорты с числом вылетов

```sql
SELECT a.airport_code,
       a.airport_name,
       a.city,
       COUNT(f.flight_id) AS departures_cnt
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name, a.city
ORDER BY departures_cnt, a.airport_code;
```

Результат:

```
 airport_code |                  airport_name                  |        city        | departures_cnt 
--------------+------------------------------------------------+--------------------+----------------
 USK          | Usinsk Airport                                 | Usinsk             |             34
 KXK          | Komsomolsk-on-Amur Airport                     | Komsomolsk-on-Amur |             35
 NYA          | Nyagan Airport                                 | Nyagan             |             51
 PYJ          | Polyarny Airport                               | Yakutia            |             51
 PKC          | Yelizovo Airport                               | Petropavlovsk      |             52
...
(104 rows)
```

План:

```
Sort  (cost=35507.37..35507.63 rows=104 width=76) (actual time=130.856..130.863 rows=104 loops=1)
  Sort Key: (count(f.flight_id)), ml.airport_code
  Sort Method: quicksort  Memory: 32kB
  Buffers: shared hit=798
  ->  HashAggregate  (cost=35450.33..35503.89 rows=104 width=76) (actual time=130.807..130.821 rows=104 loops=1)
        Group Key: ml.airport_code, (ml.airport_name ->> lang()), (ml.city ->> lang())
        Batches: 1  Memory Usage: 32kB
        Buffers: shared hit=795
        ->  Hash Right Join  (cost=5.34..34793.69 rows=65664 width=72) (actual time=0.051..115.290 rows=65664 loops=1)
              Hash Cond: (f.departure_airport = ml.airport_code)
              Buffers: shared hit=795
              ->  Seq Scan on flights f  (cost=0.00..1448.64 rows=65664 width=8) (actual time=0.002..4.316 rows=65664 loops=1)
                    Buffers: shared hit=792
              ->  Hash  (cost=4.04..4.04 rows=104 width=114) (actual time=0.032..0.033 rows=104 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 23kB
                    Buffers: shared hit=3
                    ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=114) (actual time=0.006..0.016 rows=104 loops=1)
                          Buffers: shared hit=3
Planning:
  Buffers: shared hit=28
Planning Time: 0.283 ms
Execution Time: 130.900 ms
```

Только кеш (`shared hit=798`). `flights` прочитана целиком, индекс не нужен, считаются все 65 664 рейса. `Hash Right Join` строит хеш по 104 аэропортам и прогоняет через него все рейсы, аэропорт без рейсов тоже остался бы в результате (подробнее про этот узел в задании 2). Аэропортов совсем без вылетов в данных нет, меньше всего рейсов у USK (34).

### 3.3. Топ-5 пассажиров по тратам

```sql
SELECT t.passenger_id,
       t.passenger_name,
       COUNT(*)       AS flights_cnt,
       SUM(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC, t.passenger_id
LIMIT 5;
```

Результат:

```
 passenger_id |   passenger_name   | flights_cnt | total_spent 
--------------+--------------------+-------------+-------------
 2034 201228  | ANTONINA KUZNECOVA |           6 |   529500.00
 3272 478491  | EKATERINA LAZAREVA |           6 |   506700.00
 6615 949899  | ELENA VASILEVA     |           6 |   505500.00
 7989 541468  | EVGENIY TARASOV    |           6 |   495300.00
 4805 339011  | DMITRIY KUZMIN     |           6 |   494700.00
(5 rows)
```

План:

```
Limit  (cost=403674.54..403674.55 rows=5 width=68) (actual time=3145.977..3145.985 rows=5 loops=1)
  Buffers: shared hit=1062 read=32581, temp read=32216 written=47725
  I/O Timings: shared read=86.058, temp read=87.370 write=211.545
  ->  Sort  (cost=403674.54..405747.22 rows=829071 width=68) (actual time=3139.233..3139.239 rows=5 loops=1)
        Sort Key: (sum(tf.amount)) DESC, t.passenger_id
        Sort Method: top-N heapsort  Memory: 25kB
        Buffers: shared hit=1062 read=32581, temp read=32216 written=47725
        I/O Timings: shared read=86.058, temp read=87.370 write=211.545
        ->  HashAggregate  (cost=342660.35..389903.97 rows=829071 width=68) (actual time=2248.649..3012.819 rows=829071 loops=1)
              Group Key: t.passenger_id, t.passenger_name
              Planned Partitions: 64  Batches: 65  Memory Usage: 8209kB  Disk Usage: 126880kB
              Buffers: shared hit=1059 read=32581, temp read=32216 written=47725
              I/O Timings: shared read=86.058, temp read=87.370 write=211.545
              ->  Hash Join  (cost=39861.10..124329.36 rows=2360335 width=34) (actual time=308.906..1535.588 rows=2360335 loops=1)
                    Hash Cond: (tf.ticket_no = t.ticket_no)
                    Buffers: shared hit=1059 read=32581, temp read=16797 written=16797
                    I/O Timings: shared read=86.058, temp read=50.179 write=73.564
                    ->  Seq Scan on ticket_flights tf  (cost=0.00..43323.35 rows=2360335 width=20) (actual time=0.046..242.812 rows=2360335 loops=1)
                          Buffers: shared hit=768 read=18952
                          I/O Timings: shared read=28.244
                    ->  Hash  (cost=22210.71..22210.71 rows=829071 width=42) (actual time=308.125..308.127 rows=829071 loops=1)
                          Buckets: 131072  Batches: 16  Memory Usage: 4780kB
                          Buffers: shared hit=291 read=13629, temp written=5888
                          I/O Timings: shared read=57.814, temp write=29.321
                          ->  Seq Scan on tickets t  (cost=0.00..22210.71 rows=829071 width=42) (actual time=0.022..153.527 rows=829071 loops=1)
                                Buffers: shared hit=291 read=13629
                                I/O Timings: shared read=57.814
Planning:
  Buffers: shared hit=36
Planning Time: 0.355 ms
JIT:
  Functions: 18
  Options: Inlining false, Optimization false, Expressions true, Deforming true
  Timing: Generation 0.984 ms, Inlining 0.000 ms, Optimization 0.987 ms, Emission 9.500 ms, Total 11.471 ms
Execution Time: 3163.940 ms
```

`ticket_flights` и `tickets` снова прочитаны почти целиком мимо кеша (`shared read=32581`). Кроме того, запрос много писал во временные файлы. `HashAggregate` по 829 071 пассажиру не поместился в 4 МБ `work_mem` и был разбит на 65 частей (`Disk Usage: 126880kB`), хеш по `tickets` разбит на 16. Всего `temp written=47725` страниц, около 370 МБ. Индексы не используются, потому что нужно пройти все билеты. Группирую по `passenger_id`, а не по имени, иначе одноимённые пассажиры склеились бы в одного.

## Задание 1. ROLLUP: выручка по месяцам и общий итог

```sql
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
```

Результат:

```
   month    |    revenue     
------------+----------------
 2017-06-01 | 13095070300.00
 2017-07-01 | 13585808100.00
 2017-08-01 | 13517932000.00
            | 47004388200.00
(4 rows)
```

План:

```
Sort  (cost=76511.08..76526.40 rows=6126 width=44) (actual time=1444.799..1444.823 rows=4 loops=1)
  Sort Key: (((date_trunc('month'::text, f.scheduled_departure)))::date)
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=1627 read=18888
  I/O Timings: shared read=47.298
  ->  MixedAggregate  (cost=2597.60..76125.73 rows=6126 width=44) (actual time=1444.415..1444.756 rows=4 loops=1)
        Hash Key: date_trunc('month'::text, f.scheduled_departure)
        Group Key: ()
        Filter: ((sum(tf.amount) > '10000000000'::numeric) OR (GROUPING((date_trunc('month'::text, f.scheduled_departure))) = 1))
        Batches: 1  Memory Usage: 793kB
        Rows Removed by Filter: 2
        Buffers: shared hit=1624 read=18888
        I/O Timings: shared read=47.298
        ->  Hash Join  (cost=2597.60..58016.90 rows=2359868 width=22) (actual time=15.788..1026.734 rows=2360335 loops=1)
              Hash Cond: (tf.flight_id = f.flight_id)
              Buffers: shared hit=1624 read=18888
              I/O Timings: shared read=47.298
              ->  Seq Scan on ticket_flights tf  (cost=0.00..43323.35 rows=2360335 width=10) (actual time=0.223..213.196 rows=2360335 loops=1)
                    Buffers: shared hit=832 read=18888
                    I/O Timings: shared read=47.298
              ->  Hash  (cost=1776.96..1776.96 rows=65651 width=12) (actual time=15.164..15.166 rows=65664 loops=1)
                    Buckets: 131072  Batches: 1  Memory Usage: 3846kB
                    Buffers: shared hit=792
                    ->  Seq Scan on flights f  (cost=0.00..1776.96 rows=65651 width=12) (actual time=0.012..7.212 rows=65664 loops=1)
                          Filter: ((scheduled_departure >= '2017-01-01 00:00:00+00'::timestamp with time zone) AND (scheduled_departure < '2018-01-01 00:00:00+00'::timestamp with time zone))
                          Buffers: shared hit=792
Planning:
  Buffers: shared hit=20
Planning Time: 0.295 ms
Execution Time: 1445.881 ms
```

Месяц определяю по плановой дате вылета рейса, как на семинаре. Все рейсы в базе относятся к 2017 году, поэтому условие на год ничего не отсекает, но запрос останется верным и на других данных.
`ROLLUP (месяц)` даёт группировку по месяцу и ещё одну общую, без колонок. В плане это один узел `MixedAggregate`: за один проход он считает суммы по месяцам (`Hash Key`) и общий итог (`Group Key: ()`). В итоговой строке колонка `month` равна `NULL`.
`HAVING` выполняется после группировки и проверяется для каждой строки результата, в том числе для итоговой. В плане он стал строкой `Filter` у `MixedAggregate`. `Rows Removed by Filter: 2` это май (4,5 млрд) и сентябрь (2,3 млрд).
Итоговая строка проходит фильтр, потому что условие смотрит на `SUM(tf.amount)`, а не на колонку месяца. У итоговой строки сумма 47 млрд, это больше 10 млрд, и условие истинно. `NULL` в колонке месяца в проверке не участвует. Если бы условие было на месяц, например `date_trunc(...) >= '2017-06-01'`, сравнение с `NULL` дало бы `NULL`, и итог бы пропал.
`HAVING` убирает строки из вывода, но итог не пересчитывает. В 47 004 388 200 входят и отброшенные май с сентябрём, а три оставшихся месяца в сумме дают 40 198 810 400.
Чтобы итог не потерялся при любом пороге, я добавил `OR GROUPING(...) = 1`. `GROUPING` возвращает 1 только для строки, где месяц свёрнут в итог, поэтому её не спутать с настоящим `NULL` в данных. Без этой части при пороге 50 млрд итог (47 млрд) не проходит, и запрос возвращает пустой результат:

```
 month | revenue 
-------+---------
(0 rows)
```

`ticket_flights` прочитана целиком через `shared read=18888`, а `flights` взята из кеша (`shared hit=792`). Временных файлов нет, групп всего шесть, хеш занял 793 КБ. Индексы не использовались, для суммы нужны все строки обеих таблиц.

## Задание 2. LEFT JOIN и условная агрегация

```sql
SELECT a.airport_code,
       a.airport_name,
       COUNT(f.flight_id) AS arrived_cnt
FROM airports a
LEFT JOIN flights f
       ON f.arrival_airport = a.airport_code
      AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt, a.airport_code;
```

Результат:

```
 airport_code |                  airport_name                  | arrived_cnt 
--------------+------------------------------------------------+-------------
 KXK          | Komsomolsk-on-Amur Airport                     |          26
 USK          | Usinsk Airport                                 |          26
 NYA          | Nyagan Airport                                 |          39
 PKC          | Yelizovo Airport                               |          39
 PYJ          | Polyarny Airport                               |          39
...
(104 rows)
```

План:

```
Sort  (cost=14621.32..14621.58 rows=104 width=44) (actual time=66.686..66.694 rows=104 loops=1)
  Sort Key: (count(f.flight_id)), ml.airport_code
  Sort Method: quicksort  Memory: 31kB
  Buffers: shared hit=795
  ->  HashAggregate  (cost=14590.53..14617.83 rows=104 width=44) (actual time=66.612..66.628 rows=104 loops=1)
        Group Key: ml.airport_code, (ml.airport_name ->> lang())
        Batches: 1  Memory Usage: 32kB
        Buffers: shared hit=795
        ->  Hash Right Join  (cost=5.34..14220.22 rows=49375 width=40) (actual time=0.210..56.526 rows=49235 loops=1)
              Hash Cond: (f.arrival_airport = ml.airport_code)
              Buffers: shared hit=795
              ->  Seq Scan on flights f  (cost=0.00..1612.80 rows=49375 width=8) (actual time=0.007..8.631 rows=49235 loops=1)
                    Filter: ((status)::text = 'Arrived'::text)
                    Rows Removed by Filter: 16429
                    Buffers: shared hit=792
              ->  Hash  (cost=4.04..4.04 rows=104 width=65) (actual time=0.040..0.041 rows=104 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 18kB
                    Buffers: shared hit=3
                    ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=65) (actual time=0.008..0.024 rows=104 loops=1)
                          Buffers: shared hit=3
Planning:
  Buffers: shared hit=4
Planning Time: 0.440 ms
Execution Time: 66.851 ms
```

Условие на статус стоит в `ON`. Для `LEFT JOIN` это значит, что условие решает, какие рейсы прицепить к аэропорту. Аэропорт, к которому ничего не подошло, остаётся в результате с `NULL` вместо рейса.
Запрос работал только с кешем (`shared hit=795`), чтений с диска нет. Индекс не использовался: под `status = 'Arrived'` попадает 75% рейсов, их выгоднее прочитать подряд.
`Hash Right Join` устроен так. В SQL сохраняемая сторона левая (`airports`), но хеш-таблицу выгоднее строить по маленькой таблице. Планировщик поменял стороны местами: построил хеш по 104 аэропортам и прогнал через него 49 235 рейсов. Сохраняемой стала таблица в хеше, а в плане она стоит второй, справа. Отсюда `Right`. Когда все рейсы пройдены, аэропорты из хеша, которым не нашлось пары, выводятся с `NULL` в колонках рейса.

Контрольный запуск с условием в `WHERE`:

```sql
SELECT a.airport_code,
       a.airport_name,
       COUNT(f.flight_id) AS arrived_cnt
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_cnt, a.airport_code;
```

```
Sort  (cost=14621.32..14621.58 rows=104 width=44) (actual time=83.902..83.909 rows=104 loops=1)
  Sort Key: (count(f.flight_id)), ml.airport_code
  Sort Method: quicksort  Memory: 31kB
  Buffers: shared hit=795
  ->  HashAggregate  (cost=14590.53..14617.83 rows=104 width=44) (actual time=83.858..83.871 rows=104 loops=1)
        Group Key: ml.airport_code, (ml.airport_name ->> lang())
        Batches: 1  Memory Usage: 32kB
        Buffers: shared hit=795
        ->  Hash Join  (cost=5.34..14220.22 rows=49375 width=40) (actual time=0.068..72.045 rows=49235 loops=1)
              Hash Cond: (f.arrival_airport = ml.airport_code)
              Buffers: shared hit=795
              ->  Seq Scan on flights f  (cost=0.00..1612.80 rows=49375 width=8) (actual time=0.009..8.889 rows=49235 loops=1)
                    Filter: ((status)::text = 'Arrived'::text)
                    Rows Removed by Filter: 16429
                    Buffers: shared hit=792
              ->  Hash  (cost=4.04..4.04 rows=104 width=65) (actual time=0.036..0.037 rows=104 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 18kB
                    Buffers: shared hit=3
                    ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=65) (actual time=0.004..0.020 rows=104 loops=1)
                          Buffers: shared hit=3
Planning:
  Buffers: shared hit=4
Planning Time: 0.204 ms
Execution Time: 83.960 ms
```

На полных данных результат тот же, 104 строки: за три месяца в каждый аэропорт прилетел хотя бы один рейс. Разница видна в плане: вместо `Hash Right Join` стоит `Hash Join`, обычное внутреннее соединение. `WHERE` выполняется после соединения, а строка с `NULL` в `f.status` под условие не проходит. Поэтому планировщик сам заменяет `LEFT JOIN` на внутреннее соединение.
Чтобы потеря была видна в результате, я повторил оба варианта для одного дня, 15.08.2017. С условием в `ON` осталось 104 аэропорта, у 11 из них ноль:

```
 airport_code |                  airport_name                  | arrived_cnt | count_star 
--------------+------------------------------------------------+-------------+------------
 CEE          | Cherepovets Airport                            |           0 |          1
 DYR          | Ugolny Airport                                 |           0 |          1
 EYK          | Beloyarskiy Airport                            |           0 |          1
 GDX          | Sokol Airport                                  |           0 |          1
 IWA          | Ivanovo South Airport                          |           0 |          1
...
(104 rows)
```

С условием в `WHERE` осталось 93 строки, эти 11 аэропортов пропали:

```
 airport_code |                  airport_name                  | arrived_cnt 
--------------+------------------------------------------------+-------------
 AAQ          | Anapa Vityazevo Airport                        |           1
 ASF          | Astrakhan Airport                              |           1
 BQS          | Ignatyevo Airport                              |           1
 BTK          | Bratsk Airport                                 |           1
 GRV          | Khankala Air Base                              |           1
...
(93 rows)
```

`COUNT(*)` здесь не подходит, потому что он считает строки. Для аэропорта без прибытий `LEFT JOIN` всё равно даёт одну строку: аэропорт плюс `NULL` в колонках рейса. `COUNT(*)` насчитает 1 вместо 0, это видно в колонке `count_star` выше. `COUNT(f.flight_id)` пропускает `NULL` и даёт 0.

## Задание 3. Sargability

Неоптимизированный запрос:

```sql
SELECT f.flight_id, f.flight_no, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND EXTRACT(YEAR  FROM f.actual_departure) = 2017
  AND EXTRACT(MONTH FROM f.actual_departure) = 8
  AND EXTRACT(DOW   FROM f.actual_departure) IN (0, 6)
ORDER BY f.actual_departure;
```

Оптимизированный запрос:

```sql
SELECT f.flight_id, f.flight_no, f.actual_departure
FROM flights f
WHERE f.status = 'Arrived'
  AND (   (f.actual_departure >= '2017-08-05' AND f.actual_departure < '2017-08-07')
       OR (f.actual_departure >= '2017-08-12' AND f.actual_departure < '2017-08-14')
       OR (f.actual_departure >= '2017-08-19' AND f.actual_departure < '2017-08-21')
       OR (f.actual_departure >= '2017-08-26' AND f.actual_departure < '2017-08-28'))
ORDER BY f.actual_departure;
```

Результат у обоих одинаковый:

```
 flight_id | flight_no |    actual_departure    
-----------+-----------+------------------------
     31201 | PG0244    | 2017-08-05 00:22:00+00
     52510 | PG0088    | 2017-08-05 00:25:00+00
     39604 | PG0037    | 2017-08-05 00:41:00+00
     35961 | PG0398    | 2017-08-05 00:52:00+00
     52879 | PG0660    | 2017-08-05 00:57:00+00
...
(2251 rows)
```

Дату выполнения беру по фактическому вылету (`actual_departure`). Выходные в августе 2017 это 5–6, 12–13, 19–20 и 26–27 числа. Данные заканчиваются 15 августа, поэтому рейсы нашлись только за первые два выходных.
Индекса по `actual_departure` в базе нет, а без индекса диапазон прочитать нечем, и оба запроса читают таблицу целиком. Поэтому я запускал оба запроса дважды: без индекса и после `CREATE INDEX idx_flights_actual_departure ON flights (actual_departure)`. Ниже планы с индексом, цифры без индекса привожу в тексте.
Без индекса оба запроса читают все 792 страницы из кеша (`Seq Scan`, `shared hit`), но разница есть уже здесь.
Оптимизированный вариант быстрее, 8,0 мс против 19,6 мс. `EXTRACT` вычисляется три раза для каждой из 65 664 строк, а диапазон это простое сравнение.
Кроме того, планировщик по-разному оценивает число строк. Для `EXTRACT` он ожидал 1 строку, для диапазонов 1 726, на деле их 2 251. Статистики по результату `EXTRACT` у планировщика нет, он подставляет стандартные доли и перемножает их. Для диапазонов он берёт гистограмму по `actual_departure`. В запросе с соединениями такая ошибка может дать плохой план, например `Nested Loop` в расчёте на одну строку.

С индексом, неоптимизированный:

```
Sort  (cost=2597.77..2597.78 rows=1 width=19) (actual time=19.959..20.073 rows=2251 loops=1)
  Sort Key: actual_departure
  Sort Method: quicksort  Memory: 202kB
  Buffers: shared hit=792
  ->  Seq Scan on flights f  (cost=0.00..2597.76 rows=1 width=19) (actual time=0.037..19.528 rows=2251 loops=1)
        Filter: (((status)::text = 'Arrived'::text) AND (EXTRACT(dow FROM actual_departure) = ANY ('{0,6}'::numeric[])) AND (EXTRACT(year FROM actual_departure) = '2017'::numeric) AND (EXTRACT(month FROM actual_departure) = '8'::numeric))
        Rows Removed by Filter: 63413
        Buffers: shared hit=792
Planning:
  Buffers: shared hit=15 read=1
  I/O Timings: shared read=0.025
Planning Time: 0.313 ms
Execution Time: 20.184 ms
```

С индексом:

```
Sort  (cost=1018.15..1022.46 rows=1726 width=19) (actual time=1.616..1.718 rows=2251 loops=1)
  Sort Key: actual_departure
  Sort Method: quicksort  Memory: 202kB
  Buffers: shared hit=759 read=8
  I/O Timings: shared read=0.046
  ->  Bitmap Heap Scan on flights f  (cost=58.08..925.35 rows=1726 width=19) (actual time=0.301..1.246 rows=2251 loops=1)
        Recheck Cond: (((actual_departure >= '2017-08-05 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-08-07 00:00:00+00'::timestamp with time zone)) OR ((actual_departure >= '2017-08-12 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-08-14 00:00:00+00'::timestamp with time zone)) OR ((actual_departure >= '2017-08-19 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-08-21 00:00:00+00'::timestamp with time zone)) OR ((actual_departure >= '2017-08-26 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-08-28 00:00:00+00'::timestamp with time zone)))
        Filter: ((status)::text = 'Arrived'::text)
        Rows Removed by Filter: 1
        Heap Blocks: exact=753
        Buffers: shared hit=759 read=8
        I/O Timings: shared read=0.046
        ->  BitmapOr  (cost=58.08..58.08 rows=2316 width=0) (actual time=0.213..0.214 rows=0 loops=1)
              Buffers: shared hit=6 read=8
              I/O Timings: shared read=0.046
              ->  Bitmap Index Scan on idx_flights_actual_departure  (cost=0.00..25.17 rows=1288 width=0) (actual time=0.117..0.117 rows=1126 loops=1)
                    Index Cond: ((actual_departure >= '2017-08-05 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-08-07 00:00:00+00'::timestamp with time zone))
                    Buffers: shared hit=1 read=4
                    I/O Timings: shared read=0.026
              ->  Bitmap Index Scan on idx_flights_actual_departure  (cost=0.00..22.57 rows=1028 width=0) (actual time=0.093..0.093 rows=1126 loops=1)
                    Index Cond: ((actual_departure >= '2017-08-12 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-08-14 00:00:00+00'::timestamp with time zone))
                    Buffers: shared hit=1 read=4
                    I/O Timings: shared read=0.020
              ->  Bitmap Index Scan on idx_flights_actual_departure  (cost=0.00..4.30 rows=1 width=0) (actual time=0.001..0.002 rows=0 loops=1)
                    Index Cond: ((actual_departure >= '2017-08-19 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-08-21 00:00:00+00'::timestamp with time zone))
                    Buffers: shared hit=2
              ->  Bitmap Index Scan on idx_flights_actual_departure  (cost=0.00..4.30 rows=1 width=0) (actual time=0.001..0.001 rows=0 loops=1)
                    Index Cond: ((actual_departure >= '2017-08-26 00:00:00+00'::timestamp with time zone) AND (actual_departure < '2017-08-28 00:00:00+00'::timestamp with time zone))
                    Buffers: shared hit=2
Planning:
  Buffers: shared hit=10 read=2
  I/O Timings: shared read=0.031
Planning Time: 0.166 ms
Execution Time: 1.865 ms
```

Неоптимизированный запрос не изменился: тот же `Seq Scan` по кешу и 20,2 мс. В индексе лежат значения `actual_departure`, а условие задано на `EXTRACT(...)` от них, и перевести его в диапазон по индексу планировщик не может.
Оптимизированный запрос пошёл по индексу. Четыре `Bitmap Index Scan`, по одному на каждый диапазон, объединены через `BitmapOr`, затем `Bitmap Heap Scan` читает только отмеченные страницы таблицы. Время 1,9 мс, статус проверяется у 2 252 строк вместо 65 664. Страницы индекса прочитаны мимо кеша (`read=8`), потому что индекс только что создан. Страницы таблицы взяты из кеша.
`Heap Blocks: exact=753` значит, что прочитаны 753 страницы таблицы из 792. Рейсы выходных разбросаны по всей таблице, она не упорядочена по дате. Так что выигрыш здесь получается от меньшего числа проверяемых строк, а не от числа страниц.

## Задание 7. ANTI-JOIN

Через `NOT IN`:

```sql
SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.status
FROM flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id
    FROM ticket_flights tf
    WHERE tf.fare_conditions = 'Business'
)
ORDER BY f.flight_id;
```

```
 flight_id | flight_no |  scheduled_departure   |  status   
-----------+-----------+------------------------+-----------
         3 | PG0403    | 2017-08-27 08:25:00+00 | Scheduled
         4 | PG0402    | 2017-08-27 09:25:00+00 | Scheduled
         7 | PG0402    | 2017-06-05 09:25:00+00 | Arrived
         8 | PG0403    | 2017-06-05 08:25:00+00 | Arrived
        11 | PG0403    | 2017-09-04 08:25:00+00 | Scheduled
...
(41705 rows)
```

```
Index Scan using flights_pkey on flights f  (cost=49834.04..52508.10 rows=32832 width=27) (actual time=183.757..212.263 rows=41705 loops=1)
  Filter: (NOT (hashed SubPlan 1))
  Rows Removed by Filter: 23959
  Buffers: shared hit=1989 read=18760
  I/O Timings: shared read=17.409
  SubPlan 1
    ->  Seq Scan on ticket_flights tf  (cost=0.00..49224.19 rows=243823 width=4) (actual time=0.014..147.901 rows=242204 loops=1)
          Filter: ((fare_conditions)::text = 'Business'::text)
          Rows Removed by Filter: 2118131
          Buffers: shared hit=960 read=18760
          I/O Timings: shared read=17.409
Planning:
  Buffers: shared hit=8
Planning Time: 0.141 ms
Execution Time: 214.133 ms
```

Через `NOT EXISTS`:

```sql
SELECT f.flight_id, f.flight_no, f.scheduled_departure, f.status
FROM flights f
WHERE NOT EXISTS (
    SELECT 1
    FROM ticket_flights tf
    WHERE tf.flight_id = f.flight_id
      AND tf.fare_conditions = 'Business'
)
ORDER BY f.flight_id;
```

```
Sort  (cost=56151.28..56245.34 rows=37624 width=27) (actual time=203.727..207.347 rows=41705 loops=1)
  Sort Key: f.flight_id
  Sort Method: quicksort  Memory: 3561kB
  Buffers: shared hit=1819 read=18696
  I/O Timings: shared read=16.120
  ->  Hash Right Anti Join  (cost=2269.44..53291.98 rows=37624 width=27) (actual time=186.444..194.552 rows=41705 loops=1)
        Hash Cond: (tf.flight_id = f.flight_id)
        Buffers: shared hit=1816 read=18696
        I/O Timings: shared read=16.120
        ->  Seq Scan on ticket_flights tf  (cost=0.00..49224.19 rows=243823 width=4) (actual time=0.037..143.489 rows=242204 loops=1)
              Filter: ((fare_conditions)::text = 'Business'::text)
              Rows Removed by Filter: 2118131
              Buffers: shared hit=1024 read=18696
              I/O Timings: shared read=16.120
        ->  Hash  (cost=1448.64..1448.64 rows=65664 width=27) (actual time=15.050..15.052 rows=65664 loops=1)
              Buckets: 131072  Batches: 1  Memory Usage: 5159kB
              Buffers: shared hit=792
              ->  Seq Scan on flights f  (cost=0.00..1448.64 rows=65664 width=27) (actual time=0.004..6.773 rows=65664 loops=1)
                    Buffers: shared hit=792
Planning:
  Buffers: shared hit=11
Planning Time: 0.174 ms
Execution Time: 208.956 ms
```

Оба запроса вернули одинаковые 41 705 рейсов. По диску и кешу они тоже одинаковые: `ticket_flights` прочитана целиком, почти вся через `shared read` (около 18,7 тыс. страниц), `flights` из кеша. `NOT IN` читает `flights` по индексу `flights_pkey`, чтобы сразу получить строки в порядке `flight_id` без сортировки. `NOT EXISTS` читает обе таблицы подряд и сортирует результат в конце.
`NOT EXISTS` планировщик превращает в анти-соединение `Hash Right Anti Join`. Он построил хеш по 65 664 рейсам, прогнал через него 242 204 строки бизнес-класса и вывел рейсы, которым не нашлось ни одной пары. `Right` здесь значит то же, что в задании 2: выводятся строки из хеш-таблицы. Способ соединения и порядок таблиц планировщик выбирает сам.
`NOT IN` превратить в анти-соединение нельзя, потому что с `NULL` он ведёт себя иначе (об этом ниже). Поэтому он остаётся фильтром `NOT (hashed SubPlan 1)`: подзапрос выполняется один раз, его результат складывается в хеш-таблицу, и каждый рейс проверяется по ней.
На этих данных оба варианта работают одинаково, 214 и 209 мс. Так вышло потому, что 242 тыс. значений `flight_id` поместились в память хеш-таблицы (`work_mem` × `hash_mem_multiplier`, то есть 8 МБ). Если памяти не хватает, `NOT IN` теряет хеш и становится очень медленным. Чтобы это показать, я уменьшил `work_mem` до 1 МБ и запустил `NOT IN` только на первых 500 рейсах:

```
Index Scan using flights_pkey on flights f  (cost=0.29..13443544.71 rows=259 width=11) (actual time=275.182..7784.423 rows=253 loops=1)
  Index Cond: (flight_id <= 500)
  Filter: (NOT (SubPlan 1))
  Rows Removed by Filter: 247
  Buffers: shared hit=1132 read=18600, temp read=116645 written=414
  I/O Timings: shared read=20.182, temp read=118.271 write=6.693
  SubPlan 1
    ->  Materialize  (cost=0.00..51396.30 rows=243823 width=4) (actual time=0.001..8.761 rows=136833 loops=500)
          Buffers: shared hit=1120 read=18600, temp read=116645 written=414
          I/O Timings: shared read=20.182, temp read=118.271 write=6.693
          ->  Seq Scan on ticket_flights tf  (cost=0.00..49224.19 rows=243823 width=4) (actual time=0.065..121.782 rows=242204 loops=1)
                Filter: ((fare_conditions)::text = 'Business'::text)
                Rows Removed by Filter: 2118131
                Buffers: shared hit=1120 read=18600
                I/O Timings: shared read=20.182
Planning:
  Buffers: shared hit=3
Planning Time: 0.090 ms
JIT:
  Functions: 12
  Options: Inlining true, Optimization true, Expressions true, Deforming true
  Timing: Generation 0.923 ms, Inlining 59.991 ms, Optimization 18.681 ms, Emission 15.918 ms, Total 95.513 ms
Execution Time: 7786.779 ms
```

Теперь в плане `NOT (SubPlan 1)` без `hashed`. Результат подзапроса лежит в `Materialize`, и для каждого рейса он перебирается, пока не найдётся совпадение: `loops=500`, в среднем 136 833 строки за проход, 7,8 с и `temp read=116645` страниц. На всех 65 664 рейсах это заняло бы больше 15 минут.
`NOT EXISTS` с той же памятью на всей таблице отработал за 0,21 с. Хеш по рейсам разбит на 4 части (`Batches: 4`), временные файлы небольшие, 720 страниц.
Теперь про `NULL`. `x NOT IN (a, b, NULL)` раскрывается в `x <> a AND x <> b AND x <> NULL`. Последнее сравнение даёт `NULL`, и всё выражение не может стать `TRUE`, даже если `x` не равен ни `a`, ни `b`. Поэтому один `NULL` в подзапросе делает результат пустым. Проверка: добавил в подзапрос `NULL` через `UNION ALL`.

```sql
SELECT COUNT(*) AS not_in_with_null
FROM flights f
WHERE f.flight_id NOT IN (
    SELECT tf.flight_id FROM ticket_flights tf WHERE tf.fare_conditions = 'Business'
    UNION ALL
    SELECT NULL
);
```

```
 not_in_with_null 
------------------
                0
(1 row)
```

В нашем запросе ошибки нет: `ticket_flights.flight_id` входит в первичный ключ, и `NULL` там быть не может. На колонке, где `NULL` допустим, запрос с `NOT IN` молча вернул бы ноль строк. У `NOT EXISTS` такой проблемы нет: он сравнивает `tf.flight_id = f.flight_id` построчно, и `NULL` просто ни с чем не совпадает.

## Задание 8. Index Only Scan

```sql
SELECT status, COUNT(*) FROM flights GROUP BY status;
```

Результат:

```
  status   | count 
-----------+-------
 Departed  |    58
 Arrived   | 49235
 On Time   |   518
 Cancelled |   429
 Delayed   |    41
...
(6 rows)
```

План без индекса:

```
HashAggregate  (cost=1776.96..1777.02 rows=6 width=16) (actual time=14.664..14.665 rows=6 loops=1)
  Group Key: status
  Batches: 1  Memory Usage: 24kB
  Buffers: shared hit=792
  ->  Seq Scan on flights  (cost=0.00..1448.64 rows=65664 width=8) (actual time=0.005..4.037 rows=65664 loops=1)
        Buffers: shared hit=792
Planning Time: 0.087 ms
Execution Time: 14.691 ms
```

Затем создал индекс и обновил Visibility Map:

```sql
CREATE INDEX idx_flights_status ON flights (status);
VACUUM flights;
```

План с индексом:

```
GroupAggregate  (cost=0.29..1545.63 rows=6 width=16) (actual time=7.673..10.214 rows=6 loops=1)
  Group Key: status
  Buffers: shared hit=1 read=57
  I/O Timings: shared read=0.328
  ->  Index Only Scan using idx_flights_status on flights  (cost=0.29..1217.25 rows=65664 width=8) (actual time=0.040..4.375 rows=65664 loops=1)
        Heap Fetches: 0
        Buffers: shared hit=1 read=57
        I/O Timings: shared read=0.328
Planning:
  Buffers: shared hit=3
Planning Time: 0.095 ms
Execution Time: 10.239 ms
```

Без индекса `Seq Scan` читает все 792 страницы таблицы (из кеша, `shared hit`), а `HashAggregate` раскладывает 65 664 строки по шести статусам. Время 14,7 мс.
С индексом план стал `Index Only Scan`: прочитано 58 страниц индекса и ни одной страницы таблицы (`Heap Fetches: 0`). Индекс отдаёт статусы уже отсортированными, поэтому вместо хеша работает `GroupAggregate`, который считает группы по очереди. Время 10,2 мс. Страницы индекса пришли как `read`, потому что индекс только что построен и в кеш ещё не попал.
`Index Only Scan` отвечает на запрос по одному индексу, не заходя в таблицу. Здесь это возможно, потому что запросу нужна только колонка `status`, а она есть в индексе, то есть индекс покрывающий. Есть одна сложность. В индексе нет информации о видимости строк: удалённая или ещё не закоммиченная версия строки может оставаться в индексе, а увидеть это можно только в таблице. Для этого есть Visibility Map, по два бита на каждую страницу таблицы. Бит all-visible значит, что все строки на странице видны всем транзакциям. Для таких страниц `Index Only Scan` в таблицу не ходит, для остальных ходит, и такие обращения считаются в `Heap Fetches`. Биты выставляет `VACUUM`, поэтому его нужно запустить после создания индекса и после массовых изменений.
Страниц прочитано в 13,6 раза меньше (58 против 792), а время уменьшилось только в 1,4 раза. Таблица маленькая и целиком лежит в кеше, и большая часть времени уходит на подсчёт 65 тыс. строк. На большой таблице, которая не помещается в кеш, разница в страницах превратится в такую же разницу в чтениях с диска.
