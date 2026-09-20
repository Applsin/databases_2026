# Домашнее задание №1

**Вариант №1 — Онлайн-курсы (EdTech)**

## 1. Концептуальная модель

В модели выделены основные сущности:

- **User** — зарегистрированный пользователь платформы; роль определяет, является ли он студентом, преподавателем или совмещает обе роли.
- **Course** — курс, созданный преподавателем.
- **Lesson** — отдельный урок курса.
- **Enrollment** — запись студента на курс.
- **Review** — отзыв и оценка студента по курсу.
- **LessonProgress** — состояние прохождения конкретного урока студентом.

Основные связи:

- `User 1:N Course` — преподаватель может создать несколько курсов.
- `Course 1:N Lesson` — курс состоит из уроков.
- `User M:N Course` через `Enrollment` — студент может записаться на несколько курсов.
- `User 1:N Review` и `Course 1:N Review`.
- `User M:N Lesson` через `LessonProgress`.

## 2. Логическая модель

### User

- `user_id` — PK
- `name`
- `email` — UNIQUE
- `password`
- `role`
- `created_at`

### Course

- `course_id` — PK
- `title`
- `description`
- `price`
- `teacher_id` — FK → User
- `teacher_share_percent`
- `is_published`

### Lesson

- `lesson_id` — PK
- `course_id` — FK → Course
- `title`
- `content`
- `lesson_order`
- `duration_minutes`

### Enrollment

- `enrollment_id` — PK
- `user_id` — FK → User
- `course_id` — FK → Course
- `enrolled_at`
- `price_paid`
- `completed_at`
- UNIQUE(`user_id`, `course_id`)

### Review

- `review_id` — PK
- `user_id` — FK → User
- `course_id` — FK → Course
- `rating`
- `text`
- `created_at`
- UNIQUE(`user_id`, `course_id`)

### LessonProgress

- PK(`user_id`, `lesson_id`)
- `started_at`
- `completed_at`

### Кардинальности

| Связь | Кардинальность |
|---|---|
| User — Course | 1 : 0..N |
| Course — Lesson | 1 : 1..N |
| User — Enrollment | 1 : 0..N |
| Course — Enrollment | 1 : 0..N |
| User — Review | 1 : 0..N |
| Course — Review | 1 : 0..N |
| User — LessonProgress | 1 : 0..N |
| Lesson — LessonProgress | 1 : 0..N |

### Идентифицирующие связи

Связи с `Course`, `Lesson`, `Enrollment` и `Review` являются неидентифицирующими: дочерняя таблица имеет собственный PK.

Связи `User — LessonProgress` и `Lesson — LessonProgress` являются идентифицирующими, потому что PK `LessonProgress` состоит из `(user_id, lesson_id)`.

## 3. Физическая модель

Файл `homework_1.sql` содержит PostgreSQL DDL.

В модели используются `SERIAL`, `VARCHAR`, `TEXT`, `INTEGER`, `TIMESTAMP`, `DECIMAL` и `BOOLEAN`. Добавлены `PRIMARY KEY`, `FOREIGN KEY`, `NOT NULL`, `CHECK`, `UNIQUE` и индексы для внешних ключей.

Скрипт начинается с удаления существующих таблиц, поэтому его можно запускать повторно.

### Связь с бизнес-требованиями

- регистрация пользователей → `user`;
- студенты и преподаватели → `role`;
- создание курсов → `course.teacher_id`;
- курсы состоят из уроков → `lesson`;
- запись на курс → `enrollment`;
- оценка от 1 до 5 → `review.rating`;
- один отзыв студента на курс → `UNIQUE(user_id, course_id)`;
- цена продажи и доля преподавателя → `price_paid` и `teacher_share_percent`;
- отслеживание обучения → `completed_at` и `lesson_progress`.

## 4. Частые запросы

1. Показать все опубликованные курсы с количеством записавшихся студентов.
2. Найти курсы с наибольшим количеством отзывов и средней оценкой.
3. Показать уроки выбранного курса в правильном порядке и прогресс студента.
4. Получить историю обучения студента с датами записи и завершения.
5. Рассчитать выплаты преподавателю за выбранный период на основании оплаченных записей и его доли.
