CREATE TABLE certificates (
    certificate_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    course_id INTEGER NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    certificate_code VARCHAR(50) NOT NULL UNIQUE,
    grade DECIMAL(5, 2) CHECK (grade >= 0 AND grade <= 100),
    UNIQUE (user_id, course_id)
);
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    course_id INTEGER NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'pending', 'refunded')),
    transaction_id VARCHAR(100) UNIQUE
);
--я выбрал сертификат и оплату потому что сертефикат
--добовляется после прохождения обучения,
--а оплата потому что платформа продаёт курсы