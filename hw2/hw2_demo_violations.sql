-- Тестовые данные 
INSERT INTO "User" (email, full_name, role)
VALUES ('teacher@test.com', 'Тестов Препод Тестович', 'teacher')
ON CONFLICT DO NOTHING;

INSERT INTO "User" (email, full_name, role)
VALUES ('student@test.com', 'Тестов Студент Тестович', 'student')
ON CONFLICT DO NOTHING;

INSERT INTO Course (teacher_id, title, price, is_published)
SELECT user_id, 'Тестовый курс', 1000.00, TRUE
FROM "User" WHERE email = 'teacher@test.com'
ON CONFLICT DO NOTHING;

INSERT INTO Lesson (course_id, title, position)
SELECT course_id, 'Урок 1', 1
FROM Course WHERE title = 'Тестовый курс'
ON CONFLICT DO NOTHING;

-- 1. Нарушение CHECK: рейтинг вне диапазона 1–5
DO $$
BEGIN
    INSERT INTO Review (student_id, course_id, rating)
    VALUES (
        (SELECT user_id FROM "User" WHERE email = 'student@test.com'),
        (SELECT course_id FROM Course WHERE title = 'Тестовый курс'),
        10
    );
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'Ошибка: оценка курса должна быть от 1 до 5. Студент не может поставить 10 баллов. Текст ошибки: %', SQLERRM;
END;
$$;

-- 2. Нарушение FOREIGN KEY: запись на несуществующий курс
DO $$
BEGIN
    INSERT INTO Enrollment (student_id, course_id)
    VALUES (
        (SELECT user_id FROM "User" WHERE email = 'student@test.com'),
        99999
    );
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Ошибка: нельзя записаться на курс, которого не существует. Текст ошибки: %', SQLERRM;
END;
$$;

-- 3. Нарушение UNIQUE: повторная запись на тот же курс
DO $$
BEGIN
    INSERT INTO Enrollment (student_id, course_id)
    VALUES (
        (SELECT user_id FROM "User" WHERE email = 'student@test.com'),
        (SELECT course_id FROM Course WHERE title = 'Тестовый курс')
    );
    INSERT INTO Enrollment (student_id, course_id)
    VALUES (
        (SELECT user_id FROM "User" WHERE email = 'student@test.com'),
        (SELECT course_id FROM Course WHERE title = 'Тестовый курс')
    );
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: студент уже записан на этот курс. Повторная запись невозможна. Текст ошибки: %', SQLERRM;
END;
$$;

-- 4. Нарушение NOT NULL: курс без названия
DO $$
BEGIN
    INSERT INTO Course (teacher_id, title, price)
    VALUES (
        (SELECT user_id FROM "User" WHERE email = 'teacher@test.com'),
        NULL,
        500.00
    );
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Ошибка: у курса обязательно должно быть название. Текст ошибки: %', SQLERRM;
END;
$$;

-- 5. Нарушение FOREIGN KEY (RESTRICT): удаление преподавателя с курсами
DO $$
BEGIN
    DELETE FROM "User"
    WHERE email = 'teacher@test.com';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Ошибка: нельзя удалить преподавателя, пока у него есть курсы. Сначала переназначьте или удалите курсы. Текст ошибки: %', SQLERRM;
END;
$$;