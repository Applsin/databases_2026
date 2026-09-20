CREATE TABLE "user"
(
    user_id   SERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone     VARCHAR(20)  NOT NULL UNIQUE,
    email     VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE restaurant
(
    restaurant_id SERIAL PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    description   TEXT
);

CREATE TABLE courier
(
    courier_id SERIAL PRIMARY KEY,
    full_name  VARCHAR(150) NOT NULL,
    phone      VARCHAR(20)  NOT NULL UNIQUE
);

CREATE TABLE address
(
    address_id SERIAL PRIMARY KEY,
    user_id    INT          NOT NULL,
    city       VARCHAR(100) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES "user" (user_id)
);

CREATE TABLE review
(
    review_id     SERIAL PRIMARY KEY,
    user_id       INT      NOT NULL,
    restaurant_id INT      NOT NULL,
    courier_id    INT,
    rating        SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    FOREIGN KEY (user_id) REFERENCES "user" (user_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurant (restaurant_id),
    FOREIGN KEY (courier_id) REFERENCES courier (courier_id)
);

CREATE TABLE "order"
(
    order_id      SERIAL PRIMARY KEY,
    user_id       INT            NOT NULL,
    restaurant_id INT            NOT NULL,
    courier_id    INT,
    address_id    INT            NOT NULL,
    status        VARCHAR(20)    NOT NULL DEFAULT 'new'
        CHECK (status IN ('new', 'cooking', 'delivering', 'done', 'cancelled')),
    total_amount  NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    FOREIGN KEY (user_id) REFERENCES "user" (user_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurant (restaurant_id),
    FOREIGN KEY (courier_id) REFERENCES courier (courier_id),
    FOREIGN KEY (address_id) REFERENCES address (address_id)
);

CREATE TABLE order_item
(
    order_item_id  SERIAL PRIMARY KEY,
    order_id       INT            NOT NULL,
    dish_name      VARCHAR(150)   NOT NULL,
    quantity       INT            NOT NULL CHECK (quantity > 0),
    price_at_order NUMERIC(10, 2) NOT NULL CHECK (price_at_order >= 0),
    FOREIGN KEY (order_id) REFERENCES "order" (order_id)
);

INSERT INTO "user" (full_name, phone, email)
VALUES ('Иван', '+79990000001', 'ivan@mail.ru');
INSERT INTO restaurant (name, description)
VALUES ('Суши Мастер', 'Японская кухня');
INSERT INTO courier (full_name, phone)
VALUES ('Пётр', '+79990000002');
INSERT INTO address (user_id, city)
VALUES (1, 'Москва');

--- Демонстрации

DO
$$
    BEGIN
        INSERT INTO review (user_id, restaurant_id, rating)
        VALUES (1, 1, 10);
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'Ошибка: оценка в отзыве должна быть от 1 до 5. Поставлена оценка 10 — это недопустимо. Текст ошибки: %', SQLERRM;
    END;
$$;

DO
$$
    BEGIN
        INSERT INTO address (user_id, city)
        VALUES (999, 'Санкт-Петербург');
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'Ошибка: нельзя привязать адрес к несуществующему пользователю (user_id = 999). Адрес должен принадлежать реальному клиенту. Текст ошибки: %', SQLERRM;
    END;
$$;

DO
$$
    BEGIN
        INSERT INTO "user" (full_name, phone, email)
        VALUES ('Анна', '+79990000003', 'anna@mail.ru');

        INSERT INTO "user" (full_name, phone, email)
        VALUES ('Олег', '+79990000003', 'oleg@mail.ru');
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'Ошибка: пользователь с таким телефоном уже зарегистрирован. Телефон должен быть уникальным. Текст ошибки: %', SQLERRM;
    END;
$$;

DO
$$
    BEGIN
        INSERT INTO "order" (restaurant_id, address_id, total_amount)
        VALUES (1, 1, 500);
    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE 'Ошибка: нельзя создать заказ без указания клиента (user_id). Заказ должен принадлежать пользователю. Текст ошибки: %', SQLERRM;
    END;
$$;

DO
$$
    BEGIN
        INSERT INTO "user" (user_id, full_name, phone, email)
        VALUES (100, 'Тест', '+79990000100', 'test@mail.ru');

        INSERT INTO "user" (user_id, full_name, phone, email)
        VALUES (100, 'Дубликат', '+79990000101', 'dup@mail.ru');
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'Ошибка: пользователь с таким ID уже есть. PK должен быть уникальным. Текст ошибки: %', SQLERRM;
    END;
$$;

