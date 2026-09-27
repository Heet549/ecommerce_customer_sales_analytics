"""
PHASE 1E - Validation execution script.

MySQL/MariaDB could not be installed in this sandbox (package downloads
were blocked by network policy). To make sure the validation logic in
sql/04_validation_queries.sql is actually correct (not just written and
hoped-for), this script:

  1. Builds an equivalent schema in SQLite (same tables, PK/FK, columns)
  2. Loads the provided CSV data into it
  3. Runs the SQLite-syntax equivalent of every validation query
  4. Prints and saves the actual results

This is a functional proxy for MySQL - it proves the join logic, group-by
logic and constraints are correct against the provided data. It does not
prove MySQL-specific syntax compiles; the person will need to run the
.sql files against a real MySQL/MariaDB server to confirm syntax, but
the underlying logic has been verified here.
"""

import sqlite3
import pandas as pd
import os
from pathlib import Path

# Resolve paths relative to this script's location:
# validate_phase1e.py lives in python/, so go up one level for project root
_HERE = Path(__file__).resolve().parent          # python/
_ROOT = _HERE.parent                              # project root
DATA_DIR = str(_ROOT / "data")
DB_PATH = str(_HERE / "validation_check.db")     # temporary; cleaned up below
OUT_PATH = str(_ROOT / "docs" / "phase1e_validation_results.txt")

if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

conn = sqlite3.connect(DB_PATH)
cur = conn.cursor()
cur.executescript("""
PRAGMA foreign_keys = ON;

CREATE TABLE users (
    user_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    gender TEXT NOT NULL,
    city TEXT NOT NULL,
    signup_date TEXT NOT NULL
);

CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    category TEXT NOT NULL,
    brand TEXT NOT NULL,
    price REAL NOT NULL,
    rating REAL NOT NULL
);

CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    order_date TEXT NOT NULL,
    order_status TEXT NOT NULL,
    total_amount REAL NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE order_items (
    order_item_id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    item_price REAL NOT NULL,
    item_total REAL NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

CREATE TABLE events (
    event_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_timestamp TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE reviews (
    review_id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    rating INTEGER NOT NULL,
    review_text TEXT NOT NULL,
    review_date TEXT NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);
""")
conn.commit()

# Load data (parents first)
for table in ["users", "products", "orders", "order_items", "events", "reviews"]:
    df = pd.read_csv(os.path.join(DATA_DIR, f"{table}.csv"))
    df.to_sql(table, conn, if_exists="append", index=False)

conn.commit()

lines = []
def log(msg=""):
    print(msg)
    lines.append(str(msg))

def run(title, query):
    log(f"\n-- {title} --")
    try:
        res = pd.read_sql_query(query, conn)
        if len(res) == 0:
            log("(0 rows returned)")
        else:
            log(res.to_string())
    except Exception as ex:
        log(f"ERROR: {ex}")

log("=" * 80)
log("PHASE 1E - VALIDATION QUERIES EXECUTED (SQLite proxy for MySQL logic)")
log("=" * 80)

# 1. Row counts
run("Row counts", """
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews;
""")

# 2. PK uniqueness
for tbl, col in [("users","user_id"),("products","product_id"),("orders","order_id"),
                  ("order_items","order_item_id"),("events","event_id"),("reviews","review_id")]:
    run(f"PK uniqueness check: {tbl}.{col} (expect 0 rows)", f"""
        SELECT {col}, COUNT(*) c FROM {tbl} GROUP BY {col} HAVING c > 1;
    """)

# 3. FK orphan checks
fk_checks = [
    ("orders.user_id -> users.user_id", "orders o", "users u", "o.user_id", "u.user_id"),
    ("order_items.order_id -> orders.order_id", "order_items oi", "orders o", "oi.order_id", "o.order_id"),
    ("order_items.product_id -> products.product_id", "order_items oi", "products p", "oi.product_id", "p.product_id"),
    ("events.user_id -> users.user_id", "events e", "users u", "e.user_id", "u.user_id"),
    ("events.product_id -> products.product_id", "events e", "products p", "e.product_id", "p.product_id"),
    ("reviews.order_id -> orders.order_id", "reviews r", "orders o", "r.order_id", "o.order_id"),
    ("reviews.product_id -> products.product_id", "reviews r", "products p", "r.product_id", "p.product_id"),
    ("reviews.user_id -> users.user_id", "reviews r", "users u", "r.user_id", "u.user_id"),
]
for title, child, parent, child_col, parent_col in fk_checks:
    run(f"FK orphan check: {title} (expect 0 rows)", f"""
        SELECT {child_col} FROM {child}
        LEFT JOIN {parent} ON {child_col} = {parent_col}
        WHERE {parent_col} IS NULL;
    """)

