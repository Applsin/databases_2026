-- ДЗ №2. Часть 2. Ровно 5 демонстраций нарушений.
-- CHECK, FOREIGN KEY, UNIQUE, NOT NULL, PRIMARY KEY.
-- Скрипт рассчитан на схему ДЗ №1 + dz2_setup.sql.

DO $$
DECLARE
    test_user_id INTEGER;
    test_course_id INTEGER;
    test_lesson_id INTEGER;
    test_paid_at TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
    -- Подготовка временных тестовых данных.
    INSERT INTO users (name, email, role)
    VALUES (
        'Демо ДЗ2',
        'dz2_demo_' || clock_timestamp()::text || '@example.com',
        'student'
    )
    RETURNING user_id INTO test_user_id;

    INSERT INTO courses (teacher_id, title, description, price)
    VALUES (
        test_user_id,
        'Демо-курс ДЗ2',
        'Тестовая запись',
        100.00
    )
    RETURNING course_id INTO test_course_id;

    INSERT INTO lessons (course_id, title, content, lesson_order)
    VALUES (
        test_course_id,
        'Демо-урок ДЗ2',
        'Тестовая запись',
        1
    )
    RETURNING lesson_id INTO test_lesson_id;

    RAISE NOTICE 'Тестовые данные: user_id=%, course_id=%, lesson_id=%',
        test_user_id, test_course_id, test_lesson_id;

    -- 1. CHECK
    BEGIN
        INSERT INTO lesson_progress (user_id, lesson_id, status, completed_at)
        VALUES (test_user_id, test_lesson_id, 'wrong_status', NULL);
    EXCEPTION
        WHEN others THEN
            RAISE NOTICE
                'Ошибка бизнес-логики: статус прогресса должен быть in_progress или completed. Текст ошибки СУБД: %',
                SQLERRM;
    END;

    -- 2. FOREIGN KEY
    BEGIN
        INSERT INTO lesson_progress (user_id, lesson_id, status, completed_at)
        VALUES (999999999, test_lesson_id, 'in_progress', NULL);
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE
                'Ошибка бизнес-логики: нельзя сохранить прогресс несуществующего пользователя. Текст ошибки СУБД: %',
                SQLERRM;
        WHEN others THEN
            RAISE NOTICE 'Неожиданная ошибка FOREIGN KEY: %', SQLERRM;
    END;

    -- 3. UNIQUE
    INSERT INTO payments (user_id, course_id, amount, paid_at, status)
    VALUES (test_user_id, test_course_id, 100.00, test_paid_at, 'paid');

    BEGIN
        INSERT INTO payments (user_id, course_id, amount, paid_at, status)
        VALUES (test_user_id, test_course_id, 100.00, test_paid_at, 'paid');
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'Ошибка бизнес-логики: нельзя создать дубликат одной и той же оплаты. Текст ошибки СУБД: %',
                SQLERRM;
        WHEN others THEN
            RAISE NOTICE 'Неожиданная ошибка UNIQUE: %', SQLERRM;
    END;

    -- 4. NOT NULL
    BEGIN
        INSERT INTO payments (user_id, course_id, amount, paid_at, status)
        VALUES (
            test_user_id,
            test_course_id,
            NULL,
            CURRENT_TIMESTAMP + interval '1 second',
            'paid'
        );
    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE
                'Ошибка бизнес-логики: сумма оплаты обязательна и не может быть NULL. Текст ошибки СУБД: %',
                SQLERRM;
        WHEN others THEN
            RAISE NOTICE 'Неожиданная ошибка NOT NULL: %', SQLERRM;
    END;

    -- 5. PRIMARY KEY
    INSERT INTO lesson_progress (user_id, lesson_id, status, completed_at)
    VALUES (test_user_id, test_lesson_id, 'in_progress', NULL);

    BEGIN
        INSERT INTO lesson_progress (user_id, lesson_id, status, completed_at)
        VALUES (test_user_id, test_lesson_id, 'in_progress', NULL);
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE
                'Ошибка бизнес-логики: для одного пользователя и одного урока может быть только одна запись прогресса. Текст ошибки СУБД: %',
                SQLERRM;
        WHEN others THEN
            RAISE NOTICE 'Неожиданная ошибка PRIMARY KEY: %', SQLERRM;
    END;

    -- Удаление тестовых данных.
    DELETE FROM payments
    WHERE user_id = test_user_id
      AND course_id = test_course_id;

    DELETE FROM lesson_progress
    WHERE user_id = test_user_id
      AND lesson_id = test_lesson_id;

    DELETE FROM lessons WHERE lesson_id = test_lesson_id;
    DELETE FROM courses WHERE course_id = test_course_id;
    DELETE FROM users WHERE user_id = test_user_id;

    RAISE NOTICE 'Демонстрация завершена. Тестовые данные удалены.';
END;
$$;
