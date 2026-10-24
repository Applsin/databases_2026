ФИО: Кучеровская Арина Александровна
Группа: ДЭ 16-25
ДЗ №4

База `demo-medium-en`, PostgreSQL 16. Все запросы лежат в [`sql/dz4.sql`](sql/dz4.sql), полные выводы — в папке [`output/`](output/).

Каждый запрос я запускала два раза: сначала "холодный" запуск после перезапуска сервера (этот план приведён ниже), потом сразу "тёплый" (он лежит в `output/*_explain_warm.txt`). В строке `Buffers`: `shared hit` — страница была в кеше, `shared read` — её пришлось читать.

## Запросы с семинара

### Задача 1.1

```sql
SELECT f.flight_no, f.departure_airport, f.actual_departure
FROM flights f
JOIN airports a ON a.airport_code = f.departure_airport
WHERE a.city = 'Moscow' AND f.status = 'Arrived'
  AND f.actual_departure >= '2017-08-01' AND f.actual_departure < '2017-09-01'
ORDER BY f.actual_departure;
```

```
 flight_no | departure_airport |    actual_departure
-----------+-------------------+------------------------
 PG0120    | SVO               | 2017-08-01 09:01:00+03
 PG0239    | DME               | 2017-08-01 09:08:00+03
 PG0509    | DME               | 2017-08-01 09:15:00+03
 PG0482    | DME               | 2017-08-01 09:24:00+03
 PG0269    | VKO               | 2017-08-01 09:28:00+03
 PG0335    | DME               | 2017-08-01 09:32:00+03
 PG0405    | DME               | 2017-08-01 09:39:00+03
 PG0241    | SVO               | 2017-08-01 09:41:00+03
...
(1913 строк)
```
Полный вывод: [`output/sem_1_1_data.txt`](output/sem_1_1_data.txt).

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Sort  (cost=2030.18..2030.32 rows=59 width=19) (actual time=18.519..18.689 rows=1913 loops=1)
   Sort Key: f.actual_departure
   Sort Method: quicksort  Memory: 138kB
   Buffers: shared hit=11 read=844
   I/O Timings: shared read=9.915
   ->  Hash Join  (cost=30.57..2028.44 rows=59 width=19) (actual time=3.364..18.002 rows=1913 loops=1)
         Hash Cond: (f.departure_airport = ml.airport_code)
         Buffers: shared hit=8 read=844
         I/O Timings: shared read=9.915
         ->  Seq Scan on flights f  (cost=0.00..1981.12 rows=6130 width=19) (actual time=0.283..13.977 rows=8021 loops=1)
               Filter: ((actual_departure >= '2017-08-01 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-09-01 00:00:00+03'::timestamp with time zone) AND ((status)::text = 'Arrived'::text))
               Rows Removed by Filter: 57643
               Buffers: shared read=832
               I/O Timings: shared read=7.584
         ->  Hash  (cost=30.56..30.56 rows=1 width=4) (actual time=3.060..3.062 rows=3 loops=1)
               Buckets: 1024  Batches: 1  Memory Usage: 9kB
               Buffers: shared hit=8 read=12
               I/O Timings: shared read=2.331
               ->  Seq Scan on airports_data ml  (cost=0.00..30.56 rows=1 width=4) (actual time=2.882..3.047 rows=3 loops=1)
                     Filter: ((city ->> lang()) = 'Moscow'::text)
                     Rows Removed by Filter: 101
                     Buffers: shared hit=8 read=12
                     I/O Timings: shared read=2.331
 Planning:
   Buffers: shared hit=195 read=31 dirtied=1
   I/O Timings: shared read=3.413
 Planning Time: 6.603 ms
 Execution Time: 20.711 ms
```

</details>

Резюме: в холодном запуске 844 страницы прочитаны с диска, в тёплом все 855 страниц нашлись в кеше. Индекс не используется, потому что на `flights` нет индекса ни по дате, ни по статусу, поэтому идёт `Seq Scan` по всей таблице и `Hash Join` с московскими аэропортами.

### Задача 1.2

```sql
SELECT flight_no, scheduled_arrival, actual_arrival,
  round(extract(epoch FROM actual_arrival - scheduled_arrival) / 60) AS delay_min
FROM flights
WHERE actual_arrival - scheduled_arrival > interval '2 hours'
ORDER BY delay_min DESC;
```

```
 flight_no |   scheduled_arrival    |     actual_arrival     | delay_min
-----------+------------------------+------------------------+-----------
 PG0531    | 2017-05-17 11:45:00+03 | 2017-05-17 16:26:00+03 |       281
 PG0132    | 2017-05-22 13:55:00+03 | 2017-05-22 18:36:00+03 |       281
 PG0589    | 2017-07-29 15:55:00+03 | 2017-07-29 20:32:00+03 |       277
 PG0364    | 2017-07-19 13:20:00+03 | 2017-07-19 17:49:00+03 |       269
 PG0151    | 2017-07-03 14:30:00+03 | 2017-07-03 18:57:00+03 |       267
 PG0337    | 2017-06-01 14:10:00+03 | 2017-06-01 18:36:00+03 |       266
 PG0354    | 2017-07-03 10:10:00+03 | 2017-07-03 14:36:00+03 |       266
 PG0544    | 2017-07-06 12:05:00+03 | 2017-07-06 16:31:00+03 |       266
...
(2394 строк)
```
Полный вывод: [`output/sem_1_2_data.txt`](output/sem_1_2_data.txt).

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Sort  (cost=3613.73..3668.45 rows=21888 width=55) (actual time=26.229..26.418 rows=2394 loops=1)
   Sort Key: (round((EXTRACT(epoch FROM (actual_arrival - scheduled_arrival)) / '60'::numeric), 0)) DESC
   Sort Method: quicksort  Memory: 227kB
   Buffers: shared hit=3 read=832
   I/O Timings: shared read=9.491
   ->  Seq Scan on flights  (cost=0.00..2035.84 rows=21888 width=55) (actual time=0.647..24.299 rows=2394 loops=1)
         Filter: ((actual_arrival - scheduled_arrival) > '02:00:00'::interval)
         Rows Removed by Filter: 63270
         Buffers: shared read=832
         I/O Timings: shared read=9.491
 Planning:
   Buffers: shared hit=85 read=23
   I/O Timings: shared read=1.910
 Planning Time: 4.125 ms
 Execution Time: 26.665 ms
```

</details>

Резюме: холодный запуск читает с диска все 832 страницы `flights`, тёплый берёт их из кеша. Индекс тут не используется, потому что условие стоит на разности двух столбцов, а не на самом столбце. Планировщик ожидал 21 888 строк, а на самом деле подошло 2394.

### Задача 1.3

```sql
SELECT flight_no, count(*) FILTER (WHERE status = 'Arrived') AS completed
FROM flights
WHERE flight_no >= 'PG0400' AND flight_no < 'PG0500'
GROUP BY flight_no
ORDER BY flight_no;
```

