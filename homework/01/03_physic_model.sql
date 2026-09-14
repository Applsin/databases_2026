DROP TABLE IF EXISTS review;
DROP TABLE IF EXISTS address;
DROP TABLE IF EXISTS courier;
DROP TABLE IF EXISTS restaurant;
DROP TABLE IF EXISTS "user";

CREATE TABLE "user"
(
    user_id   SERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone     VARCHAR(20)  NOT NULL,
    email     VARCHAR(100) NOT NULL
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
    phone      VARCHAR(20)  NOT NULL
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
    user_id       INT NOT NULL,
    restaurant_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES "user" (user_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurant (restaurant_id)
);
