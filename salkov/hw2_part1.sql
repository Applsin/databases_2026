-- Очистка для повторного запуска (воспроизводимость)
DROP TABLE IF EXISTS course_categories CASCADE;
DROP TABLE IF EXISTS categories CASCADE;

-- 1. Таблица категорий курсов
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Промежуточная таблица для связи M:N (Course <-> Category)
CREATE TABLE course_categories (
    course_id INTEGER NOT NULL,
    category_id INTEGER NOT NULL,
    PRIMARY KEY (course_id, category_id),
    CONSTRAINT fk_cc_course FOREIGN KEY (course_id) 
        REFERENCES courses (id) ON DELETE CASCADE,
    CONSTRAINT fk_cc_category FOREIGN KEY (category_id) 
        REFERENCES categories (id) ON DELETE CASCADE
);

-- Индексы для быстрого поиска в обе стороны
CREATE INDEX idx_course_categories_course_id ON course_categories (course_id);
CREATE INDEX idx_course_categories_category_id ON course_categories (category_id);