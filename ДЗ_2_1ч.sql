drop table if exists Certificate cascade;
drop table if exists CourseCategory cascade;
drop table if exists Category cascade;
drop table if exists Review cascade;
drop table if exists Enrollment cascade;
drop table if exists Lesson cascade;
drop table if exists Course cascade;
drop table if exists Teacher cascade;
drop table if exists Student cascade;
drop table if exists "User" cascade;


create table "User"(
    id serial primary key,
    login varchar(50) not null unique,
    password_user varchar(50) not null
);

create table Student(
    id integer primary key
    references "User"(id) on delete cascade
);

create table Teacher(
    id integer primary key
    references "User"(id) on delete cascade
);

create table Course (
    id serial primary key,
    title varchar(50) not null,
    price decimal(10,2) not null check (price >= 0),
    id_teacher integer not null
    references Teacher(id) on delete cascade
);

create table Lesson (
    id serial primary key,
    id_course integer not null
    references Course(id) on delete cascade,
    title varchar(50) not null,
    order_index integer not null,
    unique(order_index, id_course)
);

create table Enrollment (
    id serial primary key,
    id_course integer not null
    references Course(id) on delete cascade,
    id_student integer not null
    references Student(id) on delete cascade,
    progress integer default 0 check(progress between 0 and 100),
    unique(id_student, id_course)
);

create table Review (
    id serial primary key,
    id_course integer not null
    references Course(id) on delete cascade,
    id_student integer not null
    references Student(id) on delete cascade,
    rating integer not null check (rating between 1 and 5),
    comment text
);

-- таблица 1: Категории курсов
create table Category (
    id serial primary key,
    name varchar(100) not null unique
);

-- связывающая таблица: (Реализация M:N) Связь Курсов и Категорий
create table CourseCategory (
    id_course integer not null references Course(id) on delete cascade,
    id_category integer not null references Category(id) on delete cascade,
    primary key (id_course, id_category)
);

-- таблица 2: Сертификаты об окончании
create table Certificate (
    id serial primary key,
    id_student integer not null references Student(id) on delete cascade,
    id_course integer not null references Course(id) on delete cascade,
    issue_date date default current_date not null,
    certificate_code varchar(100) not null unique,
    unique(id_student, id_course)
);


create index idx_course_teacher on Course(id_teacher);
create index idx_lesson_course on Lesson(id_course);
create index idx_enrollment_course on Enrollment(id_course);
create index idx_enrollment_student on Enrollment(id_student);
create index idx_review_course on Review(id_course);
create index idx_review_student on Review(id_student);

-- Индексы для новых таблиц:
create index idx_coursecategory_category on CourseCategory(id_category);
create index idx_certificate_student on Certificate(id_student);