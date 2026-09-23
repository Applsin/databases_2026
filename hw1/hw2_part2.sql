--дз_2
-- 1. Нарушение CHECK (цена не может быть отрицательной)
DO $$
BEGIN
    INSERT INTO courses (title, teacher_id, price) VALUES ('Test Course', 1, -100);
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'Ошибка CHECK: Нельзя создать курс с отрицательной ценой. Текст ошибки: %', SQLERRM;
END $$;

-- 2. Нарушение FOREIGN KEY (несуществующий студент)
DO $$
BEGIN
    INSERT INTO enrollments (student_id, course_id) VALUES (9999, 1);
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Ошибка FOREIGN KEY: Нельзя записать на курс несуществующего студента. Текст ошибки: %', SQLERRM;
END $$;

-- 3. Нарушение UNIQUE (дубликат email)
DO $$
BEGIN
    -- Пытаемся добавить двух пользователей с одинаковым email
    INSERT INTO users (email, password, first_name, last_name, role) 
    VALUES ('test@mail.com', 'pass', 'Test', 'User', 'student');
    INSERT INTO users (email, password, first_name, last_name, role) 
    VALUES ('test@mail.com', 'pass2', 'Test2', 'User2', 'student');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка UNIQUE: Пользователь с таким email уже существует. Текст ошибки: %', SQLERRM;
END $$;

-- 4. Нарушение NOT NULL (отсутствует имя курса)
DO $$
BEGIN
    INSERT INTO courses (teacher_id, title) VALUES (1, NULL);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Ошибка NOT NULL: Название курса не может быть пустым. Текст ошибки: %', SQLERRM;
END $$;

-- 5. Нарушение PRIMARY KEY (дубликат ID)
DO $$
BEGIN
    -- Пытаемся создать пользователя с ID = 1, который уже существует
    INSERT INTO users (user_id, email, password, first_name, last_name, role) 
    VALUES (1, 'new@mail.com', 'pass', 'New', 'User', 'student');
EXCEPTION
    WHEN integrity_constraint_violation THEN
        RAISE NOTICE 'Ошибка PRIMARY KEY: Пользователь с таким ID уже существует. Текст ошибки: %', SQLERRM;
END $$;
