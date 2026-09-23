CREATE TABLE users(
user_id SERIAL,
username VARCHAR(50),
email VARCHAR(70),
);
CREATE TABLE courses(
corse_id SERIAL,
teacher_id INT,
title VARCHAR(100)
);
CREATE TABLE lessons(
lesson_id SERIAL,
course_id INT,
title VARCHAR(100)
);
CREATE TABLE enrollments(
enrollment_id SERIAL,
user_id INT,
course_id INT,
);
CREATE TABLE reviews(
review_id SERIAL,
user_id INT,
course_id INT
);
--вывести список всех курсов с колличеством записавшихся студентов
--показать все уроки конкретного курса в правильном порядке
