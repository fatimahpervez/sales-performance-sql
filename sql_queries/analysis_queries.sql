-- Superstore sales analysis (PostgreSQL 18)
-- Run after sql_schema/create_tables.sql and sql_schema/load_data.sql.
-- Q1 to Q10 are analysis queries; the two views at the end feed the Excel dashboard.

-- Q1: Profitability by region (JOINs across order_items, orders, locations)
SELECT l.region,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.sales), 2) AS sales,
       ROUND(SUM(oi.profit), 2) AS profit,
       ROUND(100 * SUM(oi.profit) / SUM(oi.sales), 2) AS profit_margin_pct
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN locations l ON l.postal_code = o.postal_code
GROUP BY l.region
ORDER BY profit DESC;

-- Q2: Profit by region and discount band (CTE)
WITH item_detail AS (
    SELECT l.region,
           CASE WHEN oi.discount = 0    THEN '1_no_discount'
                WHEN oi.discount <= 0.20 THEN '2_up_to_20pct'
                ELSE                          '3_over_20pct'
           END AS discount_band,
           oi.sales,
           oi.profit
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN locations l ON l.postal_code = o.postal_code
)
SELECT region,
       discount_band,
       COUNT(*) AS line_items,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(profit), 2) AS profit,
       ROUND(100 * SUM(profit) / SUM(sales), 2) AS margin_pct
FROM item_detail
GROUP BY region, discount_band
ORDER BY region, discount_band;

-- Q3: Three least profitable states within each region (CTE + RANK window function)
WITH state_profit AS (
    SELECT l.region,
           l.state,
           ROUND(SUM(oi.sales), 2) AS sales,
           ROUND(SUM(oi.profit), 2) AS profit
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN locations l ON l.postal_code = o.postal_code
    GROUP BY l.region, l.state
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY region ORDER BY profit ASC) AS loss_rank
    FROM state_profit
)
SELECT region, loss_rank, state, sales, profit,
       ROUND(100 * profit / sales, 2) AS margin_pct
FROM ranked
WHERE loss_rank <= 3
ORDER BY region, loss_rank;

-- Q4: Central region, discount behaviour by state (FILTER aggregate)
SELECT l.state,
       COUNT(*) AS line_items,
       ROUND(AVG(oi.discount) * 100, 1) AS avg_discount_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE oi.discount > 0.20) / COUNT(*), 1) AS pct_lines_over_20pct,
       ROUND(SUM(oi.profit), 2) AS profit
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
JOIN locations l ON l.postal_code = o.postal_code
WHERE l.region = 'Central'
GROUP BY l.state
ORDER BY profit;

-- Q5: Do states that always discount lose money? (CTE + CASE on state-level pattern)
WITH state_summary AS (
    SELECT l.state,
           COUNT(*) AS line_items,
           COUNT(*) FILTER (WHERE oi.discount > 0) AS discounted_lines,
           SUM(oi.sales) AS sales,
           SUM(oi.profit) AS profit
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN locations l ON l.postal_code = o.postal_code
    GROUP BY l.state
)
SELECT CASE WHEN discounted_lines = line_items THEN '1_every_line_discounted'
            WHEN discounted_lines = 0          THEN '3_no_line_discounted'
            ELSE                                    '2_mixed'
       END AS discount_pattern,
       COUNT(*) AS states,
       SUM(line_items) AS line_items,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(profit), 2) AS profit,
       ROUND(100 * SUM(profit) / SUM(sales), 2) AS margin_pct
FROM state_summary
GROUP BY 1
ORDER BY 1;

-- Q6: Sub-categories with a margin below the company-wide margin (subquery in HAVING)
SELECT p.category,
       p.sub_category,
       ROUND(SUM(oi.sales), 2) AS sales,
       ROUND(SUM(oi.profit), 2) AS profit,
       ROUND(100 * SUM(oi.profit) / SUM(oi.sales), 2) AS margin_pct
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.category, p.sub_category
HAVING SUM(oi.profit) / SUM(oi.sales) < (SELECT SUM(profit) / SUM(sales) FROM order_items)
ORDER BY margin_pct;

-- Q7: Margin by discount band for the weakest sub-categories (CTE)
WITH item_detail AS (
    SELECT p.sub_category,
           CASE WHEN oi.discount = 0    THEN '1_no_discount'
                WHEN oi.discount <= 0.20 THEN '2_up_to_20pct'
                ELSE                          '3_over_20pct'
           END AS discount_band,
           oi.sales,
           oi.profit
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    WHERE p.sub_category IN ('Tables', 'Bookcases', 'Supplies', 'Machines')
)
SELECT sub_category,
       discount_band,
       COUNT(*) AS line_items,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(profit), 2) AS profit,
       ROUND(100 * SUM(profit) / SUM(sales), 2) AS margin_pct
FROM item_detail
GROUP BY sub_category, discount_band
ORDER BY sub_category, discount_band;

