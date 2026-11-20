DROP TABLE IF EXISTS order_items, orders, products, locations, customers CASCADE;

CREATE TABLE customers (
    customer_id   VARCHAR(10) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    segment       VARCHAR(20) NOT NULL
);

CREATE TABLE locations (
    postal_code CHAR(5) PRIMARY KEY,
    city        VARCHAR(50) NOT NULL,
    state       VARCHAR(50) NOT NULL,
    region      VARCHAR(20) NOT NULL,
    country     VARCHAR(50) NOT NULL
);

CREATE TABLE products (
    product_id   VARCHAR(20) PRIMARY KEY,
    category     VARCHAR(30) NOT NULL,
    sub_category VARCHAR(30) NOT NULL,
    product_name VARCHAR(200) NOT NULL
);

CREATE TABLE orders (
    order_id    VARCHAR(20) PRIMARY KEY,
    order_date  DATE NOT NULL,
    ship_date   DATE NOT NULL,
    ship_mode   VARCHAR(20) NOT NULL,
    customer_id VARCHAR(10) NOT NULL REFERENCES customers(customer_id),
    postal_code CHAR(5) NOT NULL REFERENCES locations(postal_code)
);

CREATE TABLE order_items (
    row_id     INTEGER PRIMARY KEY,
    order_id   VARCHAR(20) NOT NULL REFERENCES orders(order_id),
    product_id VARCHAR(20) NOT NULL REFERENCES products(product_id),
    sales      NUMERIC(10,4) NOT NULL,
    quantity   INTEGER NOT NULL,
    discount   NUMERIC(4,2) NOT NULL,
    profit     NUMERIC(10,4) NOT NULL
);