-- seminar5_post_setup.sql
-- Донастройка базы demo для семинара №5: роли и column-level security.
-- Выполняется после загрузки дампа demo.

-- шаг 1: убираем роли, если остались с прошлого раза
DROP ROLE IF EXISTS bank_manager;
DROP ROLE IF EXISTS agro_analyst;

-- шаг 2: создаём групповые роли
CREATE ROLE bank_manager;
CREATE ROLE agro_analyst;

-- шаг 3: отзываем избыточные права у PUBLIC
REVOKE ALL ON DATABASE demo FROM PUBLIC;
REVOKE ALL ON SCHEMA bookings FROM PUBLIC;

-- шаг 4: базовый доступ к базе и схеме
GRANT CONNECT ON DATABASE demo TO bank_manager, agro_analyst;
GRANT USAGE ON SCHEMA bookings TO bank_manager, agro_analyst;

-- шаг 5: полный доступ менеджера к ПДн
GRANT SELECT ON bookings.tickets TO bank_manager;

-- шаг 6: доступ аналитика только к безопасным колонкам
GRANT SELECT (ticket_no, book_ref, passenger_id) ON bookings.tickets TO agro_analyst;

-- шаг 7: финальная проверка
SELECT 'seminar5 roles and grants created' AS status;
