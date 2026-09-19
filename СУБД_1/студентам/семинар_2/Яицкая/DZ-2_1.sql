DROP TABLE IF EXISTS course_prerequisite CASCADE;
DROP TABLE IF EXISTS lesson_progress CASCADE;
DROP TABLE IF EXISTS payment CASCADE;
DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS enrollment CASCADE;
DROP TABLE IF EXISTS lesson CASCADE;
DROP TABLE IF EXISTS course CASCADE;
DROP TABLE IF EXISTS admin CASCADE;
DROP TABLE IF EXISTS student CASCADE;
DROP TABLE IF EXISTS instructor CASCADE;
DROP TABLE IF EXISTS "user" CASCADE;

CREATE TABLE "user" (
    user_id     SERIAL PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    full_name   VARCHAR(100) NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE student (
    student_id  INTEGER PRIMARY KEY,
    balance     DECIMAL(10, 2) NOT NULL DEFAULT 0
        CHECK (balance >= 0),
    FOREIGN KEY (student_id)
        REFERENCES "user"(user_id)
        ON DELETE CASCADE
);

CREATE TABLE instructor (
    instructor_id  INTEGER PRIMARY KEY,
    payout_details VARCHAR(255),
    FOREIGN KEY (instructor_id)
        REFERENCES "user"(user_id)
        ON DELETE CASCADE
);

CREATE TABLE admin (
    admin_id     INTEGER PRIMARY KEY,
    permissions  VARCHAR(100),
    FOREIGN KEY (admin_id)
        REFERENCES "user"(user_id)
        ON DELETE CASCADE
);

CREATE TABLE course (
    course_id          SERIAL PRIMARY KEY,
    title              VARCHAR(200) NOT NULL,
    description        TEXT,
    price              DECIMAL(10, 2) NOT NULL
        CHECK (price >= 0),
    instructor_share   DECIMAL(5, 2) NOT NULL DEFAULT 0.70
        CHECK (instructor_share BETWEEN 0 AND 1),
    instructor_id      INTEGER NOT NULL,
    created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (instructor_id)
        REFERENCES instructor(instructor_id)
);

CREATE TABLE lesson (
    lesson_id     SERIAL PRIMARY KEY,
    course_id     INTEGER NOT NULL,
    title         VARCHAR(200) NOT NULL,
    order_num     INTEGER NOT NULL
        CHECK (order_num > 0),
    duration_min  INTEGER
        CHECK (duration_min > 0),
    FOREIGN KEY (course_id)
        REFERENCES course(course_id)
        ON DELETE CASCADE,
    UNIQUE (course_id, order_num)
);

CREATE TABLE enrollment (
    enrollment_id  SERIAL PRIMARY KEY,
    course_id      INTEGER NOT NULL,
    student_id     INTEGER NOT NULL,
    enrolled_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at   TIMESTAMP,
    progress       INTEGER NOT NULL DEFAULT 0
        CHECK (progress BETWEEN 0 AND 100),
    FOREIGN KEY (course_id)
        REFERENCES course(course_id)
        ON DELETE CASCADE,
    FOREIGN KEY (student_id)
        REFERENCES student(student_id)
        ON DELETE CASCADE,
    UNIQUE (student_id, course_id)
);

CREATE TABLE review (
    review_id   SERIAL PRIMARY KEY,
    course_id   INTEGER NOT NULL,
    student_id  INTEGER NOT NULL,
    rating      INTEGER NOT NULL
        CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (course_id)
        REFERENCES course(course_id)
        ON DELETE CASCADE,
    FOREIGN KEY (student_id)
        REFERENCES student(student_id)
        ON DELETE CASCADE,
    UNIQUE (student_id, course_id)
);

CREATE TABLE payment (
    payment_id     SERIAL PRIMARY KEY,
    enrollment_id  INTEGER NOT NULL,
    amount         DECIMAL(10, 2) NOT NULL
        CHECK (amount >= 0),
    paid_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status         VARCHAR(20) NOT NULL
        CHECK (status IN ('pending', 'paid', 'refunded')),
    FOREIGN KEY (enrollment_id)
        REFERENCES enrollment(enrollment_id)
        ON DELETE CASCADE
);

CREATE TABLE lesson_progress (
    lesson_progress_id  SERIAL PRIMARY KEY,
    enrollment_id       INTEGER NOT NULL,
    lesson_id           INTEGER NOT NULL,
    completed_at        TIMESTAMP,
    is_completed        BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (enrollment_id)
        REFERENCES enrollment(enrollment_id)
        ON DELETE CASCADE,
    FOREIGN KEY (lesson_id)
        REFERENCES lesson(lesson_id)
        ON DELETE CASCADE,
    UNIQUE (enrollment_id, lesson_id)
);

CREATE TABLE course_prerequisite (
    course_id               INTEGER NOT NULL,
    prerequisite_course_id  INTEGER NOT NULL,
    PRIMARY KEY (course_id, prerequisite_course_id),
    CHECK (course_id <> prerequisite_course_id),
    FOREIGN KEY (course_id)
        REFERENCES course(course_id)
        ON DELETE CASCADE,
    FOREIGN KEY (prerequisite_course_id)
        REFERENCES course(course_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_course_instructor_id      ON course(instructor_id);
CREATE INDEX idx_lesson_course_id          ON lesson(course_id);
CREATE INDEX idx_enrollment_course_id      ON enrollment(course_id);
CREATE INDEX idx_enrollment_student_id     ON enrollment(student_id);
CREATE INDEX idx_review_course_id          ON review(course_id);
CREATE INDEX idx_review_student_id         ON review(student_id);
CREATE INDEX idx_payment_enrollment_id     ON payment(enrollment_id);
CREATE INDEX idx_payment_status            ON payment(status);

CREATE INDEX idx_lesson_progress_enrollment_id ON lesson_progress(enrollment_id);
CREATE INDEX idx_lesson_progress_lesson_id     ON lesson_progress(lesson_id);
CREATE INDEX idx_lesson_progress_is_completed  ON lesson_progress(is_completed);

CREATE INDEX idx_course_prerequisite_prerequisite
    ON course_prerequisite(prerequisite_course_id);