```
 flight_no | completed
-----------+-----------
 PG0400    |        91
 PG0401    |        91
 PG0402    |        91
 PG0403    |        91
 PG0404    |        90
 PG0405    |        91
...
(100 строк)
```
Полный вывод: [`output/sem_1_3_data.txt`](output/sem_1_3_data.txt).

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Sort  (cost=1329.68..1331.45 rows=710 width=15) (actual time=12.341..12.347 rows=100 loops=1)
   Sort Key: flight_no
   Sort Method: quicksort  Memory: 28kB
   Buffers: shared hit=3 read=219
   I/O Timings: shared read=3.687
   ->  HashAggregate  (cost=1288.96..1296.06 rows=710 width=15) (actual time=12.243..12.260 rows=100 loops=1)
         Group Key: flight_no
         Batches: 1  Memory Usage: 49kB
         Buffers: shared read=219
         I/O Timings: shared read=3.687
         ->  Bitmap Heap Scan on flights  (cost=244.98..1218.30 rows=9421 width=15) (actual time=1.844..10.001 rows=9715 loops=1)
               Recheck Cond: ((flight_no >= 'PG0400'::bpchar) AND (flight_no < 'PG0500'::bpchar))
               Heap Blocks: exact=179
               Buffers: shared read=219
               I/O Timings: shared read=3.687
               ->  Bitmap Index Scan on flights_flight_no_scheduled_departure_key  (cost=0.00..242.63 rows=9421 width=0) (actual time=1.595..1.596 rows=9715 loops=1)
                     Index Cond: ((flight_no >= 'PG0400'::bpchar) AND (flight_no < 'PG0500'::bpchar))
                     Buffers: shared read=40
                     I/O Timings: shared read=0.704
 Planning:
   Buffers: shared hit=86 read=22
   I/O Timings: shared read=1.432
 Planning Time: 3.022 ms
 Execution Time: 12.768 ms
```

</details>

Резюме: здесь индекс используется — `Bitmap Index Scan` по уже существующему индексу `(flight_no, scheduled_departure)`. Холодный запуск прочитал с диска 40 страниц индекса и 179 страниц таблицы, всего 219 вместо 832. Я записала условие через диапазон, потому что с `LIKE 'PG04%'` у меня индекс не использовался и таблица читалась целиком ([`output/sem_1_3_like_explain_cold.txt`](output/sem_1_3_like_explain_cold.txt)).

### Задача 2.1

```sql
SELECT f.departure_airport, a.airport_name, count(*) AS flights,
  round(avg(extract(epoch FROM f.actual_arrival - f.scheduled_arrival) / 60), 1) AS avg_arrival_delay_min
FROM flights f
JOIN airports a ON a.airport_code = f.departure_airport
GROUP BY f.departure_airport, a.airport_name
HAVING count(*) > 500
ORDER BY avg_arrival_delay_min DESC;
```

```
 departure_airport |                  airport_name                  | flights | avg_arrival_delay_min
-------------------+------------------------------------------------+---------+-----------------------
 CEK               | Chelyabinsk Balandino Airport                  |     812 |                  15.9
 SCW               | Syktyvkar Airport                              |     501 |                  15.3
 CSY               | Cheboksary Airport                             |     605 |                  14.7
 IKT               | Irkutsk Airport                                |     727 |                  14.4
 HMA               | Khanty Mansiysk Airport                        |    1021 |                  14.1
 SVX               | Koltsovo Airport                               |    1367 |                  13.9
 PES               | Petrozavodsk Airport                           |     709 |                  13.7
 BZK               | Bryansk Airport                                |    1210 |                  13.7
...
(38 строк)
```
Полный вывод: [`output/sem_2_1_data.txt`](output/sem_2_1_data.txt).

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Sort  (cost=20697.14..20706.15 rows=3605 width=76) (actual time=166.789..166.796 rows=38 loops=1)
   Sort Key: (round(avg((EXTRACT(epoch FROM (f.actual_arrival - f.scheduled_arrival)) / '60'::numeric)), 1)) DESC
   Sort Method: quicksort  Memory: 27kB
   Buffers: shared hit=17 read=840
   I/O Timings: shared read=10.182
   ->  HashAggregate  (cost=19402.65..20484.16 rows=3605 width=76) (actual time=166.488..166.609 rows=38 loops=1)
         Group Key: f.departure_airport, (ml.airport_name ->> lang())
         Filter: (count(*) > 500)
         Batches: 1  Memory Usage: 465kB
         Rows Removed by Filter: 66
         Buffers: shared hit=14 read=840
         I/O Timings: shared read=10.182
         ->  Hash Join  (cost=5.34..18253.53 rows=65664 width=52) (actual time=1.327..126.987 rows=65664 loops=1)
               Hash Cond: (f.departure_airport = ml.airport_code)
               Buffers: shared hit=14 read=840
               I/O Timings: shared read=10.182
               ->  Seq Scan on flights f  (cost=0.00..1488.64 rows=65664 width=20) (actual time=0.255..16.267 rows=65664 loops=1)
                     Buffers: shared read=832
                     I/O Timings: shared read=9.639
               ->  Hash  (cost=4.04..4.04 rows=104 width=65) (actual time=0.180..0.182 rows=104 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 18kB
                     Buffers: shared read=3
                     I/O Timings: shared read=0.123
                     ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=65) (actual time=0.091..0.141 rows=104 loops=1)
                           Buffers: shared read=3
                           I/O Timings: shared read=0.123
 Planning:
   Buffers: shared hit=177 read=33 dirtied=1
   I/O Timings: shared read=1.781
 Planning Time: 4.182 ms
 Execution Time: 169.271 ms
```

</details>

Резюме: в холодном запуске с диска прочитано 840 страниц, в тёплом все 857 взяты из кеша. Индекс не используется, да он тут и не нужен — считаются все 65 664 рейса, проще прочитать таблицу целиком. `HAVING` в плане виден как `Filter` в `HashAggregate`, он отбросил 66 аэропортов из 104.

### Задача 3.1

```sql
SELECT t.passenger_name, tf.amount, f.flight_no,
  dep.city AS departure_city, arr.city AS arrival_city
FROM ticket_flights tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports dep ON dep.airport_code = f.departure_airport
JOIN airports arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC, tf.ticket_no
LIMIT 10;
```

