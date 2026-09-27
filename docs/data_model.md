# Data Model

This data model was **derived from the data itself**, not assumed. Every
relationship listed below was checked with an actual join/orphan-check query
against the full dataset (see `python/audit_phase1a.py` and
`python/validate_phase1e.py`, results in `docs/phase1a_audit_raw_output.txt`
and `docs/phase1e_validation_results.txt`).

## Tables and Primary Keys

| Table | Rows | Primary Key | Verified unique? |
|---|---|---|---|
| `users` | 10,000 | `user_id` | Yes — 10,000/10,000 unique |
| `products` | 2,000 | `product_id` | Yes — 2,000/2,000 unique |
| `orders` | 20,000 | `order_id` | Yes — 20,000/20,000 unique |
| `order_items` | 43,525 | `order_item_id` | Yes — 43,525/43,525 unique |
| `events` | 80,000 | `event_id` | Yes — 80,000/80,000 unique |
| `reviews` | 15,000 | `review_id` | Yes — 15,000/15,000 unique |

## Verified Relationships (Foreign Keys)

| Child table.column | Parent table.column | Orphan rows found |
|---|---|---|
| `orders.user_id` | `users.user_id` | 0 |
| `order_items.order_id` | `orders.order_id` | 0 |
| `order_items.product_id` | `products.product_id` | 0 |
| `order_items.user_id` | `users.user_id` | 0 |
| `events.user_id` | `users.user_id` | 0 |
| `events.product_id` | `products.product_id` | 0 |
| `reviews.order_id` | `orders.order_id` | 0 |
| `reviews.product_id` | `products.product_id` | 0 |
| `reviews.user_id` | `users.user_id` | 0 |

Referential integrity is 100% clean — no invalid foreign keys anywhere in the dataset.

## Relationship Diagram (text form)

```
users (10,000)
  │ user_id
  ├──< orders (20,000)              [1 user → many orders]
  │       │ order_id
  │       ├──< order_items (43,525) [1 order → many line items]
  │       └──< reviews (15,000)     [1 order → 0..many reviews]
  │
  ├──< events (80,000)              [1 user → many events]
  └──< reviews (15,000)             [1 user → many reviews]

products (2,000)
  │ product_id
  ├──< order_items (43,525)         [1 product → many line items]
  ├──< events (80,000)              [1 product → many events]
  └──< reviews (15,000)             [1 product → many reviews]
```

## Notes on Cardinality (verified, not assumed)

- **users → orders**: one-to-many. 8,635 distinct users out of 10,000 placed at
  least one order (i.e. ~1,365 users have never ordered — normal for an
  e-commerce platform: browsers/sign-ups who haven't purchased).
- **orders → order_items**: one-to-many. All 20,000 orders have at least one
  order_item row (verified: 0 orders with zero matching items). Average ≈2.18
  line items per order (43,525 order-line rows / 20,000 orders); total units
  sold = 60,818 (SUM of quantity across all order_items).
- **order_items.user_id is redundant with orders.user_id.** The dataset stores
  `user_id` directly on `order_items` as well as on `orders`. This was checked
  row-by-row: for all 43,525 order_items rows, `order_items.user_id` always
  matches the `user_id` of its parent order in `orders` (0 mismatches). This
  column is denormalized (duplicated for convenience) rather than an
  independent relationship. It is still kept in the SQL schema because it
  exists in the source file, but analysis should treat `orders.user_id` as
  the source of truth.
- **orders → reviews**: one order can have zero, one, or multiple reviews
  (multiple line items in one order can each be reviewed). Only 11,070 of the
  20,000 orders have at least one review.
- **users → events**: 9,995 of 10,000 users have at least one event recorded
  (5 users have zero browsing activity logged).
- **order_items.item_price vs. products.price**: verified identical for all
  43,525 rows (item_price always equals the product's catalog price at time
  of lookup — there is no independent/historical pricing in this dataset).
- **orders.total_amount vs. sum(order_items.item_total)**: verified identical
  (to the cent) for all 20,000 orders. `total_amount` is fully derivable from
  `order_items` and is not an independent figure.

## Why there is no single combined "denormalized" table
The six tables represent genuinely different grains (customer, product,
order, order line, browsing event, review) and are combined via SQL JOINs or
Pandas merges as needed per analysis — this keeps the model simple and
realistic for a Data Analyst project rather than pre-flattening everything
into one wide table.
