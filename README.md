# E-Commerce Customer & Sales Analytics — Project README

Portfolio-ready Data Analyst project built from a synthetic six-table e-commerce
CSV dataset, using **SQL + Python/Pandas + Excel** (no Power BI, no
unnecessary ML/software-engineering complexity).

See `PROJECT_OVERVIEW.md` for the business problem, objective, and main
business questions.

## Current Status: Project Complete ✅

- ✅ Phase 1A — Full dataset audit
- ✅ Phase 1B — Business objective defined
- ✅ Phase 1C — MySQL-compatible database schema created
- ✅ Phase 1D — Data cleaning plan documented
- ✅ Phase 1E — SQL validation queries written **and actually executed/verified**
- ✅ Phase 2 — SQL business analysis (KPIs, sales, customers, lifecycle,
  products, reviews, events) — **written and validated against the provided CSV data**
- ✅ Phase 3 — Python/Pandas EDA — **reproduces and reconciles every metric**
- ✅ Phase 4 — Excel reporting workbook — **Built, validated, and finalized without unverified manipulations**.

## Folder Structure

```
project/
│
├── PROJECT_OVERVIEW.md          <- business problem, objective, questions, tools
├── README.md                    <- this file
│
├── data/                        
│   └── (6 untouched CSVs)
│
├── sql/
│   └── (Database schema, import scripts, validated analysis queries)
│
├── python/
│   ├── notebooks/
│   ├── scripts/
│   └── outputs/                 <- SQL-vs-Pandas reconciliation CSV and charts
│
├── excel/                       
│   └── ecommerce_analytics_dashboard.xlsx  <- Phase 4 Final Dashboard & Validation
│
└── docs/
    ├── excel_dashboard_summary.md          <- Phase 4 dashboard explanation
    ├── final_business_insights.md          <- End-to-end strategic observations
    └── ... (prior documentation)
```

## What Has Been Completed

1. **Full audit of all 6 CSV files** — row/column counts, data types, missing
   values, duplicates, primary/foreign key candidates, date ranges, and
   value distributions. See `docs/phase1a_dataset_audit.md`.
2. **Verified data model** — every foreign-key relationship between the 6
   tables was checked with real orphan-row queries against the data (not
   assumed). Zero invalid foreign keys found. See `docs/data_model.md`.
3. **Business objective and scope** defined in `PROJECT_OVERVIEW.md`, using
   only questions the dataset can actually answer.
4. **MySQL-compatible database schema** (`sql/02_create_tables.sql`) with
   primary keys, foreign keys, and genuinely useful indexes — no
   over-engineering.
5. **Data import script** (`sql/03_import_data.sql`) using `LOAD DATA LOCAL
   INFILE`, including correct handling of the dataset's ISO-8601 timestamp
   format.
6. **Data cleaning plan** (`docs/data_quality_report.md`) — every real issue
   found (cross-table date inconsistencies, canned review text, a redundant
   column) documented with Problem / Why it's a problem / Action / Why this
   action was chosen. **No rows were deleted or altered.**
7. **SQL validation queries** (`sql/04_validation_queries.sql`) covering row
   counts, PK uniqueness, FK integrity, NULLs, duplicates, date validity,
   and numeric sanity — **actually executed** against the provided CSV dataset
   (via a SQLite functional proxy, since a real MySQL server could not be
   installed in this sandbox — see `sql/README.md` for full explanation).
   Results saved in `docs/phase1e_validation_results.txt`.

## Known Data Limitations (do not re-derive these — already documented)

- Dates across tables (`signup_date`, `order_date`, `event_timestamp`,
  `review_date`) are not chronologically consistent with each other for
  roughly half the dataset (e.g. ~49.7% of orders predate the customer's own
  signup date). This is a structural property of the dataset, not something
  to "fix." Avoid metrics that depend on cross-table date ordering. Full
  detail in `docs/data_quality_report.md`.
- `reviews.review_text` is a fixed set of only 10 canned phrases — treat it
  as categorical, not free text.

## What Was Completed in Phase 2

1. **7 business-question-organized SQL analysis files**
   (`sql/analysis/01`–`07`) covering business KPIs, sales trends,
   customer metrics, customer lifecycle, product performance, review
   analysis, and event/behavioral analysis — each query documents its
   business question, why it matters, and its calculation logic.
