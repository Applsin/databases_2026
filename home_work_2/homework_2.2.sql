INSERT INTO users (username, email, role) VALUES 
    ('test_student', 'student@test.com', 'student'),
    ('test_teacher', 'teacher@test.com', 'teacher');
INSERT INTO courses (teacher_id, title, price) VALUES 
    (2, 'Test Course', 100.00);
DO $$
BEGIN
    INSERT INTO reviews (user_id, course_id, rating, comment)
    VALUES (1, 1, 6, 'Отличный курс!');
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'ОШИБКА CHECK: Оценка должна быть от 1 до 5. Получено значение: 6. Текст ошибки: %', SQLERRM;
END;
$$;
DO $$
BEGIN
    INSERT INTO enrollments (user_id, course_id, status)
    VALUES (1, 999, 'active');
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'ОШИБКА FOREIGN KEY: Студент пытается записаться на несуществующий курс (ID=999). Курс не найден. Текст ошибки: %', SQLERRM;
END;
$$;
DO $$
BEGIN
    INSERT INTO users (username, email, role)
    VALUES ('another_student', 'student@test.com', 'student');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'ОШИБКА UNIQUE: Email "student@test.com" уже зарегистрирован. Каждый пользователь должен иметь уникальный email. Текст ошибки: %', SQLERRM;
END;
$$;
DO $$
BEGIN
    INSERT INTO courses (teacher_id, title, price)
    VALUES (2, NULL, 50.00);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'ОШИБКА NOT NULL: Название курса не может быть пустым. Каждый курс должен иметь название. Текст ошибки: %', SQLERRM;
END;
$$;
--я не понял как понять реализовано оно или нет и не знаю делать мне 5 пункт или нет