-- Q8: Repeat-purchase pattern by customer group (two CTEs + LAG window function)
WITH customer_orders AS (
    SELECT customer_id,
           order_id,
           order_date,
           order_date - LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS days_since_prev
    FROM orders
),
customer_summary AS (
    SELECT customer_id,
           COUNT(*) AS orders,
           AVG(days_since_prev) AS avg_gap_days
    FROM customer_orders
    GROUP BY customer_id
)
SELECT CASE WHEN orders = 1 THEN '1_one_order'
            WHEN orders <= 4 THEN '2_two_to_four'
            WHEN orders <= 9 THEN '3_five_to_nine'
            ELSE                  '4_ten_plus'
       END AS customer_group,
       COUNT(*) AS customers,
       SUM(orders) AS orders,
       ROUND(AVG(avg_gap_days), 1) AS avg_days_between_orders
FROM customer_summary
GROUP BY 1
ORDER BY 1;

-- Q9: Quarterly sales with running total and quarter-over-quarter change (window functions)
WITH quarterly AS (
    SELECT DATE_TRUNC('quarter', o.order_date)::date AS quarter_start,
           SUM(oi.sales) AS sales,
           SUM(oi.profit) AS profit
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    GROUP BY 1
)
SELECT quarter_start,
       ROUND(sales, 2) AS sales,
       ROUND(profit, 2) AS profit,
       ROUND(SUM(sales) OVER (ORDER BY quarter_start), 2) AS running_sales,
       ROUND(100.0 * (sales - LAG(sales) OVER (ORDER BY quarter_start))
             / LAG(sales) OVER (ORDER BY quarter_start), 1) AS sales_change_pct
FROM quarterly
ORDER BY quarter_start;

-- Q10: Lapsed customers (no 2017 orders) and their lifetime value (LEFT JOIN anti-join + CTE)
WITH lapsed AS (
    SELECT c.customer_id
    FROM customers c
    LEFT JOIN orders o
           ON o.customer_id = c.customer_id
          AND o.order_date >= '2017-01-01'
    WHERE o.order_id IS NULL
)
SELECT COUNT(DISTINCT la.customer_id) AS lapsed_customers,
       ROUND(SUM(oi.sales), 2) AS lifetime_sales,
       ROUND(SUM(oi.profit), 2) AS lifetime_profit
FROM lapsed la
JOIN orders o2 ON o2.customer_id = la.customer_id
JOIN order_items oi ON oi.order_id = o2.order_id;

-- View 1: v_sales_detail
-- One row per order line with all descriptive fields joined back together.
-- Source for the Excel pivot tables and dashboard.
CREATE OR REPLACE VIEW v_sales_detail AS
SELECT oi.row_id,
       o.order_id,
       o.order_date,
       o.ship_date,
       o.ship_mode,
       c.customer_id,
       c.customer_name,
       c.segment,
       l.region,
       l.state,
       l.city,
       l.postal_code,
       p.product_id,
       p.category,
       p.sub_category,
       p.product_name,
       CASE WHEN oi.discount = 0     THEN '1_no_discount'
            WHEN oi.discount <= 0.20 THEN '2_up_to_20pct'
            ELSE                          '3_over_20pct'
       END AS discount_band,
       oi.sales,
       oi.quantity,
       oi.discount,
       oi.profit
FROM order_items oi
JOIN orders o     ON o.order_id = oi.order_id
JOIN customers c  ON c.customer_id = o.customer_id
JOIN locations l  ON l.postal_code = o.postal_code
JOIN products p   ON p.product_id = oi.product_id;

-- Check: the view must contain every line item and the same totals as order_items
SELECT COUNT(*) AS line_items,
       ROUND(SUM(sales), 2) AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit
FROM v_sales_detail;

-- View 2: v_customer_summary
-- One row per customer: how often they ordered, when, and what they are worth.
-- sales and profit are kept at full precision so totals add up exactly; round only for display.
CREATE OR REPLACE VIEW v_customer_summary AS
SELECT c.customer_id,
       c.customer_name,
       c.segment,
       COUNT(DISTINCT o.order_id) AS orders,
       MIN(o.order_date) AS first_order_date,
       MAX(o.order_date) AS last_order_date,
       SUM(oi.sales) AS sales,
       SUM(oi.profit) AS profit,
       ROUND(100 * SUM(oi.profit) / SUM(oi.sales), 2) AS margin_pct,
       (MAX(o.order_date) >= DATE '2017-01-01') AS ordered_in_2017
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.customer_name, c.segment;

-- Check: customer view must cover every customer, order and all the money
SELECT COUNT(*) AS customers,
       SUM(orders) AS orders,
       ROUND(SUM(sales), 2) AS sales,
       ROUND(SUM(profit), 2) AS profit,
       COUNT(*) FILTER (WHERE NOT ordered_in_2017) AS no_2017_order
FROM v_customer_summary;