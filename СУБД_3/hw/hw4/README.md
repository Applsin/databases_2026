# Что было сделано

Разобраны и задокументированны задания из `СУБД_3/семинары/студентам/ ДЗ_семинар_4.md`
- Разобраны запросы с семинара
- Написаны и разобраны запросы из списка, которые на семинаре не успели
- Разобраны темы ROLLUP, условная агрегация, Sargability и остальные
- Написаны запросы к темам по требования

К каждому запросу приложен результат команды `EXPLAIN (ANALYZE, BUFFERS)`, анализ команд сокращен в зависимости от контекста задачи

*P.S. Этот блок пишется только ради этого предложения, спасибо за продление дедлайна на степик, запросы корректировки это нечто, даже хорошо, что сайт лег — будет дополнительное время их поизучать :Р*

# Запросы с семинара
---

## Задача 1.1.
>Выбрать все выполненные рейсы (`status` = 'Arrived') из московских аэропортов за август 2017 года: номер рейса, аэропорт вылета, фактическое время вылета. Отсортировать по возрастанию времени вылета.

### Запрос
  ```sql
SELECT f.flight_no, f.departure_airport, f.actual_departure 
FROM flights f

WHERE
f.departure_airport IN (select a.airport_code from airports a where city = 'Moscow') AND
f.status = 'Arrived' AND
f.actual_departure >= '2017-08-01' AND
f.actual_departure < '2017-09-01'
ORDER BY f.actual_departure
  ```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)` 
```
Sort  (cost=2030.00..2030.15 rows=58 width=19) (actual time=22.715..22.818 rows=1913 loops=1)
  Sort Key: f.actual_departure
  Sort Method: quicksort  Memory: 138kB
  Buffers: shared hit=17 read=837
  ->  Hash Join  (cost=30.57..2028.30 rows=58 width=19) (actual time=5.906..22.213 rows=1913 loops=1)
        Hash Cond: (f.departure_airport = ml.airport_code)
        Buffers: shared hit=14 read=837
        ->  Seq Scan on flights f  (cost=0.00..1981.12 rows=6082 width=19) (actual time=1.444..17.128 rows=8021 loops=1)
              Filter: ((actual_departure >= '2017-08-01 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-09-01 00:00:00+03'::timestamp with time zone) AND ((status)::text = 'Arrived'::text))
              Rows Removed by Filter: 57643
              Buffers: shared read=832
        ->  Hash  (cost=30.56..30.56 rows=1 width=4) (actual time=4.335..4.336 rows=3 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=14 read=5
              ->  Seq Scan on airports_data ml  (cost=0.00..30.56 rows=1 width=4) (actual time=4.188..4.325 rows=3 loops=1)
                    Filter: ((city ->> lang()) = 'Moscow'::text)
                    Rows Removed by Filter: 101
                    Buffers: shared hit=14 read=5
Planning:
  Buffers: shared hit=196 read=26
Planning Time: 12.009 ms
Execution Time: 27.325 ms
```

### Повторный прогон
```
Sort  (cost=2030.00..2030.15 rows=58 width=19) (actual time=6.392..6.519 rows=1913 loops=1)
  Sort Key: f.actual_departure
  Sort Method: quicksort  Memory: 138kB
  Buffers: shared hit=835
  ->  Hash Join  (cost=30.57..2028.30 rows=58 width=19) (actual time=0.191..5.849 rows=1913 loops=1)
        Hash Cond: (f.departure_airport = ml.airport_code)
        Buffers: shared hit=835
        ->  Seq Scan on flights f  (cost=0.00..1981.12 rows=6082 width=19) (actual time=0.017..5.072 rows=8021 loops=1)
              Filter: ((actual_departure >= '2017-08-01 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-09-01 00:00:00+03'::timestamp with time zone) AND ((status)::text = 'Arrived'::text))
              Rows Removed by Filter: 57643
              Buffers: shared hit=832
        ->  Hash  (cost=30.56..30.56 rows=1 width=4) (actual time=0.137..0.139 rows=3 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              Buffers: shared hit=3
              ->  Seq Scan on airports_data ml  (cost=0.00..30.56 rows=1 width=4) (actual time=0.062..0.134 rows=3 loops=1)
                    Filter: ((city ->> lang()) = 'Moscow'::text)
                    Rows Removed by Filter: 101
                    Buffers: shared hit=3
Planning:
  Buffers: shared hit=4
Planning Time: 0.401 ms
Execution Time: 6.651 ms
```

### Анализ

Выполнение запроса можно рассматривать как своеобразный стэк или дерево зависимостей, таким образом 

>Первым вызывается `Sort`
```
Sort  (cost=2030.00..2030.15 rows=58 width=19) (actual time=6.392..6.519 rows=1913 loops=1)
  Sort Key: f.actual_departure
  Sort Method: quicksort  Memory: 138kB
  Buffers: shared hit=835
```
Сортировка является верхним оператором дерева. Она не может начать сортировать строки, пока `Hash Join` не вернёт результат.

>Следом `Hash`
```
->  Hash Join  (cost=30.57..2028.30 rows=58 width=19) (actual time=0.191..5.849 rows=1913 loops=1)
    Hash Cond: (f.departure_airport = ml.airport_code)
    Buffers: shared hit=835
```
`Hash Join` получает данные от двух нижних ветвей:
- `Seq Scan on flights`;
- `Hash`, который строится на основе `airports_data`;

Соединение выполняется по условию
```sql
f.departure_airport = ml.airport_code
```

>Далее вызывается `Seq scan`
```
->  Seq Scan on flights f  (cost=0.00..1981.12 rows=6082 width=19) (actual time=0.017..5.072 rows=8021 loops=1)
    Filter: ((actual_departure >= '2017-08-01 00:00:00+03'::timestamp with time zone) AND (actual_departure < '2017-09-01 00:00:00+03'::timestamp with time zone) AND ((status)::text = 'Arrived'::text))
    Rows Removed by Filter: 57643
    Buffers: shared hit=832
```
Последовательно просматривает таблицу `flights` и отбирает рейсы за август 2017 года со статусом `Arrived`.

Всего обработано *65664 строки*
- *8021* прошли фильтр;
- *57643* отброшены;


Первый запуск: `shared read=832`, то есть 832 страницы были прочитаны с диска.
Повторный запуск: `shared hit=832`, то есть эти страницы уже находились в кэше PostgreSQL.

>На том же уровне что и предудыщая операция, вызывается `Hash`
```
->  Hash  (cost=30.56..30.56 rows=1 width=4) (actual time=0.137..0.139 rows=3 loops=1)
    Buckets: 1024  Batches: 1  Memory Usage: 9kB
    Buffers: shared hit=3
```

`Hash` получает результат от нижнего `Seq Scan on airports_data` и строит из него хеш-таблицу, необходимую для работы `Hash Join`.

В хеш попали **3 строки**. Используется **9 kB** памяти, `Batches: 1`, поэтому вся структура помещается в память.

>Уже на уровень глубже/ниже вызывается еще один `Seq scan`
```
->  Seq Scan on airports_data ml  (cost=0.00..30.56 rows=1 width=4) (actual time=0.062..0.134 rows=3 loops=1)
    Filter: ((city ->> lang()) = 'Moscow'::text)
    Rows Removed by Filter: 101
    Buffers: shared hit=3
```
Последовательно просматривает `airports_data` и ищет аэропорты Москвы

- найдено **3 строки**;
- **101 строка** отброшена.

Здесь интересно, что `PostgreSQL` оценивает
```sql
where city = 'Moscow'
```
как одну строку `(... rows=1 ...)` но в результате получает 3 `(actual ... rows=3 ...)`

Далее из-за этого расходятся ожидаемые и реально полученные значения уже в `Hash` и остальных

При первом выполнении весь запрос занял **27.325 мс**, при повторном — **6.651 мс**

Основная причина ускорения — кэширование данных PostgreSQL
- Первый запуск: `shared hit=17`, `shared read=837`
- Второй запуск: `shared hit=835`, `shared read=0`

`shared hit` означает, что нужная страница уже находилась в буферном кэше PostgreSQL. `shared read` означает чтение страницы с диска. Поэтому при повторном запуске данные уже находились в памяти, и обращений к диску не потребовалось.

Основным узким местом запроса является последовательное сканирование таблицы `flights`. При повторном выполнении запрос значительно ускоряется за счёт попадания страниц в кэш (`shared hit`). Поэтому при дальнейшем сравнении запросов необходимо учитывать состояние кэша: различие во времени выполнения не всегда означает изменение эффективности самого плана.

>[!attention]
>Каждый запрос дополнительный анализ `hit`/`read` прописываться не будет. Также описания каждого пункта будет сокращено

## Задача 1.2.
>Найти рейсы, прибывшие с опозданием более чем на 2 часа: номер рейса, плановое и фактическое время прибытия, опоздание в минутах. Самые большие опоздания - сверху

### Запрос
```sql
SELECT 
	f.flight_no, 
	f.scheduled_arrival, 
	f.actual_arrival, 
	ROUND(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_arrival)) / 60) AS delay_min
