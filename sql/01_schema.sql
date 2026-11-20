CREATE SCHEMA IF NOT EXISTS retail_analytics;
SET search_path TO retail_analytics, public;

CREATE TABLE IF NOT EXISTS dim_date (
    date_key        integer PRIMARY KEY,
    full_date       date NOT NULL UNIQUE,
    calendar_year   smallint NOT NULL,
    quarter_number  smallint NOT NULL CHECK (quarter_number BETWEEN 1 AND 4),
    month_number    smallint NOT NULL CHECK (month_number BETWEEN 1 AND 12),
    month_name      text NOT NULL,
    day_of_month    smallint NOT NULL CHECK (day_of_month BETWEEN 1 AND 31)
);

CREATE TABLE IF NOT EXISTS dim_product (
    product_key     integer PRIMARY KEY,
    product_name    text NOT NULL,
    category        text NOT NULL,
    subcategory     text NOT NULL,
    list_price      numeric(10, 2) NOT NULL CHECK (list_price >= 0)
);

CREATE TABLE IF NOT EXISTS dim_customer (
    customer_key    integer PRIMARY KEY,
    customer_name   text NOT NULL,
    segment         text NOT NULL,
    signup_date     date NOT NULL
);

CREATE TABLE IF NOT EXISTS dim_store (
    store_key       integer PRIMARY KEY,
    store_name      text NOT NULL,
    city            text NOT NULL,
    region          text NOT NULL
);

CREATE TABLE IF NOT EXISTS fact_sales (
    sales_key       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        text NOT NULL,
    date_key        integer NOT NULL REFERENCES dim_date (date_key),
    product_key     integer NOT NULL REFERENCES dim_product (product_key),
    customer_key    integer NOT NULL REFERENCES dim_customer (customer_key),
    store_key       integer NOT NULL REFERENCES dim_store (store_key),
    quantity        integer NOT NULL CHECK (quantity > 0),
    unit_price      numeric(10, 2) NOT NULL CHECK (unit_price >= 0),
    discount_amount numeric(10, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    net_sales       numeric(12, 2) GENERATED ALWAYS AS
                    (quantity * unit_price - discount_amount) STORED,
    CONSTRAINT fact_sales_discount_not_exceed_gross
        CHECK (discount_amount <= quantity * unit_price),
    CONSTRAINT fact_sales_order_product_unique UNIQUE (order_id, product_key)
);

CREATE INDEX IF NOT EXISTS fact_sales_date_idx ON fact_sales (date_key);
CREATE INDEX IF NOT EXISTS fact_sales_product_idx ON fact_sales (product_key);
CREATE INDEX IF NOT EXISTS fact_sales_customer_idx ON fact_sales (customer_key);
CREATE INDEX IF NOT EXISTS fact_sales_store_idx ON fact_sales (store_key);
