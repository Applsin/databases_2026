-- seminar1_cleanup.sql
-- Удаляет все объекты, созданные setup-скриптом семинара №1.

-- шаг 1: удаление схемы seminar1 со всеми объектами
DROP SCHEMA IF EXISTS seminar1 CASCADE;