FROM flights f

WHERE 
	ROUND(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_arrival)) / 60) > 120
ORDER BY delay_min DESC;
```
  
### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)` 
```
Sort  (cost=4106.21..4160.93 rows=21888 width=55) (actual time=28.060..28.136 rows=2394 loops=1)
  Sort Key: (round((EXTRACT(epoch FROM (actual_arrival - scheduled_arrival)) / '60'::numeric), 0)) DESC
  Sort Method: quicksort  Memory: 227kB
  Buffers: shared hit=835
  ->  Seq Scan on flights f  (cost=0.00..2528.32 rows=21888 width=55) (actual time=0.514..26.779 rows=2394 loops=1)
        Filter: (round((EXTRACT(epoch FROM (actual_arrival - scheduled_arrival)) / '60'::numeric), 0) > '120'::numeric)
        Rows Removed by Filter: 63270
        Buffers: shared hit=832
Planning:
  Buffers: shared hit=18 read=1
Planning Time: 1.906 ms
Execution Time: 28.338 ms
```

### Краткий анализ

`Sort` -> `Seq scan`

`Sort`сортирует  *по вычисленной задержке*, а не по отдельному столбцу

`Seq scan` последовательно проходит через таблицу, применяя фильтр
```
Rows Removed by Filter: 63270
```
## Задача 1.3. 
>Рейсы с номерами, начинающимися на PG04 (номера диапазона PG0400-PG0499): сколько выполнено рейсов каждым номером.

### Запрос
```sql
SELECT f.flight_no, COUNT(*) AS flight_count
FROM flights f

WHERE flight_no LIKE 'PG04%' AND status = 'Arrived'
GROUP BY flight_no
ORDER BY flight_no
```
### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)` 
```
Sort  (cost=1893.31..1895.08 rows=710 width=15) (actual time=9.291..9.296 rows=100 loops=1)
  Sort Key: flight_no
  Sort Method: quicksort  Memory: 28kB
  Buffers: shared hit=835
  ->  HashAggregate  (cost=1852.59..1859.68 rows=710 width=15) (actual time=8.641..8.652 rows=100 loops=1)
        Group Key: flight_no
        Batches: 1  Memory Usage: 49kB
        Buffers: shared hit=832
        ->  Seq Scan on flights f  (cost=0.00..1816.96 rows=7125 width=7) (actual time=0.025..7.507 rows=7284 loops=1)
              Filter: ((flight_no ~~ 'PG04%'::text) AND ((status)::text = 'Arrived'::text))
              Rows Removed by Filter: 58380
              Buffers: shared hit=832
Planning:
  Buffers: shared hit=5 read=4
Planning Time: 4.773 ms
Execution Time: 9.522 ms
```
### Краткий анализ

`Sort` -> `HashAggregate` -> `Seq scan`

Здесь интерестен `HashAggregate`, он группирует строки по `Group Key: flight_no`, при чем только те, что вернул `Seq scan` (те что прошли фильтр)

`Batches: 1  Memory Usage: 49kB` — относится к использованию памяти процессом
`Buffers: shared hit=832` — все нужные страницы были в кэше
`rows=100` — по итогу группировки получилось 100



## Задача 2.1.
>Для каждого аэропорта вылета: число рейсов и среднее опоздание прибытия в минутах. Оставить только аэропорты с более чем 500 рейсами, отсортировать по убыванию среднего опоздани

### Запрос
```sql
SELECT 
	f.departure_airport, 
	COUNT(*) as flight_count, 
	round(AVG(EXTRACT(EPOCH from (actual_arrival - scheduled_arrival) / 60))) AS avg_delay_min
FROM flights f

WHERE status = 'Arrived'
GROUP BY f.departure_airport
HAVING COUNT(*) > 500
ORDER BY round(AVG(EXTRACT(EPOCH from (actual_arrival - scheduled_arrival) / 60))) DESC
```
### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)` 
```
Sort  (cost=2393.12..2393.21 rows=35 width=44) (actual time=34.239..34.243 rows=28 loops=1)
  Sort Key: (round(avg(EXTRACT(epoch FROM ((actual_arrival - scheduled_arrival) / '60'::double precision))), 0)) DESC
  Sort Method: quicksort  Memory: 26kB
  Buffers: shared hit=832
  ->  HashAggregate  (cost=2390.58..2392.22 rows=35 width=44) (actual time=34.173..34.215 rows=28 loops=1)
        Group Key: departure_airport
        Filter: (count(*) > 500)
        Batches: 1  Memory Usage: 80kB
        Rows Removed by Filter: 76
        Buffers: shared hit=832
        ->  Seq Scan on flights f  (cost=0.00..1652.80 rows=49185 width=20) (actual time=0.023..11.418 rows=49235 loops=1)
              Filter: ((status)::text = 'Arrived'::text)
              Rows Removed by Filter: 16429
              Buffers: shared hit=832
Planning:
  Buffers: shared hit=7 read=2
Planning Time: 1.010 ms
Execution Time: 34.359 ms
```
### Краткий анализ

`Sort`->`HashAggergate`->`Seq scan`

В запросе 1.2. `EXTRACT(EPOCH)` давал тип `numeric`, когда тут `double precision`

Такое происходит потому, что при вычислении среднего значения задержки `/ 60` можно поставить до или после `EXTRACT(EPOCH)`

```sql
AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival)) / 60)
```
В этом случае деление выполняется для `numeric`, поэтому в `EXPLAIN` используется `'60'::numeric`

