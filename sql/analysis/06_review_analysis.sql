-- =====================================================================
-- 06_review_analysis.sql
-- PHASE 2F — Review analysis
--
-- IMPORTANT SCOPE NOTE (from Phase 1 data_quality_report.md, Issue 4):
-- reviews.review_text contains only 10 distinct canned phrases across
-- all 15,000 rows. It is treated here strictly as a CATEGORICAL field
-- (frequency counts, distribution by rating/category) — NOT as
-- free-form text. No NLP, tokenization, or sentiment scoring is
-- performed anywhere in this file.
--
-- Any relationship shown between rating and sales below is a
-- correlation/co-occurrence view only. No query in this file claims or
-- implies that rating CAUSES sales volume or revenue.
-- =====================================================================

USE ecommerce_analytics;

-- ---------------------------------------------------------------------
-- Business Question: What is the overall average rating and rating
-- distribution across all 15,000 reviews?
-- Why it matters: baseline customer-satisfaction figure.
-- ---------------------------------------------------------------------
SELECT
    ROUND(AVG(rating), 2)                                              AS avg_rating_all_reviews,
    COUNT(*)                                                           AS total_reviews
FROM reviews;

SELECT
    rating,
    COUNT(*)                                                           AS review_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM reviews), 2)        AS pct_of_reviews
FROM reviews
GROUP BY rating
ORDER BY rating;

-- ---------------------------------------------------------------------
-- Business Question: What is the product-level average rating and
-- review count? (products.rating is the static catalog rating; this
-- computes the actual rating from the reviews table itself for
-- comparison.)
-- Why it matters: PROJECT_OVERVIEW.md business question 12 — compares
-- catalog rating with review-derived rating.
-- Calculation: LEFT JOIN from products (not INNER) so products with
-- zero reviews still appear, with review_count = 0 and avg_review_rating
-- = NULL rather than being silently dropped.
-- ---------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.rating                                                           AS catalog_rating,
    COUNT(r.review_id)                                                 AS review_count,
    ROUND(AVG(r.rating), 2)                                            AS avg_review_rating,
    ROUND(p.rating - AVG(r.rating), 2)                                 AS catalog_vs_review_diff
FROM products p
LEFT JOIN reviews r ON r.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category, p.rating
ORDER BY review_count DESC
LIMIT 25;

-- ---------------------------------------------------------------------
-- Business Question: Which products have unusually HIGH review-derived
-- ratings (with a meaningful review count, to avoid a single 5-star
-- review skewing the result)?
-- Why it matters: identifies genuine quality/customer-love outliers
-- rather than statistical noise from very few reviews.
-- Calculation: HAVING clause enforces a minimum review_count threshold
-- AFTER aggregation — the correct place for a post-aggregate filter
-- (a WHERE clause cannot reference an aggregate like AVG(rating)).
-- ---------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.category,
    COUNT(r.review_id)                                                 AS review_count,
    ROUND(AVG(r.rating), 2)                                            AS avg_review_rating
FROM products p
INNER JOIN reviews r ON r.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category
HAVING COUNT(r.review_id) >= 5
ORDER BY avg_review_rating DESC, review_count DESC
LIMIT 15;

-- ---------------------------------------------------------------------
-- Business Question: Which products have unusually LOW review-derived
-- ratings (same minimum review-count guard)?
-- Why it matters: flags products with a genuine quality/satisfaction
-- problem worth investigating.
-- ---------------------------------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    p.category,
    COUNT(r.review_id)                                                 AS review_count,
    ROUND(AVG(r.rating), 2)                                            AS avg_review_rating
FROM products p
INNER JOIN reviews r ON r.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category
HAVING COUNT(r.review_id) >= 5
ORDER BY avg_review_rating ASC, review_count DESC
LIMIT 15;

-- ---------------------------------------------------------------------
-- Business Question: How frequently does each of the 10 canned
-- review_text phrases occur, and how does each phrase relate to rating?
-- Why it matters: PROJECT_OVERVIEW.md business question 13, scoped
-- explicitly to frequency/categorical analysis (per Issue 4) — this is
-- the realistic ceiling of what review_text supports, not a limitation
-- being worked around.
-- ---------------------------------------------------------------------
SELECT
    review_text,
    COUNT(*)                                                           AS times_used,
    ROUND(AVG(rating), 2)                                              AS avg_rating_when_used,
    MIN(rating)                                                        AS min_rating_seen,
    MAX(rating)                                                        AS max_rating_seen
FROM reviews
GROUP BY review_text
ORDER BY times_used DESC;

-- ---------------------------------------------------------------------
-- Business Question: How does each canned phrase break down across the
-- 1-5 rating scale (e.g. is "Item arrived damaged." exclusively used on
-- 1-2 star reviews, or does it appear across the range)?
-- Why it matters: validates whether the canned phrases are meaningfully
-- tied to rating or largely independent of it — useful context before
-- anyone downstream is tempted to over-interpret review_text.
-- Calculation: conditional aggregation (CASE inside SUM/COUNT) pivots
-- rating values into columns without needing a PIVOT operator (not
-- available in standard MySQL).
-- ---------------------------------------------------------------------
SELECT
    review_text,
    SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END)                        AS rating_1,
    SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END)                        AS rating_2,
    SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END)                        AS rating_3,
    SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END)                        AS rating_4,
    SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END)                        AS rating_5,
    COUNT(*)                                                           AS total_uses
FROM reviews
GROUP BY review_text
ORDER BY total_uses DESC;

-- ---------------------------------------------------------------------
-- Business Question: Do higher-rated products tend to sell more units,
-- viewed as a co-occurrence pattern (NOT a causal claim)?
-- Why it matters: a natural business question, but must be phrased
-- carefully — this query reports association only. Products are bucketed
-- into rating bands and each band's average units sold is compared.
-- ---------------------------------------------------------------------
WITH product_sales AS (
    SELECT
        p.product_id,
        p.rating,
        SUM(oi.quantity)   AS units_sold,
        SUM(oi.item_total) AS revenue
    FROM products p
    LEFT JOIN order_items oi ON oi.product_id = p.product_id
    GROUP BY p.product_id, p.rating
)
SELECT
    CASE
        WHEN rating < 3.0 THEN 'Under 3.0'
        WHEN rating < 4.0 THEN '3.0 - 3.99'
        ELSE '4.0 and above'
    END                                                                 AS catalog_rating_band,
    COUNT(*)                                                           AS num_products,
    ROUND(AVG(units_sold), 2)                                          AS avg_units_sold_per_product,
    ROUND(AVG(revenue), 2)                                             AS avg_revenue_per_product
FROM product_sales
GROUP BY CASE
        WHEN rating < 3.0 THEN 'Under 3.0'
        WHEN rating < 4.0 THEN '3.0 - 3.99'
        ELSE '4.0 and above'
    END
ORDER BY catalog_rating_band;
