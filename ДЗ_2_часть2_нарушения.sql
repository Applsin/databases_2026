-- ДЗ №2. Часть 2. Демонстрация нарушений ограничений целостности.
-- Запускать ПОСЛЕ dz2_part1_schema.sql.
-- Каждый блок намеренно выполняет ошибочную операцию, перехватывает ошибку
-- и выводит понятное пользователю сообщение + технический текст ошибки.


-- 1. Нарушение CHECK
-- Ограничение: reviews.rating CHECK (rating BETWEEN 1 AND 5)
-- Бизнес-правило: оценка курса выставляется по шкале от 1 до 5.

DO $$
BEGIN
    INSERT INTO reviews (user_id, course_id, rating, comment)
    VALUES (4, 3, 10, 'Ставлю 10 из 5!');

    RAISE NOTICE '1. CHECK: ошибки не произошло — ограничение не сработало!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '1. CHECK — Нельзя сохранить отзыв: оценка курса должна быть от 1 до 5 баллов. Технический текст: %', SQLERRM;
END;
$$;


-- 2. Нарушение FOREIGN KEY
-- Ограничение: lessons.course_id REFERENCES courses(course_id)
-- Бизнес-правило: урок не может существовать сам по себе, он всегда часть курса.

DO $$
BEGIN
    INSERT INTO lessons (course_id, name_lesson, lesson_time, order_number)
    VALUES (999, 'Урок из несуществующего курса', 30, 1);

    RAISE NOTICE '2. FOREIGN KEY: ошибки не произошло — ограничение не сработало!';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '2. FOREIGN KEY — Нельзя добавить урок: курс, к которому его пытаются привязать, не существует. Технический текст: %', SQLERRM;
END;
$$;


-- 3. Нарушение UNIQUE
-- Ограничение: enrollments UNIQUE (user_id, course_id)
-- Бизнес-правило: студент не может купить один и тот же курс дважды.

DO $$
BEGIN
    INSERT INTO enrollments (user_id, course_id, amount_paid, payment_status, status)
    VALUES (3, 1, 5000.00, 'paid', 'active');

    RAISE NOTICE '3. UNIQUE: ошибки не произошло — ограничение не сработало!';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE '3. UNIQUE — Нельзя записать студента на курс: он уже записан на этот курс ранее. Технический текст: %', SQLERRM;
END;
$$;


-- 4. Нарушение NOT NULL
-- Ограничение: users.email NOT NULL
-- Бизнес-правило: без email пользователь не сможет войти и получать уведомления.

DO $$
BEGIN
    INSERT INTO users (name, email, password, role)
    VALUES ('Пользователь без почты', NULL, 'hash999', 'student');

    RAISE NOTICE '4. NOT NULL: ошибки не произошло — ограничение не сработало!';
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE '4. NOT NULL — Нельзя зарегистрировать пользователя без email: почта обязательна для входа в систему. Технический текст: %', SQLERRM;
END;
$$;


-- 5. Сложный CHECK на новой таблице lesson_progress
-- Ограничение: CHECK (is_completed = TRUE AND completed_at IS NOT NULL
--                     OR is_completed = FALSE AND completed_at IS NULL)
-- Бизнес-правило: у пройденного урока обязана быть дата прохождения,
-- а у непройденного её быть не может (иначе прогресс студента противоречив).

DO $$
BEGIN
    INSERT INTO lesson_progress (enrollment_id, lesson_id, is_completed, completed_at, watched_seconds)
    VALUES (2, 6, TRUE, NULL, 900);

    RAISE NOTICE '5. Сложный CHECK: ошибки не произошло — ограничение не сработало!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '5. Сложный CHECK — Нельзя отметить урок пройденным без даты прохождения: прогресс студента стал бы противоречивым. Технический текст: %', SQLERRM;
END;
$$;



-- Показываем, что при удалении записи на курс каскадно удаляются
-- и прогресс по урокам, и сертификат — дочерние данные без родителя не нужны.
DO $$
DECLARE
    progress_before INTEGER;
    progress_after INTEGER;
    cert_before INTEGER;
    cert_after INTEGER;
BEGIN
    SELECT COUNT(*) INTO progress_before FROM lesson_progress WHERE enrollment_id = 1;
    SELECT COUNT(*) INTO cert_before FROM certificates WHERE enrollment_id = 1;

    DELETE FROM enrollments WHERE enrollment_id = 1;

    SELECT COUNT(*) INTO progress_after FROM lesson_progress WHERE enrollment_id = 1;
    SELECT COUNT(*) INTO cert_after FROM certificates WHERE enrollment_id = 1;

    RAISE NOTICE 'CASCADE — Удалена 1 запись на курс. Прогресс по урокам: было %, стало %. Сертификатов: было %, стало %.',
        progress_before, progress_after, cert_before, cert_after;

    
    RAISE EXCEPTION 'откат демонстрации';
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE 'CASCADE — Демонстрационное удаление отменено, данные восстановлены.';
END;
$$;


-- Демонстрация ON DELETE RESTRICT 
-- Ограничение: courses.teacher_id REFERENCES users ON DELETE RESTRICT
-- Бизнес-правило: нельзя удалить преподавателя, пока у него есть курсы —
-- иначе пропадёт история продаж и выплат.

DO $$
BEGIN
    DELETE FROM users WHERE user_id = 1;

    RAISE NOTICE 'RESTRICT: ошибки не произошло — ограничение не сработало!';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'RESTRICT — Нельзя удалить преподавателя: у него есть созданные курсы, их история продаж была бы потеряна. Технический текст: %', SQLERRM;
END;
$$;


-- Все демонстрации завершены.

