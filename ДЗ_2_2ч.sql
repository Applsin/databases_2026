-- Заполнение базовых тестовых данных для проверок
DO $$
BEGIN
    -- Создаем тестового пользователя-преподавателя
    INSERT INTO "User" (id, login, password_user) 
    VALUES (1, 'teacher_demo', 'pass123') 
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO Teacher (id) 
    VALUES (1) 
    ON CONFLICT (id) DO NOTHING;

    -- Создаем базовый курс для тестов
    INSERT INTO Course (id, title, price, id_teacher) 
    VALUES (1, 'Базовый курс SQL', 1000.00, 1) 
    ON CONFLICT (id) DO NOTHING;

    -- Создаем категорию (учитываем конфликт и по id, и по name)
    INSERT INTO Category (id, name) 
    VALUES (1, 'Программирование') 
    ON CONFLICT (name) DO NOTHING;
END $$;



-- Демонстрация нарушений ограничений


-- 1. Нарушение CHECK: попытка установить отрицательную цену курса
DO $$
BEGIN
    INSERT INTO Course (title, price, id_teacher) 
    VALUES ('Курс по Python', -500.00, 1);
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'Бизнес-ошибка: Цена курса не может быть отрицательной. Текст ошибки СУБД: %', SQLERRM;
END $$;

-- 2. Нарушение FOREIGN KEY: попытка привязать курс к несуществующему преподавателю
DO $$
BEGIN
    INSERT INTO Course (title, price, id_teacher) 
    VALUES ('Основы Java', 1500.00, 9999);
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Бизнес-ошибка: Нельзя создать курс для несуществующего преподавателя. Текст ошибки СУБД: %', SQLERRM;
END $$;

-- 3. Нарушение UNIQUE: попытка создать категорию с уже существующим именем
DO $$
BEGIN
    INSERT INTO Category (name) 
    VALUES ('Программирование');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Бизнес-ошибка: Категория с таким названием уже существует в системе. Текст ошибки СУБД: %', SQLERRM;
END $$;

-- 4. Нарушение NOT NULL: попытка создать урок без названия
DO $$
BEGIN
    INSERT INTO Lesson (id_course, title, order_index) 
    VALUES (1, NULL, 1);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Бизнес-ошибка: Каждый урок должен иметь название. Текст ошибки СУБД: %', SQLERRM;
END $$;

-- 5. Нарушение PRIMARY KEY: попытка явно вставить пользователя с уже занятым id = 1
DO $$
BEGIN
    INSERT INTO "User" (id, login, password_user) 
    VALUES (1, 'new_teacher', 'pass456');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Бизнес-ошибка: Пользователь с таким ID уже зарегистрирован. Текст ошибки СУБД: %', SQLERRM;
END $$;