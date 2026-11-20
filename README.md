# Advanced SQL Analytics: Retail Sales

A PostgreSQL portfolio project for analyzing retail sales performance and preparing time-series data for forecasting.

## Project contents

- `sql/01_schema.sql` — normalized star schema (four dimensions and a sales fact table)
- `sql/02_seed_data.sql` — reproducible sample data for 2024–2025
- `sql/03_analytics.sql` — a refreshable materialized view and 13 analytical queries
- `insights-report.md` — sample-data findings, interpretation, and business recommendations

## Requirements

- PostgreSQL 12 or later
- `psql` or another PostgreSQL client

Run the scripts from the project directory, in order:

```powershell
psql -d your_database -f sql/01_schema.sql
psql -d your_database -f sql/02_seed_data.sql
psql -d your_database -f sql/03_analytics.sql
```

The scripts create and use the `retail_analytics` schema. The seed script is safe to rerun. The analytics script recreates the materialized view from the current fact data before running the reports.

## Data model

`fact_sales` stores one row per order line and references `dim_date`, `dim_product`, `dim_customer`, and `dim_store`. Net sales are generated from quantity, unit price, and discount. This star schema keeps descriptive attributes in dimensions and measurable events in the fact table.

## Analytics included

The reports cover monthly trends and growth, running totals, moving averages, product and store rankings, customer lifetime value and cohorts, order-value distribution, discount rates, Pareto contribution, customer value bands, and category seasonality. Window functions are used throughout for ranking, period comparisons, rolling averages, cumulative totals, and segmentation.

The sample data is intentionally small and illustrative; replace the seed rows with an organization's validated data before making operational decisions.