Если написать
```sql
AVG(EXTRACT(EPOCH FROM (actual_arrival - scheduled_arrival) / 60))
```
то сначала делится `interval` на `60`, для чего PostgreSQL использует тип `double precision`
Поэтому в плане появляется `'60'::double precision`

`AVG` не является причиной изменения типа — оно связано с расположением операции `/ 60`

Также интересно поведение `HAVING` — оно встаривает фильтр в `HashAggregate`
```
->  HashAggregate  (cost=2390.58..2392.22 rows=35 width=44) (actual time=34.173..34.215 rows=28 loops=1)
    Group Key: departure_airport
    Filter: (count(*) > 500)          // ОТ HAVING COUNT(*)>500
    Batches: 1  Memory Usage: 80kB
    Rows Removed by Filter: 76        // Результат применения фильтра
    Buffers: shared hit=832
```

## Задача 3.1. 
>Топ-10 самых дорогих проданных билетов: имя пассажира, сумма, номер рейса, город вылета и город прилёта.

### Запрос
```sql
SELECT 
	t.passenger_name, 
	tf.amount, 
	f.flight_no, 
	f.departure_airport, 
	f.arrival_airport
FROM ticket_flights tf

JOIN tickets t ON tf.ticket_no = t.ticket_no
JOIN flights f ON tf.flight_id = f.flight_id

ORDER BY tf.amount DESC
LIMIT 10
```
### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)` 
```
Limit  (cost=97222.64..97223.81 rows=10 width=37) (actual time=918.520..933.341 rows=10 loops=1)
  Buffers: shared hit=2692 read=33640, temp read=17913 written=17992
  ->  Gather Merge  (cost=97222.64..326715.70 rows=1966946 width=37) (actual time=918.501..933.319 rows=10 loops=1)
        Workers Planned: 2
        Workers Launched: 2
        Buffers: shared hit=2692 read=33640, temp read=17913 written=17992
        ->  Sort  (cost=96222.62..98681.30 rows=983473 width=37) (actual time=906.088..906.301 rows=10 loops=3)
              Sort Key: tf.amount DESC
              Sort Method: top-N heapsort  Memory: 26kB
              Buffers: shared hit=2692 read=33640, temp read=17913 written=17992
              Worker 0:  Sort Method: top-N heapsort  Memory: 26kB
              Worker 1:  Sort Method: top-N heapsort  Memory: 25kB
              ->  Hash Join  (cost=26363.98..74970.12 rows=983473 width=37) (actual time=419.299..810.659 rows=786778 loops=3)
                    Hash Cond: (tf.flight_id = f.flight_id)
                    Buffers: shared hit=2620 read=33640, temp read=17913 written=17992
                    ->  Parallel Hash Join  (cost=24054.54..70078.89 rows=983473 width=26) (actual time=403.318..625.757 rows=786778 loops=3)
                          Hash Cond: (tf.ticket_no = t.ticket_no)
                          Buffers: shared hit=30 read=33640, temp read=17913 written=17992
                          ->  Parallel Seq Scan on ticket_flights tf  (cost=0.00..29554.73 rows=983473 width=24) (actual time=0.865..126.856 rows=786778 loops=3)
                                Buffers: shared read=19720
                          ->  Parallel Hash  (cost=17374.46..17374.46 rows=345446 width=30) (actual time=113.097..113.098 rows=276357 loops=3)
                                Buckets: 131072  Batches: 8  Memory Usage: 7680kB
                                Buffers: shared read=13920, temp written=4488
                                ->  Parallel Seq Scan on tickets t  (cost=0.00..17374.46 rows=345446 width=30) (actual time=0.483..49.407 rows=276357 loops=3)
                                      Buffers: shared read=13920
                    ->  Hash  (cost=1488.64..1488.64 rows=65664 width=19) (actual time=14.629..14.630 rows=65664 loops=3)
                          Buckets: 131072  Batches: 1  Memory Usage: 4359kB
                          Buffers: shared hit=2496
                          ->  Seq Scan on flights f  (cost=0.00..1488.64 rows=65664 width=19) (actual time=0.029..5.699 rows=65664 loops=3)
                                Buffers: shared hit=2496
Planning:
  Buffers: shared hit=162 read=24
Planning Time: 57.351 ms
Execution Time: 933.571 ms
```

### Краткий анализ

```
Limit -> Gather Merge -> Sort -> Hash Join
		                           ├── Parallel Hash Join
		                           │   ├── Parallel Seq Scan
		                           │   └── Parallel Hash
		                           │       └── Parallel Seq Scan
		                           └── Hash
		                               └── Seq Scan
```

