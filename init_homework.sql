-- Удаляем таблицы, если они существуют 
DROP TABLE IF EXISTS taskhistory CASCADE;
DROP TABLE IF EXISTS comment CASCADE;
DROP TABLE IF EXISTS assignment CASCADE;
DROP TABLE IF EXISTS task CASCADE;
DROP TABLE IF EXISTS project CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS status CASCADE;

-- Таблица сотрудников
CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    position VARCHAR(100),
    department VARCHAR(100), 
    CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Таблица проектов
CREATE TABLE project (
    project_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    start_date DATE, 
    end_date DATE,   
    manager_id INTEGER REFERENCES employee(employee_id) ON DELETE SET NULL,
    CHECK (end_date IS NULL OR end_date >= start_date)
);

-- Таблица статусов
CREATE TABLE status (
    status_id SERIAL PRIMARY KEY,
    status_name VARCHAR(100) NOT NULL UNIQUE,
    is_closed BOOLEAN DEFAULT FALSE
);

-- Таблица задач (переименована в task для единообразия)
CREATE TABLE task (
    task_id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL REFERENCES project(project_id) ON DELETE CASCADE,
    parent_task_id INTEGER REFERENCES task(task_id) ON DELETE CASCADE,
    status_id INTEGER NOT NULL REFERENCES status(status_id),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority VARCHAR(20) DEFAULT 'medium'
        CHECK (priority IN ('high', 'medium', 'low')),
    deadline DATE,
    created_at DATE DEFAULT CURRENT_DATE,
    created_by INTEGER NOT NULL REFERENCES employee(employee_id)
);

-- Таблица назначений (исправлено название на assignment)
CREATE TABLE assignment (
    assignment_id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES task(task_id) ON DELETE CASCADE,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
    assigned_date DATE DEFAULT CURRENT_DATE
);

-- Таблица комментариев
CREATE TABLE comment (
    comment_id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES task(task_id) ON DELETE CASCADE,
    employee_id INTEGER NOT NULL REFERENCES employee(employee_id),
    comment_text TEXT NOT NULL,
    created_at DATE DEFAULT CURRENT_DATE
);

-- Таблица истории изменений задачи
CREATE TABLE taskhistory (
    taskhistory_id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES task(task_id) ON DELETE CASCADE,
    changed_by INTEGER NOT NULL REFERENCES employee(employee_id),
    old_status_id INTEGER REFERENCES status(status_id),
    new_status_id INTEGER NOT NULL REFERENCES status(status_id),
    changed_at DATE DEFAULT CURRENT_DATE,
    changed_why TEXT
);

INSERT INTO status (status_name, is_closed) VALUES
    ('New', FALSE),
    ('In work', FALSE),
    ('On check', FALSE),
    ('Ended', TRUE)
ON CONFLICT (status_name) DO NOTHING;