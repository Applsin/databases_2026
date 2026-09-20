-- =====================================================================
-- ДЗ №2, Часть 1. Дополнение схемы (Food Delivery)
-- Запускать ПОСЛЕ hw1/03_physical_model.sql.
-- Скрипт воспроизводим: свои таблицы удаляет и создаёт заново,
-- индексы создаёт через IF NOT EXISTS / DROP INDEX IF EXISTS.
-- =====================================================================

DROP TABLE IF EXISTS payments             CASCADE;
DROP TABLE IF EXISTS order_status_history CASCADE;


-- ---------------------------------------------------------------------
-- Новая таблица 1: order_status_history — история статусов заказа
-- Зачем: в orders.status лежит только ТЕКУЩИЙ статус. Чтобы ответить
-- «когда заказ передали курьеру и когда доставили», нужна история.
-- Связь: Order 1 — N OrderStatusHistory (у заказа несколько записей).
-- ---------------------------------------------------------------------
CREATE TABLE order_status_history (
    history_id SERIAL,
    order_id   INTEGER      NOT NULL,
    status     VARCHAR(20)  NOT NULL,
    changed_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    note       VARCHAR(255),                       -- причина / комментарий (например, причина отмены)

    CONSTRAINT pk_order_status_history PRIMARY KEY (history_id),
    -- история — часть заказа: удалили заказ -> удалилась и его история
    CONSTRAINT fk_history_order FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE CASCADE,
    CONSTRAINT chk_history_status
        CHECK (status IN ('created', 'cooking', 'with_courier', 'delivered', 'cancelled')),
    -- каждый статус у заказа фиксируется не более одного раза.
    -- Заодно этот индекс (order_id, status) ускоряет выборку истории по order_id.
    CONSTRAINT uq_history_order_status UNIQUE (order_id, status)
);


-- ---------------------------------------------------------------------
-- Новая таблица 2: payments — оплата заказа
-- Зачем: оплата — отдельный факт со своим жизненным циклом (ожидает, оплачен,
-- ошибка, возврат). Попыток оплаты у заказа может быть несколько
-- (первая не прошла, вторая прошла) -> связь 1:N.
-- ---------------------------------------------------------------------
CREATE TABLE payments (
    payment_id SERIAL,
    order_id   INTEGER       NOT NULL,
    method     VARCHAR(20)   NOT NULL,
    amount     NUMERIC(10,2) NOT NULL,
    status     VARCHAR(20)   NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at    TIMESTAMP,

    CONSTRAINT pk_payments PRIMARY KEY (payment_id),
    -- финансовые записи не должны исчезать вместе с заказом -> RESTRICT
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE RESTRICT,
    CONSTRAINT chk_payments_method CHECK (method IN ('card', 'cash', 'sbp')),
    CONSTRAINT chk_payments_amount CHECK (amount > 0),
    CONSTRAINT chk_payments_status CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    -- время оплаты есть тогда и только тогда, когда деньги были получены
    CONSTRAINT chk_payments_paid_at
        CHECK ((status IN ('paid', 'refunded')) = (paid_at IS NOT NULL))
);

-- FK-индекс (нужен для JOIN и для проверки RESTRICT при удалении заказа)
CREATE INDEX idx_payments_order_id ON payments (order_id);

-- Бизнес-правило: заказ нельзя оплатить дважды.
-- Частичный уникальный индекс: уникальность действует только среди строк со статусом 'paid'
-- (неудачных и ожидающих попыток может быть сколько угодно).
CREATE UNIQUE INDEX uq_payments_one_paid_per_order ON payments (order_id) WHERE status = 'paid';


-- ---------------------------------------------------------------------
-- Индексы под частые запросы из ДЗ №1 (подробности — в 04_documentation.md)
-- ---------------------------------------------------------------------

-- Q1. Рестораны района с рейтингом выше порога.
-- Частичный индекс: неактивные рестораны в выдачу не попадают, в индексе их нет.
CREATE INDEX IF NOT EXISTS idx_restaurants_district_active
    ON restaurants (district) WHERE is_active;

-- Q4/Q5. Заказы ресторана за период (выручка за месяц).
-- Составной индекс (restaurant_id, created_at) заменяет одиночный FK-индекс из ДЗ №1:
-- он по-прежнему покрывает поиск по restaurant_id (левая часть индекса).
DROP INDEX IF EXISTS idx_orders_restaurant_id;
CREATE INDEX IF NOT EXISTS idx_orders_restaurant_created ON orders (restaurant_id, created_at);

-- Q3. Топ блюд за последнюю неделю: диапазон по дате без привязки к ресторану.
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders (created_at);

-- История заказов пользователя (свежие сверху). Заменяет одиночный FK-индекс по user_id.
DROP INDEX IF EXISTS idx_orders_user_id;
CREATE INDEX IF NOT EXISTS idx_orders_user_created ON orders (user_id, created_at DESC);
