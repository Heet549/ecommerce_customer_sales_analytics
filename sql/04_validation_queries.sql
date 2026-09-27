-- =====================================================================
-- 04_validation_queries.sql
-- PHASE 1E - Data validation queries.
--
-- These queries check row counts, primary-key uniqueness, foreign-key
-- integrity, NULLs, duplicates, date validity and numeric sanity.
--
-- Every query in this file was translated to SQLite and actually
-- executed against the provided CSV dataset during Phase 1A/1E (see
-- python/validate_phase1e.py and docs/phase1e_validation_results.txt
-- for the executed results). The syntax below is written for MySQL.
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- 1. ROW COUNTS
-- ---------------------------------------------------------------------
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews;
-- Expected: users=10000, products=2000, orders=20000,
--           order_items=43525, events=80000, reviews=15000

-- ---------------------------------------------------------------------
-- 2. PRIMARY KEY UNIQUENESS (should all return 0 rows)
-- ---------------------------------------------------------------------
SELECT user_id, COUNT(*) FROM users GROUP BY user_id HAVING COUNT(*) > 1;
SELECT product_id, COUNT(*) FROM products GROUP BY product_id HAVING COUNT(*) > 1;
SELECT order_id, COUNT(*) FROM orders GROUP BY order_id HAVING COUNT(*) > 1;
SELECT order_item_id, COUNT(*) FROM order_items GROUP BY order_item_id HAVING COUNT(*) > 1;
SELECT event_id, COUNT(*) FROM events GROUP BY event_id HAVING COUNT(*) > 1;
SELECT review_id, COUNT(*) FROM reviews GROUP BY review_id HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------
-- 3. FOREIGN KEY INTEGRITY (orphan check - should all return 0 rows)
-- These are redundant once FOREIGN KEY constraints exist in MySQL, but
-- are kept as explicit checks for documentation / non-InnoDB scenarios.
-- ---------------------------------------------------------------------
SELECT o.order_id FROM orders o
LEFT JOIN users u ON o.user_id = u.user_id
WHERE u.user_id IS NULL;

SELECT oi.order_item_id FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT oi.order_item_id FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT e.event_id FROM events e
LEFT JOIN users u ON e.user_id = u.user_id
WHERE u.user_id IS NULL;

SELECT e.event_id FROM events e
LEFT JOIN products p ON e.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT r.review_id FROM reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT r.review_id FROM reviews r
LEFT JOIN products p ON r.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT r.review_id FROM reviews r
LEFT JOIN users u ON r.user_id = u.user_id
WHERE u.user_id IS NULL;

-- ---------------------------------------------------------------------
-- 4. NULL CHECKS on required (NOT NULL) columns
-- (Column list mirrors every column in every table - should all be 0)
-- ---------------------------------------------------------------------
SELECT
  SUM(user_id IS NULL)     AS null_user_id,
  SUM(name IS NULL)        AS null_name,
  SUM(email IS NULL)       AS null_email,
  SUM(gender IS NULL)      AS null_gender,
  SUM(city IS NULL)        AS null_city,
  SUM(signup_date IS NULL) AS null_signup_date
FROM users;

SELECT
  SUM(order_id IS NULL)      AS null_order_id,
  SUM(user_id IS NULL)       AS null_user_id,
  SUM(order_date IS NULL)    AS null_order_date,
  SUM(order_status IS NULL)  AS null_order_status,
  SUM(total_amount IS NULL)  AS null_total_amount
FROM orders;

-- (repeat the same pattern for products, order_items, events, reviews
--  in the executed Python validation - see docs/phase1e_validation_results.txt)

-- ---------------------------------------------------------------------
-- 5. DUPLICATE FULL ROWS (should all be 0)
-- ---------------------------------------------------------------------
SELECT user_id, name, email, gender, city, signup_date, COUNT(*)
FROM users
GROUP BY user_id, name, email, gender, city, signup_date
HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------
-- 6. DATE VALIDITY
-- ---------------------------------------------------------------------
-- Range of dates per table
SELECT MIN(signup_date), MAX(signup_date) FROM users;
SELECT MIN(order_date), MAX(order_date) FROM orders;
SELECT MIN(event_timestamp), MAX(event_timestamp) FROM events;
SELECT MIN(review_date), MAX(review_date) FROM reviews;

-- KNOWN DATA ISSUE (documented, not corrected - see data_quality_report.md):
-- Orders placed before the customer's own signup_date.
SELECT COUNT(*) AS orders_before_signup
FROM orders o
JOIN users u ON o.user_id = u.user_id
WHERE DATE(o.order_date) < u.signup_date;
-- Actual result on this dataset: 9,930 out of 20,000 orders (~49.7%)

-- KNOWN DATA ISSUE: reviews dated before the order they belong to.
SELECT COUNT(*) AS reviews_before_order
FROM reviews r
JOIN orders o ON r.order_id = o.order_id
WHERE r.review_date < o.order_date;
-- Actual result on this dataset: 7,455 out of 15,000 reviews (~49.7%)

-- ---------------------------------------------------------------------
-- 7. NUMERIC SANITY CHECKS (should all return 0 rows / 0 count)
-- ---------------------------------------------------------------------
SELECT * FROM order_items WHERE quantity <= 0;
SELECT * FROM order_items WHERE item_price < 0;
SELECT * FROM order_items WHERE item_total < 0;
SELECT * FROM orders WHERE total_amount < 0;
SELECT * FROM products WHERE price < 0;
SELECT * FROM products WHERE rating < 1 OR rating > 5;
SELECT * FROM reviews WHERE rating < 1 OR rating > 5;

-- Cross-check: sum(order_items.item_total) per order should equal
-- orders.total_amount (verified: matches for all 20,000 orders)
SELECT o.order_id, o.total_amount, SUM(oi.item_total) AS items_sum,
       ROUND(o.total_amount - SUM(oi.item_total), 2) AS diff
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.total_amount
HAVING ABS(diff) >= 0.01;
