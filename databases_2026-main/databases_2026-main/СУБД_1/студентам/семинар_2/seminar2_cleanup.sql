-- seminar2_cleanup.sql
-- Удаляет все объекты, созданные setup-скриптом семинара №2.

-- шаг 1: удаление схемы seminar2 со всеми объектами
DROP SCHEMA IF EXISTS seminar2 CASCADE;