```
  passenger_name   |  amount   | flight_no | departure_city | arrival_city
-------------------+-----------+-----------+----------------+---------------
 PAVEL SCHERBAKOV  | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 ELENA STEPANOVA   | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 NADEZHDA BORISOVA | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 LILIYA KUZMINA    | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 YULIYA FADEEVA    | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 NIKOLAY MAKSIMOV  | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 NIKOLAY MAKSIMOV  | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 EDUARD SOKOLOV    | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 ALEKSANDR SERGEEV | 203300.00 | PG0144    | Moscow         | Petropavlovsk
 IGOR SERGEEV      | 203300.00 | PG0144    | Moscow         | Petropavlovsk
```

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Limit  (cost=193510.50..193515.67 rows=10 width=107) (actual time=5276.328..5276.376 rows=10 loops=1)
   Buffers: shared hit=20 read=34484, temp read=16196 written=16196
   I/O Timings: shared read=288.892, temp read=36.995 write=161.505
   ->  Result  (cost=193510.50..1414983.86 rows=2360335 width=107) (actual time=5233.768..5233.813 rows=10 loops=1)
         Buffers: shared hit=20 read=34484, temp read=16196 written=16196
         I/O Timings: shared read=288.892, temp read=36.995 write=161.505
         ->  Sort  (cost=193510.50..199411.33 rows=2360335 width=141) (actual time=5231.369..5231.382 rows=10 loops=1)
               Sort Key: tf.amount DESC, tf.ticket_no
               Sort Method: top-N heapsort  Memory: 29kB
               Buffers: shared hit=9 read=34475, temp read=16196 written=16196
               I/O Timings: shared read=287.795, temp read=36.995 write=161.505
               ->  Hash Join  (cost=40562.22..142504.50 rows=2360335 width=141) (actual time=441.707..4362.297 rows=2360335 loops=1)
                     Hash Cond: (f.arrival_airport = ml_1.airport_code)
                     Buffers: shared hit=3 read=34475, temp read=16196 written=16196
                     I/O Timings: shared read=287.795, temp read=36.995 write=161.505
                     ->  Hash Join  (cost=40556.88..136050.79 rows=2360335 width=96) (actual time=441.458..3951.742 rows=2360335 loops=1)
                           Hash Cond: (f.departure_airport = ml.airport_code)
                           Buffers: shared hit=3 read=34472, temp read=16196 written=16196
                           I/O Timings: shared read=287.659, temp read=36.995 write=161.505
                           ->  Hash Join  (cost=40551.54..129597.08 rows=2360335 width=51) (actual time=441.407..3536.493 rows=2360335 loops=1)
                                 Hash Cond: (tf.flight_id = f.flight_id)
                                 Buffers: shared read=34472, temp read=16196 written=16196
                                 I/O Timings: shared read=287.659, temp read=36.995 write=161.505
                                 ->  Hash Join  (cost=38242.10..121091.36 rows=2360335 width=40) (actual time=401.633..2695.685 rows=2360335 loops=1)
                                       Hash Cond: (tf.ticket_no = t.ticket_no)
                                       Buffers: shared read=33640, temp read=16196 written=16196
                                       I/O Timings: shared read=278.013, temp read=36.995 write=161.505
                                       ->  Seq Scan on ticket_flights tf  (cost=0.00..43323.35 rows=2360335 width=24) (actual time=0.421..473.396 rows=2360335 loops=1)
                                             Buffers: shared read=19720
                                             I/O Timings: shared read=198.133
                                       ->  Hash  (cost=22210.71..22210.71 rows=829071 width=30) (actual time=400.421..400.423 rows=829071 loops=1)
                                             Buckets: 131072  Batches: 8  Memory Usage: 7319kB
                                             Buffers: shared read=13920, temp written=4434
                                             I/O Timings: shared read=79.879, temp write=25.128
                                             ->  Seq Scan on tickets t  (cost=0.00..22210.71 rows=829071 width=30) (actual time=0.248..183.142 rows=829071 loops=1)
                                                   Buffers: shared read=13920
                                                   I/O Timings: shared read=79.879
                                 ->  Hash  (cost=1488.64..1488.64 rows=65664 width=19) (actual time=39.195..39.196 rows=65664 loops=1)
                                       Buckets: 131072  Batches: 1  Memory Usage: 4359kB
                                       Buffers: shared read=832
                                       I/O Timings: shared read=9.646
                                       ->  Seq Scan on flights f  (cost=0.00..1488.64 rows=65664 width=19) (actual time=0.244..19.220 rows=65664 loops=1)
                                             Buffers: shared read=832
                                             I/O Timings: shared read=9.646
                           ->  Hash  (cost=4.04..4.04 rows=104 width=53) (actual time=0.036..0.037 rows=104 loops=1)
                                 Buckets: 1024  Batches: 1  Memory Usage: 17kB
                                 Buffers: shared hit=3
                                 ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=53) (actual time=0.006..0.019 rows=104 loops=1)
                                       Buffers: shared hit=3
                     ->  Hash  (cost=4.04..4.04 rows=104 width=53) (actual time=0.230..0.231 rows=104 loops=1)
                           Buckets: 1024  Batches: 1  Memory Usage: 17kB
                           Buffers: shared read=3
                           I/O Timings: shared read=0.136
                           ->  Seq Scan on airports_data ml_1  (cost=0.00..4.04 rows=104 width=53) (actual time=0.119..0.177 rows=104 loops=1)
                                 Buffers: shared read=3
                                 I/O Timings: shared read=0.136
 Planning:
   Buffers: shared hit=298 read=55 dirtied=2
   I/O Timings: shared read=3.289
 Planning Time: 6.852 ms
 JIT:
   Functions: 37
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 2.624 ms, Inlining 0.000 ms, Optimization 3.302 ms, Emission 39.425 ms, Total 45.351 ms
 Execution Time: 5357.748 ms
```

</details>

Резюме: это самый долгий запрос, 5,4 с. С диска прочитано 34 484 страницы, и ещё 16 196 страниц ушло во временные файлы, потому что хеш-таблица по билетам не поместилась в память (`Batches: 8`). В тёплом запуске страницы всё равно показаны как `read`, но читаются быстрее (289 мс → 63 мс). Индексы не используются, соединяются все 2,36 млн строк, хотя нужно только 10.

Ещё я заметила, что цена 203 300 есть у 939 билетов, поэтому добавила в сортировку `ticket_no`, чтобы результат был всегда одинаковый.

Попробовала ускорить запрос: сначала выбрать 10 самых дорогих билетов, а потом уже соединять с остальными таблицами:

```sql
SELECT t.passenger_name, tf.amount, f.flight_no,
  dep.city AS departure_city, arr.city AS arrival_city
FROM (SELECT ticket_no, flight_id, amount
      FROM ticket_flights
      ORDER BY amount DESC, ticket_no
      LIMIT 10) tf
JOIN tickets t ON t.ticket_no = tf.ticket_no
JOIN flights f ON f.flight_id = tf.flight_id
JOIN airports dep ON dep.airport_code = f.departure_airport
JOIN airports arr ON arr.airport_code = f.arrival_airport
ORDER BY tf.amount DESC, tf.ticket_no;
```

Результат такой же, а время 1,19 с вместо 5,36 с, временных файлов больше нет ([`output/sem_3_1_fast_explain_cold.txt`](output/sem_3_1_fast_explain_cold.txt)).

### Задача 3.2

```sql
SELECT a.airport_code, a.airport_name, a.city, count(f.flight_id) AS departures
FROM airports a
LEFT JOIN flights f ON f.departure_airport = a.airport_code
GROUP BY a.airport_code, a.airport_name, a.city
ORDER BY departures DESC, a.airport_code;
```

```
 airport_code |                  airport_name                  |        city        | departures
--------------+------------------------------------------------+--------------------+------------
 DME          | Domodedovo International Airport               | Moscow             |       6376
 SVO          | Sheremetyevo International Airport             | Moscow             |       5912
 LED          | Pulkovo Airport                                | St. Petersburg     |       3769
 VKO          | Vnukovo International Airport                  | Moscow             |       3405
 OVB          | Tolmachevo Airport                             | Novosibirsk        |       2091
 KJA          | Yemelyanovo Airport                            | Krasnoyarsk        |       1401
 SVX          | Koltsovo Airport                               | Yekaterinburg      |       1367
 PEE          | Bolshoye Savino Airport                        | Perm               |       1228
