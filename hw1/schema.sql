DROP TABLE IF EXISTS Review CASCADE;
DROP TABLE IF EXISTS Enrollment CASCADE;
DROP TABLE IF EXISTS Lesson CASCADE;
DROP TABLE IF EXISTS Course CASCADE;
DROP TABLE IF EXISTS "User" CASCADE;

CREATE TABLE "User" (
    user_id     SERIAL PRIMARY KEY,
    email       VARCHAR(255) NOT NULL UNIQUE,
    full_name   VARCHAR(150) NOT NULL,
    role        VARCHAR(20)  NOT NULL CHECK (role IN ('student', 'teacher', 'admin')),
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE TABLE Course (
    course_id    SERIAL PRIMARY KEY,
    teacher_id   INTEGER      NOT NULL,
    title        VARCHAR(200) NOT NULL,
    description  TEXT,
    price        DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    is_published BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_course_teacher
        FOREIGN KEY (teacher_id) REFERENCES "User"(user_id)
        ON DELETE RESTRICT
);

CREATE INDEX idx_course_teacher ON Course(teacher_id);

CREATE TABLE Lesson (
    lesson_id        SERIAL PRIMARY KEY,
    course_id        INTEGER      NOT NULL,
    title            VARCHAR(200) NOT NULL,
    content          TEXT,
    position         INTEGER      NOT NULL CHECK (position > 0),
    duration_minutes INTEGER      CHECK (duration_minutes > 0),
    CONSTRAINT fk_lesson_course
        FOREIGN KEY (course_id) REFERENCES Course(course_id)
        ON DELETE CASCADE,
    CONSTRAINT uq_lesson_position UNIQUE (course_id, position)
);

CREATE INDEX idx_lesson_course ON Lesson(course_id);

CREATE TABLE Enrollment (
    enrollment_id    SERIAL PRIMARY KEY,
    student_id       INTEGER   NOT NULL,
    course_id        INTEGER   NOT NULL,
    enrolled_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    completed_at     TIMESTAMP,
    progress_percent INTEGER   NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    attempt          INTEGER   NOT NULL DEFAULT 1 CHECK (attempt > 0),
    CONSTRAINT fk_enrollment_student
        FOREIGN KEY (student_id) REFERENCES "User"(user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_enrollment_course
        FOREIGN KEY (course_id) REFERENCES Course(course_id)
        ON DELETE CASCADE,
    CONSTRAINT uq_enrollment UNIQUE (student_id, course_id)
);

CREATE INDEX idx_enrollment_student ON Enrollment(student_id);
CREATE INDEX idx_enrollment_course  ON Enrollment(course_id);

CREATE TABLE Review (
    review_id    SERIAL PRIMARY KEY,
    student_id   INTEGER   NOT NULL,
    course_id    INTEGER   NOT NULL,
    rating       INTEGER   NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment      TEXT,
    is_moderated BOOLEAN   NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_review_student
        FOREIGN KEY (student_id) REFERENCES "User"(user_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_review_course
        FOREIGN KEY (course_id) REFERENCES Course(course_id)
        ON DELETE CASCADE,
    CONSTRAINT uq_review UNIQUE (student_id, course_id)
);

CREATE INDEX idx_review_student ON Review(student_id);
CREATE INDEX idx_review_course  ON Review(course_id);