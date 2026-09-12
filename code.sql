-- 1. Справочник статусов задач
CREATE TABLE status (
    status_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);

-- 2. Сотрудники
CREATE TABLE employee (
    employee_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE,
    position    VARCHAR(150),
    hire_date   DATE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Проекты
CREATE TABLE project (
    project_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    start_date  DATE,
    end_date    DATE,
    manager_id  INT NOT NULL
        REFERENCES employee(employee_id) ON DELETE RESTRICT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT project_dates_check
        CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

-- 4. Приоритет задачи (перечисляемый тип)
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high', 'critical');

-- 5. Задачи
CREATE TABLE task (
    task_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id  INT NOT NULL
        REFERENCES project(project_id) ON DELETE CASCADE,
    title       VARCHAR(255) NOT NULL,
    description TEXT,
    status_id   INT NOT NULL
        REFERENCES status(status_id) ON DELETE RESTRICT,
    priority    task_priority NOT NULL DEFAULT 'medium',
    deadline    TIMESTAMPTZ,
    created_by  INT
        REFERENCES employee(employee_id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Назначения исполнителей (связь «многие-ко-многим»)
CREATE TABLE assignment (
    task_id     INT NOT NULL
        REFERENCES task(task_id) ON DELETE CASCADE,
    employee_id INT NOT NULL
        REFERENCES employee(employee_id) ON DELETE CASCADE,
    role        VARCHAR(100),
    assigned_by INT
        REFERENCES employee(employee_id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (task_id, employee_id)
);

-- 7. Комментарии к задачам
CREATE TABLE comment (
    comment_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    task_id     INT NOT NULL
        REFERENCES task(task_id) ON DELETE CASCADE,
    employee_id INT
        REFERENCES employee(employee_id) ON DELETE SET NULL,
    body        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. История смены статусов
CREATE TABLE task_status_history (
    task_id        INT NOT NULL
        REFERENCES task(task_id) ON DELETE CASCADE,
    from_status_id INT
        REFERENCES status(status_id) ON DELETE RESTRICT,
    to_status_id   INT NOT NULL
        REFERENCES status(status_id) ON DELETE RESTRICT,
    changed_by     INT
        REFERENCES employee(employee_id) ON DELETE SET NULL,
    changed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason         TEXT,
    PRIMARY KEY (task_id, changed_at)
);

-- Индексы для частых запросов
CREATE INDEX idx_task_project        ON task(project_id);
CREATE INDEX idx_task_status         ON task(status_id);
CREATE INDEX idx_task_deadline       ON task(deadline);
CREATE INDEX idx_assignment_employee ON assignment(employee_id);
CREATE INDEX idx_comment_task        ON comment(task_id);
CREATE INDEX idx_history_task        ON task_status_history(task_id);

-- Начальное наполнение справочника статусов
INSERT INTO status (name, description) VALUES
    ('новая',      'Задача только что создана'),
    ('в работе',   'Исполнитель приступил к выполнению'),
    ('на проверке','Задача ожидает проверки результата'),
    ('завершена',  'Задача выполнена и принята');
