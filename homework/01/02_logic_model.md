# Задание 2. Логическая модель

---

## Атрибуты сущностей

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

## Идентифицирующие и неидентифицирующие связи

Идентифицирующие - дочерняя сущность не может существовать без родителя:

    Restaurant -> Dish - блюдо не существует без ресторана

    Order -> OrderItem - позиция заказа не существует без заказа

Неидентифицирующие - у дочерней сущности свой первчиный ключ, FK просто ссылается на родителя:

    User -> Order, User -> Address, User -> Review

    Restaurant -> Order, Restaurant -> Review

    Category -> Dish
