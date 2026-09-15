-- 1. Активные рестораны с рейтингом выше 4.5
SELECT restaurant_id, name, address, rating
FROM restaurants
WHERE rating > 4.5 AND is_active = TRUE
ORDER BY rating DESC;

-- 2. Топ-10 блюд за последнюю неделю
SELECT d.dish_id, d.name, r.name AS restaurant_name,
       SUM(oi.quantity) AS ordered_quantity
FROM order_items oi
JOIN dishes d ON d.dish_id = oi.dish_id
JOIN restaurants r ON r.restaurant_id = d.restaurant_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
  AND o.status <> 'cancelled'
GROUP BY d.dish_id, d.name, r.name
ORDER BY ordered_quantity DESC
LIMIT 10;

-- 3. Полная информация о заказе №1
SELECT o.order_id, o.created_at, o.status,
       u.full_name AS customer, r.name AS restaurant,
       c.full_name AS courier, d.name AS dish,
       oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price AS item_total
FROM orders o
JOIN users u ON u.user_id = o.user_id
JOIN restaurants r ON r.restaurant_id = o.restaurant_id
LEFT JOIN couriers c ON c.courier_id = o.courier_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN dishes d ON d.dish_id = oi.dish_id
WHERE o.order_id = 1
ORDER BY d.name;

-- 4. Выручка ресторанов за текущий месяц
SELECT r.restaurant_id, r.name,
       COALESCE(SUM(o.total_amount), 0) AS revenue
FROM restaurants r
LEFT JOIN orders o
  ON o.restaurant_id = r.restaurant_id
 AND o.status = 'delivered'
 AND o.created_at >= date_trunc('month', CURRENT_TIMESTAMP)
 AND o.created_at < date_trunc('month', CURRENT_TIMESTAMP) + INTERVAL '1 month'
GROUP BY r.restaurant_id, r.name
ORDER BY revenue DESC;

-- 5. Курьеры с более чем 100 доставками и рейтингом >= 4.5
SELECT c.courier_id, c.full_name, c.phone, c.rating,
       COUNT(o.order_id) AS delivered_orders
FROM couriers c
JOIN orders o ON o.courier_id = c.courier_id
WHERE o.status = 'delivered'
GROUP BY c.courier_id, c.full_name, c.phone, c.rating
HAVING COUNT(o.order_id) > 100 AND c.rating >= 4.5
ORDER BY delivered_orders DESC;
