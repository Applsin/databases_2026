-- 7. Районы доставки
DROP TABLE IF EXISTS restaurant_delivery_zones CASCADE;
DROP TABLE IF EXISTS districts CASCADE;

CREATE TABLE districts (
    district_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    base_delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0.0 CHECK (base_delivery_fee >= 0.0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 8. Зоны доставки ресторанов (реализация связи M:N)
CREATE TABLE restaurant_delivery_zones (
    restaurant_id INTEGER NOT NULL,
    district_id INTEGER NOT NULL,
    delivery_time_min INTEGER NOT NULL CHECK (delivery_time_min > 0),
    PRIMARY KEY (restaurant_id, district_id),
    FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id) ON DELETE CASCADE,
    FOREIGN KEY (district_id) REFERENCES districts(district_id) ON DELETE CASCADE
);

-- Индексы для оптимизации частого запроса: "рестораны в конкретном районе"
CREATE INDEX idx_restaurant_delivery_zones_district_id ON restaurant_delivery_zones(district_id);
CREATE INDEX idx_restaurant_delivery_zones_restaurant_id ON restaurant_delivery_zones(restaurant_id);

