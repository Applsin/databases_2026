# ДЗ №1. От бизнес-требований к физической модели

Вариант №3. Управление проектами (Project Management)

Выполнила: Катыженкова Софья Евгеньевна
Группа: ДЭ15-25

## 1. Концептуальная модель

Взяла шесть сущностей. Проект и сотрудник — сильные, они существуют сами по себе. Задача, комментарий и история статусов — слабые, без родителя они бессмысленны. Тег — тоже сильный, он независим.

Связи получились такие:

- Проект — Задача: один проект, ноль или много задач. Без проекта задачи быть не может, поэтому это идентифицирующая связь и FK с каскадом.
- Сотрудник — Задача: исполнитель либо есть, либо его ещё не назначили. Значит, ноль или один к нулю или многим, связь неидентифицирующая, FK допускает NULL.
- Задача — Комментарий: у задачи может быть много комментариев или ни одного. Комментарий без задачи не существует — идентифицирующая.
- Сотрудник — Комментарий: один сотрудник, много написанных комментариев. Связь неидентифицирующая, комментарий имеет собственный PK.
- Задача — Тег: тут многие-ко-многим. У одной задачи много тегов, и один тег висит на многих задачах. В реляционной модели напрямую так нельзя, поэтому делаю связующую таблицу.
- Задача — История статусов: одна задача, много записей об изменениях. Это требование про аудит, поэтому вынесла в отдельную сущность.
- Сотрудник — История статусов: один сотрудник, много записей. Нужно, чтобы понимать, кто именно менял статус.

Как бизнес-требования повлияли на модель:
- Задача не может существовать без проекта — поэтому project_id NOT NULL и ON DELETE CASCADE.
- Исполнитель может быть не назначен — поэтому assignee_id допускает NULL и ON DELETE SET NULL.
- Аудит изменений статуса — вынесла в отдельную таблицу task_status_history с полями from_status, to_status, changed_at, changed_by.
- Комментарии к задачам — отдельная таблица comments, привязанная к задаче.

## 2. Логическая модель

Таблицы и их атрибуты:

projects: project_id (PK), name (UNIQUE, NOT NULL), start_date (NOT NULL), deadline (NOT NULL), status (NOT NULL, CHECK: active/completed/on_hold), created_at.

employees: employee_id (PK), first_name (NOT NULL), last_name (NOT NULL), email (UNIQUE, NOT NULL), hire_date (NOT NULL), is_active (NOT NULL, DEFAULT TRUE).

tasks: task_id (PK), project_id (FK на projects, NOT NULL), assignee_id (FK на employees, может быть NULL), title (NOT NULL), description, status (NOT NULL, CHECK: new/in_progress/done), priority (NOT NULL, CHECK: high/medium/low), estimate_hours, created_date.

comments: comment_id (PK), task_id (FK на tasks, NOT NULL), author_id (FK на employees, NOT NULL), body (NOT NULL), created_at.

tags: tag_id (PK), name (UNIQUE, NOT NULL).

task_tags: task_id (FK на tasks, часть составного PK), tag_id (FK на tags, часть составного PK), added_at. Первичный ключ составной из task_id и tag_id.

task_status_history: history_id (PK), task_id (FK на tasks, NOT NULL), changed_by_employee_id (FK на employees, NOT NULL), from_status (NOT NULL), to_status (NOT NULL), changed_at.

Кардинальность в нотации вороньей лапки:

- projects ||--o{ tasks : содержит
- employees |o--o{ tasks : исполняет
- employees ||--o{ comments : пишет
- employees ||--o{ task_status_history : меняет статус
- tasks ||--o{ comments : имеет
- tasks }o--o{ tags : помечена
- tasks ||--o{ task_status_history : фиксирует

Идентифицирующие связи: проект-задача, задача-комментарий, задача-история статусов. Дочерняя запись не имеет смысла без родителя.

Неидентифицирующие: сотрудник-задача (исполнитель опционален), сотрудник-комментарий (комментарий имеет свой PK), сотрудник-история статусов (запись имеет свой PK), задача-тег (M:N через связующую таблицу).

## 3. Физическая модель (PostgreSQL)

Скрипт воспроизводимый: работаю в отдельной схеме hw1, при повторном запуске старая схема удаляется.

DROP SCHEMA IF EXISTS hw1 CASCADE;
CREATE SCHEMA hw1;
SET search_path TO hw1;

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

## 4. Частые запросы (описание на русском)

1. Показать все задачи конкретного проекта с их статусами и исполнителями. Нужно соединить tasks с employees по assignee_id и отфильтровать по project_id.

2. Найти все просроченные задачи, у которых deadline меньше текущей даты, а статус не done. Соединяю tasks с projects, смотрю на deadline проекта и статус задачи.

3. Вывести список сотрудников с количеством назначенных им активных задач. LEFT JOIN employees с tasks по assignee_id, группировка по сотруднику, фильтр по статусу задачи.

4. Показать историю изменения статуса задачи: кто, когда и с какого на какой статус поменял. Выборка из task_status_history с соединением на employees для имени автора.

5. Рассчитать среднее время выполнения задач по каждому проекту за квартал. Соединяю task_status_history с tasks и projects, считаю разницу между временем перехода в in_progress и в done, агрегирую по проекту.
