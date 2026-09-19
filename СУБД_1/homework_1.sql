DROP TABLE IF EXISTS review CASCADE;
DROP TABLE IF EXISTS enrollment CASCADE;
DROP TABLE IF EXISTS lesson CASCADE;
DROP TABLE IF EXISTS course CASCADE;
DROP TABLE IF EXISTS "user" CASCADE;

CREATE TABLE "user" (
    user_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('student', 'teacher'))
);

CREATE TABLE course (
    course_id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    teacher_id INTEGER NOT NULL,
    FOREIGN KEY (teacher_id) REFERENCES "user"(user_id)
);

CREATE TABLE lesson (
    lesson_id SERIAL PRIMARY KEY,
    course_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    lesson_order INTEGER NOT NULL CHECK (lesson_order > 0),
    FOREIGN KEY (course_id) REFERENCES course(course_id)
);

CREATE TABLE enrollment (
    enrollment_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL CHECK (status IN ('active', 'completed')),
    FOREIGN KEY (user_id) REFERENCES "user"(user_id),
    FOREIGN KEY (course_id) REFERENCES course(course_id),
    UNIQUE (user_id, course_id)
);

CREATE TABLE review (
    review_id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    text TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES "user"(user_id),
    FOREIGN KEY (course_id) REFERENCES course(course_id)
);

CREATE INDEX idx_course_teacher ON course(teacher_id);
CREATE INDEX idx_lesson_course ON lesson(course_id);
CREATE INDEX idx_enrollment_user ON enrollment(user_id);
CREATE INDEX idx_enrollment_course ON enrollment(course_id);
CREATE INDEX idx_review_user ON review(user_id);
CREATE INDEX idx_review_course ON review(course_id);