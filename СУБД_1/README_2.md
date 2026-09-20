# ДЗ №2. Часть 3. Документирование нарушений целостности

Скрипт: [`Дз2.sql`](Дз2.sql). Работает поверх схемы `hw1`, созданной в [`Дз1.sql`](Дз1.sql).

## Как запустить

```bash
docker exec -i pg16_check psql -U postgres -d postgres < Дз1.sql
docker exec -i pg16_check psql -U postgres -d postgres < Дз2.sql
```

Сообщения выводятся через `RAISE NOTICE`. В графическом клиенте они попадают не в сетку
результатов, а в панель вывода сервера (в DBeaver — вкладка Output), поэтому проще
смотреть их в терминале.

## Таблица нарушений

| № | Ограничение | Выполняемый запрос (SQL) | Сообщение СУБД | Понятное сообщение для пользователя | Как исправить |
|---|---|---|---|---|---|
| 1 | `CHECK` | `INSERT INTO payouts (...) VALUES (123, 12345, '2026-10-01', '2026-09-01', 100, 'paid', now())` | `[23514] new row for relation "payouts" violates check constraint "payouts_check"` | «Период выплаты задан неверно: дата окончания раньше даты начала» | Указать `period_end` строго позже `period_start` |
| 2 | `UNIQUE` | `INSERT INTO payouts (...) VALUES (2, 1, '2026-09-01', '2026-09-30', 5000, 'paid', now())` после такой же выплаты с `id = 1` | `[23505] duplicate key value violates unique constraint "payouts_teacher_id_period_start_key"` | «Преподавателю уже начислена выплата за этот период, повторное начисление запрещено» | Изменить существующую выплату вместо создания новой либо задать другой отчётный период |
| 3 | `NOT NULL` | `INSERT INTO payouts (...) VALUES (3, 1, '2026-10-01', '2026-10-31', NULL, 'pending', now())` | `[23502] null value in column "amount" of relation "payouts" violates not-null constraint` | «Нельзя создать выплату без суммы: сумма к перечислению обязательна» | Передать сумму; для месяца без продаж указать `0` |
| 4 | `FOREIGN KEY` | `INSERT INTO payouts (...) VALUES (4, 999, '2026-11-01', '2026-11-30', 7000, 'pending', now())` | `[23503] insert or update on table "payouts" violates foreign key constraint "payouts_teacher_id_fkey"` | «Выплата привязана к несуществующему преподавателю: получатель должен быть зарегистрирован» | Указать `teacher_id` существующего пользователя из `users` |
| 5 | `FOREIGN KEY` при удалении (`ON DELETE RESTRICT`) | `DELETE FROM lessons WHERE id = 1` при наличии отметок о прохождении | `[23503] update or delete on table "lessons" violates foreign key constraint "lesson_progress_lesson_id_fkey" on table "lesson_progress"` | «Нельзя удалить урок: по нему есть отметки о прохождении, история обучения студентов была бы потеряна» | Сначала перенести или удалить связанные записи прогресса, либо архивировать урок вместо удаления |
