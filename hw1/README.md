## домашнее задание номер 1. онлайн-курсы

#1 задание
основные сущности :
user - польхователи, студенты и преподы
course(курс)- создается преподом
lesson (урок) - из чего состоят курсы
enrollment (запись на курс) - связь между студентом и курсом
review (отзыв) - оставляют студенты

связи:
преподы (user) создают курсы (course), а студенты их смотрят
студенты оставляют отзывы (review) на курс 
курсы (course) состоят из уроков (lesson)

#2 задание
атрибуты
user: user_id, password, email, first_name, last_name
course: course_id, title, teacher_id, description, price, created_at
lesson: lesson_id, course_id, title, content
enrllment: enrllment_id, student_id, course_id, status
review: comment, student_id, review_id

первичные ключи
user: user_id
course: course_id
lesson: lesson_id
enrollment: enrllment_id
review: review_id

внешние ключи 
user: -
course: teacher_id
lesson: course_id
enrollment: student_id
review: student_id, course_id
в моей модели используются суррогатные перичные ключи(serial). для всех таблиц. это значит что у всех сущностей ест ьнеазвисимый ID. поэтому все связи в модели 
неидентифицируеющие. идентифицируеющих связей нет 

<img width="1295" height="682" alt="image" src="https://github.com/user-attachments/assets/7e2b27d5-7e71-4f2f-aea4-f85aa122cb07" />


#4
1) вывести рейтинг курса
2) вывести количество активных студентов на курсе(статус активный, типо ещё не закончили его изучать)
3) самый высокооплачевамый препод
4) вывести список уроков для определенного курса
5) список курсов который ведет один препод





## ДЗ 2.  дополнение схемы. 1 часть

объяснение M:N и DROP CASCADE:
в моей схеме уже есть связь «многие-ко-многим» между студентами и курсами. она реализована через таблицу `enrollments`. мы не храним список студентов в таблице курсов, а создаем отдельную запись на каждого студента.

при проектировании внешних ключей для новых таблиц я использовала разные стратегии `ON DELETE`:
для таблицы `certificates` мы используем **`ON DELETE CASCADE`**. это значит что если удалить курс или пользователя то все сертфикаты удалятся вместе с ними автоматически.
для таблицы `payments` мы используем **`ON DELETE RESTRICT`**. это значит что система запретит удалять пользователя или курс если у них есть финансовые транзакции. это необходимо для сохранения финансовой истории. если бы мы использовали `CASCADE` удаление студента безвозвратно стерло бы все данные о его платежах.




##  часть 3. документирование нарушений

| № | Ограничение | Выполняемый запрос (SQL) | Сообщение СУБД | Понятное сообщение для пользователя | Как исправить |
|---|---|---|---|---|---|
| 1 | CHECK | `INSERT INTO courses (title, teacher_id, price) VALUES ('Test', 1, -100);` | `violates check constraint "courses_price_check"` | Цена курса не может быть отрицательной. | Указать цену >= 0. |
| 2 | FOREIGN KEY | `INSERT INTO enrollments (student_id, course_id) VALUES (9999, 1);` | `violates foreign key constraint "fk_enrollment_student"` | Нельзя записать на курс несуществующего студента. | Создать студента перед записью на курс. |
| 3 | UNIQUE | `INSERT INTO users (email, ...) VALUES ('test@mail.com', ...);` (дважды) | `duplicate key value violates unique constraint "users_email_key"` | Пользователь с таким email уже зарегистрирован. | Использовать другой email. |
| 4 | NOT NULL | `INSERT INTO courses (teacher_id, title) VALUES (1, NULL);` | `null value in column "title" violates not-null constraint` | Название курса обязательно для заполнения. | Указать название курса. |
| 5 | PRIMARY KEY | `INSERT INTO users (user_id, ...) VALUES (1, ...);` | `duplicate key value violates unique constraint "users_pkey"` | Пользователь с таким ID уже существует. | Не указывать ID вручную (использовать SERIAL). |






