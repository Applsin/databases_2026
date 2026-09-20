-- ДЗ №2. Часть 1. Дополнение схемы EdTech
-- Выполняется после физической модели из ДЗ №1.

CREATE TABLE lesson_progress (
    user_id INTEGER NOT NULL,
    lesson_id INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'in_progress'
        CHECK (status IN ('in_progress', 'completed')),
    completed_at TIMESTAMP,

    PRIMARY KEY (user_id, lesson_id),

    CONSTRAINT fk_lesson_progress_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_lesson_progress_lesson
        FOREIGN KEY (lesson_id)
        REFERENCES lessons(lesson_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_lesson_progress_completed_at
        CHECK (
            (status = 'completed' AND completed_at IS NOT NULL)
            OR
            (status = 'in_progress' AND completed_at IS NULL)
        )
);

CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    amount DECIMAL(10, 2) NOT NULL
        CHECK (amount > 0),
    paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'paid'
        CHECK (status IN ('pending', 'paid', 'refunded')),

    CONSTRAINT fk_payments_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_payments_course
        FOREIGN KEY (course_id)
        REFERENCES courses(course_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_payments_user_course_time
        UNIQUE (user_id, course_id, paid_at)
);

CREATE INDEX idx_lesson_progress_user_id
    ON lesson_progress(user_id);

CREATE INDEX idx_lesson_progress_lesson_id
    ON lesson_progress(lesson_id);

CREATE INDEX idx_lesson_progress_user_status
    ON lesson_progress(user_id, status);

CREATE INDEX idx_payments_course_paid_at
    ON payments(course_id, paid_at);

CREATE INDEX idx_payments_user_paid_at
    ON payments(user_id, paid_at);
