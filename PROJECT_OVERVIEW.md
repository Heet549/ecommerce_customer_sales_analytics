# E-Commerce Customer & Sales Analytics

## Project Title
**E-Commerce Customer & Sales Analytics: Understanding Revenue, Retention, and Customer Behavior**

## Business Problem
An online e-commerce retailer sells products across 10 categories (Clothing, Electronics,
Groceries, Beauty, Toys, Pet Supplies, Home & Kitchen, Books, Automotive, Sports) to
around 10,000 customers. Management does not have a consolidated, structured view of:

- How revenue is actually being generated (which products, categories, and customers drive it)
- Whether customers come back and buy again, or purchase once and disappear
- Where customers drop off between browsing and buying (view → cart → wishlist → purchase)
- What customers are saying about products through reviews
- Which order statuses (cancelled/returned) are eating into revenue

This project builds a structured analytics workflow — from raw CSV data to a validated
SQL database to Python analysis to an Excel reporting workbook — to answer these
questions using only the data that is actually available.

## Objective
Turn six raw CSV exports (users, products, orders, order_items, events, reviews) into:
1. A clean, validated relational database (MySQL)
2. Reliable, documented business metrics (Python/Pandas)
3. A stakeholder-friendly Excel workbook for reporting

## Dataset Description
The dataset simulates an e-commerce platform's operational data across
**2024-01-01 to 2025-11-14** (~1 year 10.5 months). It contains 10,000 users,
2,000 products, 20,000 orders, 43,525 order line items, 80,000 browsing/behavior
events, and 15,000 product reviews. Referential integrity between tables is
strong (verified in Phase 1A/1E — zero orphaned foreign keys). See
`docs/phase1a_dataset_audit.md` for the full audit and
`docs/data_quality_report.md` for known data-quality caveats (most notably:
signup/order/event/review dates are independently randomized and are **not**
chronologically consistent with each other — see that report before building
any "time since signup" or "days to first purchase" style metric).

## Tables

| Table | Rows | Grain | Primary Key |
|---|---|---|---|
| `users` | 10,000 | one row per customer | `user_id` |
| `products` | 2,000 | one row per product | `product_id` |
| `orders` | 20,000 | one row per order | `order_id` |
| `order_items` | 43,525 | one row per line item within an order | `order_item_id` |
| `events` | 80,000 | one row per browsing/behavior event | `event_id` |
| `reviews` | 15,000 | one row per product review | `review_id` |

See `docs/data_model.md` for the full relationship diagram and the exact
foreign-key verification results.

## Main Business Questions
Only questions the provided data can answer are included:

**Sales & Revenue**
1. What is total revenue, order volume, and average order value, and how do they trend over time?
2. Which product categories and brands generate the most revenue?
3. What share of orders end up cancelled or returned, and what revenue does that represent?

**Customers**
4. Who are the highest-value customers (by total spend / number of orders)?
5. How many orders does a typical customer place (order frequency)?
6. What does repeat-purchase behavior look like — how many customers buy more than once?
7. How is the customer base distributed by gender and city?

**Products**
8. Which products/categories have the highest and lowest customer ratings?
9. Which products are purchased most vs. most viewed (view-to-purchase behavior)?

**Behavioral (events)**
10. What does the funnel from view → cart/wishlist → purchase look like, by event counts?
11. Which event type is most common, and how does event activity vary?

**Reviews**
12. What is the distribution of review ratings, and how does it compare with product catalog ratings?
13. What are the most common review phrases, and how do they relate to rating level?
   *(Note: `review_text` in this dataset is a fixed set of 10 canned phrases, not free-form
   text — see `docs/data_quality_report.md`. This limits review analysis to
   frequency/category patterns, not open-ended NLP/sentiment modeling.)*

## Tools Used
- **SQL (MySQL-compatible)** — schema design, data loading, validation queries, and
  business-question queries
- **Python / Pandas** — data cleaning, exploratory analysis, metric calculation
- **Excel** — final reporting workbook (analysis tables, KPI reporting, formulas, and charts) for stakeholders

No Power BI. No machine learning. No unnecessary engineering complexity.

## Project Status

All four phases are complete. See `README.md` for a full phase-by-phase
summary of what was built and validated.

- ✅ Phase 1 — Dataset audit, business objective, SQL database, data quality report, SQL validation
- ✅ Phase 2 — SQL business analysis (7 modules: KPIs, sales, customers, lifecycle, products, reviews, events)
- ✅ Phase 3 — Python/Pandas EDA (Jupyter notebook; full SQL ↔ Pandas reconciliation — 21 metrics, all MATCH)
- ✅ Phase 4 — Excel reporting workbook (Dashboard, KPI summary, analysis tabs, three-way validation tab)
