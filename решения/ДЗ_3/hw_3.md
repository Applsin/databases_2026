
## 1. Уникальные рейсы и сортировка

**1.** Результат всегда одинаковый: без агрегатов `DISTINCT` и `GROUP BY` оставляют по одной строке на значение. Отличаться может только план: планировщик для обоих выбирает `HashAggregate` или `Sort` + `Unique`/`Group`, узлы в `EXPLAIN` могут называться по-разному.
**2.** `ASC` стоит по умолчанию. 'PG0001' и 'pg0001' это разные значения, порядок зависит от collation. В `C` сначала идут все заглавные, строчные в конце. В `en_US.UTF-8` они встанут рядом, строчный первым. Без учёта регистра можно сортировать по `lower(flight_no)`

## 2. Аэропорты и выручка
**1.** Два билета одного пассажира это две строки в `ticket_flights`. `SUM(amount)` посчитает обе суммы, и это правильно. `COUNT(*)` посчитает билеты, а не людей, поэтому пассажиров считаю через `COUNT(DISTINCT t.passenger_id)`.

**2.** `INNER JOIN` выбросит рейс без билетов, поэтому нужен `LEFT JOIN`:

```sql
SELECT f.flight_id,
       f.flight_no,
       COALESCE(SUM(tf.amount), 0)    AS revenue,
       COUNT(DISTINCT t.passenger_id) AS passengers
FROM flights f
LEFT JOIN ticket_flights tf ON tf.flight_id = f.flight_id
LEFT JOIN tickets t         ON t.ticket_no  = tf.ticket_no
GROUP BY f.flight_id, f.flight_no;
```

Для рейса без билетов `tf.amount` будет null, поэтому надо использовать `COALESCE(..., 0)`

## 3. Отменённые рейсы и города

**1.** `departure_airport` хранит код аэропорта, а не город, а в городе может быть несколько аэропортов. Поэтому сравниваю через `airports`

```sql
SELECT DISTINCT a.city
FROM airports a
WHERE NOT EXISTS (
    SELECT 1 FROM flights f
    JOIN airports a2 ON a2.airport_code = f.departure_airport
    WHERE a2.city = a.city AND f.status = 'Cancelled'
);
```

Город без рейсов попадёт в результат, и по условию это верно: отменённых рейсов оттуда нет. Если нужны только города с рейсами, добавляется `EXISTS`

**2.** `x NOT IN (a, NULL)` раскрывается в `x <> a AND x <> NULL`, что даёт NULL, а не true, и строка не проходит. Опасен NULL в возвращаемом столбце (`departure_airport`), строки с `status IS NULL` и так отсекаются условием = 'Cancelled' `NOT EXISTS` проверяет только наличие строк и возвращает true/false, поэтому ловушки нет.

## 4. Места на борту и дубликаты

В демо-базе таблица называется `boarding_passes`, `passenger_id` берётся из `tickets`.

**1.** Один билет даёт один талон на рейс (PK `(ticket_no, flight_id)`), дубли возможны только при двух билетах. Убираю их через `SELECT DISTINCT t.passenger_id`. `DISTINCT` и `GROUP BY` дают одинаковый план, `GROUP BY` нужен, если нужен агрегат, например `HAVING COUNT(*) > 1` для поиска таких пассажиров

**2.** В демо-базе это невозможно: внешний ключ `boarding_passes (ticket_no, flight_id)` ссылается на `ticket_flights`. Без него при `tickets JOIN boarding_passes` пассажир попал бы в список, а при соединении через `ticket_flights` отбросился бы. Второй вариант правильнее.

## 5. DDL и блокировки

**1.** `SELECT` в открытой транзакции держит `AccessShareLock` до `COMMIT`. `ALTER TABLE` нужна `AccessExclusiveLock`, она конфликтует со всем, поэтому команда ждёт. Пока она ждёт, за ней в очередь встают и новые `SELECT`, и таблица фактически зависает. Защита: `SET lock_timeout = '3s'` и повтор.
**2.** В PG 11+ константный default пишется в `pg_attribute` (`atthasmissing`, `attmissingval`), старые строки не переписываются, значение подставляется при чтении. Default для новых вставок хранится в `pg_attrdef`. После `SET DEFAULT true` старые строки так и читаются как `false`, новые `INSERT` получают `true`. `SET DEFAULT` берёт короткую эксклюзивную блокировку, параллельные `INSERT` на это время подождут.

**3.** `CREATE INDEX` берёт `ShareLock`: чтение разрешено, `INSERT/UPDATE/DELETE` ждут до конца построения. Без блокировки записи: `CREATE INDEX CONCURRENTLY`. Он строится дольше (два прохода, ждёт старые транзакции), не работает внутри транзакции, а при ошибке оставляет `INVALID` индекс, который надо удалять вручную

## 6. Агрегация и NULL

**1.** Разность с NULL даёт NULL, и `AVG` такие строки пропускает, делитель тоже уменьшается. Среднее считается только по вылетевшим рейсам (NULL бывает и у будущих рейсов, не только у отменённых). `COALESCE(..., 0)` использовать нельзя, это занизит среднее
**2.** `COUNT(*)` считает все строки, `COUNT(aircraft_code)` только не NULL. В `flights` столбец `NOT NULL`, так что результаты совпадут. Разными они будут у столбца, где NULL есть, например `actual_departure`
