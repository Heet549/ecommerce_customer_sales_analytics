-- =====================================================================
-- 03_import_data.sql
-- Loads the 6 CSV files into the tables created in 02_create_tables.sql.
--
-- HOW TO RUN (MySQL Workbench / CLI):
--   1. Replace the placeholder path /PATH/TO/YOUR/PROJECT/ in every
--      LOAD DATA LOCAL INFILE line below with the absolute path to the
--      project's /data folder on your own machine.
--      Example (Windows):  'C:/Projects/ecommerce-analytics/data/users.csv'
--      Example (macOS/Linux): '/home/yourname/ecommerce-analytics/data/users.csv'
--   2. Make sure local_infile is enabled:
--        mysql --local-infile=1 -u <user> -p
--        SET GLOBAL local_infile = 1;
--   3. Run this script AFTER 01_create_database.sql and
--      02_create_tables.sql.
--
-- Load order matters (parents before children) to satisfy foreign keys:
--   users, products  ->  orders  ->  order_items
--                                ->  events
--                                ->  reviews
--
-- Timestamp handling:
-- The source CSVs store timestamps in ISO-8601 format with 'T' as the
-- separator, e.g. 2025-09-09T14:52:37.292731
-- MySQL DATETIME(6) does not accept the 'T' separator directly, so each
-- timestamp column is loaded into a user variable and converted with
-- REPLACE(...,'T',' ') before being stored.
-- =====================================================================

USE ecommerce_analytics;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- users  (signup_date is a plain DATE: YYYY-MM-DD, no conversion needed)
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '/PATH/TO/YOUR/PROJECT/data/users.csv'
INTO TABLE users
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(user_id, name, email, gender, city, signup_date);

-- ---------------------------------------------------------------------
-- products
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '/PATH/TO/YOUR/PROJECT/data/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(product_id, product_name, category, brand, price, rating);

-- ---------------------------------------------------------------------
-- orders
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '/PATH/TO/YOUR/PROJECT/data/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_id, user_id, @order_date_raw, order_status, total_amount)
SET order_date = REPLACE(@order_date_raw, 'T', ' ');

-- ---------------------------------------------------------------------
-- order_items
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '/PATH/TO/YOUR/PROJECT/data/order_items.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(order_item_id, order_id, product_id, user_id, quantity, item_price, item_total);

-- ---------------------------------------------------------------------
-- events
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '/PATH/TO/YOUR/PROJECT/data/events.csv'
INTO TABLE events
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(event_id, user_id, product_id, event_type, @event_timestamp_raw)
SET event_timestamp = REPLACE(@event_timestamp_raw, 'T', ' ');

-- ---------------------------------------------------------------------
-- reviews
-- ---------------------------------------------------------------------
LOAD DATA LOCAL INFILE '/PATH/TO/YOUR/PROJECT/data/reviews.csv'
INTO TABLE reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, order_id, product_id, user_id, rating, review_text, @review_date_raw)
SET review_date = REPLACE(@review_date_raw, 'T', ' ');

SET FOREIGN_KEY_CHECKS = 1;

-- Quick sanity check after load
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews;
