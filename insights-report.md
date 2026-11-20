# Retail Sales Analytics — Sample Insights

## Scope and caveats

This report interprets the 20 illustrative order lines in `sql/02_seed_data.sql`. The sample covers January 2024 through April 2025; it is deliberately small and is not representative of a real retailer. Revenue means net sales after line-item discounts. Each sample order has one product line, so order-level and line-level sales coincide.

## Findings

1. **Sales are lower in the first four months of 2025.** Net sales for January–April total **$420**, compared with **$677** for the same months in 2024, a decrease of **38.0%**. The comparison is based on four months only and should not be read as a full-year forecast.
2. **Appliances are the largest category.** The sample records **$1,226** in appliance net sales versus **$585** in grocery sales. Coffee makers lead products at **$616**, followed by whole bean coffee at **$585**.
3. **Downtown Market leads the sample.** It records **$1,044** compared with **$767** at Westside Market, or **57.6%** of the sample's **$1,811** net sales. The small number of transactions makes this directional, not a basis for a store decision.
4. **Revenue is concentrated among a few customers.** The top customer contributes **$524** (28.9% of sales), while the top two contribute **$1,034** (57.1%). A customer cohort and lifetime-value review can help distinguish repeat engagement from one-off purchases.
5. **Discounting is limited in this seed data.** Only two lines include discounts; total discounts are **$24** on **$1,835** gross sales, a blended discount rate of **1.31%**. This dataset cannot establish whether promotions caused incremental sales.

## Recommended next steps

- Load at least two or three complete years of transaction data and validate returns, taxes, cancellations, and multi-line orders before interpreting trends.
- Refresh the materialized view after each load, then review same-store and same-period growth alongside the trend and moving-average queries.
- Segment cohort retention and customer value by acquisition channel and customer segment when those attributes are available.
- Treat the analytical outputs as forecasting preparation (clean monthly measures and seasonality cuts), not as a forecast; validate any forecasting model out of sample.

## Reproducing the analysis

Run the three scripts in order as described in [README.md](./README.md). Query 2 compares matching calendar months across years; query 10 calculates discounts against gross sales; query 11 ranks products by cumulative sales share. Results change when the fact data is replaced.
