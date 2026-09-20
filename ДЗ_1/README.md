# ДЗ №1. От бизнес-требований к физической модели

**Вариант №1 — Онлайн-курсы (EdTech)**

## 1. Концептуальная модель

### Описание предметной области

Рассматривается платформа онлайн-образования. Пользователи регистрируются на платформе, выбирают курсы и проходят обучение.

Каждый курс состоит из нескольких уроков. Преподаватели создают курсы и получают отчисления от их продаж. Студенты могут записываться на курсы, оставлять отзывы и оценивать курсы по шкале от 1 до 5.

Для построения концептуальной модели выделены следующие основные сущности:

- **User** — пользователь платформы;
- **Course** — онлайн-курс;
- **Lesson** — урок курса;
- **Enrollment** — запись пользователя на курс;
- **Review** — отзыв пользователя о курсе.

### Связи между сущностями

**User — Course**

Один пользователь в роли преподавателя может создать несколько курсов. Каждый курс создаётся одним преподавателем.

**Course — Lesson**

Один курс состоит из нескольких уроков. Каждый урок относится к одному курсу.

**User — Enrollment — Course**

Пользователь может записаться на несколько курсов, а на один курс могут записаться несколько пользователей. Поэтому между `User` и `Course` существует связь **M:N**, которая реализуется через сущность `Enrollment`.

**User — Review — Course**

Пользователь может оставлять отзывы на курсы. Один курс может иметь несколько отзывов, а один пользователь может оставить несколько отзывов.

### Концептуальная схема

```text
                    ┌──────────────┐
                    │     User     │
                    └──────┬───────┘
                           │
                    создаёт│
                           │ 1:N
                           ▼
                    ┌──────────────┐
                    │    Course    │
                    └──────┬───────┘
                           │
                     состоит из
                           │ 1:N
                           ▼
                    ┌──────────────┐
                    │    Lesson    │
                    └──────────────┘


       ┌──────────────┐                 ┌──────────────┐
       │     User     │                 │    Course    │
       └──────┬───────┘                 └──────┬───────┘
              │                                │
              │ 1:N                            │ 1:N
              ▼                                ▼
       ┌────────────────────────────────────────────┐
       │                 Enrollment                 │
       └────────────────────────────────────────────┘


       ┌──────────────┐                 ┌──────────────┐
       │     User     │                 │    Course    │
       └──────┬───────┘                 └──────┬───────┘
              │                                │
              │ 1:N                            │ 1:N
              ▼                                ▼
                         ┌──────────────┐
                         │    Review    │
                         └──────────────┘
```

---

## 2. Логическая модель

На логическом уровне к сущностям добавляются атрибуты, первичные ключи, внешние ключи и кардинальности связей.

### 2.1. User

| Атрибут | Ключ | Описание |
|---|---|---|
| `user_id` | PK | Уникальный идентификатор пользователя |
| `name` | — | Имя пользователя |
| `email` | — | Электронная почта |
| `role` | — | Роль пользователя: студент или преподаватель |

`email` должен быть уникальным.

### 2.2. Course

| Атрибут | Ключ | Описание |
|---|---|---|
| `course_id` | PK | Уникальный идентификатор курса |
| `teacher_id` | FK | Преподаватель курса |
| `title` | — | Название курса |
| `description` | — | Описание курса |
| `price` | — | Стоимость курса |

`teacher_id` ссылается на `User.user_id`.

Связь: **User 1:N Course**.

### 2.3. Lesson

| Атрибут | Ключ | Описание |
|---|---|---|
| `lesson_id` | PK | Уникальный идентификатор урока |
| `course_id` | FK | Курс, к которому относится урок |
| `title` | — | Название урока |
| `content` | — | Содержание урока |
| `lesson_order` | — | Порядковый номер урока |

`course_id` ссылается на `Course.course_id`.

Связь: **Course 1:N Lesson**.

Атрибут `lesson_order` позволяет получить уроки конкретного курса в правильном порядке.

### 2.4. Enrollment

| Атрибут | Ключ | Описание |
|---|---|---|
| `user_id` | PK, FK | Пользователь, записавшийся на курс |
| `course_id` | PK, FK | Выбранный курс |
| `enrolled_at` | — | Дата записи на курс |
| `status` | — | Статус обучения |

Используется составной первичный ключ: **(`user_id`, `course_id`)**.

Это не позволяет одному пользователю несколько раз записаться на один и тот же курс.

Связи:

- **User 1:N Enrollment**
- **Course 1:N Enrollment**

Через `Enrollment` реализуется связь **User M:N Course**.

### 2.5. Review

| Атрибут | Ключ | Описание |
|---|---|---|
| `review_id` | PK | Уникальный идентификатор отзыва |
| `user_id` | FK | Автор отзыва |
| `course_id` | FK | Оцениваемый курс |
| `rating` | — | Оценка от 1 до 5 |
| `comment` | — | Текст отзыва |
| `created_at` | — | Дата создания отзыва |

