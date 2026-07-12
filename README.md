# SQL Analytics Portfolio

Production-style SQL for common analytics problems, written the way I'd write it on the job: each section has a written problem statement, the query, and a short note on the approach and trade-offs.

> 🚧 **In progress** — sections are being filled in incrementally. The structure below is the roadmap.

## Sections

| Section | What it covers |
|---|---|
| [`01-window-functions/`](01-window-functions) | Ranking, running totals, moving averages, deduplication with `ROW_NUMBER`, gaps-and-islands |
| [`02-cohort-retention/`](02-cohort-retention) | Monthly signup cohorts, retention curves, revenue retention |
| [`03-funnel-analysis/`](03-funnel-analysis) | Multi-step conversion funnels, drop-off analysis, time-between-steps |
| [`04-data-quality-checks/`](04-data-quality-checks) | Row-count reconciliation, referential-integrity checks, freshness and null-rate audits |

## Datasets

All queries run against public or synthetic datasets documented in [`datasets/`](datasets) — no employer data.

## Dialect

Written primarily for Snowflake; notes call out where syntax differs for Postgres/BigQuery.
