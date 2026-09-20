-- =====================================================================
-- ДЗ №1, Задание 3. Физическая модель (PostgreSQL) — Food Delivery
--
-- Скрипт воспроизводим: при повторном запуске сначала удаляет свои таблицы,
-- потом создаёт их заново — результат каждый раз одинаковый.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Очистка
-- payments и order_status_history создаются в ДЗ №2, но ссылаются на orders.
-- Удаляем и их, чтобы после повторного прогона не оставалось «осиротевших»
-- таблиц (DROP TABLE orders CASCADE убирает только внешние ключи на orders,
-- а сами дочерние таблицы остаются).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS payments             CASCADE;
DROP TABLE IF EXISTS order_status_history CASCADE;
DROP TABLE IF EXISTS reviews              CASCADE;
DROP TABLE IF EXISTS order_items          CASCADE;
DROP TABLE IF EXISTS orders               CASCADE;
DROP TABLE IF EXISTS dishes               CASCADE;
DROP TABLE IF EXISTS couriers             CASCADE;
DROP TABLE IF EXISTS restaurants          CASCADE;
DROP TABLE IF EXISTS users                CASCADE;


-- ---------------------------------------------------------------------
-- 1. users — клиенты сервиса
-- Название во множественном числе: слова USER и ORDER зарезервированы в SQL.
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id     SERIAL,
    full_name   VARCHAR(150) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    phone       VARCHAR(20)  NOT NULL,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,   -- «мягкое» удаление вместо DELETE
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_users       PRIMARY KEY (user_id),
    CONSTRAINT uq_users_email UNIQUE (email),          -- один аккаунт на один email
    CONSTRAINT uq_users_phone UNIQUE (phone),          -- курьеру нужен уникальный контакт клиента
    CONSTRAINT chk_users_email CHECK (email LIKE '%_@_%'),
    CONSTRAINT chk_users_phone CHECK (phone ~ '^[+]?[0-9]{10,15}$')
);


-- ---------------------------------------------------------------------
-- 2. restaurants — рестораны
-- district нужен для запроса «рестораны в этом районе».
-- ---------------------------------------------------------------------
CREATE TABLE restaurants (
    restaurant_id SERIAL,
    name          VARCHAR(150) NOT NULL,
    description   TEXT,
    address       VARCHAR(255) NOT NULL,
    district      VARCHAR(100) NOT NULL,
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_restaurants PRIMARY KEY (restaurant_id),
    CONSTRAINT uq_restaurants_name_address UNIQUE (name, address)   -- нет двух одинаковых точек
);


-- ---------------------------------------------------------------------
-- 3. couriers — курьеры
-- ---------------------------------------------------------------------
CREATE TABLE couriers (
    courier_id   SERIAL,
    full_name    VARCHAR(150) NOT NULL,
    phone        VARCHAR(20)  NOT NULL,
    vehicle_type VARCHAR(20)  NOT NULL,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
    hired_at     DATE         NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT pk_couriers       PRIMARY KEY (courier_id),
    CONSTRAINT uq_couriers_phone UNIQUE (phone),
    CONSTRAINT chk_couriers_vehicle CHECK (vehicle_type IN ('foot', 'bicycle', 'scooter', 'car')),
    CONSTRAINT chk_couriers_phone   CHECK (phone ~ '^[+]?[0-9]{10,15}$')
);


-- ---------------------------------------------------------------------
-- 4. dishes — блюда в меню ресторана
-- price — ТЕКУЩАЯ цена. Историю цен хранит order_items.unit_price.
-- Блюдо не удаляем, а выключаем (is_available = FALSE) — так старые заказы
-- остаются целыми.
-- ---------------------------------------------------------------------
CREATE TABLE dishes (
    dish_id       SERIAL,
    restaurant_id INTEGER       NOT NULL,
    name          VARCHAR(150)  NOT NULL,
    description   TEXT,
    price         NUMERIC(10,2) NOT NULL,
    is_available  BOOLEAN       NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_dishes PRIMARY KEY (dish_id),
    CONSTRAINT fk_dishes_restaurant FOREIGN KEY (restaurant_id)
        REFERENCES restaurants (restaurant_id) ON DELETE CASCADE,
    CONSTRAINT uq_dishes_restaurant_name UNIQUE (restaurant_id, name),  -- в меню нет дублей
    CONSTRAINT chk_dishes_price CHECK (price > 0)
);


