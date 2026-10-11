-- seminar1_setup.sql
-- Воспроизводимая база для семинара №1.
-- Повторный прогон даёт тот же результат.

SET client_min_messages TO WARNING;

-- шаг 1: удаляем старую схему, если осталась
DROP SCHEMA IF EXISTS seminar1 CASCADE;

-- шаг 2: создаём изолированную схему
CREATE SCHEMA seminar1;
SET search_path TO seminar1;

-- ============================================================
-- Часть А. Сквозной пример: интернет-магазин
-- ============================================================

-- шаг 3: клиенты
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    registered_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_customers_email ON customers(email);

-- шаг 4: товары
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_products_name ON products(name);

-- шаг 5: заказы
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date TIMESTAMP DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'new'
        CHECK (status IN ('new', 'paid', 'shipped', 'delivered', 'cancelled')),
    total_amount DECIMAL(10, 2),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_order_date ON orders(order_date);

-- шаг 6: позиции заказа (связующая таблица)
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    UNIQUE (order_id, product_id)
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- шаг 7: тестовые данные E-Commerce
INSERT INTO customers (first_name, last_name, email, phone, registered_at) VALUES
('Анна', 'Смирнова', 'anna@example.com', '+79001234567', '2024-01-10 09:00:00'),
('Иван', 'Петров', 'ivan@example.com', '+79007654321', '2024-02-15 12:30:00');

INSERT INTO products (name, description, price, stock_quantity, created_at) VALUES
('Беспроводные наушники', 'Bluetooth 5.0', 5990.00, 50, '2024-01-05'),
('Механическая клавиатура', 'RGB-подсветка', 8990.00, 30, '2024-01-07'),
('Игровая мышь', '16000 DPI', 3490.00, 100, '2024-01-08');

INSERT INTO orders (customer_id, order_date, status, total_amount) VALUES
(1, '2024-03-01 10:00:00', 'delivered', 16470.00),
(2, '2024-03-05 14:20:00', 'paid', 5990.00);

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 5990.00),
(1, 2, 1, 8990.00),
(1, 3, 1, 3490.00),
(2, 1, 1, 5990.00);

-- ============================================================
-- Часть Б. Практика: система управления IT-проектами
-- ============================================================

-- шаг 8: проекты
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

-- шаг 9: сотрудники
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

-- шаг 10: задачи
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
CREATE INDEX idx_tasks_status ON tasks(status);

-- шаг 11: история статусов
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

-- шаг 12: теги
CREATE TABLE tags (
    tag_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- шаг 13: связующая таблица M:N
CREATE TABLE task_tags (
    task_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    added_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (task_id, tag_id),
    FOREIGN KEY (task_id) REFERENCES tasks(task_id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(tag_id) ON DELETE CASCADE
);

CREATE INDEX idx_task_tags_tag_id ON task_tags(tag_id);

-- шаг 14: тестовые данные Project Management
INSERT INTO projects (name, start_date, deadline, status, created_at) VALUES
('Корпоративный сайт', '2024-01-15', '2024-06-30', 'active', '2024-01-15 09:00:00'),
('Мобильное приложение', '2024-03-01', '2024-09-15', 'active', '2024-03-01 09:00:00');

INSERT INTO employees (first_name, last_name, email, hire_date, is_active) VALUES
('Иван', 'Иванов', 'ivan@company.com', '2023-01-15', true),
('Петр', 'Петров', 'petr@company.com', '2023-03-20', true),
('Мария', 'Сидорова', 'maria@company.com', '2024-01-10', true);

INSERT INTO tasks (project_id, assignee_id, title, description, status, priority, estimate_hours, created_date) VALUES
(1, 1, 'Разработать макет', 'Главная страница и каталог', 'in_progress', 'high', 40, '2024-01-20'),
(1, 2, 'Настроить сервер', 'Подготовка продакшн-окружения', 'done', 'medium', 8, '2024-01-25'),
(2, 3, 'Дизайн экранов', 'Фигма-макеты для iOS', 'new', 'high', 32, '2024-03-05'),
(2, NULL, 'Интеграция API', 'REST API для мобильного приложения', 'new', 'high', 24, '2024-03-10');

INSERT INTO tags (name) VALUES ('backend'), ('frontend'), ('design');

INSERT INTO task_tags (task_id, tag_id) VALUES
(1, 2),
(1, 3),
(2, 1),
(3, 3);

INSERT INTO task_status_history (task_id, changed_by_employee_id, from_status, to_status, changed_at) VALUES
(1, 1, 'new', 'in_progress', '2024-01-21 10:00:00'),
(2, 2, 'new', 'in_progress', '2024-01-26 09:00:00'),
(2, 2, 'in_progress', 'done', '2024-01-30 16:00:00');

-- шаг 15: финальная проверка
SELECT 'seminar1 schema created' AS status;
