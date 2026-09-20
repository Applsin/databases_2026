SET search_path TO hw1;

DROP TABLE IF EXISTS "lesson_progress" CASCADE;
DROP TABLE IF EXISTS "payouts" CASCADE;


CREATE TABLE "lesson_progress" (
  "enrollment_id" integer NOT NULL,
  "lesson_id" integer NOT NULL,
  "completed_at" timestamp NOT NULL,
  PRIMARY KEY ("enrollment_id", "lesson_id")
);

CREATE TABLE "payouts" (
  "id" integer PRIMARY KEY,
  "teacher_id" integer NOT NULL,
  "period_start" date NOT NULL,
  "period_end" date NOT NULL,
  "amount" numeric NOT NULL CHECK ("amount" >= 0),
  "status" varchar NOT NULL CHECK ("status" in ('pending', 'paid', 'cancelled')),
  "created_at" timestamp NOT NULL,
  UNIQUE ("teacher_id", "period_start"),
  CHECK ("period_end" > "period_start")
);



ALTER TABLE "lesson_progress" ADD FOREIGN KEY ("enrollment_id") REFERENCES "enrollments" ("id") ON DELETE CASCADE DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "lesson_progress" ADD FOREIGN KEY ("lesson_id") REFERENCES "lessons" ("id") ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "payouts" ADD FOREIGN KEY ("teacher_id") REFERENCES "users" ("id") ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;


DO $$
BEGIN
    INSERT INTO payouts (id, teacher_id, period_start, period_end, amount, status, created_at)
    VALUES (123, 12345, '2026-10-01', '2026-09-01', 100, 'paid', now());
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'Период выплаты задан неверно: дата окончания раньше даты начала. Текст ошибки: %', SQLERRM;
END;
$$;


-- Тестовые данные для демонстраций
INSERT INTO users (id, email, username, role, created_at)
VALUES (1, 'teacher@edu.ru', 'ivanov', 'teacher', now()) ON CONFLICT DO NOTHING;


-- Нарушение UNIQUE
DO $$
BEGIN
    -- корректная выплата преподавателю за сентябрь
    INSERT INTO payouts (id, teacher_id, period_start, period_end, amount, status, created_at)
    VALUES (1, 1, '2026-09-01', '2026-09-30', 5000, 'paid', now());

    -- попытка начислить тому же преподавателю за тот же период повторно
    INSERT INTO payouts (id, teacher_id, period_start, period_end, amount, status, created_at)
    VALUES (2, 1, '2026-09-01', '2026-09-30', 5000, 'paid', now());
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Преподавателю уже начислена выплата за этот период, повторное начисление запрещено. Текст ошибки: %', SQLERRM;
END;
$$;


-- Нарушение NOT NULL
DO $$
BEGIN
    -- попытка начислить выплату, не указав сумму
    INSERT INTO payouts (id, teacher_id, period_start, period_end, amount, status, created_at)
    VALUES (3, 1, '2026-10-01', '2026-10-31', NULL, 'pending', now());
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Нельзя создать выплату без суммы: сумма к перечислению обязательна. Текст ошибки: %', SQLERRM;
END;
$$;


-- Нарушение FOREIGN KEY
DO $$
BEGIN
    -- попытка начислить выплату преподавателю, которого нет в системе
    INSERT INTO payouts (id, teacher_id, period_start, period_end, amount, status, created_at)
    VALUES (4, 999, '2026-11-01', '2026-11-30', 7000, 'pending', now());
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Выплата привязана к несуществующему преподавателю: получатель должен быть зарегистрирован. Текст ошибки: %', SQLERRM;
END;
$$;


-- Тестовые данные для демонстрации каскадных правил
INSERT INTO users (id, email, username, role, created_at)
VALUES (2, 'student@edu.ru', 'petrov', 'student', now()) ON CONFLICT DO NOTHING;
INSERT INTO courses (id, author_id, title, price, created_at)
VALUES (1, 1, 'SQL для аналитиков', 5000, now()) ON CONFLICT DO NOTHING;
INSERT INTO lessons (id, course_id, title, position)
VALUES (1, 1, 'Первый SELECT', 1) ON CONFLICT DO NOTHING;
INSERT INTO enrollments (id, user_id, course_id, enrolled_at, status)
VALUES (1, 2, 1, now(), 'in_progress') ON CONFLICT DO NOTHING;
INSERT INTO lesson_progress (enrollment_id, lesson_id, completed_at)
VALUES (1, 1, now()) ON CONFLICT DO NOTHING;


-- Нарушение ссылочной целостности при удалении (ON DELETE RESTRICT)
DO $$
BEGIN
    -- попытка удалить урок, который уже пройден студентами
    DELETE FROM lessons WHERE id = 1;
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Нельзя удалить урок: он уже пройден, история обучения студентов была бы потеряна. Текст ошибки: %', SQLERRM;
END;
$$;
