TRUNCATE TABLE reviews, order_items, orders, dishes, couriers, restaurants, users
RESTART IDENTITY CASCADE;

INSERT INTO users (full_name, email, phone) VALUES
('Иван Петров', 'ivan.petrov@example.com', '+79990000001'),
('Анна Смирнова', 'anna.smirnova@example.com', '+79990000002'),
('Максим Волков', 'max.volkov@example.com', '+79990000003'),
('Елена Орлова', 'elena.orlova@example.com', '+79990000004');

INSERT INTO restaurants (name, address, rating, is_active) VALUES
('Траттория Мондо', 'ул. Пушкина, 10', 4.8, TRUE),
('Восточный сад', 'ул. Ленина, 25', 4.6, TRUE),
('Бургер Хаус', 'пр. Мира, 7', 4.3, TRUE);

INSERT INTO couriers (full_name, phone, rating, is_active) VALUES
('Алексей Соколов', '+79991110001', 4.9, TRUE),
('Дмитрий Кузнецов', '+79991110002', 4.7, TRUE),
('Сергей Морозов', '+79991110003', 4.5, TRUE);

INSERT INTO dishes (restaurant_id, name, description, price, is_available) VALUES
(1, 'Маргарита', 'Пицца с томатами, моцареллой и базиликом', 650.00, TRUE),
(1, 'Паста Карбонара', 'Паста с беконом, сыром и соусом', 720.00, TRUE),
(1, 'Тирамису', 'Классический итальянский десерт', 390.00, TRUE),
(2, 'Ролл Филадельфия', 'Ролл с лососем и сливочным сыром', 580.00, TRUE),
(2, 'Лапша с курицей', 'Пшеничная лапша с курицей и овощами', 520.00, TRUE),
(2, 'Мисо-суп', 'Традиционный японский суп', 260.00, TRUE),
(3, 'Классический бургер', 'Говяжья котлета, сыр, овощи и соус', 490.00, TRUE),
(3, 'Картофель фри', 'Картофель фри', 220.00, TRUE),
(3, 'Чизкейк', 'Нежный сливочный десерт', 350.00, TRUE);

INSERT INTO orders (user_id, restaurant_id, courier_id, status, delivery_address, total_amount, created_at) VALUES
(1, 1, 1, 'delivered', 'ул. Центральная, 12', 1370.00, CURRENT_TIMESTAMP - INTERVAL '2 days'),
(2, 2, 2, 'delivered', 'ул. Садовая, 8', 1100.00, CURRENT_TIMESTAMP - INTERVAL '1 day'),
(3, 3, 3, 'preparing', 'ул. Молодёжная, 15', 930.00, CURRENT_TIMESTAMP),
(4, 1, NULL, 'created', 'ул. Новая, 3', 1040.00, CURRENT_TIMESTAMP);

INSERT INTO order_items (order_id, dish_id, quantity, unit_price) VALUES
(1, 1, 1, 650.00),
(1, 2, 1, 720.00),
(2, 4, 1, 580.00),
(2, 6, 2, 260.00),
(3, 7, 1, 490.00),
(3, 8, 2, 220.00),
(4, 1, 1, 650.00),
(4, 3, 1, 390.00);

INSERT INTO reviews (user_id, restaurant_id, order_id, restaurant_rating, delivery_rating, comment) VALUES
(1, 1, 1, 5, 5, 'Отличная еда и быстрая доставка.'),
(2, 2, 2, 4, 5, 'Всё хорошо, курьер приехал вовремя.');
