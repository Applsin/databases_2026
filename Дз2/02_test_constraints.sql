--Демонстрация нарушений
-- 1. Нарушение CHECK (цена <= 0)
DO $$
BEGIN
    INSERT INTO dishes (restaurant_id, name, price) VALUES (1, 'Тестовое блюдо', -10.0);
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '1. CHECK: Цена блюда должна быть > 0. Ошибка СУБД: %', SQLERRM;
END $$;

-- 2. Нарушение FOREIGN KEY (несуществующий клиент)
DO $$
BEGIN
    INSERT INTO orders (customer_id, restaurant_id, total_amount) VALUES (99999, 1, 500.0);
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '2. FOREIGN KEY: Клиент с ID 99999 не существует. Ошибка СУБД: %', SQLERRM;
END $$;

-- 3. Нарушение UNIQUE (дубликат email)
DO $$
BEGIN
    INSERT INTO users (first_name, last_name, email, phone, role) 
    VALUES ('Тест1', 'Тестов', 'unique_test_dz2@example.com', '89000000000', 'customer');
    
    INSERT INTO users (first_name, last_name, email, phone, role) 
    VALUES ('Тест2', 'Тестов', 'unique_test_dz2@example.com', '89000000001', 'customer');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE '3. UNIQUE: Email уже зарегистрирован в системе. Ошибка СУБД: %', SQLERRM;
END $$;

-- 4. Нарушение NOT NULL (отсутствие обязательного адреса)
DO $$
BEGIN
    INSERT INTO restaurants (name, address) VALUES ('Ресторан без адреса', NULL);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE '4. NOT NULL: Адрес ресторана является обязательным полем. Ошибка СУБД: %', SQLERRM;
END $$;

-- 5. Нарушение сложного CHECK (дата доставки раньше даты создания)
DO $$
BEGIN
    INSERT INTO users (user_id, first_name, last_name, email, phone, role) 
    VALUES (1, 'Клиент', 'Тест', 'client1@example.com', '89000000002', 'customer') 
    ON CONFLICT (user_id) DO NOTHING;
    
    INSERT INTO restaurants (restaurant_id, name, address) 
    VALUES (1, 'Тест Ресторан', 'ул. Тестовая, 1') 
    ON CONFLICT (restaurant_id) DO NOTHING;

    INSERT INTO orders (customer_id, restaurant_id, total_amount, created_at, delivered_at) 
    VALUES (1, 1, 500.0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP - INTERVAL '1 hour');
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '5. CHECK (сложный): Дата доставки не может быть раньше даты создания заказа. Ошибка СУБД: %', SQLERRM;
END $$;
