-- =====================================================================
-- 02_create_tables.sql
-- Creates all 6 tables for the e-commerce dataset.
--
-- Data types, keys and constraints below are based on the actual
-- Phase 1A audit of the CSV files (see docs/phase1a_dataset_audit.md
-- and docs/data_quality_report.md). Nothing here is invented -
-- every column matches a column that exists in the source CSVs.
--
-- Table creation order matters because of foreign keys:
--   users, products  ->  orders  ->  order_items
--   users, products  ->  events
--   users, orders, products -> reviews
-- =====================================================================

USE ecommerce_analytics;

-- Drop in reverse dependency order (safe re-run)
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS users;

-- ---------------------------------------------------------------------
-- users
-- Source: users.csv | 10,000 rows | user_id is unique -> primary key
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id      VARCHAR(10)  NOT NULL,
    name         VARCHAR(100) NOT NULL,
    email        VARCHAR(150) NOT NULL,
    gender       VARCHAR(10)  NOT NULL,   -- observed values: Male, Female, Other
    city         VARCHAR(100) NOT NULL,
    signup_date  DATE         NOT NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- products
-- Source: products.csv | 2,000 rows | product_id is unique -> primary key
-- ---------------------------------------------------------------------
CREATE TABLE products (
    product_id    VARCHAR(10)    NOT NULL,
    product_name  VARCHAR(150)   NOT NULL,
    category      VARCHAR(50)    NOT NULL,  -- 10 observed categories
    brand         VARCHAR(50)    NOT NULL,  -- 12 observed brands
    price         DECIMAL(10,2)  NOT NULL,
    rating        DECIMAL(3,2)   NOT NULL,  -- observed range 2.50 - 4.90
    PRIMARY KEY (product_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- orders
-- Source: orders.csv | 20,000 rows | order_id is unique -> primary key
-- Every orders.user_id value exists in users.user_id (verified).
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    order_id      VARCHAR(10)     NOT NULL,
    user_id       VARCHAR(10)     NOT NULL,
    order_date    DATETIME(6)     NOT NULL,
    order_status  VARCHAR(20)     NOT NULL,  -- observed: processing, shipped, completed, cancelled, returned
    total_amount  DECIMAL(10,2)   NOT NULL,
    PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_order_date ON orders(order_date);
CREATE INDEX idx_orders_status ON orders(order_status);

-- ---------------------------------------------------------------------
-- order_items
-- Source: order_items.csv | 43,525 rows | order_item_id is unique -> PK
-- Verified: order_items.user_id always equals orders.user_id for the
-- same order_id (0 mismatches out of 43,525 rows). This column is kept
-- because it exists in the source file, but it is redundant with
-- orders.user_id - see data_quality_report.md.
-- ---------------------------------------------------------------------
CREATE TABLE order_items (
    order_item_id  VARCHAR(10)    NOT NULL,
    order_id       VARCHAR(10)    NOT NULL,
    product_id     VARCHAR(10)    NOT NULL,
    user_id        VARCHAR(10)    NOT NULL,
    quantity       INT             NOT NULL,
    item_price     DECIMAL(10,2)  NOT NULL,
    item_total     DECIMAL(10,2)  NOT NULL,
    PRIMARY KEY (order_item_id),
    CONSTRAINT fk_orderitems_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_orderitems_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_orderitems_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE INDEX idx_orderitems_order_id ON order_items(order_id);
CREATE INDEX idx_orderitems_product_id ON order_items(product_id);
CREATE INDEX idx_orderitems_user_id ON order_items(user_id);

-- ---------------------------------------------------------------------
-- events
-- Source: events.csv | 80,000 rows | event_id is unique -> primary key
-- Behavioural log: view / cart / wishlist / purchase events per user/product.
-- ---------------------------------------------------------------------
CREATE TABLE events (
    event_id          VARCHAR(10)  NOT NULL,
    user_id            VARCHAR(10)  NOT NULL,
    product_id         VARCHAR(10)  NOT NULL,
    event_type         VARCHAR(20)  NOT NULL,  -- observed: view, cart, wishlist, purchase
    event_timestamp    DATETIME(6)  NOT NULL,
    PRIMARY KEY (event_id),
    CONSTRAINT fk_events_user
        FOREIGN KEY (user_id) REFERENCES users(user_id),
    CONSTRAINT fk_events_product
        FOREIGN KEY (product_id) REFERENCES products(product_id)
) ENGINE=InnoDB;

CREATE INDEX idx_events_user_id ON events(user_id);
CREATE INDEX idx_events_product_id ON events(product_id);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_timestamp ON events(event_timestamp);

-- ---------------------------------------------------------------------
-- reviews
-- Source: reviews.csv | 15,000 rows | review_id is unique -> primary key
-- review_text is a short canned phrase, not free-form text (only 10
-- distinct phrases exist in the whole file) - see data_quality_report.md.
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    review_id     VARCHAR(10)   NOT NULL,
    order_id      VARCHAR(10)   NOT NULL,
    product_id    VARCHAR(10)   NOT NULL,
    user_id       VARCHAR(10)   NOT NULL,
    rating        TINYINT        NOT NULL,  -- observed range 1-5
    review_text   VARCHAR(255)  NOT NULL,
    review_date   DATETIME(6)   NOT NULL,
    PRIMARY KEY (review_id),
    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_reviews_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_reviews_user
        FOREIGN KEY (user_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

CREATE INDEX idx_reviews_order_id ON reviews(order_id);
CREATE INDEX idx_reviews_product_id ON reviews(product_id);
CREATE INDEX idx_reviews_user_id ON reviews(user_id);
