## Домашнее задание — Семинар 3
## Тема
### Базовый SQL, DDL/Блокировки и Edge Cases

---


### Q1. Уникальные рейсы и сортировка
1. DISTINCT и GROUP BY
Запросы:


    SELECT DISTINCT flight_no FROM flights ORDER BY flight_no;
---
    SELECT flight_no FROM flights GROUP BY flight_no ORDER BY flight_no;

Оба запроса возвращают одинаковый итоговый набор данных: уникальные значения flight_no, отсортированные по возрастанию.
При этом физический план выполнения (EXPLAIN) может отличаться, поскольку PostgreSQL самостоятельно выбирает способ выполнения запроса.
Например, для удаления дубликатов могут использоваться разные операции сортировки или агрегации.

2. Почему ASC можно не указывать

ASC является направлением сортировки по умолчанию в PostgreSQL.

Поэтому: ORDER BY flight_no; эквивалентно:ORDER BY flight_no ASC;
Значения с верхним и нижним ре гистром сортируются в соответствии с правилами сравнения строк и используемой локалью/колляцией PostgreSQL.
Поэтому значения вроде PG0001 и pg0001 могут иметь определённый порядок, зависящий от настроек сортировки базы данных.


---


### Q2. Аэропорты и выручка за билеты
Если один пассажир купил два билета на один рейс, например на разные места, то в таблице ticket_flights будут две строки.
При использовании:
COUNT(*) будут посчитаны обе строки.
Поэтому COUNT(*) в таком запросе фактически считает количество проданных билетов, а не уникальных пассажиров.
Если необходимо посчитать именно уникальных пассажиров, используется:
COUNT(DISTINCT passenger_id)
Суммарная выручка считается с помощью:
SUM(amount)
Пример:

    SELECT
        flight_id,
        SUM(amount) AS total_revenue,
        COUNT(DISTINCT passenger_id) AS passenger_count
    FROM ticket_flights
    GROUP BY flight_id;

Рейсы без проданных билетов
Если рейс есть в flights, но для него нет записей в ticket_flights, необходимо использовать LEFT JOIN.

Пример:

    SELECT
        f.flight_id,
        COALESCE(SUM(tf.amount), 0) AS total_revenue,
        COUNT(DISTINCT tf.passenger_id) AS passenger_count
    FROM flights f
    LEFT JOIN ticket_flights tf
        ON f.flight_id = tf.flight_id
    GROUP BY f.flight_id;

LEFT JOIN сохраняет все рейсы из flights, даже если соответствующих билетов нет.
INNER JOIN такой рейс удалит из результата, потому что для него не найдётся соответствующей строки в ticket_flights.


---


### Q3. Отменённые рейсы и города
Необходимо найти города, из которых не было ни одного отменённого рейса.
Надёжный вариант — использовать NOT EXISTS:

    SELECT a.city
    FROM airports a
    WHERE NOT EXISTS (
        SELECT 1
        FROM flights f
        WHERE f.departure_airport = a.airport_code
          AND f.status = 'Cancelled'
    );
Такой запрос также включит аэропорт, который вообще не встречается в flights, поскольку для него не существует отменённого рейса.
Почему NOT EXISTS безопаснее NOT IN
Вариант:

    WHERE city NOT IN (
        SELECT departure_airport
        FROM flights
        WHERE status = 'Cancelled'
    );
может столкнуться с проблемой NULL.
Если подзапрос содержит хотя бы один NULL, сравнение через NOT IN может дать UNKNOWN, из-за чего строки не будут возвращены.
NOT EXISTS проверяет существование подходящей строки и не имеет этой классической проблемы с NULL.

---


### Q4. Места на борту и дубликаты
Если один пассажир ошибочно получил два посадочных талона на один рейс, обычный JOIN может вернуть две строки для одного пассажира.
Чтобы получить уникальных пассажиров, можно использовать:

    SELECT DISTINCT
        b.flight_id,
        b.passenger_id
    FROM boardings b;

Также можно использовать GROUP BY:

    SELECT
        b.flight_id,
        b.passenger_id
    FROM boardings b
    GROUP BY
        b.flight_id,
        b.passenger_id;