Здесь интересно использование параллельного выполнения: `Workers Planned: 2`, `Workers Launched: 2`. Поэтому часть узлов выполняется сразу в трёх процессах (в `Sort` `loops=3` — основной процесс + 2 worker'а)

`Gather Merge` собирает результаты от основного процесса и двух worker'ов, которые каждый отдельно сортируют свою часть данных. Затем он объединяет эти уже отсортированные результаты в один общий поток. В отличие от обычного `Gather`, `Gather Merge` сохраняет порядок сортировки `tf.amount DESC`, поэтому сверху можно применить `LIMIT 10`

`Sort Key: tf.amount DESC` — сортировка по сумме билета от большей к меньшей. Используется `top-N heapsort`, так как нужен только `LIMIT 10`. Памяти потребовалось всего около `26kB` на процесс

`Parallel Hash Join` соединяет `ticket_flights` и `tickets`. `Batches: 8` у `Parallel Hash` означает, что хеш-таблица не поместилась целиком в выделенную память и была разбита на 8 частей. При этом появились временные файлы: `temp written=4488`

`Parallel Seq Scan` на `ticket_flights` и `tickets` читает данные параллельно, даже при том что параллельный ему `Seq scan` был вызван другим процессом. Было прочитано много страниц с диска: `shared read=33640`, поэтому запрос занял около `934 ms`

`Hash` для `flights` имеет `Batches: 1` и `Memory Usage: 4359kB` — таблица поместилась в память целиком. `shared hit=2496` означает, что эти страницы уже находились в кэше
## Задача 3.2. 
>Вывести все аэропорты с количеством вылетающих из них рейсов — включая аэропорты, из которых вообще ничего не летает.

### Запрос
```sql
SELECT 
	a.airport_code, 
	COUNT(f.flight_id) AS flight_count
FROM airports a

LEFT JOIN flights f on a.airport_code = f.departure_airport

GROUP BY a.airport_code
ORDER BY flight_count
```
  
### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)`
```
Sort  (cost=2006.21..2006.47 rows=104 width=12) (actual time=23.456..23.463 rows=104 loops=1)
  Sort Key: (count(f.flight_id))
  Sort Method: quicksort  Memory: 29kB
  Buffers: shared hit=838
  ->  HashAggregate  (cost=2001.69..2002.73 rows=104 width=12) (actual time=23.328..23.340 rows=104 loops=1)
        Group Key: ml.airport_code
        Batches: 1  Memory Usage: 24kB
        Buffers: shared hit=835
        ->  Hash Right Join  (cost=5.34..1673.37 rows=65664 width=8) (actual time=0.057..15.619 rows=65664 loops=1)
              Hash Cond: (f.departure_airport = ml.airport_code)
              Buffers: shared hit=835
              ->  Seq Scan on flights f  (cost=0.00..1488.64 rows=65664 width=8) (actual time=0.003..3.836 rows=65664 loops=1)
                    Buffers: shared hit=832
              ->  Hash  (cost=4.04..4.04 rows=104 width=4) (actual time=0.041..0.042 rows=104 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 12kB
                    Buffers: shared hit=3
                    ->  Seq Scan on airports_data ml  (cost=0.00..4.04 rows=104 width=4) (actual time=0.013..0.026 rows=104 loops=1)
                          Buffers: shared hit=3
Planning:
  Buffers: shared hit=18
Planning Time: 0.590 ms
Execution Time: 23.570 ms
```

### Краткий анализ
```
Sort -> HashAggregate
		    └── Hash Right Join
		        ├── Seq Scan on flights f
		        └── Hash
		            └── Seq Scan on airports_data ml
```

`Hash Right Join` здесь появился из-за `LEFT JOIN` в запросе. PostgreSQL может поменять внутреннее представление соединения местами: наш `airports LEFT JOIN flights` эквивалентно `flights RIGHT JOIN airports`, поэтому в плане отображается `Hash Right Join`.

Это нужно, чтобы сохранить все аэропорты из `airports`, даже если у них нет рейсов. Поэтому `COUNT(f.flight_id)` для такого аэропорта даст `0`.

`HashAggregate` группирует результат по `ml.airport_code`. В итоге получилось `104` группы — по одной на каждый аэропорт. `Batches: 1 Memory Usage: 24kB` — хеш-таблица полностью поместилась в памяти.

`Seq Scan` на `flights` прочитал все `65664` строки, а `Seq Scan` на `airports_data` — все `104` строки. `shared hit=838` означает, что все необходимые страницы уже находились в кэше.

Нейминг процессов строго определен — в данном случае 2 `Seq scan`'а находятся на разных уровнях древа => не выполняются паралелльно и называются просто "Seq scan on.."


## Задача 3.3.
>Топ-5 пассажиров по суммарным тратам на билеты: id пассажира, имя, число перелётов, суммарная стоимость.

### Запрос
```sql
SELECT 
	t.passenger_id, 
	MAX(t.passenger_name), 
	COUNT(*) AS flights, 
	SUM(tf.amount) AS amount
FROM ticket_flights tf

JOIN tickets t ON tf.ticket_no = t.ticket_no

GROUP BY t.passenger_id
ORDER BY amount DESC

LIMIT 5
```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)`
```
Limit  (cost=403674.54..403674.55 rows=5 width=84) (actual time=2081.052..2081.061 rows=5 loops=1)
  Buffers: shared hit=513 read=33127, temp read=32238 written=47738
  ->  Sort  (cost=403674.54..405747.22 rows=829071 width=84) (actual time=2073.665..2073.672 rows=5 loops=1)
        Sort Key: (sum(tf.amount)) DESC
        Sort Method: top-N heapsort  Memory: 25kB
        Buffers: shared hit=513 read=33127, temp read=32238 written=47738
        ->  HashAggregate  (cost=342660.35..389903.97 rows=829071 width=84) (actual time=1485.341..1973.069 rows=829071 loops=1)
              Group Key: t.passenger_id
              Planned Partitions: 64  Batches: 65  Memory Usage: 8209kB  Disk Usage: 126896kB
              Buffers: shared hit=513 read=33127, temp read=32238 written=47738
              ->  Hash Join  (cost=39861.10..124329.36 rows=2360335 width=34) (actual time=256.068..1055.580 rows=2360335 loops=1)
                    Hash Cond: (tf.ticket_no = t.ticket_no)
                    Buffers: shared hit=513 read=33127, temp read=16797 written=16797
                    ->  Seq Scan on ticket_flights tf  (cost=0.00..43323.35 rows=2360335 width=20) (actual time=0.119..143.974 rows=2360335 loops=1)
                          Buffers: shared hit=257 read=19463
                    ->  Hash  (cost=22210.71..22210.71 rows=829071 width=42) (actual time=255.062..255.064 rows=829071 loops=1)
                          Buckets: 131072  Batches: 16  Memory Usage: 4780kB
                          Buffers: shared hit=256 read=13664, temp written=5888
                          ->  Seq Scan on tickets t  (cost=0.00..22210.71 rows=829071 width=42) (actual time=0.403..77.590 rows=829071 loops=1)
                                Buffers: shared hit=256 read=13664
Planning:
  Buffers: shared hit=16
Planning Time: 0.471 ms
JIT:
  Functions: 18
  Options: Inlining false, Optimization false, Expressions true, Deforming true
  Timing: Generation 1.205 ms, Inlining 0.000 ms, Optimization 0.898 ms, Emission 10.722 ms, Total 12.825 ms
Execution Time: 2091.077 ms
```

### Краткий анализ
```
Limit -> Sort -> HashAggregate -> Hash Join
						            ├── Seq Scan on ticket_flights tf
						            └── Hash
							            └── Seq Scan on tickets t
```

`Hash Join` соединяет `ticket_flights` и `tickets` по `ticket_no`. В результате получилось `2360335` строк. Оба источника читаются через `Seq Scan`

`HashAggregate` группирует строки по `t.passenger_id, t.passenger_name`. Получилось `829071` групп. Здесь заметна нехватка памяти: `Batches: 65`, а `Disk Usage: 126880kB` — часть данных хеш-агрегации пришлось вынести на диск. `Memory Usage: 8209kB`

`Sort Key: (sum(tf.amount)) DESC` — группы сортируются по общей сумме покупок пассажира от большей к меньшей. Используется `top-N heapsort`, так как нужен только `LIMIT 5`, поэтому сортировка занимает всего `25kB`

`Hash` для `tickets` также не поместился в память целиком: `Batches: 16`, `Memory Usage: 4780kB`, поэтому были записаны временные данные (`temp written=5888`)

Создание дополнительных индексов и переписывание запроса *для принудительного использования* `Index Scan` нецелесообразны. По логике задачи на практике необходимо обработать все строки таблиц `ticket_flights` и `tickets`, поэтому последовательное чтение `Seq Scan` в данном случае оказывается эффективнее индексного доступа

Основные затраты связаны с соединением и агрегацией большого объёма данных. Для этого в запросе используется `MAX(t.passenger_name)` чтобы не агрегировать дополнительно по имени пассажира
```sql
GROUP BY t.passenger_id, t.passenger_name
```
От этого решения принятто было отказаться, т.к. это бесмысленно нагружает агрегацию, `t.passenger_id`  и `t.passenger_name` связаны однозначно 1:1. Как раз поэтому и подходит `MAX(t.passenger_name)`, нахождение максимального значения крайне оптимизированно и не противоречит смыслу задачи "необходимо взять любое `t.passenger_name`  от `t.passenger_id`"

Были рассмотрены и другие варианты решения проблемы,  в основном из конспекта 4-ого семинара

`LATERAL JOIN` — не подходит по условию задачи
	Задача — найти топ-5 групп по агрегату (SUM по пассажирам), а не топ-N строк внутри каждой группы. Чтобы отсортировать группы по сумме, PostgreSQL *всё равно обязан посчитать агрегат для всех пассажиров*
	LATERAL превратит это в N correlated subqueries (по одному на пассажира), что будет медленнее, чем один HashAggregate

`WITH MATERIALIZED` — не подходит по условию задачи
	CTE *используется ровно один раз* — материализация не даёт выигрыша от переиспользования. Может только ухудшить план, запретив оптимизатору перестраивать запрос

Расхождений в реальных значениях и тех, что предсказал оптимизатор, обнаружено не было — планирование задачи производится корректно

Увеличение рабочей памяти также не дало результат. Оно устранило дисковые задержки (I/O), но переложило всю нагрузку на процессор (CPU): Обработка хеш-таблицы объемом 418 МБ в оперативной памяти требует интенсивных вычислений. В однопоточном режиме (`loops=1`) процессор стал "бутылочным горлышком". Пока данные сбрасывались на диск (до увелечения `work_mem`), процессор мог переключаться на другие задачи. Во втором случае он был занят непрерывными вычислениями в RAM, что оказалось медленнее

# `ROLLUP`, `LJOIN`, Sargability, `ANTI-JOIN`, etc.
---

## Группировки и многоуровневые итоги (ROLLUP)
>Посчитайте помесячную выручку от продажи билетов за 2017 год вместе с общим итогом — одним запросом, через `ROLLUP`.
- Оставьте только месяцы с выручкой более 10 млрд рублей (`HAVING`), следя за тем, чтобы итоговая строка при этом не потерялась.
- Приложите `EXPLAIN ANALYZE`. Объясните, как `HAVING` работает вместе с `ROLLUP` и почему итоговая строка (со значением `NULL` в колонке месяца) проходит фильтр.
### Запрос
```sql
select EXTRACT(MONTH from f.actual_departure) as month, SUM(tf.amount) as revenue

