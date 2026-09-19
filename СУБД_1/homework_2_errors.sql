-- 1. CHECK
DO $$
BEGIN
    BEGIN
        INSERT INTO "user" (name, email, password, role)
        VALUES ('Test Check', 'check_test@example.com', '12345', 'admin');
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'CHECK: роль пользователя должна быть student или teacher. Ошибка БД: %', SQLERRM;
    END;
END $$;


-- 2. FOREIGN KEY
DO $$
BEGIN
    BEGIN
        INSERT INTO course (title, price, teacher_id)
        VALUES ('Test FK', 100, 999999999);
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'FOREIGN KEY: преподаватель должен существовать в таблице user. Ошибка БД: %', SQLERRM;
    END;
END $$;


-- 3. NOT NULL
DO $$
BEGIN
    BEGIN
        INSERT INTO "user" (name, email, password, role)
        VALUES (NULL, 'null_test@example.com', '12345', 'student');
    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE 'NOT NULL: имя пользователя обязательно для заполнения. Ошибка БД: %', SQLERRM;
    END;
END $$;


-- 4. UNIQUE
DO $$
DECLARE
    v_email TEXT := 'unique_test_' ||
        floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint ||
        '@example.com';
BEGIN
    INSERT INTO "user" (name, email, password, role)
    VALUES ('Test Unique', v_email, '12345', 'student');

    BEGIN
        INSERT INTO "user" (name, email, password, role)
        VALUES ('Test Unique 2', v_email, '12345', 'student');
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'UNIQUE: email пользователя должен быть уникальным. Ошибка БД: %', SQLERRM;
    END;

    DELETE FROM "user"
    WHERE email = v_email;
END $$;


-- 5. PRIMARY KEY
DO $$
DECLARE
    v_user_id INTEGER;
    v_email TEXT := 'pk_test_' ||
        floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint ||
        '@example.com';
BEGIN
    INSERT INTO "user" (name, email, password, role)
    VALUES ('Test PK', v_email, '12345', 'student')
    RETURNING user_id INTO v_user_id;

    BEGIN
        INSERT INTO "user" (user_id, name, email, password, role)
        VALUES (v_user_id, 'Test PK 2', 'pk_test_2@example.com', '12345', 'student');
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'PRIMARY KEY: user_id должен быть уникальным. Ошибка БД: %', SQLERRM;
    END;

    DELETE FROM "user"
    WHERE user_id = v_user_id;
END $$;