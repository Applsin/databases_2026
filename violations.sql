-- ==========================================
-- Часть 2. Демонстрация нарушений ограничений
-- ==========================================
DO $$
BEGIN
    -- 1. Нарушение CHECK
    BEGIN
        INSERT INTO employee (full_name, email, position, department) 
        VALUES ('Иван Иванов', 'ivan_mail.ru', 'Developer', 'IT');
    EXCEPTION
        WHEN check_violation THEN
            RAISE NOTICE 'Ошибка: Неверный формат электронной почты. Email должен содержать "@" и домен. Текст БД: %', SQLERRM;
    END;

    -- 2. Нарушение FOREIGN KEY
    BEGIN
        INSERT INTO task (project_id, status_id, title, created_by) 
        VALUES (9999, 1, 'Настроить сервер', 1);
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'Ошибка: Указан несуществующий проект. Задача не может быть создана "в воздухе". Текст БД: %', SQLERRM;
    END;

    -- 3. Нарушение UNIQUE
    BEGIN
        INSERT INTO project (name, description, start_date) 
        VALUES ('Альфа-Проект', 'Описание', CURRENT_DATE);
        
        INSERT INTO project (name, description, start_date) 
        VALUES ('Альфа-Проект', 'Другое описание', CURRENT_DATE);
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'Ошибка: Проект с таким названием уже существует. Пожалуйста, выберите другое имя. Текст БД: %', SQLERRM;
    END;

    -- 4. Нарушение NOT NULL
    BEGIN
        INSERT INTO status (status_name, is_closed) 
        VALUES (NULL, FALSE);
    EXCEPTION
        WHEN not_null_violation THEN
            RAISE NOTICE 'Ошибка: Название статуса обязательно для заполнения и не может быть пустым. Текст БД: %', SQLERRM;
    END;

    -- 5. Нарушение PRIMARY KEY
    BEGIN
        INSERT INTO status (status_id, status_name, is_closed) 
        VALUES (1, 'Custom Status', FALSE);
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'Ошибка: Статус с таким системным идентификатором уже зарегистрирован. Текст БД: %', SQLERRM;
    END;
END;
$$;