from flights f
join ticket_flights tf on f.flight_id = tf.flight_id

where
f.status = 'Arrived' and
f.actual_departure >= '2017-01-01' and
f.actual_departure <= '2017-12-31'

group by rollup(month)
having SUM(tf.amount) >= 10000000000
order by month
```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)`
```
Sort  (cost=66203.10..66224.86 rows=8705 width=64) (actual time=846.196..846.202 rows=3 loops=1)
  Sort Key: (EXTRACT(month FROM f.actual_departure))
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=1985 read=18567
  ->  MixedAggregate  (cost=2442.17..65633.46 rows=8705 width=64) (actual time=846.042..846.154 rows=3 loops=1)
        Hash Key: EXTRACT(month FROM f.actual_departure)
        Group Key: ()
        Filter: (sum(tf.amount) >= '10000000000'::numeric)
        Batches: 1  Memory Usage: 793kB
        Rows Removed by Filter: 2
        Buffers: shared hit=1985 read=18567
        ->  Hash Join  (cost=2442.17..55276.35 rows=1325819 width=38) (actual time=9.394..582.917 rows=1889439 loops=1)
              Hash Cond: (tf.flight_id = f.flight_id)
              Buffers: shared hit=1985 read=18567
              ->  Seq Scan on ticket_flights tf  (cost=0.00..43323.35 rows=2360335 width=10) (actual time=0.096..125.111 rows=2360335 loops=1)
                    Buffers: shared hit=1153 read=18567
              ->  Hash  (cost=1981.12..1981.12 rows=36884 width=12) (actual time=9.141..9.143 rows=49235 loops=1)
                    Buckets: 65536  Batches: 1  Memory Usage: 2628kB
                    Buffers: shared hit=832
                    ->  Seq Scan on flights f  (cost=0.00..1981.12 rows=36884 width=12) (actual time=0.014..5.738 rows=49235 loops=1)
                          Filter: ((actual_departure >= '2017-01-01 00:00:00+03'::timestamp with time zone) AND (actual_departure <= '2017-12-31 00:00:00+03'::timestamp with time zone) AND ((status)::text = 'Arrived'::text))
                          Rows Removed by Filter: 16429
                          Buffers: shared hit=832
Planning:
  Buffers: shared hit=6
Planning Time: 0.364 ms
Execution Time: 846.406 ms
```

### Краткий анализ

```
Sort -> MixedAggregate -> Hash Join
						    ├── Seq Scan on ticket_flights tf
						    └── Hash
						        └── Seq Scan on flights f
```


`HashKey` отвечает за то по какому тсолбцу группировать и вычислять общую сумму. `Groupkey` отсутсвует (прописывается как `()`) т.к. в мы передавали значение только в `ROLLUP`, если бы он был частичный, что-то вроде
```sql
GROUP BY a.airport_code ROLLUP(month)
```
Тогда `Hashkey` и `GroupKey` различались бы

Несмотря на то что `HAVING` выполняется после группировки, итоговая строка с `NULL` в колонке месяца остается, т.к. она удовлетворяет условию по `revenue` (Если не выполняет, то это будет значить что никакая строка до этого также не выполняля => выведется 0 строк, что логично).

Если бы в условие было бы по колонке месяца, например
```sql
HAVING EXTRACT(MONTH from f.actual_departure) > 6
```
То строка, созданная `ROLLUP` фильтр бы не прошла

Если нам все же жизненно необходимо провести фильтровку по месяцам, тогда надо отделить сгенерированную строку и исходные
```sql
SELECT
CASE
	WHEN GROUPING(EXTRACT(MONTH FROM f.actual_departure)) = 1 THEN 'Total' --если строка сгенерированна ROLLUP, CUBE и т.п.
	ELSE EXTRACT(MONTH FROM f.actual_departure)::text
END AS month,
SUM(tf.amount) AS revenue
FROM flights f
JOIN ticket_flights tf ON f.flight_id = tf.flight_id

WHERE
f.status = 'Arrived' AND
f.actual_departure >= '2017-01-01' AND
f.actual_departure < '2018-01-01'

GROUP BY ROLLUP(EXTRACT(MONTH FROM f.actual_departure))

HAVING
EXTRACT(MONTH FROM f.actual_departure) > 6
OR
GROUPING(EXTRACT(MONTH FROM f.actual_departure)) = 1 -- строка с Total игнорирует условия фильтра

ORDER BY EXTRACT(MONTH FROM f.actual_departure) NULLS LAST; -- NULLS LAST, чтобы Total был в конце
```

## LEFT JOIN и условная агрегация 
>Для каждого аэропорта прибытия посчитайте число прибывших рейсов (status = 'Arrived'), включая аэропорты, куда не прибыл ни один рейс: код аэропорта, название, число рейсов
-  Важно: условие по статусу перенесите в `ON` соединения, а не в
`WHERE`. Продемонстрируйте контрольным запуском, что произойдёт
с результатом, если оставить условие в `WHERE` .
- Приложите `EXPLAIN ANALYZE`. Объясните, почему здесь недопустим
`COUNT (*)`, и что означает узел `Hash Right Join` в плане.


