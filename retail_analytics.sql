-- =============================================================================
-- RETAIL SALES & INVENTORY INTELLIGENCE SYSTEM
-- SQL Schema, Data Integrity Checks, Queries & Views
-- =============================================================================

-- -----------------------------------------------------------------------------
-- SECTION 1: SCHEMA CREATION
-- -----------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS retail_analytics;
USE retail_analytics;

-- Categories
CREATE TABLE IF NOT EXISTS categories (
    category_id   INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

-- Brands
CREATE TABLE IF NOT EXISTS brands (
    brand_id   INT PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL
);

-- Stores
CREATE TABLE IF NOT EXISTS stores (
    store_id   INT PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL,
    phone      VARCHAR(20),
    email      VARCHAR(100),
    street     VARCHAR(255),
    city       VARCHAR(100),
    state      CHAR(2),
    zip_code   INT
);

-- Products
CREATE TABLE IF NOT EXISTS products (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    brand_id     INT,
    category_id  INT,
    model_year   INT,
    list_price   DECIMAL(10,2),
    FOREIGN KEY (brand_id)    REFERENCES brands(brand_id),
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- Customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id INT PRIMARY KEY,
    first_name  VARCHAR(100),
    last_name   VARCHAR(100),
    phone       VARCHAR(20),
    email       VARCHAR(100),
    street      VARCHAR(255),
    city        VARCHAR(100),
    state       CHAR(2),
    zip_code    INT
);

-- Staffs
CREATE TABLE IF NOT EXISTS staffs (
    staff_id   INT PRIMARY KEY,
    first_name VARCHAR(100),
    last_name  VARCHAR(100),
    email      VARCHAR(100),
    phone      VARCHAR(20),
    active     TINYINT(1),
    store_id   INT,
    manager_id INT,
    FOREIGN KEY (store_id) REFERENCES stores(store_id)
);

-- Stocks
CREATE TABLE IF NOT EXISTS stocks (
    store_id   INT,
    product_id INT,
    quantity   INT,
    PRIMARY KEY (store_id, product_id),
    FOREIGN KEY (store_id)   REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Orders
CREATE TABLE IF NOT EXISTS orders (
    order_id      INT PRIMARY KEY,
    customer_id   INT,
    order_status  TINYINT COMMENT '1=Pending, 2=Processing, 3=Rejected, 4=Completed',
    order_date    DATE,
    required_date DATE,
    shipped_date  DATE,
    store_id      INT,
    staff_id      INT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (store_id)    REFERENCES stores(store_id),
    FOREIGN KEY (staff_id)    REFERENCES staffs(staff_id)
);

-- Order Items
CREATE TABLE IF NOT EXISTS order_items (
    order_id   INT,
    item_id    INT,
    product_id INT,
    quantity   INT,
    list_price DECIMAL(10,2),
    discount   DECIMAL(4,2),
    PRIMARY KEY (order_id, item_id),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);


-- -----------------------------------------------------------------------------
-- SECTION 2: DATA INTEGRITY CHECKS
-- -----------------------------------------------------------------------------

-- Check for orphan order items (orders without matching order_id)
SELECT 'Orphan order_items' AS check_name, COUNT(*) AS issues
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

-- Staffs without valid store
SELECT 'Staffs without valid store', COUNT(*)
FROM staffs s
LEFT JOIN stores st ON s.store_id = st.store_id
WHERE st.store_id IS NULL

UNION ALL

-- Products without valid brand
SELECT 'Products without valid brand', COUNT(*)
FROM products p
LEFT JOIN brands b ON p.brand_id = b.brand_id
WHERE b.brand_id IS NULL

UNION ALL

-- Orders with shipped_date after required_date (delayed)
SELECT 'Delayed shipments', COUNT(*)
FROM orders
WHERE shipped_date > required_date

UNION ALL

-- Orders missing shipped_date (not yet shipped)
SELECT 'Orders not yet shipped', COUNT(*)
FROM orders
WHERE shipped_date IS NULL;


-- -----------------------------------------------------------------------------
-- SECTION 3: BUSINESS QUERIES
-- -----------------------------------------------------------------------------

-- -----------------------------------------------
-- Q1: Total Revenue by Store and State
-- -----------------------------------------------
SELECT
    st.store_name,
    st.state,
    st.city,
    COUNT(DISTINCT o.order_id)                                          AS total_orders,
    SUM(oi.quantity)                                                    AS units_sold,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS total_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN stores st      ON o.store_id = st.store_id
GROUP BY st.store_name, st.state, st.city
ORDER BY total_revenue DESC;


-- -----------------------------------------------
-- Q2: Top-Selling Brands by Revenue
-- -----------------------------------------------
SELECT
    b.brand_name,
    COUNT(DISTINCT o.order_id)                                          AS orders,
    SUM(oi.quantity)                                                    AS units_sold,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN brands b   ON p.brand_id = b.brand_id
JOIN orders o   ON oi.order_id = o.order_id
GROUP BY b.brand_name
ORDER BY total_revenue DESC;


-- -----------------------------------------------
-- Q3: Top-Selling Brands by Store
-- -----------------------------------------------
SELECT
    st.store_name,
    b.brand_name,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN brands b   ON p.brand_id = b.brand_id
JOIN orders o   ON oi.order_id = o.order_id
JOIN stores st  ON o.store_id = st.store_id
GROUP BY st.store_name, b.brand_name
ORDER BY st.store_name, revenue DESC;


-- -----------------------------------------------
-- Q4: Most Profitable Product Categories
-- -----------------------------------------------
SELECT
    c.category_name,
    SUM(oi.quantity)                                                    AS units_sold,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS net_revenue,
    ROUND(SUM(oi.list_price * oi.quantity * oi.discount), 2)           AS total_discount_given,
    ROUND(AVG(oi.discount) * 100, 1)                                   AS avg_discount_pct
FROM order_items oi
JOIN products p    ON oi.product_id = p.product_id
JOIN categories c  ON p.category_id = c.category_id
GROUP BY c.category_name
ORDER BY net_revenue DESC;


-- -----------------------------------------------
-- Q5: Staff Performance Report
-- -----------------------------------------------
SELECT
    CONCAT(sf.first_name, ' ', sf.last_name)                           AS staff_name,
    st.store_name,
    COUNT(DISTINCT o.order_id)                                          AS orders_handled,
    SUM(oi.quantity)                                                    AS units_sold,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS total_revenue,
    ROUND(AVG(oi.discount) * 100, 1)                                   AS avg_discount_pct
FROM orders o
JOIN staffs sf      ON o.staff_id = sf.staff_id
JOIN stores st      ON o.store_id = st.store_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY sf.staff_id, staff_name, st.store_name
ORDER BY total_revenue DESC;


-- -----------------------------------------------
-- Q6: Customer Order Frequency & Value
-- -----------------------------------------------
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)                             AS customer_name,
    c.state,
    c.city,
    COUNT(DISTINCT o.order_id)                                          AS total_orders,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS lifetime_value,
    MAX(o.order_date)                                                   AS last_order_date
FROM customers c
JOIN orders o       ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, customer_name, c.state, c.city
ORDER BY lifetime_value DESC
LIMIT 50;


-- -----------------------------------------------
-- Q7: Monthly Revenue Trend
-- -----------------------------------------------
SELECT
    YEAR(o.order_date)                                                  AS year,
    MONTH(o.order_date)                                                 AS month,
    DATE_FORMAT(o.order_date, '%Y-%m')                                  AS month_label,
    COUNT(DISTINCT o.order_id)                                          AS orders,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY year, month, month_label
ORDER BY year, month;


-- -----------------------------------------------
-- Q8: Delayed Shipments Monitoring
-- -----------------------------------------------
SELECT
    o.order_id,
    CONCAT(c.first_name, ' ', c.last_name)                             AS customer_name,
    st.store_name,
    o.order_date,
    o.required_date,
    o.shipped_date,
    DATEDIFF(o.shipped_date, o.required_date)                           AS days_delayed,
    CASE WHEN o.shipped_date IS NULL     THEN 'Not Shipped'
         WHEN o.shipped_date > o.required_date THEN 'Delayed'
         ELSE 'On Time'
    END                                                                 AS shipment_status
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN stores st   ON o.store_id = st.store_id
WHERE o.shipped_date > o.required_date OR o.shipped_date IS NULL
ORDER BY days_delayed DESC;


-- -----------------------------------------------
-- Q9: Inventory Stock Levels by Store
-- -----------------------------------------------
SELECT
    st.store_name,
    p.product_name,
    c.category_name,
    b.brand_name,
    sk.quantity,
    CASE
        WHEN sk.quantity = 0  THEN 'Out of Stock'
        WHEN sk.quantity < 5  THEN 'Critical'
        WHEN sk.quantity < 10 THEN 'Low'
        ELSE 'Adequate'
    END AS stock_status
FROM stocks sk
JOIN stores st     ON sk.store_id = st.store_id
JOIN products p    ON sk.product_id = p.product_id
JOIN categories c  ON p.category_id = c.category_id
JOIN brands b      ON p.brand_id = b.brand_id
ORDER BY sk.quantity ASC;


-- -----------------------------------------------
-- Q10: Top 20 Best-Selling Products
-- -----------------------------------------------
SELECT
    p.product_id,
    p.product_name,
    b.brand_name,
    c.category_name,
    SUM(oi.quantity)                                                    AS units_sold,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS revenue
FROM order_items oi
JOIN products p   ON oi.product_id = p.product_id
JOIN brands b     ON p.brand_id = b.brand_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY p.product_id, p.product_name, b.brand_name, c.category_name
ORDER BY units_sold DESC
LIMIT 20;


-- -----------------------------------------------
-- Q11: Customer Demographics by State
-- -----------------------------------------------
SELECT
    state,
    COUNT(customer_id)                    AS customer_count,
    SUM(CASE WHEN phone IS NOT NULL THEN 1 ELSE 0 END) AS has_phone,
    ROUND(SUM(CASE WHEN phone IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS phone_coverage_pct
FROM customers
GROUP BY state
ORDER BY customer_count DESC;


-- -----------------------------------------------
-- Q12: Order Status Summary
-- -----------------------------------------------
SELECT
    CASE order_status
        WHEN 1 THEN 'Pending'
        WHEN 2 THEN 'Processing'
        WHEN 3 THEN 'Rejected'
        WHEN 4 THEN 'Completed'
    END                                   AS status_label,
    COUNT(order_id)                       AS order_count,
    ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM orders), 1) AS percentage
FROM orders
GROUP BY order_status
ORDER BY order_status;


-- -----------------------------------------------
-- Q13: Revenue & Discount Analysis
-- -----------------------------------------------
SELECT
    ROUND(SUM(oi.list_price * oi.quantity), 2)                         AS gross_revenue,
    ROUND(SUM(oi.list_price * oi.quantity * oi.discount), 2)           AS total_discounts,
    ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2)     AS net_revenue,
    ROUND(AVG(oi.discount) * 100, 2)                                   AS avg_discount_pct,
    ROUND(SUM(oi.list_price * oi.quantity * oi.discount) /
          SUM(oi.list_price * oi.quantity) * 100, 2)                   AS effective_discount_rate
