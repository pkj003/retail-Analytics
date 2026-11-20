SET search_path TO retail_analytics, public;

DROP MATERIALIZED VIEW IF EXISTS monthly_product_store_sales;

CREATE MATERIALIZED VIEW monthly_product_store_sales AS
SELECT
    date_trunc('month', d.full_date)::date AS sales_month,
    p.product_key,
    p.product_name,
    p.category,
    s.store_key,
    s.store_name,
    SUM(f.quantity) AS units_sold,
    COUNT(DISTINCT f.order_id) AS order_count,
    SUM(f.net_sales)::numeric(14, 2) AS net_sales
FROM fact_sales AS f
JOIN dim_date AS d ON d.date_key = f.date_key
JOIN dim_product AS p ON p.product_key = f.product_key
JOIN dim_store AS s ON s.store_key = f.store_key
GROUP BY
    date_trunc('month', d.full_date)::date,
    p.product_key, p.product_name, p.category, s.store_key, s.store_name;

CREATE UNIQUE INDEX monthly_product_store_sales_pk
    ON monthly_product_store_sales (sales_month, product_key, store_key);

REFRESH MATERIALIZED VIEW monthly_product_store_sales;

-- 1. Monthly net sales, order volume, and month-over-month change.
WITH bounds AS (
    SELECT MIN(date_trunc('month', d.full_date)) AS first_month,
           MAX(date_trunc('month', d.full_date)) AS last_month
    FROM fact_sales AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
),
months AS (
    SELECT generate_series(first_month, last_month, INTERVAL '1 month')::date AS sales_month
    FROM bounds
),
monthly AS (
    SELECT m.sales_month,
           COALESCE(SUM(f.net_sales), 0) AS net_sales,
           COUNT(DISTINCT f.order_id) AS orders
    FROM months AS m
    LEFT JOIN dim_date AS d ON date_trunc('month', d.full_date)::date = m.sales_month
    LEFT JOIN fact_sales AS f ON f.date_key = d.date_key
    GROUP BY m.sales_month
)
SELECT sales_month, net_sales, orders,
       net_sales - LAG(net_sales) OVER (ORDER BY sales_month) AS sales_change,
       ROUND(
           100.0 * (net_sales - LAG(net_sales) OVER (ORDER BY sales_month))
           / NULLIF(LAG(net_sales) OVER (ORDER BY sales_month), 0),
           2
       ) AS mom_growth_pct
FROM monthly
ORDER BY sales_month;

-- 2. Year-over-year sales by calendar month.
WITH monthly AS (
    SELECT d.calendar_year, d.month_number, SUM(f.net_sales) AS net_sales
    FROM fact_sales AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    GROUP BY d.calendar_year, d.month_number
)
SELECT month_number,
       MAX(net_sales) FILTER (WHERE calendar_year = 2024) AS sales_2024,
       MAX(net_sales) FILTER (WHERE calendar_year = 2025) AS sales_2025,
       ROUND(
           100.0 * (
               MAX(net_sales) FILTER (WHERE calendar_year = 2025)
               - MAX(net_sales) FILTER (WHERE calendar_year = 2024)
           ) / NULLIF(MAX(net_sales) FILTER (WHERE calendar_year = 2024), 0),
           2
       ) AS yoy_growth_pct
FROM monthly
GROUP BY month_number
ORDER BY month_number;

