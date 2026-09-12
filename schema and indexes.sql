-- ==========================================
-- Часть 1. Дополнение схемы (две новые таблицы)
-- ==========================================

-- Таблица сущности "Тег"
CREATE TABLE tag (
    tag_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- Связующая таблица для отношения M:N (задачи и теги)
CREATE TABLE task_tag (
    task_id INTEGER REFERENCES task(task_id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tag(tag_id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);

-- ==========================================
-- Индексы для частых запросов
-- ==========================================

-- Поиск задач по проекту и расчет среднего времени
CREATE INDEX idx_task_project_id ON task(project_id);

-- Поиск просроченных задач и фильтрация по статусам
CREATE INDEX idx_task_deadline ON task(deadline);
CREATE INDEX idx_task_status_id ON task(status_id);

-- Поиск активных задач по сотрудникам
CREATE INDEX idx_assignment_employee_id ON assignment(employee_id);
CREATE INDEX idx_assignment_task_id ON assignment(task_id);

-- Поиск истории по конкретной задаче
CREATE INDEX idx_taskhistory_task_id ON taskhistory(task_id);