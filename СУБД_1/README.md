# Домашнее задание №1

**Вариант №1 — Онлайн-курсы (EdTech)**

---

## 1. Концептуальная модель

### 1.1 Основные сущности

Выделены 5 ключевых сущностей предметной области:

| Сущность | Назначение |
|---|---|
| **User** | Пользователь платформы: студент или преподаватель. |
| **Course** | Курс, созданный преподавателем. |
| **Lesson** | Урок, входящий в курс. |
| **Enrollment** | Факт записи студента на курс. |
| **Review** | Отзыв студента на курс с оценкой. |

### 1.2 Связи между сущностями

- `User (teacher) 1 ─── N Course` — один преподаватель создаёт много курсов.
- `Course 1 ─── N Lesson` — один курс содержит много уроков.
- `User (student) N ─── M Course` — реализуется через `Enrollment`.
- `User (student) 1 ─── N Review` — студент оставляет отзывы.
- `Course 1 ─── N Review` — у курса много отзывов.

### 1.3 Обоснование выбора сущностей

- **`User`** — единая сущность для студентов и преподавателей, так как оба типа имеют одинаковый базовый набор атрибутов (имя, email, пароль). Различие отражается полем `role`. Это проще, чем наследование или две отдельные таблицы, и достаточно для бизнес-требований.
- **`Course`** — бизнес-требование «преподаватели могут создавать курсы» требует отдельной сущности для курса с привязкой к преподавателю.
- **`Lesson`** — бизнес-требование «каждый курс состоит из нескольких уроков» → отдельная сущность, связанная с курсом.
- **`Enrollment`** — связь «студент — курс» имеет собственные атрибуты (дата записи, статус), поэтому это классический случай M:N со свойствами, который выделяется в отдельную сущность.
- **`Review`** — бизнес-требование «студенты могут оставлять отзывы и оценивать курсы по шкале от 1 до 5» требует отдельной сущности, связанной и со студентом, и с курсом.

---

## 2. Логическая модель

### 2.1 Атрибуты сущностей и ключи

#### User

| Атрибут | Тип | Ограничение |
|---|---|---|
| `user_id` | SERIAL | **PK** |
| `name` | VARCHAR(100) | NOT NULL |
| `email` | VARCHAR(150) | NOT NULL, UNIQUE |
| `password` | VARCHAR(255) | NOT NULL |
| `role` | VARCHAR(20) | NOT NULL, CHECK (role IN ('student','teacher')) |

#### Course

| Атрибут | Тип | Ограничение |
|---|---|---|
| `course_id` | SERIAL | **PK** |
| `title` | VARCHAR(200) | NOT NULL |
| `description` | TEXT | — |
| `price` | DECIMAL(10,2) | NOT NULL, CHECK (price >= 0) |
| `teacher_id` | INTEGER | **FK** → user(user_id), NOT NULL |

#### Lesson

| Атрибут | Тип | Ограничение |
|---|---|---|
| `lesson_id` | SERIAL | **PK** |
| `course_id` | INTEGER | **FK** → course(course_id), NOT NULL |
| `title` | VARCHAR(200) | NOT NULL |
| `content` | TEXT | — |
| `lesson_order` | INTEGER | NOT NULL, CHECK (lesson_order > 0) |

#### Enrollment

| Атрибут | Тип | Ограничение |
|---|---|---|
| `enrollment_id` | SERIAL | **PK** |
| `user_id` | INTEGER | **FK** → user(user_id), NOT NULL |
| `course_id` | INTEGER | **FK** → course(course_id), NOT NULL |
| `enrolled_at` | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |
| `status` | VARCHAR(20) | NOT NULL, CHECK (status IN ('active','completed')) |
| — | — | UNIQUE (user_id, course_id) |

#### Review

| Атрибут | Тип | Ограничение |
|---|---|---|
| `review_id` | SERIAL | **PK** |
| `user_id` | INTEGER | **FK** → user(user_id), NOT NULL |
| `course_id` | INTEGER | **FK** → course(course_id), NOT NULL |
| `rating` | INTEGER | NOT NULL, CHECK (rating BETWEEN 1 AND 5) |
| `text` | TEXT | — |
| `created_at` | TIMESTAMP | NOT NULL, DEFAULT CURRENT_TIMESTAMP |

