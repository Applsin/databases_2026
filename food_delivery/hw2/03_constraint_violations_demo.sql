-- =====================================================================
-- ДЗ №2, Часть 2. Демонстрация нарушений ограничений целостности
--
-- Ровно 5 демонстраций: CHECK, FOREIGN KEY, UNIQUE, NOT NULL, PRIMARY KEY.
-- Перед запуском должны быть выполнены: hw1/03, hw2/01, hw2/02 (тестовые данные).
--
-- Как устроен каждый блок:
--   1) в BEGIN пытаемся выполнить «плохую» операцию;
--   2) если ограничение сработало — СУБД кидает ошибку, мы её ловим в EXCEPTION
--      и печатаем понятное сообщение + оригинальный SQLERRM;
--   3) если ограничение НЕ сработало — RAISE EXCEPTION откатывает вставку
--      и сообщает о проблеме (сработает ветка WHEN OTHERS).
-- Изменения внутри блока с EXCEPTION при ошибке откатываются автоматически,
-- поэтому скрипт можно запускать сколько угодно раз.
--
-- Сообщения смотрите в консоли psql или во вкладке Output в DBeaver (Ctrl+Shift+O).
-- =====================================================================


-- ---------------------------------------------------------------------
-- Демонстрация 1. CHECK — цена блюда должна быть положительной
-- ---------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO dishes (restaurant_id, name, price)
    VALUES ((SELECT MIN(restaurant_id) FROM restaurants), 'Блюдо с отрицательной ценой', -100.00);

    RAISE EXCEPTION 'Ограничение CHECK не сработало — так быть не должно!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '[1] CHECK: цена блюда должна быть строго больше нуля, добавить блюдо с ценой -100 нельзя. Текст ошибки СУБД: % (SQLSTATE %)', SQLERRM, SQLSTATE;
    WHEN OTHERS THEN
        RAISE NOTICE '[1] Неожиданная ошибка: % (SQLSTATE %)', SQLERRM, SQLSTATE;
END;
$$;


-- ---------------------------------------------------------------------
-- Демонстрация 2. FOREIGN KEY — заказ в несуществующий ресторан
-- ---------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO orders (user_id, restaurant_id, delivery_address)
    VALUES ((SELECT MIN(user_id) FROM users), 999999, 'ул. Тестовая, 1');

    RAISE EXCEPTION 'Ограничение FOREIGN KEY не сработало — так быть не должно!';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '[2] FOREIGN KEY: нельзя оформить заказ в несуществующий ресторан (restaurant_id = 999999). Текст ошибки СУБД: % (SQLSTATE %)', SQLERRM, SQLSTATE;
    WHEN OTHERS THEN
        RAISE NOTICE '[2] Неожиданная ошибка: % (SQLSTATE %)', SQLERRM, SQLSTATE;
END;
$$;


-- ---------------------------------------------------------------------
-- Демонстрация 3. UNIQUE — регистрация с уже занятым email
-- ---------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO users (full_name, email, phone)
    VALUES ('Двойник Ивана', 'ivan.petrov@example.com', '+79009998877');

    RAISE EXCEPTION 'Ограничение UNIQUE не сработало — так быть не должно!';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE '[3] UNIQUE: пользователь с таким email уже зарегистрирован, email должен быть уникальным. Текст ошибки СУБД: % (SQLSTATE %)', SQLERRM, SQLSTATE;
    WHEN OTHERS THEN
        RAISE NOTICE '[3] Неожиданная ошибка: % (SQLSTATE %)', SQLERRM, SQLSTATE;
END;
$$;


-- ---------------------------------------------------------------------
-- Демонстрация 4. NOT NULL — заказ без адреса доставки
-- ---------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO orders (user_id, restaurant_id, delivery_address)
    VALUES ((SELECT MIN(user_id) FROM users), (SELECT MIN(restaurant_id) FROM restaurants), NULL);

    RAISE EXCEPTION 'Ограничение NOT NULL не сработало — так быть не должно!';
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE '[4] NOT NULL: нельзя оформить заказ без адреса доставки — курьеру некуда ехать. Текст ошибки СУБД: % (SQLSTATE %)', SQLERRM, SQLSTATE;
    WHEN OTHERS THEN
        RAISE NOTICE '[4] Неожиданная ошибка: % (SQLSTATE %)', SQLERRM, SQLSTATE;
END;
$$;


-- ---------------------------------------------------------------------
-- Демонстрация 5. PRIMARY KEY (составной) — одно блюдо дважды в одном заказе
-- Берём существующую позицию заказа №1 и пытаемся добавить то же блюдо ещё раз.
-- ---------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO order_items (order_id, dish_id, quantity, unit_price)
    SELECT order_id, dish_id, 1, unit_price
    FROM order_items
    WHERE order_id = 1
    LIMIT 1;

    RAISE EXCEPTION 'Ограничение PRIMARY KEY не сработало — так быть не должно!';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE '[5] PRIMARY KEY: это блюдо уже есть в заказе. Второй строкой его добавлять нельзя — нужно увеличить quantity в существующей позиции. Текст ошибки СУБД: % (SQLSTATE %)', SQLERRM, SQLSTATE;
    WHEN OTHERS THEN
        RAISE NOTICE '[5] Неожиданная ошибка: % (SQLSTATE %)', SQLERRM, SQLSTATE;
END;
$$;
