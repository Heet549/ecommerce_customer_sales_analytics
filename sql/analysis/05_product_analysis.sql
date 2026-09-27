-- =====================================================================
-- 05_product_analysis.sql
-- PHASE 2E — Product-level performance analysis
--
-- All revenue/units figures come from order_items (the line-item grain),
-- joined to products only for display attributes (name/category/brand).
-- Every GROUP BY here is at product_id grain, so a product appearing in
-- many different orders is aggregated correctly, not double-counted.
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- Business Question: Full per-product performance table — units sold,
-- revenue, average selling price, revenue contribution %.
-- Why it matters: single source-of-truth product performance table that
-- other queries in this file slice differently.
-- Calculation: window function SUM(...) OVER () for the revenue-share
-- percentage avoids a second pass/subquery for the grand total.
-- ---------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    p.price                                                            AS catalog_price,
    SUM(oi.quantity)                                                   AS total_units_sold,
    SUM(oi.item_total)                                                 AS total_revenue,
    ROUND(SUM(oi.item_total) / SUM(oi.quantity), 2)                    AS avg_selling_price,
    ROUND(100.0 * SUM(oi.item_total) / SUM(SUM(oi.item_total)) OVER (), 4)
                                                                         AS pct_of_total_revenue
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category, p.brand, p.price
ORDER BY total_revenue DESC;

-- ---------------------------------------------------------------------
-- Business Question: Which products are the lowest performers by
-- revenue (still sold at least once)?
-- Why it matters: candidates for discontinuation, promotion, or
-- repricing review.
-- Calculation: same product-grain aggregation as above, ascending sort.
-- Products with ZERO sales are intentionally not shown here (an
-- INNER JOIN on order_items only reaches products that were actually
-- ordered) — see the separate "never-sold products" query below for
-- that population, since it needs a LEFT JOIN instead.
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
ORDER BY total_revenue ASC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Business Question: Are there products in the catalog that were never
-- sold at all?
-- Why it matters: a product with sales activity of exactly zero is a
-- different (and more urgent) problem than a "low performer" — an
-- INNER JOIN to order_items would silently hide these products.
-- Calculation: LEFT JOIN from products to order_items, filtered to
-- WHERE the joined order_item_id IS NULL (correct anti-join pattern).
-- ---------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    p.price
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.order_item_id IS NULL;

-- ---------------------------------------------------------------------
-- Business Question: Category-level performance summary (revenue,
-- units, distinct products sold, average selling price).
-- Why it matters: complements the category revenue breakdown in
-- 02_sales_analysis.sql with a product-count dimension — is a
-- category's revenue coming from many products or a few?
-- ---------------------------------------------------------------------
SELECT
    p.category,
    COUNT(DISTINCT p.product_id)                                       AS distinct_products_sold,
    SUM(oi.quantity)                                                   AS total_units_sold,
    SUM(oi.item_total)                                                 AS category_revenue,
    ROUND(SUM(oi.item_total) / COUNT(DISTINCT p.product_id), 2)        AS avg_revenue_per_product
FROM order_items oi
INNER JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category
ORDER BY category_revenue DESC;

-- ---------------------------------------------------------------------
-- Business Question: Which products sell high VOLUME but comparatively
-- low revenue (likely low unit price), and which sell high REVENUE with
-- comparatively low volume (likely premium/high unit price)?
-- Why it matters: separates "popular, cheap" products from "premium,
-- low-frequency" products — different merchandising strategies apply.
-- Calculation: RANK() window functions rank every product independently
-- by units sold and by revenue; a large gap between the two ranks for
-- the same product identifies the pattern requested. Using RANK() (not
-- ROW_NUMBER()) here is intentional in case of exact ties in units or
-- revenue.
-- ---------------------------------------------------------------------
WITH product_perf AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.quantity)    AS total_units_sold,
        SUM(oi.item_total)  AS total_revenue
    FROM order_items oi
    INNER JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name, p.category
),
ranked AS (
    SELECT
        product_id,
        product_name,
        category,
        total_units_sold,
        total_revenue,
        RANK() OVER (ORDER BY total_units_sold DESC)  AS volume_rank,
        RANK() OVER (ORDER BY total_revenue DESC)      AS revenue_rank
    FROM product_perf
)
-- High volume, comparatively low revenue rank (volume_rank much better
-- / lower number than revenue_rank)
SELECT
    'High Volume / Lower Revenue' AS pattern,
    product_id, product_name, category, total_units_sold, total_revenue,
    volume_rank, revenue_rank, (revenue_rank - volume_rank) AS rank_gap
FROM ranked
WHERE volume_rank <= 50
ORDER BY rank_gap DESC
LIMIT 15;

WITH product_perf AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.quantity)    AS total_units_sold,
        SUM(oi.item_total)  AS total_revenue
    FROM order_items oi
    INNER JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name, p.category
),
ranked AS (
    SELECT
        product_id,
        product_name,
        category,
        total_units_sold,
        total_revenue,
        RANK() OVER (ORDER BY total_units_sold DESC)  AS volume_rank,
        RANK() OVER (ORDER BY total_revenue DESC)      AS revenue_rank
    FROM product_perf
)
-- High revenue, comparatively lower volume rank (revenue_rank much
-- better / lower number than volume_rank)
SELECT
    'High Revenue / Lower Volume' AS pattern,
    product_id, product_name, category, total_units_sold, total_revenue,
    volume_rank, revenue_rank, (volume_rank - revenue_rank) AS rank_gap
FROM ranked
WHERE revenue_rank <= 50
ORDER BY rank_gap DESC
LIMIT 15;