...
(104 строк)
```
Полный вывод: [`output/sem_3_2_data.txt`](output/sem_3_2_data.txt).

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Sort  (cost=35547.37..35547.63 rows=104 width=76) (actual time=194.736..194.743 rows=104 loops=1)
   Sort Key: (count(f.flight_id)) DESC, ml.airport_code
   Sort Method: quicksort  Memory: 32kB
   Buffers: shared hit=22 read=837
   I/O Timings: shared read=10.253
   ->  HashAggregate  (cost=35490.33..35543.89 rows=104 width=76) (actual time=194.643..194.659 rows=104 loops=1)
         Group Key: ml.airport_code, (ml.airport_name ->> lang()), (ml.city ->> lang())
         Batches: 1  Memory Usage: 32kB
         Buffers: shared hit=16 read=837
         I/O Timings: shared read=10.253
         ->  Hash Right Join  (cost=5.34..34833.69 rows=65664 width=72) (actual time=1.064..173.954 rows=65664 loops=1)
               Hash Cond: (f.departure_airport = ml.airport_code)
               Buffers: shared hit=16 read=837
               I/O Timings: shared read=10.253
               ->  Seq Scan on flights f  (cost=0.00..1488.64 rows=65664 width=8) (actual time=0.129..15.630 rows=65664 loops=1)
                     Buffers: shared read=832
                     I/O Timings: shared read=9.971
               ->  Hash  (cost=4.04..4.04 rows=104 width=114) (actual time=0.234..0.236 rows=104 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 23kB
                     Buffers: shared read=3
                     I/O Timings: shared read=0.105
                     ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=114) (actual time=0.158..0.206 rows=104 loops=1)
                           Buffers: shared read=3
                           I/O Timings: shared read=0.105
 Planning:
   Buffers: shared hit=169 read=34
   I/O Timings: shared read=2.143
 Planning Time: 4.874 ms
 Execution Time: 197.096 ms
```

</details>

Резюме: холодный запуск читает с диска 837 страниц, в тёплом все 859 берутся из кеша. Индексы не используются, потому что считаются все вылеты. `LEFT JOIN` в плане стал `Hash Right Join` (про него подробнее в задании 2). Аэропортов совсем без вылетов в базе нет, но `count(f.flight_id)` показал бы для них 0.

### Задача 3.3

```sql
SELECT t.passenger_id, t.passenger_name, count(*) AS flights, sum(tf.amount) AS total_spent
FROM tickets t
JOIN ticket_flights tf ON tf.ticket_no = t.ticket_no
GROUP BY t.passenger_id, t.passenger_name
ORDER BY total_spent DESC
LIMIT 5;
```

```
 passenger_id |   passenger_name   | flights | total_spent
--------------+--------------------+---------+-------------
 2034 201228  | ANTONINA KUZNECOVA |       6 |   529500.00
 3272 478491  | EKATERINA LAZAREVA |       6 |   506700.00
 6615 949899  | ELENA VASILEVA     |       6 |   505500.00
 7989 541468  | EVGENIY TARASOV    |       6 |   495300.00
 4805 339011  | DMITRIY KUZMIN     |       6 |   494700.00
```

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Limit  (cost=403674.54..403674.55 rows=5 width=68) (actual time=5490.632..5490.640 rows=5 loops=1)
   Buffers: shared hit=3 read=33640, temp read=32216 written=47725
   I/O Timings: shared read=233.334, temp read=66.180 write=606.623
   ->  Sort  (cost=403674.54..405747.22 rows=829071 width=68) (actual time=5465.451..5465.458 rows=5 loops=1)
         Sort Key: (sum(tf.amount)) DESC
         Sort Method: top-N heapsort  Memory: 25kB
         Buffers: shared hit=3 read=33640, temp read=32216 written=47725
         I/O Timings: shared read=233.334, temp read=66.180 write=606.623
         ->  HashAggregate  (cost=342660.35..389903.97 rows=829071 width=68) (actual time=3889.906..5273.748 rows=829071 loops=1)
               Group Key: t.passenger_id, t.passenger_name
               Planned Partitions: 64  Batches: 65  Memory Usage: 8209kB  Disk Usage: 126880kB
               Buffers: shared read=33640, temp read=32216 written=47725
               I/O Timings: shared read=233.334, temp read=66.180 write=606.623
               ->  Hash Join  (cost=39861.10..124329.36 rows=2360335 width=34) (actual time=396.665..2449.570 rows=2360335 loops=1)
                     Hash Cond: (tf.ticket_no = t.ticket_no)
                     Buffers: shared read=33640, temp read=16797 written=16797
                     I/O Timings: shared read=233.334, temp read=36.322 write=156.489
                     ->  Seq Scan on ticket_flights tf  (cost=0.00..43323.35 rows=2360335 width=20) (actual time=0.191..434.400 rows=2360335 loops=1)
                           Buffers: shared read=19720
                           I/O Timings: shared read=182.946
                     ->  Hash  (cost=22210.71..22210.71 rows=829071 width=42) (actual time=395.753..395.756 rows=829071 loops=1)
                           Buckets: 131072  Batches: 16  Memory Usage: 4780kB
                           Buffers: shared read=13920, temp written=5888
                           I/O Timings: shared read=50.389, temp write=30.425
                           ->  Seq Scan on tickets t  (cost=0.00..22210.71 rows=829071 width=42) (actual time=0.200..151.332 rows=829071 loops=1)
                                 Buffers: shared read=13920
                                 I/O Timings: shared read=50.389
 Planning:
   Buffers: shared hit=220 read=44
   I/O Timings: shared read=2.715
 Planning Time: 5.638 ms
 JIT:
   Functions: 18
   Options: Inlining false, Optimization false, Expressions true, Deforming true
   Timing: Generation 1.766 ms, Inlining 0.000 ms, Optimization 2.305 ms, Emission 27.521 ms, Total 31.592 ms
 Execution Time: 5573.906 ms
```

</details>

Резюме: запрос много работает с диском. С диска прочитано 33 640 страниц таблиц, и ещё группировка по 829 071 пассажиру не поместилась в память, поэтому `HashAggregate` писал временные файлы (`Disk Usage: 126880kB`). Тёплый запуск не быстрее холодного (около 6 с), потому что `tickets` и `ticket_flights` большие и в кеше не остаются. Индексы не используются.

## Основные задания

### Задание 1. ROLLUP

```sql
SELECT date_trunc('month', book_date)::date AS month, sum(total_amount) AS revenue
FROM bookings
WHERE book_date >= '2017-01-01' AND book_date < '2018-01-01'
GROUP BY ROLLUP (date_trunc('month', book_date))
HAVING sum(total_amount) > 10000000000
  OR GROUPING(date_trunc('month', book_date)) = 1
ORDER BY month NULLS LAST;
```

```
   month    |    revenue
------------+----------------
 2017-05-01 | 12968141200.00
 2017-06-01 | 13091987500.00
 2017-07-01 | 13609642400.00
            | 47004388200.00
