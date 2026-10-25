-- ============================================================
-- ДЗ №2. Часть 2. Демонстрация нарушений ограничений
-- 5 блоков DO $$ ... EXCEPTION ... END $$.
-- Каждый блок перехватывает ошибку и выводит понятное сообщение
-- + технический текст SQLERRM.
-- ============================================================

SET search_path TO hw2;

-- 1. Нарушение CHECK: отрицательное количество часов.
DO $$
BEGIN
    INSERT INTO time_entries (task_id, employee_id, hours_spent, worked_on)
    VALUES (1, 1, -3, CURRENT_DATE);
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'Ошибка: количество затраченных часов должно быть положительным и не больше 24. СУБД: %', SQLERRM;
END;
$$;

-- 2. Нарушение FOREIGN KEY: трудозатраты по несуществующей задаче.
DO $$
BEGIN
    INSERT INTO time_entries (task_id, employee_id, hours_spent, worked_on)
    VALUES (999, 1, 4, CURRENT_DATE);
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Ошибка: нельзя записать трудозатраты по несуществующей задаче. СУБД: %', SQLERRM;
END;
$$;

-- 3. Нарушение UNIQUE: попытка вставить сотрудника с уже существующим email.
DO $$
BEGIN
    INSERT INTO employees (first_name, last_name, email, hire_date)
    VALUES ('Дубль', 'Дублёв', 'ivan@company.com', CURRENT_DATE);
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: сотрудник с таким email уже зарегистрирован. СУБД: %', SQLERRM;
END;
$$;

-- 4. Нарушение NOT NULL: комментарий без текста.
DO $$
BEGIN
    INSERT INTO comments (task_id, author_id, body)
    VALUES (1, 1, NULL);
EXCEPTION
    WHEN not_null_violation THEN
        RAISE NOTICE 'Ошибка: комментарий не может быть пустым, текст обязателен. СУБД: %', SQLERRM;
END;
$$;

-- 5. Другое: нарушение PRIMARY KEY (составной) в project_members.
--    Тот же сотрудник уже добавлен в этот проект.
DO $$
BEGIN
    INSERT INTO project_members (project_id, employee_id, role_in_project)
    VALUES (1, 1, 'member');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Ошибка: сотрудник уже состоит в этом проекте, повторное добавление запрещено. СУБД: %', SQLERRM;
END;
$$;

SELECT 'all demonstrations completed' AS status;
