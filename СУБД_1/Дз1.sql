DROP SCHEMA IF EXISTS hw1 CASCADE;
CREATE SCHEMA hw1;
SET search_path TO hw1;

CREATE TABLE "users" (
  "id" integer PRIMARY KEY,
  "email" varchar UNIQUE NOT NULL,
  "username" varchar NOT NULL,
  "role" varchar NOT NULL,
  "created_at" timestamp NOT NULL
);

CREATE TABLE "courses" (
  "id" integer PRIMARY KEY,
  "author_id" integer NOT NULL,
  "title" varchar NOT NULL,
  "price" numeric,
  "created_at" timestamp NOT NULL
);

CREATE TABLE "lessons" (
  "id" integer PRIMARY KEY,
  "course_id" integer NOT NULL,
  "title" varchar NOT NULL,
  "position" integer NOT NULL
);

CREATE TABLE "enrollments" (
  "id" integer PRIMARY KEY,
  "user_id" integer NOT NULL,
  "course_id" integer NOT NULL,
  "enrolled_at" timestamp NOT NULL,
  "status" varchar NOT NULL
);

CREATE TABLE "reviews" (
  "id" integer PRIMARY KEY,
  "user_id" integer NOT NULL,
  "course_id" integer NOT NULL,
  "rating" integer NOT NULL,
  "comment" text,
  "created_at" timestamp NOT NULL
);


ALTER TABLE "courses" ADD FOREIGN KEY ("author_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "lessons" ADD FOREIGN KEY ("course_id") REFERENCES "courses" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "enrollments" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "enrollments" ADD FOREIGN KEY ("course_id") REFERENCES "courses" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "reviews" ADD FOREIGN KEY ("user_id") REFERENCES "users" ("id") DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE "reviews" ADD FOREIGN KEY ("course_id") REFERENCES "courses" ("id") DEFERRABLE INITIALLY IMMEDIATE;


CREATE INDEX idx_courses_author_id ON courses (author_id);

CREATE INDEX idx_lessons_course_id ON lessons (course_id);

CREATE INDEX idx_enrollments_user_id ON enrollments (user_id);

CREATE INDEX idx_enrollments_course_id ON enrollments (course_id);

CREATE INDEX idx_reviews_user_id ON reviews (user_id);

CREATE INDEX idx_reviews_course_id ON reviews (course_id);