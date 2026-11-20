-- load_data.sql
-- Rebuilds the data in the five tables from the raw CSV.
-- Run create_tables.sql first.

-- 1. Staging table: every column is text so the CSV import cannot fail on types.
DROP TABLE IF EXISTS staging_superstore;
CREATE TABLE staging_superstore (
    row_id TEXT, order_id TEXT, order_date TEXT, ship_date TEXT, ship_mode TEXT,
    customer_id TEXT, customer_name TEXT, segment TEXT, country TEXT, city TEXT,
    state TEXT, postal_code TEXT, region TEXT, product_id TEXT, category TEXT,
    sub_category TEXT, product_name TEXT, sales TEXT, quantity TEXT,
    discount TEXT, profit TEXT
);

-- 2. MANUAL STEP: import data_raw/Sample - Superstore.csv into staging_superstore
--    with pgAdmin (right-click table > Import/Export Data).
--    Settings: Import, format csv, encoding WIN1252, Header on, delimiter ",", quote and escape '"'.
--    Expected result: 9,994 rows.

-- 3. Clear the final tables so the load can be re-run safely.
TRUNCATE order_items, orders, products, locations, customers;

-- 4. Locations. Postal codes lost their leading zeros in the source file, so pad to 5 digits.
--    If a postal code appears with more than one city (92024), keep the most frequent city.
INSERT INTO locations (postal_code, city, state, region, country)
SELECT postal_code, city, state, region, country
FROM (
    SELECT LPAD(postal_code, 5, '0') AS postal_code, city, state, region, country,
           ROW_NUMBER() OVER (PARTITION BY LPAD(postal_code, 5, '0') ORDER BY COUNT(*) DESC, city) AS rn
    FROM staging_superstore
    GROUP BY LPAD(postal_code, 5, '0'), city, state, region, country
) ranked
WHERE rn = 1;

-- 5. Customers.
INSERT INTO customers (customer_id, customer_name, segment)
SELECT DISTINCT customer_id, customer_name, segment
FROM staging_superstore;

-- 6. Products. 32 product IDs appear with more than one name; keep the name from the first occurrence (lowest Row ID).
INSERT INTO products (product_id, category, sub_category, product_name)
SELECT DISTINCT ON (product_id) product_id, category, sub_category, product_name
FROM staging_superstore
ORDER BY product_id, row_id::int;

-- 7. Orders. Dates in the file are US month/day/year.
INSERT INTO orders (order_id, order_date, ship_date, ship_mode, customer_id, postal_code)
SELECT DISTINCT order_id, TO_DATE(order_date, 'MM/DD/YYYY'), TO_DATE(ship_date, 'MM/DD/YYYY'),
       ship_mode, customer_id, LPAD(postal_code, 5, '0')
FROM staging_superstore;

-- 8. Order items.
INSERT INTO order_items (row_id, order_id, product_id, sales, quantity, discount, profit)
SELECT row_id::int, order_id, product_id, sales::numeric, quantity::int, discount::numeric, profit::numeric
FROM staging_superstore;

-- 9. Check: staging and final totals must match
--    (9,994 rows, sales 2297200.86, profit 286397.02, quantity 37873).
SELECT 'staging' AS source, COUNT(*) AS line_items, ROUND(SUM(sales::numeric), 2) AS total_sales,
       ROUND(SUM(profit::numeric), 2) AS total_profit, SUM(quantity::int) AS total_quantity
FROM staging_superstore
UNION ALL
SELECT 'final', COUNT(*), ROUND(SUM(sales), 2), ROUND(SUM(profit), 2), SUM(quantity)
FROM order_items;