-- ---------------------------------------------------------------------
-- 5. orders — заказы
-- status  — текущий статус заказа (полная история — в order_status_history, ДЗ №2)
-- courier_id может быть NULL: заказ создан, а курьер ещё не назначен.
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id         SERIAL,
    user_id          INTEGER      NOT NULL,
    restaurant_id    INTEGER      NOT NULL,
    courier_id       INTEGER,
    status           VARCHAR(20)  NOT NULL DEFAULT 'created',
    delivery_address VARCHAR(255) NOT NULL,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivered_at     TIMESTAMP,

    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_user       FOREIGN KEY (user_id)       REFERENCES users (user_id)              ON DELETE RESTRICT,
    CONSTRAINT fk_orders_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (restaurant_id)  ON DELETE RESTRICT,
    CONSTRAINT fk_orders_courier    FOREIGN KEY (courier_id)    REFERENCES couriers (courier_id)        ON DELETE RESTRICT,

    -- статусы из бизнес-описания: создан → готовится → передан курьеру → доставлен (+ отменён)
    CONSTRAINT chk_orders_status CHECK (status IN ('created', 'cooking', 'with_courier', 'delivered', 'cancelled')),
    -- передать курьеру / доставить можно только когда курьер назначен
    CONSTRAINT chk_orders_courier_required
        CHECK (status NOT IN ('with_courier', 'delivered') OR courier_id IS NOT NULL),
    -- время доставки заполнено тогда и только тогда, когда статус «доставлен»
    CONSTRAINT chk_orders_delivered_at
        CHECK ((status = 'delivered') = (delivered_at IS NOT NULL)),
    -- доставить раньше, чем создали, нельзя
    CONSTRAINT chk_orders_dates
        CHECK (delivered_at IS NULL OR delivered_at >= created_at)
);


-- ---------------------------------------------------------------------
-- 6. order_items — позиции заказа (связь M:N между orders и dishes)
-- Составной первичный ключ (order_id, dish_id): одно блюдо — одна строка,
-- чтобы взять две порции, увеличивают quantity.
-- unit_price — цена на момент заказа (снимок): меню меняется, чек — нет.
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_id   INTEGER       NOT NULL,
    dish_id    INTEGER       NOT NULL,
    quantity   INTEGER       NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,

    CONSTRAINT pk_order_items PRIMARY KEY (order_id, dish_id),
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT fk_order_items_dish  FOREIGN KEY (dish_id)  REFERENCES dishes (dish_id)  ON DELETE RESTRICT,
    CONSTRAINT chk_order_items_quantity CHECK (quantity > 0),
    CONSTRAINT chk_order_items_price    CHECK (unit_price > 0)
);


-- ---------------------------------------------------------------------
-- 7. reviews — отзывы (о ресторане и о доставке)
-- Отзыв привязан к заказу: оставить его может только тот, кто заказывал,
-- и только один раз (UNIQUE по order_id). Ресторан и курьер определяются
-- через заказ, поэтому их id здесь не дублируются.
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    review_id         SERIAL,
    order_id          INTEGER   NOT NULL,
    restaurant_rating SMALLINT  NOT NULL,
    courier_rating    SMALLINT,                       -- оценка доставки, можно не ставить
    review_text       TEXT,
    created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_reviews PRIMARY KEY (review_id),
    CONSTRAINT fk_reviews_order FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT uq_reviews_order UNIQUE (order_id),
    CONSTRAINT chk_reviews_restaurant_rating CHECK (restaurant_rating BETWEEN 1 AND 5),
    CONSTRAINT chk_reviews_courier_rating    CHECK (courier_rating BETWEEN 1 AND 5)  -- NULL проходит проверку
);


-- ---------------------------------------------------------------------
-- 8. Индексы на внешние ключи
-- PostgreSQL сам создаёт индекс под PRIMARY KEY и UNIQUE, но НЕ под FOREIGN KEY.
-- Уже покрыты автоматически:
--   dishes.restaurant_id     — левая часть индекса uq_dishes_restaurant_name
--   order_items.order_id     — левая часть первичного ключа pk_order_items
--   reviews.order_id         — индекс uq_reviews_order
-- ---------------------------------------------------------------------
CREATE INDEX idx_orders_user_id       ON orders      (user_id);
CREATE INDEX idx_orders_restaurant_id ON orders      (restaurant_id);
CREATE INDEX idx_orders_courier_id    ON orders      (courier_id);
CREATE INDEX idx_order_items_dish_id  ON order_items (dish_id);
