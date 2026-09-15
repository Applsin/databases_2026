-- =========================================================
-- Удаление таблиц
-- Таблицы удаляются в обратном порядке зависимостей,
-- чтобы скрипт можно было запускать повторно.
-- =========================================================

DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS dishes CASCADE;
DROP TABLE IF EXISTS couriers CASCADE;
DROP TABLE IF EXISTS restaurants CASCADE;
DROP TABLE IF EXISTS users CASCADE;


-- =========================================================
-- Пользователи сервиса
-- Телефон и email уникальны для каждого пользователя.
-- =========================================================

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(30) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE
);


-- =========================================================
-- Рестораны
-- is_active показывает, доступен ли ресторан в сервисе.
-- opening_time и closing_time задают время работы ресторана.
-- =========================================================

CREATE TABLE restaurants (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    cuisine_type VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    description TEXT NOT NULL,
    opening_time TIME NOT NULL,
    closing_time TIME NOT NULL
);


-- =========================================================
-- Блюда
-- Каждое блюдо принадлежит конкретному ресторану.
-- Цена должна быть строго больше нуля.
-- =========================================================

CREATE TABLE dishes (
    id BIGSERIAL PRIMARY KEY,

    restaurant_id BIGINT NOT NULL,

    name VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,

    price NUMERIC(10, 2) NOT NULL
        CHECK (price > 0),

    is_available BOOLEAN NOT NULL DEFAULT TRUE,

    -- КБЖУ на 100 грамм
    calories_per_100g NUMERIC(6, 2) NOT NULL
        CHECK (calories_per_100g >= 0),

    protein_per_100g NUMERIC(6, 2) NOT NULL
        CHECK (protein_per_100g >= 0),

    fat_per_100g NUMERIC(6, 2) NOT NULL
        CHECK (fat_per_100g >= 0),

    carbohydrates_per_100g NUMERIC(6, 2) NOT NULL
        CHECK (carbohydrates_per_100g >= 0),

    CONSTRAINT fk_dishes_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurants(id)
);


-- =========================================================
-- Курьеры
-- is_active показывает, работает ли курьер в системе.
-- Телефон курьера должен быть уникальным.
-- =========================================================

CREATE TABLE couriers (
    id BIGSERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(30) NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);


-- =========================================================
-- Заказы
-- Каждый заказ принадлежит конкретному пользователю и конкретному ресторану.
-- courier_id может быть NULL, пока курьер не назначен.
-- =========================================================

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,

    user_id BIGINT NOT NULL,

    restaurant_id BIGINT NOT NULL,

    -- Курьер может быть назначен позже,
    -- поэтому поле не имеет ограничения NOT NULL
    courier_id BIGINT,

    status VARCHAR(30) NOT NULL DEFAULT 'created',

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id)
        REFERENCES users(id),

    CONSTRAINT fk_orders_restaurant
        FOREIGN KEY (restaurant_id)
        REFERENCES restaurants(id),

    CONSTRAINT fk_orders_courier
        FOREIGN KEY (courier_id)
        REFERENCES couriers(id),

    -- Разрешены только заданные статусы заказа
    CONSTRAINT chk_orders_status
        CHECK (
            status IN (
                'created',
                'cooking',
                'assigned',
                'delivered'
            )
        )
);


-- =========================================================
-- Позиции заказа
-- Таблица связывает заказы и блюда.
-- Составной первичный ключ не позволяет добавить
-- одно и то же блюдо в один заказ двумя строками.
-- =========================================================

CREATE TABLE order_items (
    order_id BIGINT NOT NULL,

    dish_id BIGINT NOT NULL,
а
    quantity INTEGER NOT NULL
        CHECK (quantity > 0),

    -- Цена блюда на момент оформления заказа.
    -- Она хранится отдельно от dishes.price,
    -- чтобы изменение цены блюда не изменяло старые заказы.
    price_at_order NUMERIC(10, 2) NOT NULL
        CHECK (price_at_order > 0),

    -- Составной первичный ключ
    PRIMARY KEY (order_id, dish_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(id),

    CONSTRAINT fk_order_items_dish
        FOREIGN KEY (dish_id)
        REFERENCES dishes(id)
);


-- =========================================================
-- Отзывы
-- На один заказ разрешён максимум один отзыв.
-- Пользователь отдельно оценивает ресторан и доставку.
-- =========================================================

CREATE TABLE reviews (
    id BIGSERIAL PRIMARY KEY,

    order_id BIGINT NOT NULL UNIQUE,

    restaurant_rating INTEGER NOT NULL
        CHECK (restaurant_rating BETWEEN 1 AND 5),

    delivery_rating INTEGER NOT NULL
        CHECK (delivery_rating BETWEEN 1 AND 5),

    -- Текст отзыва необязателен
    comment TEXT,

    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES orders(id)
);


-- =========================================================
-- Индексы на внешние ключи
-- Они ускоряют поиск и соединение связанных таблиц.
-- =========================================================

CREATE INDEX idx_dishes_restaurant_id
    ON dishes(restaurant_id);

CREATE INDEX idx_orders_user_id
    ON orders(user_id);

CREATE INDEX idx_orders_restaurant_id
    ON orders(restaurant_id);

CREATE INDEX idx_orders_courier_id
    ON orders(courier_id);

CREATE INDEX idx_order_items_order_id
    ON order_items(order_id);

CREATE INDEX idx_order_items_dish_id
    ON order_items(dish_id);

--5 самых популярных запросов к бд:
--1.Определить ресторан, из которого чаще всего заказывают доставку
--2.Определить средний чек заказа в сервисе
--3.Определить самую популярную позицию у конкретного ресторана
--4.Получить историю заказов конкретного пользователя
--5.расчитать средний рейтинг ресторана