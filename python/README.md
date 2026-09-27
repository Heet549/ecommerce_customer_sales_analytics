# Python — README

This folder contains all Python work across the project's phases.

## Phase 1 Validation Scripts (already complete — outputs saved)

- `audit_phase1a.py` — Phase 1A dataset audit script (reads raw CSVs;
  results saved at `docs/phase1a_audit_raw_output.txt`).
- `validate_phase1e.py` — Phase 1E SQL validation script (via a SQLite
  functional proxy of the MySQL schema; results saved at
  `docs/phase1e_validation_results.txt`). Requires `pandas` and
  `sqlite3` (stdlib). Run with `python validate_phase1e.py` from this
  folder — it creates a temporary SQLite DB, runs all validation queries,
  saves results, then cleans up the DB automatically.

These are kept for reproducibility — they are what the Phase 1 SQL logic
was actually verified against. Pre-run outputs are saved in `docs/` so
you do not need to re-run them to read verified results.

## Phase 3 (Python/Pandas EDA — this phase)

```
python/
├── notebooks/
│   └── ecommerce_analysis.ipynb   <- MAIN DELIVERABLE, fully executed
├── scripts/
│   └── analysis_lib.py            <- shared functions (import this, don't copy-paste)
└── outputs/                        <- charts + reconciliation CSV produced by the notebook
```

### How to run

**Option A — open the notebook directly (recommended):**

```bash
cd python/notebooks
jupyter notebook ecommerce_analysis.ipynb
```

The notebook is already fully executed with real output and charts — you
can read it as-is, or click "Run All" to reproduce every result from
scratch (it reads directly from `data/*.csv`, no database required).

**Option B — reuse the shared functions in your own script:**

```python
import sys
sys.path.insert(0, "python/scripts")
from analysis_lib import load_data, convert_types, compute_kpis

dfs = load_data()
dfs = convert_types(dfs)
kpis = compute_kpis(dfs)
print(kpis)
```

### Dependencies

See the root-level `requirements.txt` for the required packages (`pandas`, `numpy`, `matplotlib`, `seaborn`, `jupyter`).

No database connection is required for Phase 3 — it reads the 6 raw CSVs
in `data/` directly, independently of the SQL work in Phase 1/2. This is
intentional: it lets the Phase 2 SQL results and the Phase 3 Pandas
results be cross-checked against each other from two independent code
paths reading the same source data (see Section 13 of the notebook and
`docs/pandas_analysis_summary.md` for the reconciliation).

### What NOT to expect here

Per the project's scope decisions (see `docs/pandas_analysis_summary.md`
and `docs/data_quality_report.md`):

- No NLP/sentiment analysis on `review_text` (it's 10 canned categorical
  phrases, not free text).
- No "days since signup" or signup-based cohort/retention analysis
  (`signup_date` is not chronologically reliable relative to `order_date`).
- No claim that browsing events cause purchases (the funnel is aggregate,
  not a verified per-user sequence).