```

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Sort  (cost=93647.64..93751.55 rows=41563 width=44) (actual time=498.124..498.126 rows=4 loops=1)
   Sort Key: (((date_trunc('month'::text, book_date)))::date)
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=6 read=3780, temp read=2397 written=2407
   I/O Timings: shared read=37.108, temp read=4.933 write=10.067
   ->  GroupAggregate  (cost=83228.45..90459.13 rows=41563 width=44) (actual time=381.045..498.087 rows=4 loops=1)
         Group Key: (date_trunc('month'::text, book_date))
         Group Key: ()
         Filter: ((sum(total_amount) > '10000000000'::numeric) OR (GROUPING((date_trunc('month'::text, book_date))) = 1))
         Rows Removed by Filter: 2
         Buffers: shared hit=3 read=3780, temp read=2397 written=2407
         I/O Timings: shared read=37.108, temp read=4.933 write=10.067
         ->  Sort  (cost=83228.45..84711.74 rows=593314 width=22) (actual time=339.913..399.559 rows=593433 loops=1)
               Sort Key: (date_trunc('month'::text, book_date))
               Sort Method: external merge  Disk: 19176kB
               Buffers: shared hit=3 read=3780, temp read=2397 written=2407
               I/O Timings: shared read=37.108, temp read=4.933 write=10.067
               ->  Seq Scan on bookings  (cost=0.00..14164.78 rows=593314 width=22) (actual time=0.527..222.448 rows=593433 loops=1)
                     Filter: ((book_date >= '2017-01-01 00:00:00+03'::timestamp with time zone) AND (book_date < '2018-01-01 00:00:00+03'::timestamp with time zone))
                     Buffers: shared read=3780
                     I/O Timings: shared read=37.108
 Planning:
   Buffers: shared hit=78 read=20
   I/O Timings: shared read=1.331
 Planning Time: 3.194 ms
 Execution Time: 501.252 ms
```

</details>

Резюме: с диска прочитаны все 3780 страниц `bookings`, в тёплом запуске они уже в кеше. Сортировка не поместилась в память и шла на диске (`Sort Method: external merge Disk: 19176kB`). Индекс не используется, потому что под условие попадает весь 2017 год, то есть почти вся таблица.

`ROLLUP` в плане видно по двум строкам `Group Key` в `GroupAggregate`: одна для месяцев, а `Group Key: ()` — это общий итог.

Как `HAVING` работает с `ROLLUP`: сначала считаются все строки (и месяцы, и итог), а потом к ним применяется `HAVING`. В плане это `Filter` в том же `GroupAggregate`, `Rows Removed by Filter: 2` — убраны два месяца с выручкой меньше 10 млрд.

Почему итоговая строка проходит фильтр: в `HAVING` сравнивается сумма, а не месяц. У итоговой строки месяц `NULL`, но сумма 47 млрд, она больше 10 млрд, значит условие верное. А `OR GROUPING(...) = 1` я добавила на всякий случай: `GROUPING` равен 1 как раз для итоговой строки, так что итог останется при любом пороге.

Ещё заметила, что итог не равен сумме трёх показанных месяцев, потому что он считается по всем месяцам, включая отфильтрованные.

### Задание 2. LEFT JOIN

Условие в `ON`:

```sql
SELECT a.airport_code, a.airport_name, count(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code AND f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC, a.airport_code;
```

```
 airport_code |                  airport_name                  | arrived_flights
--------------+------------------------------------------------+-----------------
 DME          | Domodedovo International Airport               |            4775
 SVO          | Sheremetyevo International Airport             |            4431
 LED          | Pulkovo Airport                                |            2825
 VKO          | Vnukovo International Airport                  |            2553
 OVB          | Tolmachevo Airport                             |            1572
 KJA          | Yemelyanovo Airport                            |            1053
 SVX          | Koltsovo Airport                               |            1025
 PEE          | Bolshoye Savino Airport                        |             920
...
(104 строк)
```
Полный вывод: [`output/dz2_on_data.txt`](output/dz2_on_data.txt).

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Sort  (cost=14667.10..14667.36 rows=104 width=44) (actual time=85.221..85.230 rows=104 loops=1)
   Sort Key: (count(f.flight_id)) DESC, ml.airport_code
   Sort Method: quicksort  Memory: 31kB
   Buffers: shared hit=19 read=837
   I/O Timings: shared read=7.461
   ->  HashAggregate  (cost=14636.31..14663.61 rows=104 width=44) (actual time=85.132..85.147 rows=104 loops=1)
         Group Key: ml.airport_code, (ml.airport_name ->> lang())
         Batches: 1  Memory Usage: 32kB
         Buffers: shared hit=13 read=837
         I/O Timings: shared read=7.461
         ->  Hash Right Join  (cost=5.34..14265.83 rows=49397 width=40) (actual time=1.232..73.221 rows=49235 loops=1)
               Hash Cond: (f.arrival_airport = ml.airport_code)
               Buffers: shared hit=13 read=837
               I/O Timings: shared read=7.461
               ->  Seq Scan on flights f  (cost=0.00..1652.80 rows=49397 width=8) (actual time=0.146..15.786 rows=49235 loops=1)
                     Filter: ((status)::text = 'Arrived'::text)
                     Rows Removed by Filter: 16429
                     Buffers: shared read=832
                     I/O Timings: shared read=7.143
               ->  Hash  (cost=4.04..4.04 rows=104 width=65) (actual time=0.413..0.414 rows=104 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 18kB
                     Buffers: shared read=3
                     I/O Timings: shared read=0.187
                     ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=65) (actual time=0.263..0.385 rows=104 loops=1)
                           Buffers: shared read=3
                           I/O Timings: shared read=0.187
 Planning:
   Buffers: shared hit=168 read=33
   I/O Timings: shared read=1.666
 Planning Time: 3.941 ms
 Execution Time: 87.124 ms
```

</details>

Контрольный запуск, условие в `WHERE`:

```sql
SELECT a.airport_code, a.airport_name, count(f.flight_id) AS arrived_flights
FROM airports a
LEFT JOIN flights f ON f.arrival_airport = a.airport_code
WHERE f.status = 'Arrived'
GROUP BY a.airport_code, a.airport_name
ORDER BY arrived_flights DESC, a.airport_code;
```

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Sort  (cost=14667.10..14667.36 rows=104 width=44) (actual time=95.681..95.688 rows=104 loops=1)
   Sort Key: (count(f.flight_id)) DESC, ml.airport_code
   Sort Method: quicksort  Memory: 31kB
   Buffers: shared hit=19 read=837
   I/O Timings: shared read=8.508
   ->  HashAggregate  (cost=14636.31..14663.61 rows=104 width=44) (actual time=95.604..95.617 rows=104 loops=1)
         Group Key: ml.airport_code, (ml.airport_name ->> lang())
         Batches: 1  Memory Usage: 32kB
         Buffers: shared hit=13 read=837
         I/O Timings: shared read=8.508
         ->  Hash Join  (cost=5.34..14265.83 rows=49397 width=40) (actual time=1.131..83.711 rows=49235 loops=1)
               Hash Cond: (f.arrival_airport = ml.airport_code)
               Buffers: shared hit=13 read=837
               I/O Timings: shared read=8.508
               ->  Seq Scan on flights f  (cost=0.00..1652.80 rows=49397 width=8) (actual time=0.281..18.989 rows=49235 loops=1)
                     Filter: ((status)::text = 'Arrived'::text)
                     Rows Removed by Filter: 16429
                     Buffers: shared read=832
                     I/O Timings: shared read=8.213
               ->  Hash  (cost=4.04..4.04 rows=104 width=65) (actual time=0.214..0.215 rows=104 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 18kB
                     Buffers: shared read=3
                     I/O Timings: shared read=0.118
                     ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=65) (actual time=0.081..0.134 rows=104 loops=1)
                           Buffers: shared read=3
                           I/O Timings: shared read=0.118
 Planning:
   Buffers: shared hit=168 read=33
   I/O Timings: shared read=2.343
 Planning Time: 4.987 ms
 Execution Time: 97.601 ms
```

