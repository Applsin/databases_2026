# Домашнее задание №1. От бизнес-требований к физической модели

## Вариант №2 — Служба доставки еды

## 1. Концептуальная модель

### Основные сущности

- **User** — пользователь сервиса.
- **Restaurant** — ресторан.
- **Dish** — блюдо конкретного ресторана.
- **Order** — заказ пользователя из ресторана.
- **OrderItem** — позиция заказа с количеством и ценой на момент заказа.
- **Courier** — курьер.
- **Review** — отзыв пользователя о ресторане и доставке.

### Связи

- User 1:N Order
- Restaurant 1:N Dish
- Restaurant 1:N Order
- Courier 1:N Order
- Order 1:N OrderItem
- Dish 1:N OrderItem
- User 1:N Review
- Restaurant 1:N Review
- Order 1:0..1 Review

Order и Dish образуют связь M:N, реализованную через OrderItem.

### Влияние бизнес-требований

| Требование | Решение |
|---|---|
| Пользователь делает заказы | User + Order, связь 1:N |
| Ресторан имеет меню | Restaurant + Dish, связь 1:N |
| В заказе несколько блюд | OrderItem |
| Нужно хранить количество | OrderItem.quantity |
| Курьеры доставляют | Order.courier_id |
| Пользователь оставляет отзыв | Review |
| У заказа есть жизненный цикл | Order.status + CHECK |
| Цена может изменяться | OrderItem.unit_price хранит историческую цену |
| Рейтинги должны быть корректными | CHECK от 0 до 5 |
| Количество должно быть положительным | CHECK quantity > 0 |
| Контакты должны быть уникальными | UNIQUE |
| Частые соединения должны быть быстрыми | Индексы FK |

## 2. Логическая модель

### User
`user_id` PK, `full_name`, `email` UNIQUE, `phone` UNIQUE, `created_at`.

### Restaurant
`restaurant_id` PK, `name`, `address`, `rating`, `is_active`.

### Dish
`dish_id` PK, `restaurant_id` FK, `name`, `description`, `price`, `is_available`.

### Order
`order_id` PK, `user_id` FK, `restaurant_id` FK, `courier_id` FK NULL, `status`, `delivery_address`, `total_amount`, `created_at`.

### OrderItem
`order_id` PK/FK, `dish_id` PK/FK, `quantity`, `unit_price`.

### Courier
`courier_id` PK, `full_name`, `phone` UNIQUE, `rating`, `is_active`.

### Review
`review_id` PK, `user_id` FK, `restaurant_id` FK, `order_id` FK NULL, `restaurant_rating`, `delivery_rating`, `comment`, `created_at`.

### Кардинальность

- User 1:N Order.
- Restaurant 1:N Dish.
- Restaurant 1:N Order.
- Courier 1:N Order, при этом у заказа 0..1 курьер.
- Order 1:N OrderItem.
- Dish 1:N OrderItem.
- User 1:N Review.
- Restaurant 1:N Review.
- Order 1:0..1 Review.

### Идентифицирующие связи

Order → OrderItem и Dish → OrderItem являются идентифицирующими: оба FK входят в состав PK `OrderItem(order_id, dish_id)`.

Остальные связи являются неидентифицирующими: FK дочерней таблицы не входит в её PK.

## 3. Физическая модель

База реализована в PostgreSQL.

Используемые типы:
- BIGSERIAL — идентификаторы;
- VARCHAR — короткие строки;
- TEXT — адреса и описания;
- NUMERIC(10,2) — деньги;
- NUMERIC(2,1) — рейтинг;
- INTEGER — количество;
- BOOLEAN — флаги;
- TIMESTAMP — время.

Использованы PRIMARY KEY, FOREIGN KEY, NOT NULL, UNIQUE, CHECK и DEFAULT.

Статусы заказа:
- `created` — создан;
- `preparing` — готовится;
- `courier_assigned` — назначен курьер;
- `delivered` — доставлен;
- `cancelled` — отменён.

Текущая цена хранится в Dish. Цена конкретной позиции заказа сохраняется в OrderItem.unit_price, поэтому изменение цены меню не меняет историю старого заказа.

SQL-файл физической модели: `sql/01_create_tables.sql`.

## 4. Частые запросы

1. Показать активные рестораны с рейтингом выше 4.5.
2. Вывести топ-10 популярных блюд за последнюю неделю.
3. Получить полную информацию о заказе: пользователь, ресторан, курьер и блюда.
4. Рассчитать выручку каждого ресторана за текущий месяц.
5. Найти курьеров, выполнивших более 100 доставок и имеющих рейтинг не ниже 4.5.

SQL этих запросов находится в `sql/03_queries.sql`.

## 5. Воспроизводимость

`01_create_tables.sql` сначала удаляет существующие таблицы через `DROP TABLE IF EXISTS ... CASCADE`, поэтому повторный запуск приводит БД к тому же состоянию схемы.

`02_insert_data.sql` очищает таблицы и заново добавляет демонстрационный набор данных.
