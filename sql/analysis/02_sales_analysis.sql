-- =====================================================================
-- 02_sales_analysis.sql
-- PHASE 2B — Sales analysis: revenue and order volume over time,
-- product- and category-level performance.
--
-- Grain reminder (from Phase 1 docs/data_model.md):
--   orders       = 1 row per order (order_date, total_amount live here)
--   order_items  = 1 row per line item within an order (avg ~2.18 per
--                  order); product-level revenue MUST come from here,
--                  not from orders.total_amount, because total_amount is
--                  an order-level total covering possibly several
--                  products.
-- Time-based queries use orders.order_date only (internally consistent
-- within the orders table itself). They do NOT compare order_date
-- against signup_date, event_timestamp, or review_date.
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- Business Question: How does revenue and order volume trend month over
-- month across the dataset's ~22.5 month window (2024-01 to 2025-11)?
-- Why it matters: baseline trend line for any revenue narrative;
-- surfaces seasonality or growth/decline.
-- Calculation: revenue/orders grouped by order-level month. No
-- order_items join — order-level grain avoids multi-row inflation.
-- ---------------------------------------------------------------------
SELECT
    DATE_FORMAT(order_date, '%Y-%m')                                   AS order_month,
    COUNT(DISTINCT order_id)                                           AS order_count,
    SUM(total_amount)                                                  AS monthly_revenue,
    ROUND(SUM(total_amount) / COUNT(DISTINCT order_id), 2)             AS monthly_avg_order_value
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY order_month;

-- ---------------------------------------------------------------------
-- Business Question: Same trend, but net of cancelled/returned orders —
-- what did the business actually keep each month?
-- Why it matters: gross monthly revenue can hide a cancellation/return
-- problem concentrated in specific months.
-- ---------------------------------------------------------------------
SELECT
    DATE_FORMAT(order_date, '%Y-%m')                                   AS order_month,
    COUNT(DISTINCT CASE WHEN order_status NOT IN ('cancelled','returned')
                        THEN order_id END)                              AS net_order_count,
    SUM(CASE WHEN order_status NOT IN ('cancelled','returned')
             THEN total_amount ELSE 0 END)                              AS net_monthly_revenue
FROM orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY order_month;

-- ---------------------------------------------------------------------
-- Business Question: Which individual products generate the most
-- revenue?
-- Why it matters: identifies the products the business depends on most.
-- Calculation: order_items joined to products, revenue = SUM(item_total)
-- (already quantity x item_price at the line-item grain — no need to
-- multiply again). Grouping by product_id (and product_name/category
-- for readability) keeps one row per product; this is the correct grain
-- to aggregate at, so no order-level double counting occurs even though
-- a product can appear on many different orders.
-- ---------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    SUM(oi.quantity)                                                   AS total_units_sold,
    SUM(oi.item_total)                                                 AS total_revenue,
    ROUND(SUM(oi.item_total) / SUM(oi.quantity), 2)                    AS avg_selling_price
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category, p.brand
ORDER BY total_revenue DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Business Question: Which products sell the highest unit volume
-- (regardless of price point)?
-- Why it matters: high-volume, lower-price products matter for
-- inventory/logistics planning even if they aren't top revenue drivers.
-- ---------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(oi.quantity)                                                   AS total_units_sold,
    SUM(oi.item_total)                                                 AS total_revenue
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_units_sold DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Business Question: Which categories generate the most revenue and
-- order volume, and what share of total revenue does each represent?
-- Why it matters: category mix drives merchandising/marketing priority.
-- Calculation: window function SUM(...) OVER () gives the grand total
-- alongside each category row in a single pass, avoiding a separate
-- correlated subquery for the percentage.
-- ---------------------------------------------------------------------
SELECT
    p.category,
    COUNT(DISTINCT oi.order_id)                                        AS orders_containing_category,
    SUM(oi.quantity)                                                   AS total_units_sold,
    SUM(oi.item_total)                                                 AS category_revenue,
    ROUND(
        100.0 * SUM(oi.item_total) / SUM(SUM(oi.item_total)) OVER ()
    , 2)                                                                AS pct_of_total_revenue
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY category_revenue DESC;

-- ---------------------------------------------------------------------
-- Business Question: How many distinct orders include each category,
-- and what's the average order value for orders in that category?
-- Why it matters: distinguishes "revenue driver" from "frequently
-- purchased" — a category can drive revenue via a few large orders or
-- via many small, frequent ones.
-- Calculation: COUNT(DISTINCT oi.order_id) prevents inflating the order
-- count when an order has multiple line items in the same category.
-- ---------------------------------------------------------------------
SELECT
    p.category,
    COUNT(DISTINCT oi.order_id)                                        AS distinct_orders,
    ROUND(SUM(oi.item_total) / COUNT(DISTINCT oi.order_id), 2)         AS avg_line_revenue_per_order
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY distinct_orders DESC;

-- ---------------------------------------------------------------------
-- Business Question: Which brands generate the most revenue?
-- Why it matters: PROJECT_OVERVIEW.md business question 2 asks about
-- categories AND brands specifically.
-- ---------------------------------------------------------------------
SELECT
    p.brand,
    COUNT(DISTINCT oi.order_id)                                        AS distinct_orders,
    SUM(oi.quantity)                                                   AS total_units_sold,
    SUM(oi.item_total)                                                 AS brand_revenue
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY p.brand
ORDER BY brand_revenue DESC;

-- ---------------------------------------------------------------------
-- Business Question: Within each category, which is the single
-- top-revenue product? (useful for a "category leaders" report page)
-- Why it matters: turns a flat product list into an actionable,
-- one-per-category leaderboard.
-- Calculation: CTE ranks products within category by revenue using
-- ROW_NUMBER() (a window function), then filters to rank = 1. This is a
-- genuine case for a window function — a plain GROUP BY cannot express
-- "top 1 per group" cleanly.
-- ---------------------------------------------------------------------
WITH product_revenue AS (
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        SUM(oi.item_total) AS product_revenue
    FROM order_items oi
    INNER JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.category, p.product_id, p.product_name
),
ranked AS (
    SELECT
        category,
        product_id,
        product_name,
        product_revenue,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY product_revenue DESC) AS category_rank
    FROM product_revenue
)
SELECT category, product_id, product_name, product_revenue
FROM ranked
WHERE category_rank = 1
ORDER BY product_revenue DESC;