</details>

На всей базе оба запроса вернули по 104 строки, потому что в каждый аэропорт был хотя бы один прилёт. Но планы разные: с условием в `WHERE` вместо `Hash Right Join` получился обычный `Hash Join`, то есть `LEFT JOIN` фактически стал обычным `JOIN`.

Чтобы увидеть разницу в данных, я повторила оба запроса за один день, 15.08.2017 (в этот день прилёты были не во все аэропорты). С условием в `ON` получилось 104 строки, из них 9 с нулём. С условием в `WHERE` — только 95 строк, эти 9 аэропортов просто пропали. Вывод лежит в [`output/dz2_dz7_controls.txt`](output/dz2_dz7_controls.txt).

Почему нельзя `COUNT(*)`: если у аэропорта нет прилётов, после `LEFT JOIN` для него всё равно остаётся одна строка, где поля рейса `NULL`. `COUNT(*)` посчитает эту строку и выдаст 1, а `COUNT(f.flight_id)` не считает `NULL` и выдаст 0. За 15.08 у всех 9 таких аэропортов так и получилось: `COUNT(*) = 1`, `COUNT(f.flight_id) = 0`.

Что значит `Hash Right Join`: PostgreSQL строит хеш-таблицу по маленькой таблице аэропортов и прогоняет через неё рейсы. Так как аэропорты — это та сторона, которую по `LEFT JOIN` надо сохранить, а она оказалась справа, соединение называется правым. По смыслу это тот же `LEFT JOIN`, просто таблицы поменяны местами.

Резюме: оба варианта прочитали с диска 837 страниц, в тёплом запуске всё из кеша. Индекс не используется, его по статусу нет, и статус `Arrived` у большинства рейсов, так что читается вся таблица.

### Задание 3. Sargability

Неоптимизированный запрос (`EXTRACT`):

```sql
SELECT flight_id, flight_no, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND EXTRACT(YEAR FROM actual_departure) = 2017
  AND EXTRACT(MONTH FROM actual_departure) = 8
  AND EXTRACT(DOW FROM actual_departure) IN (0, 6)
ORDER BY actual_departure;
```

Оптимизированный запрос (диапазоны дат, выходные в августе 2017 — 5–6, 12–13, 19–20 и 26–27 число):

```sql
SELECT flight_id, flight_no, actual_departure
FROM flights
WHERE status = 'Arrived'
  AND ((actual_departure >= '2017-08-05' AND actual_departure < '2017-08-07')
    OR (actual_departure >= '2017-08-12' AND actual_departure < '2017-08-14')
    OR (actual_departure >= '2017-08-19' AND actual_departure < '2017-08-21')
    OR (actual_departure >= '2017-08-26' AND actual_departure < '2017-08-28'))
ORDER BY actual_departure;
```

Оба запроса вернули одинаковые 2251 строку.

```
 flight_id | flight_no |    actual_departure
-----------+-----------+------------------------
     52954 | PG0328    | 2017-08-05 02:50:00+03
     31201 | PG0244    | 2017-08-05 03:22:00+03
     52510 | PG0088    | 2017-08-05 03:25:00+03
     39604 | PG0037    | 2017-08-05 03:41:00+03
     35961 | PG0398    | 2017-08-05 03:52:00+03
     52879 | PG0660    | 2017-08-05 03:57:00+03
...
(2251 строк)
```
Полный вывод: [`output/dz3_data.txt`](output/dz3_data.txt).

Сначала я запустила оба запроса без индекса. Индекса по дате вылета на `flights` нет, поэтому оба читают всю таблицу:

<details>
<summary>EXTRACT, без индекса</summary>

```
 Sort  (cost=2637.77..2637.78 rows=1 width=19) (actual time=45.123..45.280 rows=2251 loops=1)
   Sort Key: actual_departure
   Sort Method: quicksort  Memory: 202kB
   Buffers: shared hit=3 read=832
   I/O Timings: shared read=9.557
   ->  Seq Scan on flights  (cost=0.00..2637.76 rows=1 width=19) (actual time=0.730..44.099 rows=2251 loops=1)
         Filter: (((status)::text = 'Arrived'::text) AND (EXTRACT(dow FROM actual_departure) = ANY ('{0,6}'::numeric[])) AND (EXTRACT(year FROM actual_departure) = '2017'::numeric) AND (EXTRACT(month FROM actual_departure) = '8'::numeric))
         Rows Removed by Filter: 63413
         Buffers: shared read=832
         I/O Timings: shared read=9.557
 Planning:
   Buffers: shared hit=123 read=24
   I/O Timings: shared read=1.814
 Planning Time: 4.272 ms
 Execution Time: 45.408 ms
```

</details>

<details>
<summary>Диапазоны, без индекса</summary>

```
 Sort  (cost=3060.16..3064.53 rows=1747 width=19) (actual time=14.981..15.159 rows=2251 loops=1)
   Sort Key: actual_departure
   Sort Method: quicksort  Memory: 202kB
   Buffers: shared hit=3 read=832
   I/O Timings: shared read=6.495
   ->  Seq Scan on flights  (cost=0.00..2966.08 rows=1747 width=19) (actual time=0.268..14.279 rows=2251 loops=1)
         Filter: (((status)::text = 'Arrived'::text) AND (((actual_departure >= '2017-08-05 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-07 00:00:00+03'::timestamp with time zone)) OR ((actual_departure >= '2017-08-12 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-14 00:00:00+03'::timestamp with time zone)) OR ((actual_departure >= '2017-08-19 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-21 00:00:00+03'::timestamp with time zone)) OR ((actual_departure >= '2017-08-26 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-28 00:00:00+03'::timestamp with time zone))))
         Rows Removed by Filter: 63413
         Buffers: shared read=832
         I/O Timings: shared read=6.495
 Planning:
   Buffers: shared hit=97 read=23
   I/O Timings: shared read=1.401
 Planning Time: 2.909 ms
 Execution Time: 15.527 ms
```

</details>

Потом создала индекс по `actual_departure` и повторила оба запроса:

<details>
<summary>EXTRACT, с индексом</summary>

```
 Sort  (cost=2637.77..2637.78 rows=1 width=19) (actual time=30.504..30.731 rows=2251 loops=1)
   Sort Key: actual_departure
   Sort Method: quicksort  Memory: 202kB
   Buffers: shared hit=3 read=832
   I/O Timings: shared read=6.946
   ->  Seq Scan on flights  (cost=0.00..2637.76 rows=1 width=19) (actual time=0.491..29.759 rows=2251 loops=1)
         Filter: (((status)::text = 'Arrived'::text) AND (EXTRACT(dow FROM actual_departure) = ANY ('{0,6}'::numeric[])) AND (EXTRACT(year FROM actual_departure) = '2017'::numeric) AND (EXTRACT(month FROM actual_departure) = '8'::numeric))
         Rows Removed by Filter: 63413
         Buffers: shared read=832
         I/O Timings: shared read=6.946
 Planning:
   Buffers: shared hit=134 read=25 dirtied=3
   I/O Timings: shared read=1.646
 Planning Time: 4.036 ms
 Execution Time: 30.865 ms
```

</details>

