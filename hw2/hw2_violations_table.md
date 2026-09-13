# HW2. Часть 3. Документирование нарушений

| № | Ограничение | Выполняемый запрос (SQL) | Сообщение СУБД | Понятное сообщение для пользователя | Как исправить |
|---|---|---|---|---|---|
| 1 | CHECK | `INSERT INTO Review (...) VALUES (..., 10)` | `new row for relation "review" violates check constraint "review_rating_check"` | «Оценка курса должна быть от 1 до 5. Студент не может поставить 10 баллов.» | Указать значение в диапазоне 1–5 |
| 2 | FOREIGN KEY | `INSERT INTO Enrollment (student_id, course_id) VALUES (..., 99999)` | `insert or update on table "enrollment" violates foreign key constraint "fk_enrollment_course"` | «Нельзя записаться на курс, которого не существует.» | Указать `course_id` существующего курса |
| 3 | UNIQUE | `INSERT INTO Enrollment (...) VALUES (..., ...)` дважды | `duplicate key value violates unique constraint "uq_enrollment"` | «Студент уже записан на этот курс. Повторная запись невозможна.» | Не дублировать запись; обновить существующую |
| 4 | NOT NULL | `INSERT INTO Course (teacher_id, title, price) VALUES (..., NULL, ...)` | `null value in column "title" of relation "course" violates not-null constraint` | «У курса обязательно должно быть название.» | Указать непустое значение `title` |
| 5 | FOREIGN KEY (RESTRICT) | `DELETE FROM "User" WHERE email = 'teacher@test.com'` | `update or delete on table "user" violates foreign key constraint "fk_course_teacher" on table "course"` | «Нельзя удалить преподавателя, пока у него есть курсы.» | Сначала переназначить или удалить курсы |

## Выводы

Все 5 типов ограничений работают корректно:
- **CHECK** защищает от некорректных значений (рейтинг 1–5, цена ≥ 0).
- **FOREIGN KEY** гарантирует ссылочную целостность.
- **UNIQUE** предотвращает дубли.
- **NOT NULL** требует обязательные поля.
- **ON DELETE RESTRICT** защищает от потери важных данных.