-- 3. Daily sales, running sales total, and share of the calendar-year total.
WITH daily AS (
    SELECT d.full_date, d.calendar_year, SUM(f.net_sales) AS net_sales
    FROM fact_sales AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    GROUP BY d.full_date, d.calendar_year
)
SELECT full_date, net_sales,
       SUM(net_sales) OVER (
           PARTITION BY calendar_year ORDER BY full_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS year_to_date_sales,
       ROUND(
           100.0 * SUM(net_sales) OVER (
               PARTITION BY calendar_year ORDER BY full_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) / SUM(net_sales) OVER (PARTITION BY calendar_year),
           2
       ) AS share_of_annual_sales_pct
FROM daily
ORDER BY full_date;

-- 4. Product ranking within category by total sales.
WITH product_sales AS (
    SELECT product_key, product_name, category,
           SUM(net_sales) AS net_sales, SUM(units_sold) AS units_sold
    FROM monthly_product_store_sales
    GROUP BY product_key, product_name, category
)
SELECT *,
       RANK() OVER (PARTITION BY category ORDER BY net_sales DESC) AS category_sales_rank
FROM product_sales
ORDER BY category, category_sales_rank, product_name;

-- 5. Three-month moving average of monthly sales.
WITH bounds AS (
    SELECT MIN(date_trunc('month', d.full_date)) AS first_month,
           MAX(date_trunc('month', d.full_date)) AS last_month
    FROM fact_sales AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
),
months AS (
    SELECT generate_series(first_month, last_month, INTERVAL '1 month')::date AS sales_month
    FROM bounds
),
monthly AS (
    SELECT m.sales_month, COALESCE(SUM(f.net_sales), 0) AS net_sales
    FROM months AS m
    LEFT JOIN dim_date AS d ON date_trunc('month', d.full_date)::date = m.sales_month
    LEFT JOIN fact_sales AS f ON f.date_key = d.date_key
    GROUP BY m.sales_month
)
SELECT sales_month, net_sales,
       ROUND(AVG(net_sales) OVER (
           ORDER BY sales_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2) AS trailing_three_month_avg
FROM monthly
ORDER BY sales_month;

-- 6. Store performance, sales share, and rank.
WITH store_sales AS (
    SELECT s.store_key, s.store_name, s.region,
           SUM(f.net_sales) AS net_sales,
           COUNT(DISTINCT f.order_id) AS orders
    FROM fact_sales AS f
    JOIN dim_store AS s ON s.store_key = f.store_key
    GROUP BY s.store_key, s.store_name, s.region
)
SELECT *,
       RANK() OVER (ORDER BY net_sales DESC) AS sales_rank,
       ROUND(100.0 * net_sales / SUM(net_sales) OVER (), 2) AS sales_share_pct
FROM store_sales
ORDER BY sales_rank;

-- 7. Customer lifetime value, order value, and customer ranking.
WITH order_totals AS (
    SELECT order_id, customer_key, SUM(net_sales) AS order_sales
    FROM fact_sales
    GROUP BY order_id, customer_key
),
customer_totals AS (
    SELECT c.customer_key, c.customer_name, c.segment,
           SUM(o.order_sales) AS lifetime_sales,
           COUNT(*) AS order_count,
           AVG(o.order_sales) AS avg_order_value
    FROM order_totals AS o
    JOIN dim_customer AS c ON c.customer_key = o.customer_key
    GROUP BY c.customer_key, c.customer_name, c.segment
)
SELECT *,
       DENSE_RANK() OVER (ORDER BY lifetime_sales DESC) AS lifetime_value_rank
FROM customer_totals
ORDER BY lifetime_value_rank, customer_name;

-- 8. Monthly customer cohort retention by months since first purchase.
WITH customer_months AS (
    SELECT DISTINCT f.customer_key, date_trunc('month', d.full_date)::date AS activity_month
    FROM fact_sales AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
),
cohorts AS (
    SELECT customer_key, MIN(activity_month) AS cohort_month
    FROM customer_months
    GROUP BY customer_key
)
SELECT c.cohort_month, cm.activity_month,
       (
           (EXTRACT(YEAR FROM cm.activity_month) - EXTRACT(YEAR FROM c.cohort_month)) * 12
           + EXTRACT(MONTH FROM cm.activity_month) - EXTRACT(MONTH FROM c.cohort_month)
       )::integer AS months_since_first_purchase,
       COUNT(DISTINCT cm.customer_key) AS active_customers
FROM customer_months AS cm
JOIN cohorts AS c ON c.customer_key = cm.customer_key
GROUP BY c.cohort_month, cm.activity_month
ORDER BY c.cohort_month, cm.activity_month;

-- 9. Order-value distribution and median.
WITH order_totals AS (
    SELECT order_id, SUM(net_sales) AS order_sales
    FROM fact_sales
    GROUP BY order_id
)
SELECT COUNT(*) AS order_count,
       ROUND(AVG(order_sales), 2) AS avg_order_value,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY order_sales) AS median_order_value,
       MIN(order_sales) AS smallest_order,
       MAX(order_sales) AS largest_order
FROM order_totals;

-- 10. Category discount rate and sales after discount.
SELECT p.category,
       SUM(f.quantity * f.unit_price) AS gross_sales,
       SUM(f.discount_amount) AS discounts,
       SUM(f.net_sales) AS net_sales,
       ROUND(
           100.0 * SUM(f.discount_amount)
           / NULLIF(SUM(f.quantity * f.unit_price), 0),
           2
       ) AS discount_rate_pct
FROM fact_sales AS f
JOIN dim_product AS p ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY net_sales DESC;

-- 11. Product Pareto contribution: cumulative share of sales.
WITH product_sales AS (
    SELECT p.product_key, p.product_name, SUM(f.net_sales) AS net_sales
    FROM fact_sales AS f
    JOIN dim_product AS p ON p.product_key = f.product_key
    GROUP BY p.product_key, p.product_name
)
SELECT product_name, net_sales,
       ROUND(
           100.0 * SUM(net_sales) OVER (
               ORDER BY net_sales DESC, product_name
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) / SUM(net_sales) OVER (),
           2
       ) AS cumulative_sales_share_pct
FROM product_sales
ORDER BY net_sales DESC, product_name;

-- 12. Customer lifetime-sales quartiles.
WITH customer_sales AS (
    SELECT c.customer_key, c.customer_name, SUM(f.net_sales) AS lifetime_sales
    FROM fact_sales AS f
    JOIN dim_customer AS c ON c.customer_key = f.customer_key
    GROUP BY c.customer_key, c.customer_name
)
SELECT customer_name, lifetime_sales,
       NTILE(4) OVER (ORDER BY lifetime_sales DESC) AS value_quartile
FROM customer_sales
ORDER BY value_quartile, lifetime_sales DESC;

-- 13. Quarterly category sales and category rank within each quarter.
WITH quarterly AS (
    SELECT d.calendar_year, d.quarter_number, p.category,
           SUM(f.net_sales) AS net_sales
    FROM fact_sales AS f
    JOIN dim_date AS d ON d.date_key = f.date_key
    JOIN dim_product AS p ON p.product_key = f.product_key
    GROUP BY d.calendar_year, d.quarter_number, p.category
)
SELECT calendar_year, quarter_number, category, net_sales,
       RANK() OVER (
           PARTITION BY calendar_year, quarter_number
           ORDER BY net_sales DESC
       ) AS category_rank
FROM quarterly
ORDER BY calendar_year, quarter_number, category_rank;
