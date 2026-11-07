--ДЗ №2. Часть 1. Дополнение схемы.
-- Домен: платформа онлайн-образования (EdTech), продолжение ДЗ №1.
DROP TABLE IF EXISTS lesson_progress CASCADE;
DROP TABLE IF EXISTS certificates CASCADE;
DROP TABLE IF EXISTS payouts CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ТАБЛИЦЫ ИЗ ДЗ №1

-- Пользователи: и студенты, и преподаватели
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL
        CHECK (role IN ('student', 'teacher'))
);

-- Курсы, которые создают преподаватели
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    teacher_id INTEGER NOT NULL,
    name_course VARCHAR(200) NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    commission_rate DECIMAL(5, 2) NOT NULL DEFAULT 30.00
        CHECK (commission_rate BETWEEN 0 AND 100),
    FOREIGN KEY (teacher_id) REFERENCES users(user_id) ON DELETE RESTRICT
);

CREATE INDEX idx_courses_teacher_id ON courses(teacher_id);

-- Уроки внутри курса
CREATE TABLE lessons (
    lesson_id SERIAL PRIMARY KEY,
    course_id INTEGER NOT NULL,
    name_lesson VARCHAR(200) NOT NULL,
    lesson_time INTEGER CHECK (lesson_time > 0),
    order_number INTEGER NOT NULL CHECK (order_number > 0),
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    UNIQUE (course_id, order_number)
);

CREATE INDEX idx_lessons_course_id ON lessons(course_id);

-- Запись студента на курс (фиксирует факт и сумму оплаты)
CREATE TABLE enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    enrolled_at TIMESTAMP DEFAULT NOW(),
    amount_paid DECIMAL(10, 2) NOT NULL CHECK (amount_paid >= 0),
    payment_status VARCHAR(20) NOT NULL DEFAULT 'paid'
        CHECK (payment_status IN ('paid', 'refunded')),
    status VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('active', 'completed')),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    UNIQUE (user_id, course_id)
);

CREATE INDEX idx_enrollments_user_id ON enrollments(user_id);
CREATE INDEX idx_enrollments_course_id ON enrollments(course_id);

-- Отзывы студентов о курсах
CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    UNIQUE (user_id, course_id)
);

CREATE INDEX idx_reviews_user_id ON reviews(user_id);
CREATE INDEX idx_reviews_course_id ON reviews(course_id);

-- Выплаты преподавателям за период
CREATE TABLE payouts (
    payout_id SERIAL PRIMARY KEY,
    teacher_id INTEGER NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    payout_status VARCHAR(20) NOT NULL DEFAULT 'pending'
        CHECK (payout_status IN ('pending', 'paid')),
    paid_at TIMESTAMP,
    FOREIGN KEY (teacher_id) REFERENCES users(user_id) ON DELETE RESTRICT,
    CHECK (period_end >= period_start)
);

CREATE INDEX idx_payouts_teacher_id ON payouts(teacher_id);

-- НОВАЯ ТАБЛИЦА №1: lesson_progress
-- Реализует связь M:N между Enrollment и Lesson.
-- Бизнес-требование: ястуденты проходят обучение» — нужно знать,
-- какие уроки студент уже прошёл, а какие ещё нет.

CREATE TABLE lesson_progress (
    enrollment_id INTEGER NOT NULL,
    lesson_id INTEGER NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMP,
    watched_seconds INTEGER NOT NULL DEFAULT 0 
    CHECK (watched_seconds >= 0),
    PRIMARY KEY (enrollment_id, lesson_id),
    FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id) ON DELETE CASCADE,
    FOREIGN KEY (lesson_id) REFERENCES lessons(lesson_id) ON DELETE CASCADE,
    CHECK (
        (is_completed = TRUE AND completed_at IS NOT NULL)
        OR
        (is_completed = FALSE AND completed_at IS NULL)
    )
);

CREATE INDEX idx_lesson_progress_lesson_id ON lesson_progress(lesson_id);


CREATE INDEX idx_lesson_progress_completed ON lesson_progress(enrollment_id)
    WHERE is_completed = TRUE;


-- НОВАЯ ТАБЛИЦА №2: certificates
-- Бизнес-требование: студент, прошедший курс до конца, получает сертификат.
-- Связь 1:1 с enrollments (один сертификат на одну запись на курс).

CREATE TABLE certificates (
    certificate_id SERIAL PRIMARY KEY,
    enrollment_id INTEGER NOT NULL UNIQUE,
    certificate_number VARCHAR(50) NOT NULL UNIQUE,
    issued_at TIMESTAMP NOT NULL DEFAULT NOW(),
    final_score INTEGER CHECK (final_score BETWEEN 0 AND 100),
    FOREIGN KEY (enrollment_id) REFERENCES enrollments(enrollment_id) ON DELETE CASCADE
);


CREATE INDEX idx_certificates_issued_at ON certificates(issued_at);


-- Тестовые данные

INSERT INTO users (name, email, password, role) VALUES
    ('Иван Петров', 'teacher1@edu.ru', 'hash1', 'teacher'),
    ('Мария Сидорова', 'teacher2@edu.ru', 'hash2', 'teacher'),
    ('Алексей Смирнов', 'student1@edu.ru', 'hash3', 'student'),
    ('Ольга Кузнецова', 'student2@edu.ru', 'hash4', 'student');

INSERT INTO courses (teacher_id, name_course, price, commission_rate) VALUES
    (1, 'Основы SQL', 5000.00, 30.00),
    (1, 'PostgreSQL для аналитиков', 8000.00, 25.00),
    (2, 'Python с нуля', 6500.00, 30.00);

INSERT INTO lessons (course_id, name_lesson, lesson_time, order_number) VALUES
    (1, 'Что такое база данных', 30, 1),
    (1, 'Первый SELECT', 45, 2),
    (1, 'Фильтрация WHERE', 40, 3),
    (2, 'Установка PostgreSQL', 25, 1),
    (2, 'Индексы и планы запросов', 60, 2),
    (3, 'Переменные и типы', 35, 1);

INSERT INTO enrollments (user_id, course_id, amount_paid, payment_status, status) VALUES
    (3, 1, 5000.00, 'paid', 'completed'),
    (3, 2, 8000.00, 'paid', 'active'),
    (4, 1, 5000.00, 'paid', 'active');

INSERT INTO reviews (user_id, course_id, rating, comment) VALUES
    (3, 1, 5, 'Отличный курс, всё понятно объясняют'),
    (4, 1, 4, 'Хорошо, но хотелось бы больше практики');

INSERT INTO payouts (teacher_id, period_start, period_end, amount, payout_status, paid_at) VALUES
    (1, '2026-08-01', '2026-08-31', 9500.00, 'paid', '2026-09-05 12:00:00'),
    (2, '2026-08-01', '2026-08-31', 0.00, 'pending', NULL);

INSERT INTO lesson_progress (enrollment_id, lesson_id, is_completed, completed_at, watched_seconds) VALUES
    (1, 1, TRUE,  '2026-08-10 14:00:00', 1800),
    (1, 2, TRUE,  '2026-08-11 15:30:00', 2700),
    (1, 3, TRUE,  '2026-08-12 16:00:00', 2400),
    (2, 4, TRUE,  '2026-08-20 10:00:00', 1500),
    (2, 5, FALSE, NULL, 600),
    (3, 1, TRUE,  '2026-09-01 09:00:00', 1800),
    (3, 2, FALSE, NULL, 300);

INSERT INTO certificates (enrollment_id, certificate_number, final_score) VALUES
    (1, 'CERT-2026-000001', 92);

SELECT 'Схема ДЗ №2 создана' AS status;
