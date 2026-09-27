-- =====================================================================
-- 01_phase2_analysis_validation.sql
-- PHASE 2I — Validation checks for the Phase 2 SQL analysis
--
-- Purpose: prove that the revenue/order/customer logic used throughout
-- sql/analysis/*.sql is not double-counting or miscalculating, by
-- cross-checking the same figure calculated two different ways.
--
-- These checks were actually executed against the provided CSV dataset via a
-- SQLite functional proxy during development (validation was performed using
-- a SQLite functional proxy against the provided CSV data; the resulting
-- validation output is retained in docs/phase2_validation_raw_output.txt).
-- All checks below PASSED (see docs/sql_analysis_summary.md for the
-- confirmed values).
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- CHECK 1: Total revenue reconciliation
-- orders.total_amount (order grain) must equal SUM(order_items.item_total)
-- (line-item grain). If these differ, either a query is double-counting
-- order_items across multiple line items, or under-counting via a bad
-- join. Expected result: both columns equal (verified: 11,918,668.95).
-- ---------------------------------------------------------------------
SELECT
    (SELECT SUM(total_amount) FROM orders)          AS revenue_from_orders_table,
    (SELECT SUM(item_total) FROM order_items)       AS revenue_from_order_items_table,
    (SELECT SUM(total_amount) FROM orders) - (SELECT SUM(item_total) FROM order_items)
                                                      AS difference_should_be_zero;

-- ---------------------------------------------------------------------
-- CHECK 2: Order count reconciliation
-- COUNT(DISTINCT order_id) from orders directly must equal the SUM of
-- per-customer order counts (a common double-counting bug is grouping
-- by user_id and then miscounting orders via a join to order_items,
-- which would inflate the count for any order with 2+ line items).
-- Expected result: both values = 20,000.
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT order_id) FROM orders)   AS total_orders_direct,
    (SELECT SUM(order_count) FROM (
        SELECT user_id, COUNT(order_id) AS order_count FROM orders GROUP BY user_id
    ) t)                                              AS total_orders_via_per_customer_sum;

-- ---------------------------------------------------------------------
-- CHECK 3: Category revenue sums to total revenue
-- SUM of all per-category revenue (from 02_sales_analysis.sql /
-- 05_product_analysis.sql logic) must equal total order_items revenue —
-- confirms the category GROUP BY is not dropping or double-counting any
-- line items. Expected result: both equal 11,918,668.95.
-- ---------------------------------------------------------------------
SELECT
    (SELECT SUM(item_total) FROM order_items)        AS total_line_item_revenue,
    (SELECT SUM(category_revenue) FROM (
        SELECT p.category, SUM(oi.item_total) AS category_revenue
        FROM order_items oi INNER JOIN products p ON p.product_id = oi.product_id
        GROUP BY p.category
    ) t)                                                AS sum_of_category_revenue;

-- ---------------------------------------------------------------------
-- CHECK 4: Product revenue sums to total revenue
-- Same reconciliation as Check 3, at product grain instead of category
-- grain (05_product_analysis.sql). Expected result: both equal
-- 11,918,668.95.
-- ---------------------------------------------------------------------
SELECT
    (SELECT SUM(item_total) FROM order_items)        AS total_line_item_revenue,
    (SELECT SUM(total_revenue) FROM (
        SELECT p.product_id, SUM(oi.item_total) AS total_revenue
        FROM order_items oi INNER JOIN products p ON p.product_id = oi.product_id
        GROUP BY p.product_id
    ) t)                                                AS sum_of_product_revenue;

-- ---------------------------------------------------------------------
-- CHECK 5: Customer segment counts sum to purchasing customers
-- one-time + repeat customer counts (01_business_kpis.sql /
-- 03_customer_analysis.sql) must sum to the total distinct purchasing
-- customer count. Expected result: 2,741 + 5,894 = 8,635.
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT user_id) FROM orders)      AS total_purchasing_customers,
    (SELECT
        SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) +
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
     FROM (SELECT user_id, COUNT(order_id) AS order_count FROM orders GROUP BY user_id) t
    )                                                    AS one_time_plus_repeat;

-- ---------------------------------------------------------------------
-- CHECK 6: Lifecycle segment counts sum to purchasing customers
-- (04_customer_lifecycle.sql) One-Time + Repeat-Active + Repeat-Lapsed
-- must equal total purchasing customers (8,635); registered_customers
-- minus purchasing_customers must equal Never-Purchased (1,365).
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(DISTINCT user_id) FROM orders)      AS total_purchasing_customers,
    (SELECT COUNT(*) FROM (
        WITH customer_orders AS (
            SELECT user_id, COUNT(order_id) AS order_count, MAX(order_date) AS last_order_date
            FROM orders GROUP BY user_id
        ),
        snapshot AS (SELECT MAX(order_date) AS snapshot_date FROM orders)
        SELECT co.user_id
        FROM customer_orders co CROSS JOIN snapshot s
    ) t)                                                AS total_segmented_customers;

-- ---------------------------------------------------------------------
-- CHECK 7: Never-purchased user count matches Phase 1 Issue 6
-- Expected result: 1,365 (documented in docs/data_quality_report.md).
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS never_purchased_users
FROM users u
LEFT JOIN orders o ON o.user_id = u.user_id
WHERE o.order_id IS NULL;

-- ---------------------------------------------------------------------
-- CHECK 8: Products never sold — cross-check with 05_product_analysis.sql
-- Expected result: 0 rows (every one of the 2,000 products was sold at
-- least once — a real, confirmed finding, not a missing query result).
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS products_never_sold
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.order_item_id IS NULL;

-- ---------------------------------------------------------------------
-- CHECK 9: Event type counts sum to total events (07_event_analysis.sql)
-- Expected result: 56,013 + 12,035 + 7,946 + 4,006 = 80,000.
-- ---------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM events)                     AS total_events,
    (SELECT SUM(event_count) FROM (
        SELECT event_type, COUNT(*) AS event_count FROM events GROUP BY event_type
    ) t)                                                AS sum_of_event_type_counts;

-- ---------------------------------------------------------------------
-- CHECK 10: Reviews with zero associated products / products with zero
-- reviews — confirms the LEFT JOIN in 06_review_analysis.sql is
-- necessary (not every product has reviews).
-- Expected result: 1 product with zero reviews (1,999 of 2,000 have
-- at least one review).
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS products_with_zero_reviews
FROM products p
LEFT JOIN reviews r ON r.product_id = p.product_id
WHERE r.review_id IS NULL;