### 2.2 Кардинальность связей (Crow's Foot)

| Связь | Кардинальность |
|---|---|
| User (teacher) — Course | 1 : 0..N |
| Course — Lesson | 1 : 1..N |
| User (student) — Enrollment | 1 : 0..N |
| Course — Enrollment | 1 : 0..N |
| User (student) — Review | 1 : 0..N |
| Course — Review | 1 : 0..N |

Связь `User ↔ Course` реализована как **M:N** через таблицу `Enrollment`.

В нотации «воронья лапка»:

```
User ──┼────────o<── Course          (teacher создаёт курсы)
Course ──┼──────|<── Lesson          (курс содержит уроки)
User ──┼────────o<── Enrollment ──>┼── Course
User ──┼────────o<── Review ──>┼── Course
```

### 2.3 Идентифицирующие и неидентифицирующие связи

Все связи в модели — **неидентифицирующие**, так как у каждой дочерней сущности есть собственный суррогатный первичный ключ (`SERIAL`), а внешний ключ не входит в состав PK.

| Связь | Тип | Обоснование |
|---|---|---|
| User (teacher) → Course | Неидентифицирующая | У `Course` собственный PK `course_id` |
| Course → Lesson | Неидентифицирующая | У `Lesson` собственный PK `lesson_id` |
| User → Enrollment | Неидентифицирующая | У `Enrollment` собственный PK `enrollment_id` |
| Course → Enrollment | Неидентифицирующая | То же самое |
| User → Review | Неидентифицирующая | У `Review` собственный PK `review_id` |
| Course → Review | Неидентифицирующая | То же самое |

**Альтернатива.** Связь `Course → Lesson` можно сделать идентифицирующей, задав составной первичный ключ `(course_id, lesson_order)` и убрав `lesson_id`. Тогда урок не сможет существовать без курса, что соответствует бизнес-логике. Однако в текущей модели выбран суррогатный `lesson_id` — это удобнее для будущих ссылок (например, на таблицу прогресса по урокам).

### 2.4 Обоснование решений

- **Роль вместо отдельных таблиц Student/Teacher.** Бизнес-требование «платформа позволяет пользователям регистрироваться» не различает студента и преподавателя на уровне базовых атрибутов — оба имеют имя, email, пароль. Различие — только в правах доступа. Поэтому выбран `role` вместо наследования.
- **Цена `DECIMAL(10,2)`.** Бизнес-требование «преподаватели получают отчисления от продаж» требует точной денежной арифметики. `FLOAT`/`REAL` дают ошибки округления, `DECIMAL` — нет.
- **`CHECK (rating BETWEEN 1 AND 5)`** — прямо следует из требования «оценивать по шкале от 1 до 5».
- **`CHECK (price >= 0)`** — цена не может быть отрицательной.
- **`UNIQUE (user_id, course_id)` в Enrollment** — студент не может записаться на один курс дважды.
- **`lesson_order`** — из требования «уроки идут в определённом порядке»: у каждого урока в курсе есть свой номер.
- **`status` в Enrollment** — для отслеживания прогресса: студент может быть активен на курсе или завершить его.
- **Индексы на все FK** — PostgreSQL не создаёт их автоматически, а по этим колонкам идут JOIN и каскадные операции.

---

## 3. Физическая модель

### 3.1 SQL-скрипт (PostgreSQL)