# 4. NULL checks
run("NULL check: users (expect all 0)", """
    SELECT
      SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
      SUM(CASE WHEN name IS NULL THEN 1 ELSE 0 END) AS null_name,
      SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS null_email,
      SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END) AS null_gender,
      SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS null_city,
      SUM(CASE WHEN signup_date IS NULL THEN 1 ELSE 0 END) AS null_signup_date
    FROM users;
""")
run("NULL check: orders (expect all 0)", """
    SELECT
      SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
      SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
      SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
      SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_order_status,
      SUM(CASE WHEN total_amount IS NULL THEN 1 ELSE 0 END) AS null_total_amount
    FROM orders;
""")
run("NULL check: products (expect all 0)", """
    SELECT
      SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
      SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS null_product_name,
      SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category,
      SUM(CASE WHEN brand IS NULL THEN 1 ELSE 0 END) AS null_brand,
      SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
      SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END) AS null_rating
    FROM products;
""")
run("NULL check: order_items (expect all 0)", """
    SELECT
      SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS null_order_item_id,
      SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
      SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
      SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
      SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantity,
      SUM(CASE WHEN item_price IS NULL THEN 1 ELSE 0 END) AS null_item_price,
      SUM(CASE WHEN item_total IS NULL THEN 1 ELSE 0 END) AS null_item_total
    FROM order_items;
""")
run("NULL check: events (expect all 0)", """
    SELECT
      SUM(CASE WHEN event_id IS NULL THEN 1 ELSE 0 END) AS null_event_id,
      SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
      SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
      SUM(CASE WHEN event_type IS NULL THEN 1 ELSE 0 END) AS null_event_type,
      SUM(CASE WHEN event_timestamp IS NULL THEN 1 ELSE 0 END) AS null_event_timestamp
    FROM events;
""")
run("NULL check: reviews (expect all 0)", """
    SELECT
      SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END) AS null_review_id,
      SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
      SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
      SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_id,
      SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
      SUM(CASE WHEN review_text IS NULL THEN 1 ELSE 0 END) AS null_review_text,
      SUM(CASE WHEN review_date IS NULL THEN 1 ELSE 0 END) AS null_review_date
    FROM reviews;
""")

# 5. Duplicate full rows
for tbl, cols in [
    ("users", "user_id, name, email, gender, city, signup_date"),
    ("products", "product_id, product_name, category, brand, price, rating"),
    ("orders", "order_id, user_id, order_date, order_status, total_amount"),
]:
    run(f"Duplicate full-row check: {tbl} (expect 0 rows)", f"""
        SELECT {cols}, COUNT(*) c FROM {tbl} GROUP BY {cols} HAVING c > 1;
    """)

# 6. Date validity
run("Date ranges", """
    SELECT
      (SELECT MIN(signup_date) FROM users) AS min_signup,
      (SELECT MAX(signup_date) FROM users) AS max_signup,
      (SELECT MIN(order_date) FROM orders) AS min_order_date,
      (SELECT MAX(order_date) FROM orders) AS max_order_date,
      (SELECT MIN(event_timestamp) FROM events) AS min_event_ts,
      (SELECT MAX(event_timestamp) FROM events) AS max_event_ts,
      (SELECT MIN(review_date) FROM reviews) AS min_review_date,
      (SELECT MAX(review_date) FROM reviews) AS max_review_date;
""")

run("KNOWN ISSUE - orders placed before customer signup_date", """
    SELECT COUNT(*) AS orders_before_signup
    FROM orders o
    JOIN users u ON o.user_id = u.user_id
    WHERE DATE(o.order_date) < DATE(u.signup_date);
""")

run("KNOWN ISSUE - reviews dated before their order's order_date", """
    SELECT COUNT(*) AS reviews_before_order
    FROM reviews r
    JOIN orders o ON r.order_id = o.order_id
    WHERE r.review_date < o.order_date;
""")

# 7. Numeric sanity
run("Numeric sanity: order_items.quantity <= 0 (expect 0 rows)",
    "SELECT * FROM order_items WHERE quantity <= 0;")
run("Numeric sanity: order_items.item_price < 0 (expect 0 rows)",
    "SELECT * FROM order_items WHERE item_price < 0;")
run("Numeric sanity: order_items.item_total < 0 (expect 0 rows)",
    "SELECT * FROM order_items WHERE item_total < 0;")
run("Numeric sanity: orders.total_amount < 0 (expect 0 rows)",
    "SELECT * FROM orders WHERE total_amount < 0;")
run("Numeric sanity: products.price < 0 (expect 0 rows)",
    "SELECT * FROM products WHERE price < 0;")
run("Numeric sanity: products.rating outside 1-5 (expect 0 rows)",
    "SELECT * FROM products WHERE rating < 1 OR rating > 5;")
run("Numeric sanity: reviews.rating outside 1-5 (expect 0 rows)",
    "SELECT * FROM reviews WHERE rating < 1 OR rating > 5;")

run("Cross-check: sum(order_items.item_total) per order vs orders.total_amount (expect 0 mismatching rows)", """
    SELECT o.order_id, o.total_amount, SUM(oi.item_total) AS items_sum,
           ROUND(o.total_amount - SUM(oi.item_total), 2) AS diff
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.order_id, o.total_amount
    HAVING ABS(diff) >= 0.01;
""")

with open(OUT_PATH, "w") as f:
    f.write("\n".join(lines))

conn.close()

# Remove the temporary SQLite DB — it's a build artifact, not a repo file
if os.path.exists(DB_PATH):
    os.remove(DB_PATH)

print(f"\n\nSaved validation results to {OUT_PATH}")
