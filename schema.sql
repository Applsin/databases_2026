-- =====================================================================
-- Вариант №1. Онлайн-курсы (EdTech)
-- Физическая модель базы данных для PostgreSQL
--
-- Скрипт можно запускать несколько раз подряд — в начале каждая таблица
-- удаляется командой DROP TABLE IF EXISTS, а потом создаётся заново.
-- =====================================================================

DROP TABLE IF EXISTS payouts CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS enrollments CASCADE;
DROP TABLE IF EXISTS lessons CASCADE;
DROP TABLE IF EXISTS courses CASCADE;
DROP TABLE IF EXISTS users CASCADE;


-- ---------------------------------------------------------------------
-- Таблица 1. users — все пользователи платформы: и студенты,
-- и преподаватели. Кто есть кто — определяет поле role.
--
-- Решение: не делать отдельные таблицы students и teachers, а хранить
-- всех в одной users с полем role. Так проще для старта — не нужно
-- дублировать общие поля (имя, почта) в двух таблицах.
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id            SERIAL PRIMARY KEY,          -- номер пользователя, генерируется сам
    full_name     VARCHAR(150) NOT NULL,       -- имя, обязательно
    email         VARCHAR(150) NOT NULL UNIQUE,-- почта, обязательна и не повторяется
    password_hash VARCHAR(255) NOT NULL,       -- пароль (в базе хранится не сам пароль, а его хеш)
    role          VARCHAR(20)  NOT NULL CHECK (role IN ('student', 'teacher')),
    created_at    TIMESTAMP NOT NULL DEFAULT now() -- дата регистрации, ставится автоматически
);


-- ---------------------------------------------------------------------
-- Таблица 2. courses — курсы. У каждого курса есть автор-преподаватель
-- (поэтому teacher_id ссылается на users) и цена.
-- ---------------------------------------------------------------------
CREATE TABLE courses (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    description TEXT,
    teacher_id  INTEGER NOT NULL REFERENCES users(id), -- какой преподаватель создал курс
    price       DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    created_at  TIMESTAMP NOT NULL DEFAULT now()
);

-- Индекс на внешний ключ: помогает базе быстрее находить все курсы
-- конкретного преподавателя, не перебирая таблицу целиком.
CREATE INDEX idx_courses_teacher_id ON courses(teacher_id);


-- ---------------------------------------------------------------------
-- Таблица 3. lessons — уроки внутри курса.
-- order_number — порядковый номер урока в курсе (1, 2, 3...),
-- чтобы можно было показывать уроки по порядку.
-- ---------------------------------------------------------------------
CREATE TABLE lessons (
    id           SERIAL PRIMARY KEY,
    course_id    INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    title        VARCHAR(200) NOT NULL,
    content      TEXT,
    order_number INTEGER NOT NULL CHECK (order_number > 0)
);

-- ON DELETE CASCADE выше значит: если удалить курс, все его уроки
-- удалятся вместе с ним автоматически (без "осиротевших" уроков).

CREATE INDEX idx_lessons_course_id ON lessons(course_id);


-- ---------------------------------------------------------------------
-- Таблица 4. enrollments — запись студента на курс.
-- Это связь "многие-ко-многим": один студент может учиться на многих
-- курсах, у одного курса может быть много студентов. Напрямую такую
-- связь в SQL не сделать, поэтому заводим отдельную таблицу-посредник.
--
-- status — здесь же храним, прошёл ли студент курс целиком (это ответ
-- на вопрос "как хранить статус завершения курса" из задания).
-- ---------------------------------------------------------------------
CREATE TABLE enrollments (
    id          SERIAL PRIMARY KEY,
    student_id  INTEGER NOT NULL REFERENCES users(id),
    course_id   INTEGER NOT NULL REFERENCES courses(id),
    status      VARCHAR(20) NOT NULL DEFAULT 'in_progress'
                    CHECK (status IN ('in_progress', 'completed')),
    enrolled_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (student_id, course_id) -- один студент не может записаться на один курс дважды
);

CREATE INDEX idx_enrollments_student_id ON enrollments(student_id);
CREATE INDEX idx_enrollments_course_id ON enrollments(course_id);


-- ---------------------------------------------------------------------
-- Таблица 5. reviews — отзывы студентов на курсы, с оценкой от 1 до 5.
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    id         SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES users(id),
    course_id  INTEGER NOT NULL REFERENCES courses(id),
    rating     SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment    TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (student_id, course_id) -- один отзыв от студента на курс, не больше
);

CREATE INDEX idx_reviews_student_id ON reviews(student_id);
CREATE INDEX idx_reviews_course_id ON reviews(course_id);


-- ---------------------------------------------------------------------
-- Таблица 6. payouts — сколько денег и за какой курс должен получить
-- преподаватель. Отдельная таблица, потому что один преподаватель может
-- вести несколько курсов и получать выплаты по каждому отдельно.
-- ---------------------------------------------------------------------
CREATE TABLE payouts (
    id         SERIAL PRIMARY KEY,
    teacher_id INTEGER NOT NULL REFERENCES users(id),
    course_id  INTEGER NOT NULL REFERENCES courses(id),
    amount     DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    pay_month  DATE NOT NULL, -- за какой месяц начислена выплата
    paid_at    TIMESTAMP      -- когда фактически выплачено (пусто, если ещё не выплачено)
);

CREATE INDEX idx_payouts_teacher_id ON payouts(teacher_id);
CREATE INDEX idx_payouts_course_id ON payouts(course_id);