### Запрос
```sql
SELECT
	ad.airport_code,
	MIN(ad.airport_name->>'en') as airport_name,
	COUNT(f.arrival_airport) as no_flights
FROM flights f

RIGHT JOIN airports_data ad ON 
f.arrival_airport = ad.airport_code AND f.status = 'Arrived'

GROUP BY ad.airport_code
ORDER BY no_flights
```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)`
```
Sort  (cost=2288.89..2289.15 rows=104 width=44) (actual time=21.696..21.703 rows=105 loops=1)
  Sort Key: (count(f.arrival_airport))
  Sort Method: quicksort  Memory: 31kB
  Buffers: shared hit=835
  ->  HashAggregate  (cost=2284.36..2285.40 rows=104 width=44) (actual time=21.591..21.602 rows=105 loops=1)
        Group Key: ad.airport_code
        Batches: 1  Memory Usage: 32kB
        Buffers: shared hit=835
        ->  Hash Right Join  (cost=5.34..1792.51 rows=49185 width=69) (actual time=0.058..11.747 rows=49236 loops=1)
              Hash Cond: (f.arrival_airport = ad.airport_code)
              Buffers: shared hit=835
              ->  Seq Scan on flights f  (cost=0.00..1652.80 rows=49185 width=4) (actual time=0.007..6.021 rows=49235 loops=1)
                    Filter: ((status)::text = 'Arrived'::text)
                    Rows Removed by Filter: 16429
                    Buffers: shared hit=832
              ->  Hash  (cost=4.04..4.04 rows=104 width=65) (actual time=0.042..0.043 rows=105 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 19kB
                    Buffers: shared hit=3
                    ->  Seq Scan on airports_data ad  (cost=0.00..4.04 rows=104 width=65) (actual time=0.011..0.026 rows=105 loops=1)
                          Buffers: shared hit=3
Planning:
  Buffers: shared hit=4
Planning Time: 0.488 ms
Execution Time: 21.887 ms
```

### Краткий анализ

```
Sort -> HashAggregate -> Hash Right Join
						            ├── Seq Scan on flights f
						            └── Hash
							            └── Seq Scan on airports_data ad
```

**Почему недопустим WHERE**
- `RIGHT JOIN` сначала соединит все строки, создав строки с `NULL` в полях `flights` для аэропортов без рейсов.
- Затем `WHERE f.status = 'Arrived'` отфильтрует все строки, где `f.status IS NULL`.
- Аэропорты без записей рейсов полностью исчезнут из результата.
- По сути, `RIGHT JOIN` превратится в `INNER JOIN`.

**Почему не подходит `COUNT(*)`**
При `RIGHT JOIN` для аэропортов без рейсов создается строка вида:

| f.arrival_airport | f.status | ad.airport_code | ad.airport_name |
| ----------------- | -------- | --------------- | --------------- |
| **NULL**          | **NULL** | 123             | Test Airport    |

- `COUNT(*)` считает **все строки**, включая эту "пустую" -> вернет **1** 
- `COUNT(f.arrival_airport)` игнорирует `NULL` -> вернет **0** 


**Почему именно Hash Right Join**
Структура:
1. Build phase (построение хеша):
    - Сканируется *правая* таблица `airports_data` (105 строк).
    - Строится хеш-таблица в памяти по ключу `airport_code` (19 kB).
2. Probe phase (поиск совпадений):
    - Сканируется *левая* таблица `flights` (65 664 строки).
    - Применяется фильтр `status = 'Arrived'` (остается 49 235 строк, отбрасывается 16 429).
    - Для каждой строки ищется совпадение в хеше по `arrival_airport`.

Итого все строки из `airports_data` без совпадений -> строки с `NULL` в полях `flights`.

Правая таблица (`airports_data`) очень маленькая (105 строк) — идеально подходит для хеша. В то время как левую таблицу (`flights`) *т.к. она большая (65 664 строки)* эффективнее сканировать и искать в хеше совпадения. PostgreSQL оптимизировал запрос: условие `f.status = 'Arrived'` из `ON` было перенесено в `Filter` при сканировании `flights` (`Rows Removed by Filter: 16429`). Это эффективнее и логически вернее, чем фильтровать после соединения



## Sargability (Оптимизация предикатов) 
>Найдите все рейсы, выполненные (status = 'Arrived' ) в выходные дни (суббота и воскресенье) в августе 2017 года.

- Напишите неоптимизированный запрос с `EXTRACT(DOW FROM...)` или `TO_CHAR(...)`
- Напишите оптимизированный запрос с использованием диапазонов дат
- Приложите `EXPLAIN ANALYZE` к обоим. Объясните разницу в планах выполнения


### Запрос через `EXTRACT(DOW FROM...)` и `TO_CHAR(...)`
```sql
SELECT *
FROM flights f

WHERE
	f.status = 'Arrived'
	AND TO_CHAR(f.actual_arrival , 'YYYY-MM') = '2017-08'
	AND EXTRACT(DAY FROM f.actual_arrival) IN (5,6,12,13,19,20,26,27)
```
### Оптимизированный запрос
```sql
SELECT *
FROM flights f

WHERE
f.status = 'Arrived'
AND (
	f.actual_arrival >= '2017-08-05' AND f.actual_arrival < '2017-08-07'
	OR f.actual_arrival >= '2017-08-12' AND f.actual_arrival < '2017-08-14'
	OR f.actual_arrival >= '2017-08-19' AND f.actual_arrival < '2017-08-21'
	OR f.actual_arrival >= '2017-08-26' AND f.actual_arrival < '2017-08-28'
	)
```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)` для первого
```
Seq Scan on flights f  (cost=0.00..2801.92 rows=10 width=27) (actual time=0.054..25.209 rows=2247 loops=1)
  Filter: (((status)::text = 'Arrived'::text) AND (to_char(actual_arrival, 'YYYY-MM'::text) = '2017-08'::text) AND (EXTRACT(day FROM actual_arrival) = ANY ('{5,6,12,13,19,20,26,27}'::numeric[])))
  Rows Removed by Filter: 63417
  Buffers: shared hit=832
Planning Time: 0.167 ms
Execution Time: 25.368 ms
```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)`для второго
```
Bitmap Heap Scan on flights f  (cost=60.71..975.98 rows=1900 width=27) (actual time=0.369..1.985 rows=2247 loops=1)
  Recheck Cond: (((actual_arrival >= '2017-08-05 00:00:00+03'::timestamp with time zone) AND (actual_arrival < '2017-08-07 00:00:00+03'::timestamp with time zone)) OR ((actual_arrival >= '2017-08-12 00:00:00+03'::timestamp with time zone) AND (actual_arrival < '2017-08-14 00:00:00+03'::timestamp with time zone)) OR ((actual_arrival >= '2017-08-19 00:00:00+03'::timestamp with time zone) AND (actual_arrival < '2017-08-21 00:00:00+03'::timestamp with time zone)) OR ((actual_arrival >= '2017-08-26 00:00:00+03'::timestamp with time zone) AND (actual_arrival < '2017-08-28 00:00:00+03'::timestamp with time zone)))
  Filter: ((status)::text = 'Arrived'::text)
  Rows Removed by Filter: 1
  Heap Blocks: exact=753
  Buffers: shared hit=767
  ->  BitmapOr  (cost=60.71..60.71 rows=2562 width=0) (actual time=0.265..0.266 rows=0 loops=1)
        Buffers: shared hit=14
        ->  Bitmap Index Scan on idx_flights_actual_arrival  (cost=0.00..25.04 rows=1275 width=0) (actual time=0.105..0.106 rows=1125 loops=1)
              Index Cond: ((actual_arrival >= '2017-08-05 00:00:00+03'::timestamp with time zone) AND (actual_arrival < '2017-08-07 00:00:00+03'::timestamp with time zone))
              Buffers: shared hit=5
        ->  Bitmap Index Scan on idx_flights_actual_arrival  (cost=0.00..25.16 rows=1287 width=0) (actual time=0.155..0.155 rows=1123 loops=1)
              Index Cond: ((actual_arrival >= '2017-08-12 00:00:00+03'::timestamp with time zone) AND (actual_arrival < '2017-08-14 00:00:00+03'::timestamp with time zone))
              Buffers: shared hit=5
        ->  Bitmap Index Scan on idx_flights_actual_arrival  (cost=0.00..4.30 rows=1 width=0) (actual time=0.003..0.003 rows=0 loops=1)
              Index Cond: ((actual_arrival >= '2017-08-19 00:00:00+03'::timestamp with time zone) AND (actual_arrival < '2017-08-21 00:00:00+03'::timestamp with time zone))
              Buffers: shared hit=2
        ->  Bitmap Index Scan on idx_flights_actual_arrival  (cost=0.00..4.30 rows=1 width=0) (actual time=0.001..0.001 rows=0 loops=1)
              Index Cond: ((actual_arrival >= '2017-08-26 00:00:00+03'::timestamp with time zone) AND (actual_arrival < '2017-08-28 00:00:00+03'::timestamp with time zone))
              Buffers: shared hit=2