<details>
<summary>Диапазоны, с индексом</summary>

```
 Sort  (cost=1058.45..1062.77 rows=1727 width=19) (actual time=9.399..9.538 rows=2251 loops=1)
   Sort Key: actual_departure
   Sort Method: quicksort  Memory: 202kB
   Buffers: shared hit=9 read=761
   I/O Timings: shared read=6.479
   ->  Bitmap Heap Scan on flights  (cost=58.13..965.59 rows=1727 width=19) (actual time=1.049..8.712 rows=2251 loops=1)
         Recheck Cond: (((actual_departure >= '2017-08-05 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-07 00:00:00+03'::timestamp with time zone)) OR ((actual_departure >= '2017-08-12 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-14 00:00:00+03'::timestamp with time zone)) OR ((actual_departure >= '2017-08-19 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-21 00:00:00+03'::timestamp with time zone)) OR ((actual_departure >= '2017-08-26 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-28 00:00:00+03'::timestamp with time zone)))
         Filter: ((status)::text = 'Arrived'::text)
         Rows Removed by Filter: 1
         Heap Blocks: exact=753
         Buffers: shared hit=6 read=761
         I/O Timings: shared read=6.479
         ->  BitmapOr  (cost=58.13..58.13 rows=2322 width=0) (actual time=0.666..0.668 rows=0 loops=1)
               Buffers: shared hit=6 read=8
               I/O Timings: shared read=0.337
               ->  Bitmap Index Scan on idx_flights_actual_departure  (cost=0.00..25.26 rows=1297 width=0) (actual time=0.360..0.360 rows=1126 loops=1)
                     Index Cond: ((actual_departure >= '2017-08-05 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-07 00:00:00+03'::timestamp with time zone))
                     Buffers: shared hit=1 read=4
                     I/O Timings: shared read=0.229
               ->  Bitmap Index Scan on idx_flights_actual_departure  (cost=0.00..22.53 rows=1024 width=0) (actual time=0.170..0.171 rows=1126 loops=1)
                     Index Cond: ((actual_departure >= '2017-08-12 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-14 00:00:00+03'::timestamp with time zone))
                     Buffers: shared hit=1 read=4
                     I/O Timings: shared read=0.107
               ->  Bitmap Index Scan on idx_flights_actual_departure  (cost=0.00..4.30 rows=1 width=0) (actual time=0.003..0.003 rows=0 loops=1)
                     Index Cond: ((actual_departure >= '2017-08-19 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-21 00:00:00+03'::timestamp with time zone))
                     Buffers: shared hit=2
               ->  Bitmap Index Scan on idx_flights_actual_departure  (cost=0.00..4.30 rows=1 width=0) (actual time=0.001..0.001 rows=0 loops=1)
                     Index Cond: ((actual_departure >= '2017-08-26 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-08-28 00:00:00+03'::timestamp with time zone))
                     Buffers: shared hit=2
 Planning:
   Buffers: shared hit=117 read=27
   I/O Timings: shared read=2.546
 Planning Time: 4.887 ms
 Execution Time: 10.166 ms
```

</details>

| | План | Холодный | Тёплый |
|---|---|---|---|
| `EXTRACT`, без индекса | `Seq Scan` | 45,4 мс | 29,3 мс |
| Диапазоны, без индекса | `Seq Scan` | 15,5 мс | 14,6 мс |
| `EXTRACT`, с индексом | `Seq Scan` | 30,9 мс | 25,4 мс |
| Диапазоны, с индексом | `Bitmap Heap Scan` + `BitmapOr` | 10,2 мс | 3,5 мс |

Разница в планах: запрос с `EXTRACT` не использует индекс даже после того, как я его создала. В индексе хранятся сами значения `actual_departure`, а в условии стоит функция от них, поэтому её приходится считать для каждой строки и читать всю таблицу (`Seq Scan`). В запросе с диапазонами столбец сравнивается просто с датами, и индекс подходит: в плане четыре `Bitmap Index Scan` (по одному на каждые выходные), которые объединяются через `BitmapOr`.

Ещё видно, что для `EXTRACT` планировщик ожидал всего 1 строку (`rows=1`), а для диапазонов 1727, что гораздо ближе к настоящим 2251.

Резюме: без индекса оба запроса читают с диска всю таблицу (832 страницы), в тёплом запуске — из кеша. С индексом запрос с диапазонами использует его через `Bitmap Index Scan` и читает 770 страниц, а запрос с `EXTRACT` индекс не использует. Выигрыш по страницам небольшой, потому что нужные рейсы разбросаны почти по всей таблице.

### Задание 7. Anti-join

`NOT IN`:

```sql
SELECT f.flight_id, f.flight_no, f.status
FROM flights f
WHERE f.flight_id NOT IN (SELECT tf.flight_id FROM ticket_flights tf
                          WHERE tf.fare_conditions = 'Business');
```

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Seq Scan on flights f  (cost=49841.42..51494.22 rows=32832 width=19) (actual time=362.946..407.982 rows=41705 loops=1)
   Filter: (NOT (hashed SubPlan 1))
   Rows Removed by Filter: 23959
   Buffers: shared read=20552
   I/O Timings: shared read=90.592
   SubPlan 1
     ->  Seq Scan on ticket_flights tf  (cost=0.00..49224.19 rows=246891 width=4) (actual time=0.158..294.573 rows=242204 loops=1)
           Filter: ((fare_conditions)::text = 'Business'::text)
           Rows Removed by Filter: 2118131
           Buffers: shared read=19720
           I/O Timings: shared read=80.067
 Planning:
   Buffers: shared hit=88 read=23
   I/O Timings: shared read=1.201
 Planning Time: 2.483 ms
 Execution Time: 412.121 ms
```

</details>

`NOT EXISTS`:

```sql
SELECT f.flight_id, f.flight_no, f.status
FROM flights f
WHERE NOT EXISTS (SELECT 1 FROM ticket_flights tf
                  WHERE tf.flight_id = f.flight_id AND tf.fare_conditions = 'Business');
```

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 Hash Right Anti Join  (cost=2309.44..53344.81 rows=37858 width=19) (actual time=294.042..303.694 rows=41705 loops=1)
   Hash Cond: (tf.flight_id = f.flight_id)
   Buffers: shared read=20552
   I/O Timings: shared read=71.359
   ->  Seq Scan on ticket_flights tf  (cost=0.00..49224.19 rows=246891 width=4) (actual time=0.384..215.710 rows=242204 loops=1)
         Filter: ((fare_conditions)::text = 'Business'::text)
         Rows Removed by Filter: 2118131
         Buffers: shared read=19720
         I/O Timings: shared read=64.547
   ->  Hash  (cost=1488.64..1488.64 rows=65664 width=19) (actual time=31.308..31.315 rows=65664 loops=1)
         Buckets: 131072  Batches: 1  Memory Usage: 4326kB
         Buffers: shared read=832
         I/O Timings: shared read=6.812
         ->  Seq Scan on flights f  (cost=0.00..1488.64 rows=65664 width=19) (actual time=0.290..14.428 rows=65664 loops=1)
               Buffers: shared read=832
               I/O Timings: shared read=6.812
 Planning:
   Buffers: shared hit=196 read=36
   I/O Timings: shared read=1.935
 Planning Time: 4.123 ms
 Execution Time: 305.293 ms
```

