-- ============================================
-- HW2. Часть 1. Две новые таблицы
-- ============================================

-- ============================================
-- LESSON PROGRESS
-- Прогресс студента по каждому уроку.
-- Закрывает запрос: "история обучения студента".
-- ============================================
CREATE TABLE LessonProgress (
    progress_id   SERIAL PRIMARY KEY,
    student_id    INTEGER   NOT NULL,
    lesson_id     INTEGER   NOT NULL,
    is_passed     BOOLEAN   NOT NULL DEFAULT FALSE,
    attempt       INTEGER   NOT NULL DEFAULT 1 CHECK (attempt > 0),
    passed_at     TIMESTAMP,
    updated_at    TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_lp_student
        FOREIGN KEY (student_id) REFERENCES "User"(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_lp_lesson
        FOREIGN KEY (lesson_id) REFERENCES Lesson(lesson_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_lp_student_lesson UNIQUE (student_id, lesson_id)
);

CREATE INDEX idx_lp_student ON LessonProgress(student_id);
CREATE INDEX idx_lp_lesson  ON LessonProgress(lesson_id);

-- ============================================
-- PAYMENT
-- Платежи студентов за курсы.
-- Закрывает запрос: "рассчитать выплаты преподавателю".
-- ============================================
CREATE TABLE Payment (
    payment_id    SERIAL PRIMARY KEY,
    student_id    INTEGER       NOT NULL,
    course_id     INTEGER       NOT NULL,
    amount        DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    status        VARCHAR(20)   NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'paid', 'refunded')),
    paid_at       TIMESTAMP,
    created_at    TIMESTAMP     NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_payment_student
        FOREIGN KEY (student_id) REFERENCES "User"(user_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_payment_course
        FOREIGN KEY (course_id) REFERENCES Course(course_id)
        ON DELETE RESTRICT
);

CREATE INDEX idx_payment_student ON Payment(student_id);
CREATE INDEX idx_payment_course  ON Payment(course_id);
CREATE INDEX idx_payment_status  ON Payment(status);