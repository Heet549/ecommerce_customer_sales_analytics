# SQL Folder

Target engine: **MySQL 8.0+** (MariaDB 10.x is also compatible).

## Files, in run order

1. **`01_create_database.sql`** — creates the `ecommerce_analytics` database.
2. **`02_create_tables.sql`** — creates all 6 tables with primary keys,
   foreign keys, and indexes. Safe to re-run (drops tables first, in
   dependency-safe order).
3. **`03_import_data.sql`** — loads the 6 CSV files from `/data` into the
   tables using `LOAD DATA LOCAL INFILE`. Each `LOAD DATA` statement uses a
   `/PATH/TO/YOUR/PROJECT/` placeholder — **replace this with the absolute
   path to the project's `/data` folder on your machine** before running.
   See the comment block at the top of that file for Windows and macOS/Linux
   examples.
4. **`04_validation_queries.sql`** — Phase 1E validation queries: row
   counts, primary-key uniqueness, foreign-key integrity, NULL checks,
   duplicate checks, date-range checks, and numeric sanity checks.

## How to run (MySQL CLI example)

```bash
mysql --local-infile=1 -u <your_user> -p < 01_create_database.sql
mysql --local-infile=1 -u <your_user> -p < 02_create_tables.sql
mysql --local-infile=1 -u <your_user> -p ecommerce_analytics < 03_import_data.sql
mysql --local-infile=1 -u <your_user> -p ecommerce_analytics < 04_validation_queries.sql
```

If `LOAD DATA LOCAL INFILE` is rejected, enable it first:
```sql
SET GLOBAL local_infile = 1;
```
and make sure your client connection also allows it (`--local-infile=1` flag,
as shown above, or the equivalent setting in MySQL Workbench's connection
options).

## How these scripts were tested

This sandbox environment could not install a real MySQL/MariaDB server
(package downloads were blocked by network policy). To make sure the logic
in these scripts is actually correct — not just written and assumed to
work — every table definition and every validation query was rebuilt and
executed against the **real CSV data** using SQLite as a functional proxy
(`python/validate_phase1e.py`). Results are saved in
`docs/phase1e_validation_results.txt` and match the Phase 1A audit exactly
(e.g. 0 orphaned foreign keys, 0 duplicate PKs, 9,930 orders before
signup_date, etc.).

**What this proves:** the join logic, group-by logic, and constraint logic
are correct against the provided CSV dataset.
**What this does not prove:** that the exact MySQL syntax (e.g.
`LOAD DATA LOCAL INFILE`, `ENGINE=InnoDB`, `DECIMAL` types) compiles
error-free on a real MySQL server, since none was available in this
environment. The syntax was written carefully to standard MySQL 8 conventions,
but you should run these scripts on your own MySQL/MariaDB instance
(e.g. via MySQL Workbench, XAMPP, or a Docker `mysql` container) and let
this project know if anything needs adjusting.

## Expected results after running `04_validation_queries.sql`

| Check | Expected result |
|---|---|
| Row counts | users=10,000, products=2,000, orders=20,000, order_items=43,525, events=80,000, reviews=15,000 |
| Primary key duplicates | 0 rows for every table |
| Foreign key orphans | 0 rows for every relationship |
| NULLs in required columns | 0 for every column |
| Duplicate full rows | 0 for every table |
| Numeric sanity (negative prices/quantities, out-of-range ratings) | 0 rows |
| `total_amount` vs `SUM(item_total)` mismatch | 0 rows |
| Orders before signup_date (known issue, not an error) | 9,930 rows |
| Reviews before their order's order_date (known issue, not an error) | 7,455 rows |
