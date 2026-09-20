DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS users CASCADE;


CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    role VARCHAR(20) NOT NULL
        CHECK (role IN ('student', 'teacher'))
);


CREATE TABLE courses (
    course_id SERIAL PRIMARY KEY,
    teacher_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL
        CHECK (price >= 0),

    CONSTRAINT fk_courses_teacher
        FOREIGN KEY (teacher_id)
        REFERENCES users(user_id)
);


CREATE TABLE lessons (
    lesson_id SERIAL PRIMARY KEY,
    course_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    lesson_order INTEGER NOT NULL
        CHECK (lesson_order > 0),

    CONSTRAINT fk_lessons_course
        FOREIGN KEY (course_id)
        REFERENCES courses(course_id)
        ON DELETE CASCADE
);


CREATE TABLE enrollments (
    user_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'completed', 'cancelled')),

    PRIMARY KEY (user_id, course_id),

    CONSTRAINT fk_enrollments_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_enrollments_course
        FOREIGN KEY (course_id)
        REFERENCES courses(course_id)
        ON DELETE CASCADE
);


CREATE TABLE reviews (
    review_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    rating INTEGER NOT NULL
        CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reviews_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_reviews_course
        FOREIGN KEY (course_id)
        REFERENCES courses(course_id)
        ON DELETE CASCADE,

    CONSTRAINT uq_reviews_user_course
        UNIQUE (user_id, course_id)
);


CREATE INDEX idx_courses_teacher_id
    ON courses(teacher_id);

CREATE INDEX idx_lessons_course_id
    ON lessons(course_id);

CREATE INDEX idx_enrollments_course_id
    ON enrollments(course_id);

CREATE INDEX idx_reviews_user_id
    ON reviews(user_id);

CREATE INDEX idx_reviews_course_id
    ON reviews(course_id);