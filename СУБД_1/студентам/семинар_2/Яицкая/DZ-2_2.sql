DO $$
BEGIN
    -- преподаватель
    INSERT INTO "user" (user_id, email, full_name)
    VALUES (1, 'prepod@email.com', 'Сергей Иванович')
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO instructor (instructor_id, payout_details)
    VALUES (1, 'Сбер 1')
    ON CONFLICT (instructor_id) DO NOTHING;

    -- студент
    INSERT INTO "user" (user_id, email, full_name)
    VALUES (2, 'student@email.com', 'Полное Имя')
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO student (student_id, balance)
    VALUES (2, 0)
    ON CONFLICT (student_id) DO NOTHING;

    -- курс от преподавателя
    INSERT INTO course (course_id, title, price, instructor_id)
    VALUES (1, 'Курс SQL для новичков', 1000.00, 1)
    ON CONFLICT (course_id) DO NOTHING;

    -- урок в этом курсе
    INSERT INTO lesson (lesson_id, course_id, title, order_num, duration_min)
    VALUES (1, 1, 'Введение в SQL', 1, 60)
    ON CONFLICT (lesson_id) DO NOTHING;

    -- запись на курс
    INSERT INTO enrollment (enrollment_id, course_id, student_id)
    VALUES (1, 1, 2)
    ON CONFLICT (enrollment_id) DO NOTHING;

    -- отзыв
    INSERT INTO review (course_id, student_id, rating)
    VALUES (1, 2, 5)
    ON CONFLICT (student_id, course_id) DO NOTHING;
END $$;


--CHECK
DO $$
BEGIN
    INSERT INTO review (course_id, student_id, rating)
    VALUES (1, 1, 10);
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'oшибка: оценка в отзыве должна быть от 1 до 5. Текст ошибки: %', SQLERRM;
END $$;


--FOREIGN KEY
DO $$
BEGIN
    INSERT INTO lesson_progress (enrollment_id, lesson_id)
    VALUES (9999, 1);
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'ошибка: нельзя сохранить прогресс для несущестаующей записи на курс. Текст ошибки: %', SQLERRM;
END $$;


--UNIQUE
DO $$
BEGIN
    INSERT INTO review (course_id, student_id, rating)
    VALUES (1, 2, 4);
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'ошибка: студент уже оставлял отзыв на этот курс. Текст ошибки: %', SQLERRM;
END $$;


--NOT NULL
DO $$
BEGIN
    INSERT INTO "user" (full_name)
    VALUES ('Пользователь без email');
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'ошибка: email обязателен. Текст ошибки: %', SQLERRM;
END $$;


-- PRIMARY KEY
DO $$
BEGIN
    INSERT INTO lesson (lesson_id, course_id, title, order_num)
    VALUES (1, 1, 'Дубликат урока', 2);
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Ошибка: урок с таким id уже существует. Текст ошибки: %', SQLERRM;
END $$;