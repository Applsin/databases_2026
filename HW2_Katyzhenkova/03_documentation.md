# ДЗ №2. Документация

**Домен:** Project Management
**Выполнила:** Катыженкова Софья Евгеньевна
**Группа:** ДЭ15-25

## Часть 1. Две новые таблицы

**`time_entries`** — реестр затраченного времени по задачам. Нужна, чтобы отвечать на частый запрос №5 из ДЗ №1: «среднее время выполнения задач по проектам». По каждой задаче видно, сколько часов реально потратил сотрудник. Ограничения: `hours_spent > 0 AND <= 24` (нельзя работать больше суток в день), `worked_on <= CURRENT_DATE` (нельзя списать время в будущем), FK на `tasks` с `ON DELETE CASCADE` (удалили задачу — ушли и её трудозатраты), FK на `employees` с `ON DELETE RESTRICT` (нельзя удалить сотрудника, если по нему есть часы — сначала нужно разобраться с записями).

**`project_members`** — состав участников проекта с ролью. В ДЗ №1 был только исполнитель задачи, а явного списка «кто в проекте» не было. Роли ограничены значениями `manager / member / observer`. Первичный ключ составной `(project_id, employee_id)` — один сотрудник не может дважды входить в один проект. Оба FK с `ON DELETE CASCADE`: если удалить проект или сотрудника, запись об участии теряет смысл.

### Реализация M:N

В ДЗ №1 связь «задача — тег» реализована через связующую таблицу `task_tags` с составным PK `(task_id, tag_id)`. Это классический способ: обе стороны имеют свои PK, а ассоциация живёт в отдельной таблице.

Альтернатива — хранить теги в `JSONB` прямо в `tasks`. Это быстрее читается без JOIN, но теряется целостность (нельзя поставить FK на тег) и сложнее искать «все задачи с тегом X». Поэтому выбран связующий стол.

**Что будет при `DROP TABLE tasks CASCADE`:** PostgreSQL удалит не только `tasks`, но и все объекты, которые от неё зависят. В нашем случае это `comments`, `task_tags`, `time_entries` и `task_status_history` (у всех FK на `tasks` с `ON DELETE CASCADE`). `tags`, `employees`, `projects` останутся — они независимы. Это ожидаемое поведение: задача — центральная сущность, без неё её дочерние записи не нужны.

## Часть 2. Демонстрация нарушений

Все 5 блоков используют конструкцию `DO $$ ... EXCEPTION ... END $$`, перехватывают конкретный тип ошибки и выводят сообщение через `RAISE NOTICE`.

## Часть 3. Таблица нарушений

| № | Ограничение | Выполняемый запрос (SQL) | Сообщение СУБД | Понятное сообщение для пользователя | Как исправить |
|---|---|---|---|---|---|
| 1 | CHECK | `INSERT INTO time_entries (task_id, employee_id, hours_spent, worked_on) VALUES (1, 1, -3, CURRENT_DATE)` | `new row for relation "time_entries" violates check constraint "time_entries_hours_spent_check"` | Количество затраченных часов должно быть положительным и не больше 24 | Указать значение в диапазоне от 0 до 24 |
| 2 | FOREIGN KEY | `INSERT INTO time_entries (task_id, employee_id, hours_spent, worked_on) VALUES (999, 1, 4, CURRENT_DATE)` | `insert or update on table "time_entries" violates foreign key constraint "time_entries_task_id_fkey"` | Нельзя записать трудозатраты по несуществующей задаче | Сначала создать задачу с нужным task_id или указать существующий |
| 3 | UNIQUE | `INSERT INTO employees (first_name, last_name, email, hire_date) VALUES ('Дубль', 'Дублёв', 'ivan@company.com', CURRENT_DATE)` | `duplicate key value violates unique constraint "employees_email_key"` | Сотрудник с таким email уже зарегистрирован | Использовать уникальный email |
| 4 | NOT NULL | `INSERT INTO comments (task_id, author_id, body) VALUES (1, 1, NULL)` | `null value in column "body" of relation "comments" violates not-null constraint` | Комментарий не может быть пустым, текст обязателен | Передать непустой текст комментария |
| 5 | PRIMARY KEY (составной) | `INSERT INTO project_members (project_id, employee_id, role_in_project) VALUES (1, 1, 'member')` | `duplicate key value violates unique constraint "project_members_pkey"` | Сотрудник уже состоит в этом проекте, повторное добавление запрещено | Не добавлять повторно или обновить роль через UPDATE |

## Краткие выводы

- Все пять типов ограничений (CHECK, FK, UNIQUE, NOT NULL, PK) реально работают и не дают записать некорректные данные. Это и есть целостность на уровне СУБД, а не приложения.
- `DO $$ ... EXCEPTION ... END $$` позволяет перехватить ошибку и превратить техническое сообщение в понятное пользователю. Без этого исключение просто прервало бы транзакцию.
- Проверка показала: если не добавить CHECK на `from_status` / `to_status`, туда можно записать мусор (что и было замечанием по ДЗ №1 — исправлено).
- Индексы на FK (`time_entries.task_id`, `time_entries.employee_id`, `project_members.employee_id`) нужны, чтобы запросы вида «все трудозатраты по задаче» или «все проекты сотрудника» не делали Seq Scan.
- Для M:N выбран связующий стол с составным PK — это единственный способ сохранить ссылочную целостность на обе стороны. JSONB-вариант быстрее, но теряет FK и усложняет выборки.
