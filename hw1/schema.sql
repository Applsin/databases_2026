-- Удаляем старые таблицы для воспроизводимости
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 2. Таблица Пользователей (Студенты и Преподаватели)
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    password VARCHAR(255) NOT NULL, 
    email VARCHAR(100) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL, 
    last_name VARCHAR(50) NOT NULL
);

-- 3. Таблица Курсов
CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    teacher_id INTEGER NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) CHECK (price >= 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_course_teacher FOREIGN KEY (teacher_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- 4. Таблица Уроков
CREATE TABLE lessons (
    lesson_id SERIAL PRIMARY KEY,
    course_id INTEGER NOT NULL,
    title VARCHAR(150) NOT NULL,
    content TEXT,
    CONSTRAINT fk_lesson_course FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE
);

-- 5. Таблица Записей на курсы 
CREATE TABLE enrollments (
    enrollment_id SERIAL PRIMARY KEY, 
    student_id INTEGER NOT NULL,      
    course_id INTEGER NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    CONSTRAINT fk_enrollment_student FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_enrollment_course FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE
);

-- 6. Таблица Отзывов
CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL, 
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5), 
    comment TEXT,
    CONSTRAINT fk_review_student FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_review_course FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    CONSTRAINT unique_student_review UNIQUE (student_id, course_id) -- один студент - один отзыв на курс
);

-- 7. Индексы на внешние ключи
CREATE INDEX idx_courses_teacher ON courses(teacher_id);
CREATE INDEX idx_lessons_course ON lessons(course_id);
CREATE INDEX idx_enrollments_student ON enrollments(student_id);
CREATE INDEX idx_enrollments_course ON enrollments(course_id);
CREATE INDEX idx_reviews_student ON reviews(student_id);
CREATE INDEX idx_reviews_course ON reviews(course_id);



--8 таблтца платежей
CREATE TABLE payments (
    payments_id SERIAL PRIMARY KEY,
    student_id INTEGER NUT NULL,
    course_id INTEGER NUT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount>=0),
    payment_date TIMESTAAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN('pending', 'completed', 'failed')),
    CONSTRAINT fk_payment_student FOREIGN KEY (student_id) REFERENCES users(use_id) ON DELETE RESTRICT
    CONSTRAINT fk_payment_course FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE RESTRICT
);
CREATE INDEX idx_payments_course_date ON payments(course_id, payment_date);
