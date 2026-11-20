-- Каждый блок пытается нарушить ограничение и перехватывает ошибку
-- с понятным бизнес-сообщением + техническим текстом SQLERRM.

-- 1. Нарушение CHECK (оценка вне диапазона 1-5)
DO $$
BEGIN
    INSERT INTO reviews (user_id, course_id, rating) 
    VALUES (1, 1, 10);  -- 10 — недопустимо, CHECK разрешает только 1-5
EXCEPTION
    WHEN others THEN
        RAISE NOTICE E'Бизнес-ошибка: Оценка должна быть целым числом от 1 до 5. \nТехнический текст: %', SQLERRM;
END $$;

-- 2. Нарушение FOREIGN KEY (ссылка на несуществующего студента)
DO $$
BEGIN
    INSERT INTO enrollments (user_id, course_id)
    VALUES (99999, 1);  -- user_id = 99999 — такого студента нет
EXCEPTION
    WHEN others THEN
        RAISE NOTICE E'Бизнес-ошибка: Нельзя записать на курс несуществующего студента. \nsТехнический текст: %', SQLERRM;
END $$;

-- 3. Нарушение UNIQUE (дубликат email пользователя)
DO $$
BEGIN
    -- Сначала убедимся, что пользователь с таким email существует
    INSERT INTO users (email, password_hash, role) 
    VALUES ('unique_check@example.com', 'hash1', 'student');
    
    -- А теперь пытаемся создать второго с таким же email
    INSERT INTO users (email, password_hash, role) 
    VALUES ('unique_check@example.com', 'hash2', 'student');
EXCEPTION
    WHEN others THEN
        RAISE NOTICE E'Бизнес-ошибка: Пользователь с таким email уже зарегистрирован. \nТехнический текст: %', SQLERRM;
END $$;

-- 4. Нарушение NOT NULL (курс без названия)
DO $$
BEGIN
    INSERT INTO courses (teacher_id, title) 
    VALUES (1, NULL);  -- title = NULL — недопустимо, NOT NULL
EXCEPTION
    WHEN others THEN
        RAISE NOTICE E'Бизнес-ошибка: У курса обязательно должно быть название. \nТехнический текст: %', SQLERRM;
END $$;

-- 5. Нарушение PRIMARY KEY (дубликат id категории)
DO $$
BEGINs
    -- Убедимся, что категория с id=1 существует
    INSERT INTO categories (id, name) 
    VALUES (1, 'Первая категория')
    ON CONFLICT (id) DO NOTHING;  -- если уже есть — не падаем
    
    -- А теперь пытаемся вставить с тем же id ещё раз
    INSERT INTO categories (id, name) 
    VALUES (1, 'Дубликат id');
EXCEPTION
    WHEN others THEN
        RAISE NOTICE E'Бизнес-ошибка: Категория с таким ID уже существует. \nТехнический текст: %', SQLERRM;
END $$;








