-- ДЗ №2: демонстрация нарушений целостности.
-- Ошибки перехватываются, поэтому скрипт можно запускать целиком.

DO $$
BEGIN
    BEGIN
        INSERT INTO categories(name) VALUES ('Пицца');
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'OK: UNIQUE categories.name запрещает дубликат';
    END;
END $$;

DO $$
BEGIN
    BEGIN
        INSERT INTO dishes(restaurant_id, name, price)
        VALUES (999999, 'Тест', 100);
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: FK dishes.restaurant_id запрещает несуществующий ресторан';
    END;
END $$;

DO $$
BEGIN
    BEGIN
        INSERT INTO order_items(order_id, dish_id, quantity, unit_price)
        VALUES (1, 1, 0, 650);
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: CHECK quantity > 0';
    END;
END $$;

DO $$
BEGIN
    BEGIN
        INSERT INTO restaurants(name, address, rating)
        VALUES ('Тест', 'Тест', 6);
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: CHECK rating BETWEEN 0 AND 5';
    END;
END $$;

DO $$
BEGIN
    BEGIN
        INSERT INTO orders(user_id, restaurant_id, status, delivery_address, total_amount)
        VALUES (1, 1, 'wrong_status', 'Тест', 100);
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: CHECK orders.status запрещает неизвестный статус';
    END;
END $$;

DO $$
BEGIN
    BEGIN
        INSERT INTO dish_categories(dish_id, category_id)
        VALUES (1, 1);
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'OK: составной PK (dish_id, category_id) запрещает дубликат M:N';
    END;
END $$;

DO $$
BEGIN
    BEGIN
        INSERT INTO dish_categories(dish_id, category_id)
        VALUES (999999, 1);
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'OK: FK dish_categories.dish_id запрещает несуществующее блюдо';
    END;
END $$;

-- Проверка ON DELETE CASCADE.
-- Временная категория удаляется, её строка связи удаляется автоматически.
DO $$
DECLARE
    cid BIGINT;
    before_count INTEGER;
    after_count INTEGER;
BEGIN
    INSERT INTO categories(name) VALUES ('_TEMP_CASCADE_TEST')
    RETURNING category_id INTO cid;

    INSERT INTO dish_categories(dish_id, category_id)
    VALUES (1, cid);

    SELECT COUNT(*) INTO before_count
    FROM dish_categories WHERE category_id = cid;

    DELETE FROM categories WHERE category_id = cid;

    SELECT COUNT(*) INTO after_count
    FROM dish_categories WHERE category_id = cid;

    IF before_count = 1 AND after_count = 0 THEN
        RAISE NOTICE 'OK: ON DELETE CASCADE удалил зависимую связь';
    ELSE
        RAISE EXCEPTION 'CASCADE работает некорректно';
    END IF;
END $$;
