# Часть 1. Дополнение схемы

---

## Обновленные атрибуты сущностей

1. `User`
    + `user_id` (PK) - уникальный идентификатор
    + `full_name` - (string) ФИО
    + `phone` (string) - номер телефона
    + `email` (string) - электронная почта
2. `Restaurant`
    + `restaurant_id` (PK) - уникальный идентификатор
    + `name` (string) - название ресторана
    + `description` (text) - кухня
3. `Courier`
    + `courier_id` (PK) - уникальный идентификатор
    + `full_name` (string) - ФИО курьера
    + `phone` (string) - телефон
4. `Address`
    + `address_id` (PK) - уникальный идентификатор
    + `user_id` (FK -> User) - владелец адреса
    + `city` (string) - город
5. `Review`
    + `review_id` (PK) - уникальный идентификатор
    + `user_id` (FK -> User) - автор отзыва
    + `restaurant_id` (FK -> Restaurant) - id ресторана
6. `Order` (новая таблица)
    + `order_id` (PK)
    + `user_id` (FK -> User)
    + `restaurant_id` (FK -> Restaurant)
    + `courier_id` (FK -> Courier, nullable)
    + `address_id` (FK -> Address)
    + `status` (string)
    + `total_amount` (integer)
7. `OrderItem` (новая таблица)
    + `order_id` (FK -> Order)
    + `dish_name` (string)
    + `quantity` (int)
    + `price_at_order` (integer)

---

## Ограничения целостности для новых таблиц

1. Общие ограничения
    + `*_id` NOT NULL (не сможем определить заказ, получателя, отправителя, и так далее)
    + PK на `*_id` у всех сущностей
    + FK для ссылок на родителей у всех сущностей
2. Таблица `Order`
    + `status DEFAULT "new"` (только что созданный заказ всегда новый)
    + `total_amount DEFAULT 0` (сумма будет считаться по позициям)
3. Таблица `OrderItem`
    + `dish_name` NOT NULL
    + `quantity` NOT NULL
    + `price_at_order` NOT NULL
    + FK `order_id -> order.order_id`

---

## Индексы под частые запросы

1. Показать все отзывы о конкретном ресторане
```sql
CREATE INDEX idx_review_restaurant ON review(restaurant_id);
```

2. Найти средний рейтинг каждого ресторана
```sql
CREATE INDEX idx_review_restaurant_rating ON review(restaurant_id, rating);
```

3. Показать все адреса конкретного пользователя
```sql
CREATE INDEX idx_address_user ON address(user_id);
```

4. Вывести все рестораны, у которых есть отзывы с оценкой ниже 3
```sql
CREATE INDEX idx_review_rating ON review(rating);
```

5. Найти всех курьеров, о которых есть отзывы
```sql
CREATE INDEX idx_review_courier ON review(courier_id);
```
