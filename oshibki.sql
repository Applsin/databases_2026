DO $$
BEGIN
    -- Попытка выполнить ошибочную операцию
    INSERT INTO restaurant (id,"name", address)
    VALUES ('998', 'Несуществующий проект', 10);
EXCEPTION
    WHEN others THEN
        raise notice 'ошибка id должжен быть числом%', SQLERRM;
END;
$$;
select * from restaurant ;
DO $$
BEGIN
    -- Попытка выполнить ошибочную операцию
    INSERT INTO dish (id,"name", price, vege, spicy, restaurant)
    VALUES (1, 'Несуществующий', 10, False, True, 43);
EXCEPTION
    WHEN others THEN
        raise notice 'ошибка блюдо привязано к несуществующему ресторану%', SQLERRM;
END;
$$;
DO $$
BEGIN
    -- Попытка выполнить ошибочную операцию
    INSERT INTO restaurant (id,"name", address)
    VALUES (3, 'puskin', 'fwefwef');
EXCEPTION
    WHEN others THEN
        raise notice 'ошибка уникальности%', SQLERRM;
END;
$$;
DO $$
BEGIN
    -- Попытка выполнить ошибочную операцию
    INSERT INTO restaurant (id,"name", address)
    VALUES (44, Null, 'rgj');
EXCEPTION
    WHEN others THEN
        raise notice 'ошибка название должно быть не  пустое%', SQLERRM;
END;
$$;
DO $$
BEGIN
    -- Попытка выполнить ошибочную операцию
    INSERT INTO restaurant (id,"name", address)
    VALUES (1, 'Несуществующийкт', 'fddrbd');
EXCEPTION
    WHEN others THEN
        raise notice 'ошибка первичный ключ не уникален%', SQLERRM;
END;
$$;