Связи:

- **User 1:N Review**
- **Course 1:N Review**

Для `rating` устанавливается ограничение от 1 до 5.

### Кардинальности связей

| Связь | Кардинальность |
|---|---|
| User → Course | 1:N |
| Course → Lesson | 1:N |
| User → Enrollment | 1:N |
| Course → Enrollment | 1:N |
| User → Review | 1:N |
| Course → Review | 1:N |

### Идентифицирующие и неидентифицирующие связи

Связи **User → Enrollment** и **Course → Enrollment** являются идентифицирующими, поскольку внешние ключи `user_id` и `course_id` входят в состав первичного ключа таблицы `Enrollment`.

Связи `User → Course`, `Course → Lesson`, `User → Review` и `Course → Review` являются неидентифицирующими, поскольку внешние ключи не входят в состав первичных ключей дочерних таблиц.

---

## 3. Физическая модель

Физическая модель реализована в **PostgreSQL**.

Для каждой сущности создана отдельная таблица. Используются:

- `PRIMARY KEY`;
- `FOREIGN KEY`;
- `NOT NULL`;
- `UNIQUE`;
- `CHECK`;
- индексы на внешние ключи;
- `ON DELETE CASCADE`.

SQL-скрипт является воспроизводимым и начинается с удаления существующих таблиц с помощью `DROP TABLE IF EXISTS ... CASCADE`.

### SQL-скрипт

```sql
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
```

### Обоснование физической модели

Для идентификаторов используется тип `SERIAL`.

Для текстовых значений используются `VARCHAR` и `TEXT`.

Стоимость курса хранится в `DECIMAL(10,2)`, что позволяет хранить денежные значения с двумя знаками после запятой.

Для оценки используется `INTEGER` с ограничением `rating BETWEEN 1 AND 5`.

Для статуса обучения используется ограниченный набор значений:

- `active`;
- `completed`;
- `cancelled`.

Для электронной почты установлен `UNIQUE`, поэтому одинаковые адреса электронной почты не могут использоваться несколькими пользователями.

Индексы на внешние ключи добавлены для повышения эффективности запросов по связанным таблицам.

---

## 4. Пять самых частых запросов к базе данных

### 1. Список курсов

Получить список всех курсов с количеством студентов, записавшихся на каждый курс.

**Используемые сущности:** `Course`, `Enrollment`.

### 2. Популярные курсы

Получить 10 самых популярных курсов по количеству отзывов и средней оценке.

**Используемые сущности:** `Course`, `Review`.

### 3. Уроки курса

Получить все уроки конкретного курса в правильном порядке.

**Используемые сущности:** `Course`, `Lesson`.

Порядок определяется атрибутом `lesson_order`.

### 4. История обучения студента

Получить историю обучения конкретного студента: курсы, на которые он записан, и статус обучения по каждому курсу.

**Используемые сущности:** `User`, `Enrollment`, `Course`.

### 5. Выплата преподавателю

Получить сумму, которую должен получить преподаватель за месяц по всем своим курсам.

**Используемые сущности:** `User`, `Course`, `Enrollment`.

---

## Связь бизнес-требований с моделью

| Бизнес-требование | Реализация в модели |
|---|---|
| Пользователи регистрируются на платформе | Сущность `User` |
| Пользователи могут быть студентами или преподавателями | Атрибут `User.role` |
| Преподаватели создают курсы | `Course.teacher_id` → `User.user_id` |
| Каждый курс состоит из нескольких уроков | Связь `Course 1:N Lesson` |
| Студенты выбирают курсы | Сущность `Enrollment` |
| Один пользователь может выбрать несколько курсов | Связь `User 1:N Enrollment` |
| Один курс могут проходить разные пользователи | Связь `Course 1:N Enrollment` |
| Студенты оставляют отзывы | Сущность `Review` |
| Оценка должна быть от 1 до 5 | `Review.rating` + `CHECK` |
| Уроки должны отображаться в правильном порядке | `Lesson.lesson_order` |
| У курса есть стоимость | `Course.price` |
| Пользователь не должен записываться на один курс несколько раз | Составной PK `Enrollment(user_id, course_id)` |
| Один пользователь не должен оставлять несколько отзывов на один курс | `UNIQUE(user_id, course_id)` |

---

## Дополнительные рекомендации

Для дальнейшего развития модели можно добавить отдельную сущность `LessonProgress`, которая будет хранить прогресс пользователя по каждому уроку. Это позволит более точно отслеживать завершение отдельных уроков.

Также для расчёта выплат преподавателям можно расширить модель информацией о фактической сумме покупки и проценте отчисления преподавателю. В текущей базовой модели стоимость курса хранится в `Course.price`.