Planning:
  Buffers: shared hit=15
Planning Time: 0.267 ms
Execution Time: 2.098 ms
```

### Краткий анализ

**В первом случае** выполняется `Seq scan on flights f`,
	PostgreSQL читает *ВСЕ 65 664 строки* из таблицы
	Для каждой строки вызывает `TO_CHAR()` и `EXTRACT()`
	Проверяет условия фильтра
	Отбрасывает 63 417 строк, оставляет 2 247

Функции `TO_CHAR()` и `EXTRACT()` *преобразуют значение колонки*, поэтому PostgreSQL не может использовать обычный B-tree индекс. Индекс хранит исходные значения дат, а не результаты функций

Во втором случае используется `Bitmap Heap Scan`, 
```
Bitmap Heap Scan -> BitmapOr
						├── Bitmap Index Scan on idx_flights_actual_arrival
						├── Bitmap Index Scan on idx_flights_actual_arrival
						├── Bitmap Index Scan on idx_flights_actual_arrival
						└── Bitmap Index Scan on idx_flights_actual_arrival
```
то есть
	PostgreSQL ищет в индексе `idx_flights_actual_arrival` строки, где `actual_arrival` попадает в диапазоны
	Находит через 4 отдельных `Bitmap Index Scan` (по одному на каждый диапазон)
	Читает только эти строки из таблицы (Bitmap Heap Scan)
	Применяет фильтр `status = 'Arrived'` — отбрасывает всего 1 строку
	Итого `rows 2247`  

Условия `>=` и `<` *не преобразуют значение колонки*, поэтому PostgreSQL может использовать индекс напрямую


## ANTI-JOIN (Оптимизация отрицания) 
>Найдите все рейсы, на которые не был продан ни один билет бизнес-класса `(fare_conditions = 'Business')`

- Напишите запрос с использованием `NOT IN`
- Напишите запрос с использованием `NOT EXISTS`
- Приложите `EXPLAIN ANALYZE` к обоим. Объясните, почему `NOT EXISTS` работает эффективнее (`Anti Join`) и почему `NOT IN` может быть опасен при наличии `NULL` в данных.

### Запрос с использованием `NOT IN`
```sql
SELECT f.flight_id, tf.fare_conditions
FROM flights f

JOIN ticket_flights tf ON f.flight_id = tf.flight_id

WHERE f.flight_id NOT IN
	(
	SELECT tf2.flight_id
	FROM ticket_flights tf2
	WHERE tf2.fare_conditions = 'Business'
	)

ORDER BY f.flight_id
```

### Запрос с использованием `NOT EXISTS`
```sql
SELECT f.flight_id, tf.fare_conditions
FROM flights f

JOIN ticket_flights tf ON f.flight_id = tf.flight_id

WHERE NOT EXIST
	(
	SELECT 1
	FROM ticket_flights tf2
	WHERE tf2.flight_id = f.flight_id
	AND tf2.fare_conditions = 'Business'
	)

ORDER BY f.flight_id
```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)` для  `NOT IN`
```
Sort  (cost=240854.84..243805.26 rows=1180168 width=12) (actual time=997.244..1035.671 rows=380968 loops=1)
  Sort Key: f.flight_id
  Sort Method: external merge  Disk: 8248kB
  Buffers: shared hit=6402 read=33220, temp read=1031 written=1037
  ->  Hash Join  (cost=52141.46..101661.09 rows=1180168 width=12) (actual time=319.580..858.883 rows=380968 loops=1)
        Hash Cond: (tf.flight_id = f.flight_id)
        Buffers: shared hit=6402 read=33220
        ->  Seq Scan on ticket_flights tf  (cost=0.00..43323.35 rows=2360335 width=12) (actual time=0.017..210.894 rows=2360335 loops=1)
              Buffers: shared hit=3126 read=16594
        ->  Hash  (cost=51731.06..51731.06 rows=32832 width=4) (actual time=319.207..319.213 rows=41705 loops=1)
              Buckets: 65536  Batches: 1  Memory Usage: 1979kB
              Buffers: shared hit=3276 read=16626
              ->  Index Only Scan using flights_pkey on flights f  (cost=49809.84..51731.06 rows=32832 width=4) (actual time=285.918..311.595 rows=41705 loops=1)
                    Filter: (NOT (hashed SubPlan 1))
                    Rows Removed by Filter: 23959
                    Heap Fetches: 0
                    Buffers: shared hit=3276 read=16626
                    SubPlan 1
                      ->  Seq Scan on ticket_flights tf2  (cost=0.00..49224.19 rows=234145 width=4) (actual time=5.441..221.442 rows=242204 loops=1)
                            Filter: ((fare_conditions)::text = 'Business'::text)
                            Rows Removed by Filter: 2118131
                            Buffers: shared hit=3094 read=16626
Planning:
  Buffers: shared hit=6
Planning Time: 0.394 ms
JIT:
  Functions: 23
  Options: Inlining false, Optimization false, Expressions true, Deforming true
  Timing: Generation 1.460 ms, Inlining 0.000 ms, Optimization 0.752 ms, Emission 12.969 ms, Total 15.180 ms
Execution Time: 1055.982 ms
```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)`для `NOT EXISTS`
```
Gather Merge  (cost=112921.45..268046.51 rows=1310916 width=12) (actual time=318.818..381.697 rows=380968 loops=1)
  Workers Planned: 3
  Workers Launched: 3
  Buffers: shared hit=6184 read=33636, temp read=1030 written=1034
  ->  Sort  (cost=111921.41..113013.84 rows=436972 width=12) (actual time=285.550..295.719 rows=95242 loops=4)
        Sort Key: f.flight_id
        Sort Method: external merge  Disk: 2480kB
        Buffers: shared hit=6184 read=33636, temp read=1030 written=1034
        Worker 0:  Sort Method: external merge  Disk: 2048kB
        Worker 1:  Sort Method: external merge  Disk: 2272kB
        Worker 2:  Sort Method: external merge  Disk: 1440kB
        ->  Parallel Hash Join  (cost=31915.53..63514.29 rows=436972 width=12) (actual time=109.631..239.509 rows=95242 loops=4)
              Hash Cond: (tf.flight_id = f.flight_id)
              Buffers: shared hit=6076 read=33636
              ->  Parallel Seq Scan on ticket_flights tf  (cost=0.00..27333.98 rows=761398 width=12) (actual time=0.073..50.948 rows=590084 loops=4)
                    Buffers: shared hit=2966 read=16754
              ->  Parallel Hash  (cost=31763.58..31763.58 rows=12156 width=4) (actual time=108.504..108.512 rows=10426 loops=4)
                    Buckets: 65536  Batches: 1  Memory Usage: 2144kB
                    Buffers: shared hit=3023 read=16882
                    ->  Parallel Hash Right Anti Join  (cost=1969.80..31763.58 rows=12156 width=4) (actual time=91.227..93.221 rows=10426 loops=4)
                          Hash Cond: (tf2.flight_id = f.flight_id)
                          Buffers: shared hit=3023 read=16882
                          ->  Parallel Seq Scan on ticket_flights tf2  (cost=0.00..29237.48 rows=75531 width=4) (actual time=2.520..52.190 rows=60551 loops=4)
                                Filter: ((fare_conditions)::text = 'Business'::text)
                                Rows Removed by Filter: 529533
                                Buffers: shared hit=2838 read=16882
                          ->  Parallel Hash  (cost=1486.97..1486.97 rows=38626 width=4) (actual time=25.985..25.987 rows=16416 loops=4)
                                Buckets: 131072  Batches: 1  Memory Usage: 3648kB
                                Buffers: shared hit=185
                                ->  Parallel Index Only Scan using flights_pkey on flights f  (cost=0.29..1486.97 rows=38626 width=4) (actual time=0.064..2.217 rows=16416 loops=4)
                                      Heap Fetches: 0
                                      Buffers: shared hit=185