В данном случае оба варианта дают одинаковый результат. Какой именно план выполнения будет выбран, зависит от PostgreSQL. Для проверки можно использовать:

    EXPLAIN
    SELECT DISTINCT
        b.flight_id,
        b.passenger_id
    FROM boardings b;
    EXPLAIN
    SELECT
        b.flight_id,
        b.passenger_id
    FROM boardings b
    GROUP BY
        b.flight_id,
        b.passenger_id;

Пассажир есть в boardings, но отсутствует в ticket_flights
Если используется INNER JOIN между tickets и boardings, пассажир без соответствующего билета не попадёт в результат.
Например:
SELECT
    b.flight_id,
    b.passenger_id
FROM boardings b
INNER JOIN tickets t
    ON b.ticket_no = t.ticket_no;
Поскольку соответствующей строки в tickets нет, строка такого пассажира будет исключена.


---


### Q5. DDL и блокировки
1. ALTER TABLE и длительный SELECT
Если один пользователь выполняет:
BEGIN;


    SELECT COUNT(*)
    FROM flights;

и транзакция остаётся открытой, то другой пользователь, выполняющий:

    ALTER TABLE flights
    ADD COLUMN weather_data JSONB;
будет ждать освобождения необходимой блокировки.
ALTER TABLE в данном случае требует блокировку уровня ACCESS EXCLUSIVE.
Она конфликтует с блокировками, которые удерживаются выполняющимся запросом, поэтому DDL может ждать завершения транзакции.



2. Добавление колонки с DEFAULT
На современных версиях PostgreSQL добавление колонки с константным значением DEFAULT может выполняться без полного переписывания таблицы.
Пример:


    ALTER TABLE flights
    ADD COLUMN is_delayed BOOLEAN DEFAULT false;

PostgreSQL хранит информацию о значении по умолчанию в системном каталоге и может использовать его для старых строк без физической записи false в каждую строку таблицы.
Если впоследствии изменить значение по умолчанию:


    ALTER TABLE flights
    ALTER COLUMN is_delayed SET DEFAULT true;

это изменит значение по умолчанию для новых INSERT. Уже существующие строки автоматически не изменятся.



   
3. Создание индекса
Обычный индекс:


    CREATE INDEX idx_flights_status
    ON flights(status);

может блокировать операции записи на таблицу во время построения индекса.
Чтобы создать индекс с меньшим влиянием на обычную работу таблицы, используется:


    CREATE INDEX CONCURRENTLY idx_flights_status
    ON flights(status);

CREATE INDEX CONCURRENTLY позволяет продолжать обычные INSERT, UPDATE и DELETE, но построение индекса занимает больше времени и требует дополнительных ресурсов. Кроме того, такой индекс нельзя создавать внутри обычной транзакции.


---


### Q6. Агрегация и NULL
1. AVG и NULL
При вычислении:


    SELECT AVG(actual_departure - scheduled_departure)
    FROM flights;

строки, где actual_departure равен NULL, не участвуют в расчёте.
В PostgreSQL агрегат AVG игнорирует NULL.
Например, если задержки равны:
10 минут
20 минут
NULL
30 минут
среднее будет рассчитано только для трёх числовых значений:
(10 + 20 + 30) / 3 = 20 минут
Таким образом, отменённые или ещё не выполненные рейсы с NULL не уменьшают и не увеличивают напрямую среднее значение, но уменьшают количество строк, участвующих в расчёте.




2. COUNT(column) и COUNT(*)
Запрос:


    SELECT COUNT(aircraft_code)
    FROM flights;

считает только строки, в которых aircraft_code не равен NULL.
Запрос:


    SELECT COUNT(*)
    FROM flights;


считает все строки таблицы.
Поэтому результаты будут различаться, если хотя бы в одной строке aircraft_code содержит NULL.
Если для aircraft_code установлено ограничение:
NOT NULL
то COUNT(aircraft_code) и COUNT(*) будут давать одинаковый результат.
Проверить наличие NULL можно запросом:


    SELECT COUNT(*)
    FROM flights
    WHERE aircraft_code IS NULL;


Если результат равен 0, то значения aircraft_code отсутствуют только в виде NULL.