FROM order_items oi;


-- -----------------------------------------------
-- Q14: Year-over-Year Revenue Growth
-- -----------------------------------------------
SELECT
    y1.yr                                                               AS year,
    y1.revenue                                                          AS revenue,
    LAG(y1.revenue) OVER (ORDER BY y1.yr)                              AS prev_year_revenue,
    ROUND((y1.revenue - LAG(y1.revenue) OVER (ORDER BY y1.yr)) /
           LAG(y1.revenue) OVER (ORDER BY y1.yr) * 100, 1)            AS yoy_growth_pct
FROM (
    SELECT YEAR(o.order_date) AS yr,
           ROUND(SUM(oi.list_price * oi.quantity * (1 - oi.discount)), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY yr
) y1
ORDER BY year;


-- -----------------------------------------------
-- Q15: Stock vs Sales Velocity (Demand vs Supply)
-- -----------------------------------------------
SELECT
    p.product_name,
    b.brand_name,
    SUM(sk.quantity)                      AS total_stock,
    COALESCE(SUM(sold.units_sold), 0)     AS units_sold_total,
    ROUND(COALESCE(SUM(sold.units_sold), 0) / NULLIF(SUM(sk.quantity), 0), 2) AS sell_through_ratio
FROM stocks sk
JOIN products p ON sk.product_id = p.product_id
JOIN brands b   ON p.brand_id = b.brand_id
LEFT JOIN (
    SELECT product_id, SUM(quantity) AS units_sold
    FROM order_items
    GROUP BY product_id
) sold ON p.product_id = sold.product_id
GROUP BY p.product_id, p.product_name, b.brand_name
ORDER BY sell_through_ratio DESC
LIMIT 25;


-- -----------------------------------------------------------------------------
-- SECTION 4: VIEWS FOR REUSABLE INSIGHTS
-- -----------------------------------------------------------------------------

-- View 1: Full Order Details
CREATE OR REPLACE VIEW vw_order_details AS
SELECT
    o.order_id,
    o.order_date,
    o.required_date,
    o.shipped_date,
    CASE o.order_status WHEN 1 THEN 'Pending' WHEN 2 THEN 'Processing'
                        WHEN 3 THEN 'Rejected' WHEN 4 THEN 'Completed' END AS status,
    CASE WHEN o.shipped_date > o.required_date THEN 'Delayed'
         WHEN o.shipped_date IS NULL THEN 'Not Shipped'
         ELSE 'On Time' END AS shipment_status,
    CONCAT(c.first_name, ' ', c.last_name)   AS customer_name,
    c.state AS customer_state,
    st.store_name,
    st.state AS store_state,
    CONCAT(sf.first_name, ' ', sf.last_name) AS staff_name,
    p.product_name,
    b.brand_name,
    cat.category_name,
    oi.quantity,
    oi.list_price,
    oi.discount,
    ROUND(oi.list_price * oi.quantity * (1 - oi.discount), 2) AS net_revenue
FROM orders o
JOIN customers c   ON o.customer_id = c.customer_id
JOIN stores st     ON o.store_id = st.store_id
JOIN staffs sf     ON o.staff_id = sf.staff_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p    ON oi.product_id = p.product_id
JOIN brands b      ON p.brand_id = b.brand_id
JOIN categories cat ON p.category_id = cat.category_id;


-- View 2: Store KPIs
CREATE OR REPLACE VIEW vw_store_kpis AS
SELECT
    st.store_name,
    st.state,
    COUNT(DISTINCT o.order_id)                                      AS total_orders,
    COUNT(DISTINCT o.customer_id)                                   AS unique_customers,
    SUM(oi.quantity)                                                AS units_sold,
    ROUND(SUM(oi.list_price * oi.quantity * (1-oi.discount)), 2)   AS net_revenue,
    ROUND(AVG(oi.discount)*100, 1)                                  AS avg_discount_pct
FROM stores st
JOIN orders o       ON st.store_id = o.store_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY st.store_id, st.store_name, st.state;


-- View 3: Monthly Revenue Trend
CREATE OR REPLACE VIEW vw_monthly_revenue AS
SELECT
    YEAR(o.order_date)                                              AS year,
    MONTH(o.order_date)                                             AS month,
    DATE_FORMAT(o.order_date, '%Y-%m')                              AS period,
    COUNT(DISTINCT o.order_id)                                      AS orders,
    ROUND(SUM(oi.list_price * oi.quantity * (1-oi.discount)), 2)   AS net_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY year, month, period
ORDER BY year, month;


-- View 4: Staff Leaderboard
CREATE OR REPLACE VIEW vw_staff_leaderboard AS
SELECT
    CONCAT(sf.first_name, ' ', sf.last_name)                       AS staff_name,
    st.store_name,
    COUNT(DISTINCT o.order_id)                                      AS orders_handled,
    ROUND(SUM(oi.list_price * oi.quantity * (1-oi.discount)), 2)   AS total_revenue,
    RANK() OVER (ORDER BY SUM(oi.list_price * oi.quantity * (1-oi.discount)) DESC) AS revenue_rank
FROM orders o
JOIN staffs sf      ON o.staff_id = sf.staff_id
JOIN stores st      ON o.store_id = st.store_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY sf.staff_id, staff_name, st.store_name;


-- View 5: Inventory Health
CREATE OR REPLACE VIEW vw_inventory_health AS
SELECT
    st.store_name,
    p.product_name,
    b.brand_name,
    c.category_name,
    sk.quantity,
    CASE
        WHEN sk.quantity = 0  THEN 'Out of Stock'
        WHEN sk.quantity < 5  THEN 'Critical'
        WHEN sk.quantity < 10 THEN 'Low'
        ELSE 'Adequate'
    END AS stock_status
FROM stocks sk
JOIN stores st    ON sk.store_id = st.store_id
JOIN products p   ON sk.product_id = p.product_id
JOIN brands b     ON p.brand_id = b.brand_id
JOIN categories c ON p.category_id = c.category_id;


-- View 6: Customer Lifetime Value
CREATE OR REPLACE VIEW vw_customer_ltv AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name)                         AS customer_name,
    c.state,
    COUNT(DISTINCT o.order_id)                                      AS total_orders,
    ROUND(SUM(oi.list_price * oi.quantity * (1-oi.discount)), 2)   AS lifetime_value,
    MIN(o.order_date)                                               AS first_order,
    MAX(o.order_date)                                               AS last_order
FROM customers c
JOIN orders o       ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY c.customer_id, customer_name, c.state;


-- =============================================================================
-- END OF SCRIPT
-- =============================================================================
