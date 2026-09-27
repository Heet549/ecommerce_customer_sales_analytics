# Phase 1A — Dataset Audit

Full raw script output (every column, every check) is saved at
`docs/phase1a_audit_raw_output.txt`, produced by `python/audit_phase1a.py`.
This document summarizes the findings per table.

---

## 1. users.csv

- **Rows:** 10,000 | **Columns:** 6
- **Columns:** `user_id, name, email, gender, city, signup_date`
- **Missing values:** none in any column
- **Duplicate rows:** 0
- **Duplicate `user_id`:** 0 | **Duplicate `email`:** 0
- **Primary key:** `user_id` (10,000 unique values / 10,000 rows)
- **`gender`** — 3 values: `Male` (3,247), `Female` (3,334), `Other` (3,419)
- **`city`** — 7,755 unique city values (free-text, high cardinality)
- **`signup_date`** — type DATE, range **2024-01-01 to 2025-11-14**, all values parse cleanly
- **Suspicious values:** none found (no placeholder nulls like "N/A", "unknown", etc.; all emails contain "@")

## 2. products.csv

- **Rows:** 2,000 | **Columns:** 6
- **Columns:** `product_id, product_name, category, brand, price, rating`
- **Missing values:** none
- **Duplicate rows:** 0
- **Primary key:** `product_id` (2,000 unique / 2,000 rows)
- **`category`** — 10 values, fairly balanced: Clothing (213), Toys (213), Pet Supplies (212),
  Beauty (207), Electronics (203), Home & Kitchen (199), Books (194), Automotive (193),
  Groceries (183), Sports (183)
- **`brand`** — 12 distinct brands (Astra, NeoTech, Acme, Nimbus, Zenith, Everest, Harbor,
  Orion, GreenLeaf, Solace, Willow, Pulse)
- **`price`** — numeric, range **$1.11 to $2,338.13**, mean ≈$200.34
- **`rating`** — numeric, range **2.50 to 4.90**, mean ≈3.68 (catalog/product-level rating,
  distinct from individual `reviews.rating`)
- **Suspicious values:** none (no negative prices, no ratings outside a plausible 1–5 scale)

## 3. orders.csv

- **Rows:** 20,000 | **Columns:** 5
- **Columns:** `order_id, user_id, order_date, order_status, total_amount`
- **Missing values:** none
- **Duplicate rows:** 0
- **Primary key:** `order_id` (20,000 unique / 20,000 rows)
- **Foreign key:** `user_id` → `users.user_id` (0 orphan rows — every order belongs to a real user)
- **`order_date`** — datetime with microseconds, range **2024-01-01 to 2025-11-14**
- **`order_status`** — 5 values, fairly balanced: shipped (4,113), returned (4,066),
  completed (4,021), cancelled (3,920), processing (3,880)
- **`total_amount`** — numeric, range **$1.11 to $7,950.74**, mean ≈$595.93
- **Verified:** `total_amount` matches `SUM(order_items.item_total)` exactly for all 20,000 orders

## 4. order_items.csv

- **Rows:** 43,525 | **Columns:** 7
- **Columns:** `order_item_id, order_id, product_id, user_id, quantity, item_price, item_total`
- **Missing values:** none
- **Duplicate rows:** 0
- **Primary key:** `order_item_id` (43,525 unique / 43,525 rows)
- **Foreign keys:** `order_id` → `orders.order_id`, `product_id` → `products.product_id`,
  `user_id` → `users.user_id` — all 0 orphan rows
- **`quantity`** — integer, range 1–3, no zero/negative values
- **`item_price`** — always equals the product's catalog `price` at the time of lookup (verified for all rows)
- **`item_total`** — always equals `quantity × item_price` (consistent with `item_price` and `quantity`)
- **Note:** `user_id` on this table is redundant with the `user_id` on the parent `orders`
  row (verified 0 mismatches across all 43,525 rows) — see `data_model.md`

## 5. events.csv

- **Rows:** 80,000 | **Columns:** 5
- **Columns:** `event_id, user_id, product_id, event_type, event_timestamp`
- **Missing values:** none
- **Duplicate rows:** 0
- **Primary key:** `event_id` (80,000 unique / 80,000 rows)
- **Foreign keys:** `user_id` → `users.user_id`, `product_id` → `products.product_id` — 0 orphan rows
- **`event_type`** — 4 values: view (56,013), cart (12,035), wishlist (7,946), purchase (4,006)
- **`event_timestamp`** — datetime with microseconds, range **2024-01-01 to 2025-11-14**

## 6. reviews.csv

- **Rows:** 15,000 | **Columns:** 7
- **Columns:** `review_id, order_id, product_id, user_id, rating, review_text, review_date`
- **Missing values:** none
- **Duplicate rows:** 0
- **Primary key:** `review_id` (15,000 unique / 15,000 rows)
- **Foreign keys:** `order_id` → `orders.order_id`, `product_id` → `products.product_id`,
  `user_id` → `users.user_id` — 0 orphan rows
- **`rating`** — integer 1–5. Distribution: 1★(594), 2★(2,084), 3★(4,289), 4★(4,624), 5★(3,409)
- **`review_text`** — **only 10 distinct phrases exist across all 15,000 rows**
  (e.g. "Item arrived damaged.", "Highly recommend this brand.", "Value for money.").
  This is a fixed/canned text field, not free-form review content.
- **`review_date`** — datetime with microseconds, range **2024-01-01 to 2025-11-14**

---

## Cross-Table Relationships (verified from data)

See `docs/data_model.md` for the full relationship diagram. In summary:

```
users     ──< orders ──< order_items
users     ──< events
users     ──< reviews
products  ──< order_items
products  ──< events
products  ──< reviews
orders    ──< reviews
```

All foreign keys were checked with actual orphan-row queries — **zero invalid
foreign keys found anywhere in the dataset.**

## Date-Logic Observations (see data_quality_report.md for full detail)

- **~49.7% of orders (9,930 / 20,000)** have an `order_date` earlier than the
  ordering customer's own `signup_date`.
- **~49.7% of reviews (7,455 / 15,000)** have a `review_date` earlier than the
  `order_date` of the order they are attached to.
- **~49.6% of events (39,703 / 80,000)** have an `event_timestamp` earlier
  than the user's `signup_date`.

These are treated as a **known limitation of the synthetic dataset**
(dates across tables appear to be generated independently within the same
overall 2024-01-01 to 2025-11-14 window, rather than being generated in a
logically consistent sequence per customer). They are documented, not
silently fixed — see the Data Quality Report for the recommended handling.