2. **Validated business KPIs** — total revenue (gross/net), total
   orders, total customers, items sold, AOV, revenue per customer,
   repeat/one-time customer rates — verified with explicit
   double-counting cross-checks (`sql/validation/01_phase2_analysis_validation.sql`).
3. **A defensible customer lifecycle model** (`sql/analysis/04_customer_lifecycle.sql`)
   based on order count and order recency only — deliberately **not**
   based on `signup_date`, per the Phase 1 date-quality finding. Full
   methodology in `docs/customer_lifecycle_definition.md`.
4. **Review analysis treating `review_text` as categorical only** — no
   NLP/sentiment modeling, consistent with Phase 1's finding that it is
   a fixed set of 10 canned phrases.
5. **Event/funnel analysis** using the dataset's actual 4 event types
   (`view`, `cart`, `wishlist`, `purchase`), built as an aggregate
   funnel (not a chronological per-user sequence), consistent with the
   event-timestamp date-quality limitation.
6. **Every query validated against the provided CSV dataset** via the same
   SQLite functional-proxy method used in Phase 1 (validation was performed
   during development using a SQLite functional proxy against the provided
   CSV data; the resulting validation output is retained in
   `docs/phase2_validation_raw_output.txt`),
   with explicit reconciliation checks (e.g. total revenue calculated
   two different ways always matches: $11,918,668.95).

See `docs/sql_analysis_summary.md` for full findings, assumptions, and
limitations.

## What Was Completed in Phase 3

1. **Fully executed Jupyter notebook** (`python/notebooks/ecommerce_analysis.ipynb`)
   reproducing every validated Phase 2 KPI, customer metric, lifecycle
   segmentation, product ranking, review statistic, and event-funnel
   figure independently in Pandas, reading directly from the raw CSVs
   (no database dependency).
2. **Data validation re-confirmed in Pandas** — row counts, missing
   values, duplicates, PK uniqueness, FK integrity, date ranges, numeric
   ranges — all agree with Phase 1.
3. **A worked example of the one-to-many merge risk** — the notebook
   deliberately shows what happens if `orders` and `order_items` are
   merged naively and revenue is summed on the inflated result (~2.18x
   too high), then shows the correct order-level calculation.
4. **Full SQL-vs-Pandas reconciliation** — 21 metrics compared side by
   side (`python/outputs/sql_vs_pandas_reconciliation.csv`); all 21
   match exactly. One real discrepancy (an 18-customer lifecycle
   miscount caused by flooring fractional days instead of comparing
   them continuously) was found, root-caused, and fixed during
   development — see `docs/pandas_analysis_summary.md` for the full
   investigation.
5. **7 business-relevant charts** saved to `python/outputs/` (monthly
   revenue/orders trend, category revenue, customer revenue
   distribution, lifecycle segment sizes, top products, rating
   distribution, aggregate event funnel).
6. **`review_text` treated strictly as categorical** (no NLP/sentiment
   analysis) and the event funnel explicitly labeled as aggregate, not a
   verified per-user chronological sequence — both consistent with
   Phase 1/2's documented data limitations.

See `docs/pandas_analysis_summary.md` for full findings, assumptions,
and limitations.

## What Was Completed in Phase 4 (Excel Dashboard)

1. **Native Excel Aggregation Tabs**: Generated precise isolated views for Sales, Products, Customers, Lifecycle, Reviews, and Events, acting as verified model layers directly attached to the original native raw tabular sheets.
2. **Interactive Front-End Dashboard**: Constructed a clean UI displaying exact verified KPIs and visual charts (Revenue Trend, Sub-categories, Lifecycle pie charts, etc.)
3. **Data Constraint Adherence**: Strictly labeled constraints such as November 2025 being a partial month. Excluded sentiment analysis on synthetic reviews and avoided faking chronological funnels.
4. **Three-Way Reconciliation**: The Validation tab contains SQL/Pandas benchmark values and Excel comparison results; all tracked metrics match. No values were manually overridden or artificially adjusted.
5. **Final Strategic Insights**: Extracted rigorous Observation->Insight->Impact->Recommendation frameworks based strictly on mathematically defended models. See `docs/final_business_insights.md`.
