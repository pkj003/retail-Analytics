SET search_path TO retail_analytics, public;

INSERT INTO dim_date (
    date_key, full_date, calendar_year, quarter_number, month_number, month_name, day_of_month
)
SELECT
    to_char(d::date, 'YYYYMMDD')::integer,
    d::date,
    extract(year FROM d)::smallint,
    extract(quarter FROM d)::smallint,
    extract(month FROM d)::smallint,
    to_char(d::date, 'FMMonth'),
    extract(day FROM d)::smallint
FROM generate_series(
    DATE '2024-01-01',
    DATE '2025-12-31',
    INTERVAL '1 day'
) AS dates(d)
ON CONFLICT (date_key) DO NOTHING;

INSERT INTO dim_product (product_key, product_name, category, subcategory, list_price)
VALUES
    (101, 'Coffee Maker', 'Appliances', 'Coffee', 80.00),
    (102, 'Coffee Grinder', 'Appliances', 'Coffee', 40.00),
    (103, 'Whole Bean Coffee', 'Grocery', 'Coffee', 15.00),
    (104, 'Electric Kettle', 'Appliances', 'Kitchen', 50.00)
ON CONFLICT (product_key) DO NOTHING;

INSERT INTO dim_customer (customer_key, customer_name, segment, signup_date)
VALUES
    (201, 'Avery Morgan', 'Consumer', DATE '2023-08-12'),
    (202, 'Blake Taylor', 'Small Business', DATE '2023-11-03'),
    (203, 'Casey Jordan', 'Consumer', DATE '2024-01-15'),
    (204, 'Drew Parker', 'Small Business', DATE '2024-02-20')
ON CONFLICT (customer_key) DO NOTHING;

INSERT INTO dim_store (store_key, store_name, city, region)
VALUES
    (301, 'Downtown Market', 'Riverton', 'East'),
    (302, 'Westside Market', 'Lakewood', 'West')
ON CONFLICT (store_key) DO NOTHING;

INSERT INTO fact_sales (
    order_id, date_key, product_key, customer_key, store_key,
    quantity, unit_price, discount_amount
)
VALUES
    ('R-24001', 20240110, 101, 201, 301, 2, 80.00, 0.00),
    ('R-24002', 20240122, 103, 202, 302, 5, 15.00, 0.00),
    ('R-24003', 20240205, 102, 203, 301, 1, 40.00, 0.00),
    ('R-24004', 20240218, 103, 201, 302, 4, 15.00, 0.00),
    ('R-24005', 20240312, 104, 202, 301, 2, 50.00, 0.00),
    ('R-24006', 20240322, 101, 204, 302, 1, 80.00, 8.00),
    ('R-24007', 20240404, 103, 203, 301, 6, 15.00, 0.00),
    ('R-24008', 20240427, 102, 201, 302, 2, 40.00, 0.00),
    ('R-24009', 20240515, 104, 204, 301, 1, 50.00, 0.00),
    ('R-24010', 20240602, 101, 202, 302, 1, 80.00, 0.00),
    ('R-24011', 20240711, 104, 203, 301, 3, 50.00, 0.00),
    ('R-24012', 20240819, 101, 201, 302, 1, 80.00, 0.00),
    ('R-24013', 20240901, 103, 202, 301, 8, 15.00, 0.00),
    ('R-24014', 20241020, 102, 204, 302, 1, 40.00, 0.00),
    ('R-24015', 20241102, 101, 203, 301, 2, 80.00, 16.00),
    ('R-24016', 20241215, 104, 201, 302, 1, 50.00, 0.00),
    ('R-25001', 20250107, 103, 202, 301, 6, 15.00, 0.00),
    ('R-25002', 20250211, 101, 201, 302, 1, 80.00, 0.00),
    ('R-25003', 20250318, 104, 203, 301, 2, 50.00, 0.00),
    ('R-25004', 20250422, 103, 204, 302, 10, 15.00, 0.00)
ON CONFLICT (order_id, product_key) DO NOTHING;
