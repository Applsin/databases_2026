DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS enrollment CASCADE;
DROP TABLE IF EXISTS lesson CASCADE;
DROP TABLE IF EXISTS course CASCADE;
DROP TABLE IF EXISTS "user" CASCADE;

CREATE TABLE "user" (
    user_id SERIAL PRIMARY KEY,

    email VARCHAR(255) NOT NULL UNIQUE,

    full_name VARCHAR(100) NOT NULL,

    role VARCHAR(20) NOT NULL
        CHECK (role IN ('student', 'instructor', 'admin')),

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE course (
    course_id SERIAL PRIMARY KEY,

    title VARCHAR(200) NOT NULL,

    description TEXT,

    price DECIMAL(10, 2) NOT NULL
        CHECK (price >= 0),

    instructor_id INTEGER NOT NULL,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (instructor_id)
        REFERENCES "user"(user_id)
);


CREATE TABLE lesson (
    lesson_id SERIAL PRIMARY KEY,

    course_id INTEGER NOT NULL,

    title VARCHAR(200) NOT NULL,

    order_num INTEGER NOT NULL
        CHECK (order_num > 0),

    duration_min INTEGER
        CHECK (duration_min > 0),

    FOREIGN KEY (course_id)
        REFERENCES course(course_id)
        ON DELETE CASCADE,

    UNIQUE (course_id, order_num)
);


CREATE TABLE enrollment (
    enrollment_id SERIAL PRIMARY KEY,

    course_id INTEGER NOT NULL,

    user_id INTEGER NOT NULL,

    enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    completed_at TIMESTAMP,

    progress INTEGER NOT NULL DEFAULT 0
        CHECK (progress BETWEEN 0 AND 100),

    FOREIGN KEY (course_id)
        REFERENCES course(course_id)
        ON DELETE CASCADE,

    FOREIGN KEY (user_id)
        REFERENCES "user"(user_id)
        ON DELETE CASCADE,

    UNIQUE (user_id, course_id)
);


CREATE TABLE review (
    review_id SERIAL PRIMARY KEY,

    course_id INTEGER NOT NULL,

    user_id INTEGER NOT NULL,

    rating INTEGER NOT NULL
        CHECK (rating BETWEEN 1 AND 5),

    comment TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (course_id)
        REFERENCES course(course_id)
        ON DELETE CASCADE,

    FOREIGN KEY (user_id)
        REFERENCES "user"(user_id)
        ON DELETE CASCADE,

    UNIQUE (user_id, course_id)
);


CREATE INDEX idx_course_instructor_id
    ON course(instructor_id);

CREATE INDEX idx_lesson_course_id
    ON lesson(course_id);

CREATE INDEX idx_enrollment_course_id
    ON enrollment(course_id);

CREATE INDEX idx_enrollment_user_id
    ON enrollment(user_id);

CREATE INDEX idx_review_course_id
    ON review(course_id);

CREATE INDEX idx_review_user_id
    ON review(user_id);