import os
import psycopg2

CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "dbname": os.getenv("DB_NAME", "food_delivery"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "postgres"),
}

TABLES = ["users", "restaurants", "dishes", "couriers", "orders", "order_items", "reviews"]

def main():
    print("Подключение к PostgreSQL...")
    conn = psycopg2.connect(**CONFIG)
    cur = conn.cursor()
    print("Подключение успешно.\n")

    for table in TABLES:
        cur.execute(f"SELECT COUNT(*) FROM {table};")
        print(f"{table:15} -> {cur.fetchone()[0]} записей")

    print("\nЗаказы:")
    cur.execute("""
        SELECT o.order_id, u.full_name, r.name, o.status, o.total_amount
        FROM orders o
        JOIN users u ON u.user_id = o.user_id
        JOIN restaurants r ON r.restaurant_id = o.restaurant_id
        ORDER BY o.order_id;
    """)
    for row in cur.fetchall():
        print(row)

    cur.close()
    conn.close()
    print("\nПроверка завершена.")

if __name__ == "__main__":
    main()