</details>

Оба запроса вернули одни и те же 41 705 рейсов.

```
 flight_id | flight_no |  status
-----------+-----------+-----------
      2026 | PG0335    | Scheduled
     46770 | PG0648    | Arrived
     59315 | PG0385    | Scheduled
     55290 | PG0354    | Arrived
     56414 | PG0431    | Arrived
     49059 | PG0111    | Arrived
...
(41705 строк)
```
Полный вывод: [`output/dz7_data.txt`](output/dz7_data.txt).

По времени: `NOT IN` — 412 мс (тёплый 384 мс), `NOT EXISTS` — 305 мс (тёплый 291 мс).

Почему `NOT EXISTS` эффективнее: его планировщик превращает в anti join (в плане `Hash Right Anti Join`), то есть в обычное соединение, для которого он может выбрать удобный способ. `NOT IN` так переделать нельзя из-за `NULL` (про это ниже), поэтому он выполняется как фильтр с подзапросом (`Filter: NOT (hashed SubPlan 1)`): каждая строка `flights` проверяется по результату подзапроса.

У меня `NOT IN` отработал нормально, потому что результат подзапроса поместился в память и по нему построилась хеш-таблица (`hashed SubPlan`). Чтобы проверить, что будет, если памяти мало, я поставила `work_mem = 64kB`:

```
Filter: (NOT (SubPlan 1))
SubPlan 1
  ->  Materialize (actual rows=140896 loops=50)
        ->  Seq Scan on ticket_flights tf (actual rows=242204 loops=1)
Execution Time: 982.979 ms
```

Хеш-таблица уже не помещается, и подзапрос перебирается заново для каждой строки: только на 50 рейсах получилось 0,98 с. `NOT EXISTS` с теми же 64 КБ выполнился за 136 мс по всем рейсам.

Почему `NOT IN` опасен при `NULL`: `x NOT IN (a, b, NULL)` — это `x <> a AND x <> b AND x <> NULL`. Сравнение с `NULL` даёт `UNKNOWN`, поэтому всё условие никогда не будет `TRUE`, и запрос вернёт 0 строк. Я проверила: без `NULL` `NOT IN` вернул 41 705 строк, а если добавить в подзапрос один `NULL` — 0 строк. `NOT EXISTS` с тем же подзапросом всё равно вернул 41 705, потому что он просто проверяет, есть ли подходящая строка. В этой базе `ticket_flights.flight_id` не может быть `NULL`, но в других таблицах так может случиться.

Резюме: оба запроса читают одни и те же 20 552 страницы — всю `ticket_flights` и всю `flights`. В тёплом запуске страницы `ticket_flights` всё равно идут как `read`, потому что таблица большая и не остаётся в кеше PostgreSQL, но читается быстрее. Индексы не используются.

### Задание 8. Index Only Scan

```sql
SELECT status, count(*)
FROM flights
GROUP BY status;
```

```
  status   | count
-----------+-------
 Departed  |    58
 Arrived   | 49235
 On Time   |   518
 Cancelled |   429
 Delayed   |    41
 Scheduled | 15383
```

До создания индекса:

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 HashAggregate  (cost=1816.96..1817.02 rows=6 width=16) (actual time=35.637..35.641 rows=6 loops=1)
   Group Key: status
   Batches: 1  Memory Usage: 24kB
   Buffers: shared read=832
   I/O Timings: shared read=8.931
   ->  Seq Scan on flights  (cost=0.00..1488.64 rows=65664 width=8) (actual time=0.233..15.876 rows=65664 loops=1)
         Buffers: shared read=832
         I/O Timings: shared read=8.931
 Planning:
   Buffers: shared hit=83 read=22 dirtied=1
   I/O Timings: shared read=1.497
 Planning Time: 3.307 ms
 Execution Time: 36.480 ms
```

</details>

После `CREATE INDEX idx_flights_status ON flights(status)` и `VACUUM flights`:

<details>
<summary>EXPLAIN (ANALYZE, BUFFERS) — холодный запуск</summary>

```
 GroupAggregate  (cost=0.29..1482.49 rows=6 width=16) (actual time=7.863..10.108 rows=6 loops=1)
   Group Key: status
   Buffers: shared read=58
   I/O Timings: shared read=1.045
   ->  Index Only Scan using idx_flights_status on flights  (cost=0.29..1169.89 rows=62507 width=8) (actual time=0.239..5.133 rows=65664 loops=1)
         Heap Fetches: 0
         Buffers: shared read=58
         I/O Timings: shared read=1.045
 Planning:
   Buffers: shared hit=99 read=23
   I/O Timings: shared read=1.259
 Planning Time: 2.752 ms
 Execution Time: 11.698 ms
```

</details>

Без индекса запрос прочитал 832 страницы за 36,5 мс, с индексом — 58 страниц за 11,7 мс.

Что такое `Index Only Scan`: обычно по индексу находится адрес строки, а потом сама строка читается из таблицы. Но здесь запросу нужен только `status`, а он есть в индексе, поэтому данные берутся прямо из индекса, а в таблицу запрос не ходит (`Heap Fetches: 0`). Индекс занимает 58 страниц, а таблица 832, поэтому читать нужно намного меньше. И так как в индексе значения уже отсортированы, вместо `HashAggregate` используется `GroupAggregate`.

При чём тут Visibility Map: в индексе нет информации о том, видна ли строка (может, её уже удалили или изменили), это хранится только в таблице. Карта видимости хранит для каждой страницы таблицы отметку "все строки на странице видимы". Если отметка есть, в таблицу можно не ходить, если нет — приходится проверять строку в таблице, и это считается в `Heap Fetches`. Эти отметки ставит `VACUUM`, поэтому перед запросом его надо выполнить.

Ещё я проверила, что будет, если карта неактуальна. Обновила каждую десятую строку (`UPDATE flights SET status = status WHERE flight_id % 10 = 0`) и повторила запрос:

<details>
<summary>После UPDATE, до VACUUM</summary>

```
 GroupAggregate  (cost=0.29..1860.68 rows=6 width=16) (actual time=30.012..36.659 rows=6 loops=1)
   Group Key: status
   Buffers: shared hit=1822 read=935 dirtied=871
   I/O Timings: shared read=9.180
   ->  Index Only Scan using idx_flights_status on flights  (cost=0.29..1516.91 rows=68742 width=8) (actual time=0.711..30.964 rows=65664 loops=1)
         Heap Fetches: 72202
         Buffers: shared hit=1822 read=935 dirtied=871
         I/O Timings: shared read=9.180
 Planning:
   Buffers: shared hit=100 read=25
   I/O Timings: shared read=2.453
 Planning Time: 4.132 ms
 Execution Time: 37.365 ms
```

</details>

Теперь `Heap Fetches: 72202` — запрос ходил в таблицу почти за каждой строкой, и времени ушло больше, чем без индекса. После повторного `VACUUM` снова стало `Heap Fetches: 0` ([`output/dz8_extra_after_revacuum_explain.txt`](output/dz8_extra_after_revacuum_explain.txt)).

Резюме: без индекса запрос читает с диска всю таблицу, 832 страницы. С индексом и после `VACUUM` используется `Index Only Scan`, прочитано только 58 страниц индекса, а в таблицу запрос не обращался. В тёплом запуске оба варианта работают из кеша.