Planning:
  Buffers: shared hit=12
Planning Time: 0.438 ms
JIT:
  Functions: 76
  Options: Inlining false, Optimization false, Expressions true, Deforming true
  Timing: Generation 6.218 ms, Inlining 0.000 ms, Optimization 3.454 ms, Emission 51.926 ms, Total 61.599 ms
Execution Time: 401.820 ms
```

### Краткий анализ

```NOT_IN
Sort 
  └── Hash Join (tf <-> f)
        ├── Seq Scan on ticket_flights tf 
        └── Hash
              └── Index Only Scan on flights f
                    Filter: NOT (hashed SubPlan 1)
                    └── SubPlan 1:
                          └── Seq Scan on ticket_flights tf2
                                Filter: fare_conditions = 'Business'
```

Результат подзапроса материализуется в хэш-таблицу, относительно которой для *каждого рейса* проверяется, есть ли его `flight_id` в хэш-таблице. 

Здесь Хэш-таблица содержит **все** `flight_id` Business-билетов, даже если эти рейсы потом не понадобятся, например, при последующей фильтрации по дате

При этом `NOT IN` потенциально опасен при `NULL` значениях
- Сравнение с `NULL` даёт `UNKNOWN` (не `TRUE` и не `FALSE`)
- Например `TRUE AND UNKNOWN AND TRUE` = `UNKNOWN`
- `WHERE` фильтрует строки, где условие не `TRUE`
В результате будет 0 строк, даже если рейсы существуют

```NOT_EXISTS
Gather Merge (3 воркера)
  └── Sort (каждый воркер сортирует свою часть)
        └── Parallel Hash Join (tf <-> f)
              ├── Parallel Seq Scan on ticket_flights tf
              └── Parallel Hash
                    └── Parallel Hash Right Anti Join (tf2 <-> f)
                          ├── Parallel Seq Scan on ticket_flights tf2
                          │     Filter: fare_conditions = 'Business'
                          └── Parallel Hash
                                └── Parallel Index Only Scan on flights f
```


1. PostgreSQL распознаёт паттерн `NOT EXISTS` как `Parallel Hash Right Anti Join` 
2. Берёт все рейсы из `flights`
3.  Исключает те, для которых есть совпадение в `ticket_flights` с `fare_conditions = 'Business'`
Выполняется параллельно на 3 воркерах, что ускоряет результат

- Anti Join *не материализует* промежуточный результат подзапроса
- Сразу исключает несовпадающие строки на этапе соединения

Также `NOT EXISTS` безопаснее при наличии `NULL`
Он проверяет существование строк, а не сравнивает значения:
- Если `tf2.flight_id = f.flight_id` даёт `UNKNOWN` (из-за `NULL`), строка просто не считается совпадающей
- Рейс не исключается, если нет *точного совпадения*

## Индексное сканирование (Index Only Scan)
>Посчитайте количество рейсов для каждого статуса: `SELECT status, COUNT (*) FROM flights GROUP BY status`

- Запустите запрос без дополнительных индексов.
- Создайте покрывающий индекс:
```sql
CREATE INDEX idx_flights_status ON flights(status);
```
*Примечание: для Index Only Scan индекс должен содержать все
запрашиваемые поля; для актуальности Visibility Мар выполните
VACUUM flights ;*
- Приложите `EXPLAIN (ANALYZE, BUFFERS)` до и после создания
индекса. Объясните, что означает `Index Only Scan` и почему это
значительно ускоряет запрос (ссылка на Visibility Map).

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)`ДО
```
HashAggregate  (cost=1729.61..1729.66 rows=6 width=16) (actual time=8.001..8.002 rows=6 loops=1)
  Group Key: status
  Batches: 1  Memory Usage: 24kB
  Buffers: shared hit=792
  ->  Seq Scan on flights  (cost=0.00..1417.07 rows=62507 width=8) (actual time=0.008..2.402 rows=65664 loops=1)
        Buffers: shared hit=792
Planning Time: 0.066 ms
Execution Time: 8.029 ms
```

### Вывод команды `EXPLAIN (ANALYZE, BUFFERS)`ПОСЛЕ
```
GroupAggregate  (cost=0.29..1545.63 rows=6 width=16) (actual time=4.678..5.949 rows=6 loops=1)
  Group Key: status
  Buffers: shared hit=58
  ->  Index Only Scan using idx_flights_status on flights  (cost=0.29..1217.25 rows=65664 width=8) (actual time=0.020..2.795 rows=65664 loops=1)
        Heap Fetches: 0
        Buffers: shared hit=58
Planning Time: 0.083 ms
Execution Time: 5.973 ms
```
### Краткий анализ

`Index Only Scan` используется после создания индекса и работает особенно эфективно, при условии что все страницы `all-visible`. Для проверки `all-visible` страниц `PostgreSQL` взял каждую строку из индекса и определил, на какой странице heap она находится. Следом проверил `Visibility Map` для страницы
- Если бит = 1 -> строка гарантированно видима → Heap Fetch не нужен
- Если бит = 0 -> нужно прочитать страницу heap и проверить видимость

В данном случае все страницы были помечен как `all-visible`. `PostgreSQL` ни разу не обратился к heap(основной таблице) `Heap Fetches: 0`

Важно, что `Visibility Map` не перепроверят каждый раз мертвые строки, а лишь выдает сохраненные значения. Переопределяет и присваивает `all-visible` именно `VACUUM`

Это максимально быстрый способ чтения данных