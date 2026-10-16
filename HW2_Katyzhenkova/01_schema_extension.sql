-- ============================================================
-- ДЗ №2. Часть 1. Дополнение схемы ДЗ №1 двумя новыми таблицами
-- Домен: Project Management
-- ============================================================

DROP SCHEMA IF EXISTS hw2 CASCADE;
CREATE SCHEMA hw2;
SET search_path TO hw2;

-- ---- Таблицы из ДЗ №1 (чтобы скрипт был самодостаточным) ----

CREATE TABLE projects (
    project_id   SERIAL PRIMARY KEY,
    name         VARCHAR(100) NOT NULL UNIQUE,
    start_date   DATE NOT NULL,
    deadline     DATE NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'on_hold')),
    created_at   TIMESTAMP DEFAULT NOW(),
    CHECK (deadline >= start_date)
);

CREATE TABLE employees (
    employee_id  SERIAL PRIMARY KEY,
    first_name   VARCHAR(50) NOT NULL,
    last_name    VARCHAR(50) NOT NULL,
    email        VARCHAR(100) NOT NULL UNIQUE,
    hire_date    DATE NOT NULL,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CHECK (hire_date <= CURRENT_DATE)
);

CREATE TABLE tasks (
    task_id        SERIAL PRIMARY KEY,
    project_id     INTEGER NOT NULL,
    assignee_id    INTEGER,
    title          VARCHAR(200) NOT NULL,
    description    TEXT,
    status         VARCHAR(20) NOT NULL DEFAULT 'new'
        CHECK (status IN ('new', 'in_progress', 'done')),
    priority       VARCHAR(10) NOT NULL DEFAULT 'medium'
        CHECK (priority IN ('high', 'medium', 'low')),
    estimate_hours DECIMAL(5,2) CHECK (estimate_hours > 0),
    created_date   DATE DEFAULT CURRENT_DATE,
    FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,
    FOREIGN KEY (assignee_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

CREATE INDEX idx_tasks_project_id  ON tasks(project_id);
CREATE INDEX idx_tasks_assignee_id ON tasks(assignee_id);
CREATE INDEX idx_tasks_status      ON tasks(status);

CREATE TABLE comments (
    comment_id  SERIAL PRIMARY KEY,
    task_id     INTEGER NOT NULL,
    author_id   INTEGER NOT NULL,
    body        TEXT NOT NULL,
    created_at  TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (task_id)   REFERENCES tasks(task_id)         ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES employees(employee_id) ON DELETE RESTRICT
);

CREATE INDEX idx_comments_task_id   ON comments(task_id);
CREATE INDEX idx_comments_author_id ON comments(author_id);

CREATE TABLE tags (
    tag_id  SERIAL PRIMARY KEY,
    name    VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE task_tags (
    task_id   INTEGER NOT NULL,
    tag_id    INTEGER NOT NULL,
    added_at  TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (task_id, tag_id),
    FOREIGN KEY (task_id) REFERENCES tasks(task_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)  REFERENCES tags(tag_id)   ON DELETE CASCADE
);

CREATE INDEX idx_task_tags_tag_id ON task_tags(tag_id);

CREATE TABLE task_status_history (
    history_id              SERIAL PRIMARY KEY,
    task_id                 INTEGER NOT NULL,
    changed_by_employee_id  INTEGER NOT NULL,
    from_status             VARCHAR(20) NOT NULL
        CHECK (from_status IN ('new', 'in_progress', 'done')),
    to_status               VARCHAR(20) NOT NULL
        CHECK (to_status IN ('new', 'in_progress', 'done')),
    changed_at              TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (task_id)                REFERENCES tasks(task_id)         ON DELETE CASCADE,
    FOREIGN KEY (changed_by_employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT
);

CREATE INDEX idx_task_status_history_task_id ON task_status_history(task_id);

-- ---- Две новые таблицы ----

-- 1. Реестр затраченного времени по задачам.
--    Нужен для запроса "среднее время выполнения задач по проектам":
--    по каждой задаче видно, сколько часов реально потратил сотрудник.
CREATE TABLE time_entries (
    entry_id      SERIAL PRIMARY KEY,
    task_id       INTEGER NOT NULL,
    employee_id   INTEGER NOT NULL,
    hours_spent   DECIMAL(5,2) NOT NULL CHECK (hours_spent > 0 AND hours_spent <= 24),
    worked_on     DATE NOT NULL DEFAULT CURRENT_DATE,
    comment_text  TEXT,
    created_at    TIMESTAMP DEFAULT NOW(),
    CHECK (worked_on <= CURRENT_DATE),
    FOREIGN KEY (task_id)     REFERENCES tasks(task_id)         ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE RESTRICT
);

-- Индексы под частые запросы:
-- "все трудозатраты по задаче", "трудозатраты сотрудника", "за период".
CREATE INDEX idx_time_entries_task_id     ON time_entries(task_id);
CREATE INDEX idx_time_entries_employee_id ON time_entries(employee_id);
CREATE INDEX idx_time_entries_worked_on   ON time_entries(worked_on);

-- 2. Участники проекта.
--    В ДЗ №1 у проекта не было явного состава — была только привязка задач.
--    Теперь фиксируем, кто входит в проект и в какой роли.
CREATE TABLE project_members (
    project_id       INTEGER NOT NULL,
    employee_id      INTEGER NOT NULL,
    role_in_project  VARCHAR(30) NOT NULL DEFAULT 'member'
        CHECK (role_in_project IN ('manager', 'member', 'observer')),
    joined_at        TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (project_id, employee_id),
    FOREIGN KEY (project_id)  REFERENCES projects(project_id)   ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE
);

CREATE INDEX idx_project_members_employee_id ON project_members(employee_id);
CREATE INDEX idx_project_members_role        ON project_members(role_in_project);

-- ---- Тестовые данные ----

INSERT INTO projects (name, start_date, deadline, status) VALUES
('Корпоративный сайт', '2024-01-15', '2024-06-30', 'active'),
('Мобильное приложение', '2024-03-01', '2024-09-15', 'active');

INSERT INTO employees (first_name, last_name, email, hire_date) VALUES
('Иван', 'Иванов', 'ivan@company.com', '2023-01-15'),
('Петр', 'Петров', 'petr@company.com', '2023-03-20'),
('Мария', 'Сидорова', 'maria@company.com', '2024-01-10');

INSERT INTO tasks (project_id, assignee_id, title, status, priority, estimate_hours) VALUES
(1, 1, 'Разработать макет', 'in_progress', 'high', 40),
(1, 2, 'Настроить сервер', 'done', 'medium', 8),
(2, 3, 'Дизайн экранов', 'new', 'high', 32);

INSERT INTO project_members (project_id, employee_id, role_in_project) VALUES
(1, 1, 'manager'),
(1, 2, 'member'),
(2, 3, 'manager');

INSERT INTO time_entries (task_id, employee_id, hours_spent, worked_on) VALUES
(1, 1, 6.5, '2024-01-22'),
(1, 1, 4.0, '2024-01-23'),
(2, 2, 8.0, '2024-01-26'),
(3, 3, 3.5, '2024-03-06');

SELECT 'hw2 schema extended' AS status;
