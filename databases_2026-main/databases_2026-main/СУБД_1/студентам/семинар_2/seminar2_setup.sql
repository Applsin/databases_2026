-- seminar2_setup.sql
-- Воспроизводимая среда для семинара №2 (DDL, ограничения, нормализация, COPY/JSONB).
-- Повторный прогон даёт тот же результат.

SET client_min_messages TO WARNING;

-- шаг 1: удаляем старую схему, если осталась
DROP SCHEMA IF EXISTS seminar2 CASCADE;

-- шаг 2: создаём изолированную схему
CREATE SCHEMA seminar2;
SET search_path TO seminar2;

-- шаг 3: проекты
CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    deadline DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'on_hold')),
    created_at TIMESTAMP DEFAULT NOW(),
    CHECK (deadline >= start_date)
);

-- шаг 4: сотрудники
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    hire_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CHECK (hire_date <= CURRENT_DATE)
);

CREATE INDEX idx_employees_email ON employees(email);

-- шаг 5: задачи (estimate_hours — исходное имя для упражнения по RENAME COLUMN)
CREATE TABLE tasks (
    task_id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL,
    assignee_id INTEGER,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'new'
        CHECK (status IN ('new', 'in_progress', 'done')),
    priority VARCHAR(10) DEFAULT 'medium'
        CHECK (priority IN ('high', 'medium', 'low')),
    estimate_hours DECIMAL(5, 2) CHECK (estimate_hours > 0),
    created_date DATE DEFAULT CURRENT_DATE,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
    FOREIGN KEY (assignee_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_assignee_id ON tasks(assignee_id);

-- шаг 6: история статусов
CREATE TABLE task_status_history (
    history_id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    changed_by_employee_id INTEGER NOT NULL,
    from_status VARCHAR(20) NOT NULL,
    to_status VARCHAR(20) NOT NULL,
    changed_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (task_id) REFERENCES tasks(task_id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by_employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT
);

CREATE INDEX idx_task_status_history_task_id ON task_status_history(task_id);

-- шаг 7: теги
CREATE TABLE tags (
    tag_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- шаг 8: связующая таблица M:N
CREATE TABLE task_tags (
    task_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    added_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (task_id, tag_id),
    FOREIGN KEY (task_id) REFERENCES tasks(task_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE
);

CREATE INDEX idx_task_tags_tag_id ON task_tags(tag_id);

-- шаг 9: детерминированные тестовые данные (генерация через массивы, без random)
INSERT INTO projects (name, start_date, deadline, status, created_at)
SELECT
    'Проект ' || chr(64 + i),
    DATE '2024-01-01' + (i - 1) * 15,
    DATE '2024-01-01' + (i - 1) * 15 + 180,
    (ARRAY['active', 'active', 'completed'])[i],
    TIMESTAMP '2024-01-01 09:00:00'
FROM generate_series(1, 3) AS i;

INSERT INTO employees (first_name, last_name, email, hire_date, is_active)
SELECT
    (ARRAY['Иван', 'Пётр', 'Мария', 'Алексей', 'Ольга'])[i],
    (ARRAY['Иванов', 'Петров', 'Сидорова', 'Алексеев', 'Ольгина'])[i],
    'employee' || i || '@company.com',
    DATE '2023-01-15' + (i - 1) * 40,
    TRUE
FROM generate_series(1, 5) AS i;

INSERT INTO tasks (project_id, assignee_id, title, description, status, priority, estimate_hours, created_date)
SELECT
    ((i - 1) % 3) + 1,
    CASE WHEN i % 4 = 0 THEN NULL ELSE ((i - 1) % 5) + 1 END,
    'Задача ' || i,
    'Описание задачи ' || i,
    (ARRAY['new', 'in_progress', 'done'])[((i - 1) % 3) + 1],
    (ARRAY['low', 'medium', 'high'])[((i - 1) % 3) + 1],
    (i * 4) + 4,
    DATE '2024-01-20' + i
FROM generate_series(1, 9) AS i;

INSERT INTO tags (name)
VALUES ('backend'), ('frontend'), ('design'), ('devops');

INSERT INTO task_tags (task_id, tag_id)
SELECT t.task_id, ((t.task_id - 1) % 4) + 1
FROM tasks t
WHERE t.task_id <= 6;

INSERT INTO task_status_history (task_id, changed_by_employee_id, from_status, to_status, changed_at)
SELECT
    t.task_id,
    COALESCE(t.assignee_id, 1),
    'new',
    t.status,
    TIMESTAMP '2024-01-21 10:00:00' + t.task_id * INTERVAL '1 hour'
FROM tasks t
WHERE t.status <> 'new';

-- шаг 10: финальная проверка
SELECT 'seminar2 schema created' AS status;
