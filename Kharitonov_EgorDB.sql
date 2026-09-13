-- 1. Таблица user (Пользователи)
CREATE TABLE "user" (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    age INT,
    phone_number VARCHAR(20)
);

-- 2. Таблица restaurant (Рестораны)
CREATE TABLE restaurant (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    address VARCHAR(255)
);

-- 3. Таблица courier (Курьеры)
CREATE TABLE courier (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    INN VARCHAR(12) -- ИНН обычно 10 или 12 цифр
);

-- 4. Таблица dish (Блюда) - зависит от restaurant
CREATE TABLE dish (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    price DECIMAL(10, 2),
    vege BOOLEAN,
    spicy BOOLEAN,
    restaurant INT
);

-- 5. Таблица order (Заказы) - зависит от user и courier
CREATE TABLE "order" (
    id INT PRIMARY KEY,
    time TIMESTAMP,
    "user" INT,
    courierID INT,
    CONSTRAINT fk_order_user FOREIGN KEY ("user") 
        REFERENCES "user"(id),
    CONSTRAINT fk_order_courier FOREIGN KEY (courierID) 
        REFERENCES courier(id)
);

-- 6. Таблица review (Отзывы) - зависит от order
CREATE TABLE review (
    id INT PRIMARY KEY,
    orderid INT,
    score INT,
    CONSTRAINT fk_review_order FOREIGN KEY (orderid) 
        REFERENCES "order"(id)
);

-- 7. Таблица orderItem (Состав заказа) - связующая таблица для order и dish
CREATE TABLE orderItem (
    orderID INT,
    dishID INT,
    PRIMARY KEY (orderID, dishID), -- Составной первичный ключ
    CONSTRAINT fk_orderitem_order FOREIGN KEY (orderID) 
        REFERENCES "order"(id),
    CONSTRAINT fk_orderitem_dish FOREIGN KEY (dishID) 
        REFERENCES dish(id)
);

alter table dish 
add constraint fk_dish_restaurant
FOREIGN KEY (restaurant)
REFERENCES restaurant(id);