```sql
-- ============================================================
-- ДЗ №1. Вариант №1 — Онлайн-курсы (EdTech)
-- Физическая модель, PostgreSQL
-- Скрипт воспроизводим: повторный запуск даёт тот же результат
-- ============================================================

DROP TABLE IF EXISTS review     CASCADE;
DROP TABLE IF EXISTS enrollment CASCADE;
DROP TABLE IF EXISTS lesson     CASCADE;
DROP TABLE IF EXISTS course     CASCADE;
DROP TABLE IF EXISTS "user"     CASCADE;

CREATE TABLE "user" (
    user_id  SERIAL       PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    email    VARCHAR(150) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role     VARCHAR(20)  NOT NULL CHECK (role IN ('student', 'teacher'))
);

CREATE TABLE course (
    course_id   SERIAL        PRIMARY KEY,
    title       VARCHAR(200)  NOT NULL,
    description TEXT,
    price       DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    teacher_id  INTEGER       NOT NULL,
    FOREIGN KEY (teacher_id) REFERENCES "user"(user_id)
);

CREATE TABLE lesson (
    lesson_id    SERIAL       PRIMARY KEY,
    course_id    INTEGER      NOT NULL,
    title        VARCHAR(200) NOT NULL,
    content      TEXT,
    lesson_order INTEGER      NOT NULL CHECK (lesson_order > 0),
    FOREIGN KEY (course_id) REFERENCES course(course_id)
);

CREATE TABLE enrollment (
    enrollment_id SERIAL      PRIMARY KEY,
    user_id       INTEGER     NOT NULL,
    course_id     INTEGER     NOT NULL,
    enrolled_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status        VARCHAR(20) NOT NULL CHECK (status IN ('active', 'completed')),
    FOREIGN KEY (user_id)   REFERENCES "user"(user_id),
    FOREIGN KEY (course_id) REFERENCES course(course_id),
    UNIQUE (user_id, course_id)
);

CREATE TABLE review (
    review_id  SERIAL      PRIMARY KEY,
    user_id    INTEGER     NOT NULL,
    course_id  INTEGER     NOT NULL,
    rating     INTEGER     NOT NULL CHECK (rating BETWEEN 1 AND 5),
    text       TEXT,
    created_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)   REFERENCES "user"(user_id),
    FOREIGN KEY (course_id) REFERENCES course(course_id)
);

CREATE INDEX idx_course_teacher    ON course(teacher_id);
CREATE INDEX idx_lesson_course     ON lesson(course_id);
CREATE INDEX idx_enrollment_user   ON enrollment(user_id);
CREATE INDEX idx_enrollment_course ON enrollment(course_id);
CREATE INDEX idx_review_user       ON review(user_id);
CREATE INDEX idx_review_course     ON review(course_id);
```

### 3.2 Обоснование типов данных

- `SERIAL` — суррогатные PK, автоинкремент.
- `VARCHAR(n)` — короткие строки с известным лимитом.
- `TEXT` — длинный свободный текст (описание, содержимое урока, отзыв).
- `INTEGER` — FK и числовые поля (рейтинг, порядок).
- `DECIMAL(10,2)` — точные деньги, без ошибок округления.
- `TIMESTAMP` — даты и время.

### 3.3 Обоснование ограничений

- `NOT NULL` — обязательные поля.
- `UNIQUE (email)` — email — логин пользователя.
- `CHECK (role IN ...)`, `CHECK (rating BETWEEN 1 AND 5)`, `CHECK (price >= 0)`, `CHECK (lesson_order > 0)`, `CHECK (status IN ...)` — прямо следуют из бизнес-требований.
- `UNIQUE (user_id, course_id)` в `Enrollment` — студент не может записаться на курс дважды.

### 3.4 Воспроизводимость

Блок `DROP TABLE IF EXISTS ... CASCADE` в начале в порядке «от зависимых к базовым» гарантирует, что повторный запуск скрипта даёт тот же результат.

---

## 4. Частые запросы к базе данных

Ниже — 5 наиболее частых запросов, которые будет обслуживать база. Формулировки приведены на русском, без SQL, с указанием бизнес-задачи.

1. **Список всех курсов с количеством записавшихся студентов.**
   Для витрины каталога и аналитики популярности. По каждому курсу выводится название, имя преподавателя, цена и число записавшихся студентов.

2. **Топ-10 курсов по средней оценке и количеству отзывов.**
   Для блока «Лучшие курсы» на главной странице. Отбираются курсы с наибольшим числом отзывов и средней оценкой не ниже 4.5.

3. **Все уроки конкретного курса в правильном порядке.**
   Для страницы прохождения курса. Уроки сортируются по `lesson_order`, выводятся название и содержимое каждого урока.

4. **История обучения студента.**
   Для личного кабинета: по `user_id` выводится список курсов студента с датой зачисления, статусом (`active` / `completed`) и датой завершения, если курс закончен.

5. **Сумма отчислений преподавателю за месяц.**
   Для расчёта выплат: по `teacher_id` и заданному месяцу суммируется стоимость курсов преподавателя, умноженная на число записавшихся студентов.