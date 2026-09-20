-- =====================================================================
-- Тестовые данные (Food Delivery)
-- Запускать после hw1/03_physical_model.sql и hw2/01_schema_additions.sql.
-- Скрипт воспроизводим: сначала очищает таблицы и сбрасывает счётчики SERIAL,
-- поэтому id ниже всегда получаются 1, 2, 3... в порядке вставки.
-- Даты считаются от NOW(), чтобы запросы «за неделю» и «за месяц» возвращали данные.
-- =====================================================================

TRUNCATE TABLE payments, order_status_history, reviews, order_items,
               orders, dishes, couriers, restaurants, users
    RESTART IDENTITY CASCADE;

-- ---------- Пользователи (id 1..4) ----------
INSERT INTO users (full_name, email, phone) VALUES
    ('Иван Петров',      'ivan.petrov@example.com',      '+79001112233'),
    ('Мария Сидорова',   'maria.sidorova@example.com',   '+79002223344'),
    ('Алексей Смирнов',  'alexey.smirnov@example.com',   '+79003334455'),
    ('Елена Кузнецова',  'elena.kuznetsova@example.com', '+79004445566');

-- ---------- Рестораны (id 1..3) ----------
INSERT INTO restaurants (name, description, address, district) VALUES
    ('Pizza Napoli', 'Итальянская пицца на дровах', 'ул. Ленина, 10',   'Центральный'),
    ('Sushi Master', 'Суши и роллы',                'пр. Мира, 25',     'Центральный'),
    ('Burger House', 'Бургеры и закуски',           'ул. Гагарина, 5',  'Северный');

-- ---------- Курьеры (id 1..2) ----------
INSERT INTO couriers (full_name, phone, vehicle_type) VALUES
    ('Дмитрий Волков', '+79005556677', 'bicycle'),
    ('Ольга Морозова', '+79006667788', 'scooter');

-- ---------- Блюда (id 1..9) ----------
INSERT INTO dishes (restaurant_id, name, price) VALUES
    (1, 'Маргарита',           450.00),   -- 1
    (1, 'Пепперони',           550.00),   -- 2
    (1, 'Кальцоне',            600.00),   -- 3
    (2, 'Ролл Филадельфия',    480.00),   -- 4
    (2, 'Ролл Калифорния',     420.00),   -- 5
    (2, 'Мисо-суп',            250.00),   -- 6
    (3, 'Чизбургер',           320.00),   -- 7
    (3, 'Картофель фри',       150.00),   -- 8
    (3, 'Двойной бургер',      490.00);   -- 9

-- ---------- Заказы (id 1..7) ----------
INSERT INTO orders (user_id, restaurant_id, courier_id, status, delivery_address, created_at, delivered_at) VALUES
    (1, 1, 1,    'delivered',    'ул. Пушкина, 12, кв. 5', NOW() - INTERVAL '2 days',    NOW() - INTERVAL '2 days'    + INTERVAL '40 minutes'),
    (2, 2, 2,    'delivered',    'пр. Победы, 8, кв. 31',  NOW() - INTERVAL '1 day',     NOW() - INTERVAL '1 day'     + INTERVAL '40 minutes'),
    (1, 3, 1,    'delivered',    'ул. Пушкина, 12, кв. 5', NOW() - INTERVAL '3 days',    NOW() - INTERVAL '3 days'    + INTERVAL '40 minutes'),
    (3, 1, 2,    'delivered',    'ул. Садовая, 3',         NOW() - INTERVAL '5 days',    NOW() - INTERVAL '5 days'    + INTERVAL '40 minutes'),
    (4, 2, NULL, 'created',      'ул. Лесная, 17, кв. 2',  NOW() - INTERVAL '5 minutes', NULL),
    (2, 1, 1,    'with_courier', 'пр. Победы, 8, кв. 31',  NOW() - INTERVAL '30 minutes', NULL),
    (3, 2, 2,    'delivered',    'ул. Садовая, 3',         NOW() - INTERVAL '40 days',   NOW() - INTERVAL '40 days'   + INTERVAL '40 minutes');

-- ---------- Позиции заказов ----------
-- В заказе №7 (40 дней назад) ролл Филадельфия стоил 450, сейчас 480 —
-- пример того, зачем в order_items хранится unit_price.
INSERT INTO order_items (order_id, dish_id, quantity, unit_price) VALUES
    (1, 1, 2, 450.00), (1, 2, 1, 550.00),
    (2, 4, 1, 480.00), (2, 5, 2, 420.00),
    (3, 7, 2, 320.00), (3, 8, 1, 150.00),
    (4, 1, 1, 450.00), (4, 3, 1, 600.00),
    (5, 6, 2, 250.00),
    (6, 2, 1, 550.00),
    (7, 4, 3, 450.00);

-- ---------- Отзывы (только на доставленные заказы) ----------
INSERT INTO reviews (order_id, restaurant_rating, courier_rating, review_text) VALUES
    (1, 5, 5,    'Быстро и вкусно'),
    (2, 4, 5,    'Хорошо, но роллы немного остыли'),
    (3, 5, 4,    'Бургеры отличные'),
    (4, 5, 4,    'Пицца супер'),
    (7, 5, 5,    'Как всегда отлично');

-- ---------- История статусов ----------
-- Для каждого заказа записываем все шаги до его текущего статуса.
INSERT INTO order_status_history (order_id, status, changed_at)
SELECT o.order_id, s.status, o.created_at + s.delay_interval
FROM orders o
JOIN (VALUES
        ('created',      1, INTERVAL '0 minutes'),
        ('cooking',      2, INTERVAL '5 minutes'),
        ('with_courier', 3, INTERVAL '20 minutes'),
        ('delivered',    4, INTERVAL '40 minutes')
     ) AS s (status, step, delay_interval)
  ON s.step <= CASE o.status
                   WHEN 'created'      THEN 1
                   WHEN 'cooking'      THEN 2
                   WHEN 'with_courier' THEN 3
                   WHEN 'delivered'    THEN 4
               END;

-- ---------- Оплаты ----------
-- Доставленные заказы и заказ «у курьера» оплачены картой.
INSERT INTO payments (order_id, method, amount, status, created_at, paid_at)
SELECT o.order_id, 'card', SUM(oi.quantity * oi.unit_price), 'paid',
       o.created_at, o.created_at + INTERVAL '1 minute'
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status IN ('delivered', 'with_courier')
GROUP BY o.order_id, o.created_at;

-- Только что созданный заказ — оплата наличными ожидается.
INSERT INTO payments (order_id, method, amount, status, created_at)
SELECT o.order_id, 'cash', SUM(oi.quantity * oi.unit_price), 'pending', o.created_at
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status = 'created'
GROUP BY o.order_id, o.created_at;
