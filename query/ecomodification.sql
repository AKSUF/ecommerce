create database ecommerce;
use ecommerce;
drop table ecommerce_orders;
drop database ecommerce;
show tables;

CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id VARCHAR(50),
    order_date DATE,
    status VARCHAR(50),
    fulfilment VARCHAR(50),
    sales_channel VARCHAR(100),
    ship_service_level VARCHAR(100),
    style VARCHAR(100),
    sku VARCHAR(100),
    category VARCHAR(50),
    size VARCHAR(20),
    asin VARCHAR(20),
    courier_status VARCHAR(50),
    qty INT,
    currency VARCHAR(10),
    amount DECIMAL(10,2),
    ship_city VARCHAR(100),
    ship_state VARCHAR(100),
    ship_postal_code VARCHAR(20),
    ship_country VARCHAR(10),
    promotion_ids VARCHAR(100),
    b2b BOOLEAN,
    fulfilled_by VARCHAR(50),
    extra_field VARCHAR(100)
);


CREATE TABLE price_comparison (
    id INT PRIMARY KEY,
    shiprocket VARCHAR(100),
    price_per_unit_shiprocket VARCHAR(100),
    price_per_unit_increff VARCHAR(100)
);

CREATE TABLE finance_summary (
    id INT PRIMARY KEY,
    received_particular VARCHAR(255),
    received_amount DECIMAL(12,2),
    expense_particular VARCHAR(255),
    expense_amount DECIMAL(12,2)
);

CREATE TABLE sales_summary (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_date DATE,
    month_name VARCHAR(20),
    customer_name VARCHAR(100),
    style VARCHAR(50),
    sku VARCHAR(50),
    size VARCHAR(10),
    pcs DECIMAL(10,2),
    rate DECIMAL(10,2),
    gross_amount DECIMAL(10,2)
);



CREATE TABLE product_pricing (
    id INT PRIMARY KEY AUTO_INCREMENT,
    sku VARCHAR(50),
    style_id VARCHAR(50),
    catalog VARCHAR(50),
    category VARCHAR(50),
    weight DECIMAL(10,2),
    tp DECIMAL(10,2),
    mrp_old DECIMAL(10,2),
    final_mrp_old DECIMAL(10,2),
    ajio_mrp DECIMAL(10,2),
    amazon_mrp DECIMAL(10,2),
    amazon_fba_mrp DECIMAL(10,2),
    flipkart_mrp DECIMAL(10,2),
    limeroad_mrp DECIMAL(10,2),
    myntra_mrp DECIMAL(10,2),
    paytm_mrp DECIMAL(10,2),
    snapdeal_mrp DECIMAL(10,2)
);

CREATE TABLE product_pricing_v2 (
    id INT PRIMARY KEY AUTO_INCREMENT,
    sku VARCHAR(50),
    style_id VARCHAR(50),
    catalog VARCHAR(50),
    category VARCHAR(50),
    weight DECIMAL(10,2),
    tp_1 DECIMAL(10,2),
    tp_2 DECIMAL(10,2),
    mrp_old DECIMAL(10,2),
    final_mrp_old DECIMAL(10,2),
    ajio_mrp DECIMAL(10,2),
    amazon_mrp DECIMAL(10,2),
    amazon_fba_mrp DECIMAL(10,2),
    flipkart_mrp DECIMAL(10,2),
    limeroad_mrp DECIMAL(10,2),
    myntra_mrp DECIMAL(10,2),
    paytm_mrp DECIMAL(10,2),
    snapdeal_mrp DECIMAL(10,2)
);

CREATE TABLE sku_stock_clean (
    id INT,
    sku_code VARCHAR(50),
    design_no VARCHAR(50),
    stock DECIMAL(10,2),
    category VARCHAR(100),
    size VARCHAR(10),
    color VARCHAR(50)
);

select * from sku_stock_clean;

-- 1) Create target table (run once)
CREATE TABLE IF NOT EXISTS product_pricing_combined (
    sku VARCHAR(255),
    catalog VARCHAR(255),
    category VARCHAR(255),
    weight FLOAT,
    style_id VARCHAR(255),
    ajio_mrp FLOAT,
    amazon_fba_mrp FLOAT,
    amazon_mrp FLOAT,
    final_mrp_old FLOAT,
    flipkart_mrp FLOAT,
    limeroad_mrp FLOAT,
    mrp_old FLOAT,
    myntra_mrp FLOAT,
    paytm_mrp FLOAT,
    snapdeal_mrp FLOAT,
    tp_1 FLOAT,
    tp_2 FLOAT,
    merge_source VARCHAR(32)
);

-- 2) Create temporary table from a single SELECT (no CTEs)
CREATE TEMPORARY TABLE temp_pricing AS
SELECT
    v1.sku,
    v1.catalog,
    v1.category,
    v1.weight,
    v1.style_id,
    COALESCE(v2.ajio_mrp, v1.ajio_mrp)        AS ajio_mrp,
    COALESCE(v2.amazon_fba_mrp, v1.amazon_fba_mrp) AS amazon_fba_mrp,
    COALESCE(v2.amazon_mrp, v1.amazon_mrp)    AS amazon_mrp,
    COALESCE(v2.final_mrp_old, v1.final_mrp_old)   AS final_mrp_old,
    COALESCE(v2.flipkart_mrp, v1.flipkart_mrp)     AS flipkart_mrp,
    COALESCE(v2.limeroad_mrp, v1.limeroad_mrp)     AS limeroad_mrp,
    COALESCE(v2.mrp_old, v1.mrp_old)           AS mrp_old,
    COALESCE(v2.myntra_mrp, v1.myntra_mrp)     AS myntra_mrp,
    COALESCE(v2.paytm_mrp, v1.paytm_mrp)       AS paytm_mrp,
    COALESCE(v2.snapdeal_mrp, v1.snapdeal_mrp) AS snapdeal_mrp,
    COALESCE(v2.tp_1, v1.tp_1)                 AS tp_1,
    v2.tp_2                                    AS tp_2,
    CASE
        WHEN v2.sku IS NOT NULL THEN 'v2_priority'
        WHEN v1.sku IS NOT NULL THEN 'v1_only'
        ELSE 'unknown'
    END                                        AS merge_source
FROM
    (
      -- pricing_v1 as subquery
      SELECT
        sku,
        catalog,
        category,
        CAST(weight AS FLOAT) AS weight,
        style_id,
        CAST(ajio_mrp AS FLOAT) AS ajio_mrp,
        CAST(amazon_fba_mrp AS FLOAT) AS amazon_fba_mrp,
        CAST(amazon_mrp AS FLOAT) AS amazon_mrp,
        CAST(final_mrp_old AS FLOAT) AS final_mrp_old,
        CAST(flipkart_mrp AS FLOAT) AS flipkart_mrp,
        CAST(limeroad_mrp AS FLOAT) AS limeroad_mrp,
        CAST(mrp_old AS FLOAT) AS mrp_old,
        CAST(myntra_mrp AS FLOAT) AS myntra_mrp,
        CAST(paytm_mrp AS FLOAT) AS paytm_mrp,
        CAST(snapdeal_mrp AS FLOAT) AS snapdeal_mrp,
        CAST(tp AS FLOAT) AS tp_1,
        NULL AS tp_2
      FROM product_pricing
    ) AS v1
LEFT JOIN
    (
      -- pricing_v2 as subquery
      SELECT
        sku,
        catalog,
        category,
        CAST(weight AS FLOAT) AS weight,
        style_id,
        CAST(ajio_mrp AS FLOAT) AS ajio_mrp,
        CAST(amazon_fba_mrp AS FLOAT) AS amazon_fba_mrp,
        CAST(amazon_mrp AS FLOAT) AS amazon_mrp,
        CAST(final_mrp_old AS FLOAT) AS final_mrp_old,
        CAST(flipkart_mrp AS FLOAT) AS flipkart_mrp,
        CAST(limeroad_mrp AS FLOAT) AS limeroad_mrp,
        CAST(mrp_old AS FLOAT) AS mrp_old,
        CAST(myntra_mrp AS FLOAT) AS myntra_mrp,
        CAST(paytm_mrp AS FLOAT) AS paytm_mrp,
        CAST(snapdeal_mrp AS FLOAT) AS snapdeal_mrp,
        CAST(tp_1 AS FLOAT) AS tp_1,
        CAST(tp_2 AS FLOAT) AS tp_2
      FROM product_pricing_v2
    ) AS v2
ON v1.sku = v2.sku;

-- 3) Insert from temporary table into final table
INSERT INTO product_pricing_combined (
    sku, catalog, category, weight, style_id,
    ajio_mrp, amazon_fba_mrp, amazon_mrp, final_mrp_old,
    flipkart_mrp, limeroad_mrp, mrp_old, myntra_mrp,
    paytm_mrp, snapdeal_mrp, tp_1, tp_2, merge_source
)
SELECT
    sku, catalog, category, weight, style_id,
    ajio_mrp, amazon_fba_mrp, amazon_mrp, final_mrp_old,
    flipkart_mrp, limeroad_mrp, mrp_old, myntra_mrp,
    paytm_mrp, snapdeal_mrp, tp_1, tp_2, merge_source
FROM temp_pricing;

-- 4) Drop temporary table (optional but tidy)
DROP TEMPORARY TABLE IF EXISTS temp_pricing;

select * from product_pricing_combined;


-- Post-Merge: Add Derived Columns & Indexes
ALTER TABLE product_pricing_combined 
ADD COLUMN avg_mrp FLOAT,
ADD COLUMN avg_tp_cost FLOAT;
select * from product_pricing_combined;
UPDATE product_pricing_combined 
SET avg_mrp = (ajio_mrp + amazon_mrp + myntra_mrp + flipkart_mrp + paytm_mrp + snapdeal_mrp + limeroad_mrp) / 7,  -- Avg across channels
    avg_tp_cost = (tp_1 + COALESCE(tp_2, tp_1)) / (1 + CASE WHEN tp_2 IS NOT NULL THEN 1 ELSE 0 END);

CREATE INDEX idx_sku ON product_pricing_combined (sku);
CREATE INDEX idx_category ON product_pricing_combined (category);

show tables;


-- Enrich: LEFT JOIN summary to orders; derive/fill gaps
drop view enriched_orders;
drop view orders_with_summary;
select * from orders_with_summary;


CREATE VIEW orders_with_summary AS
SELECT
    o.order_id,
    DATE(o.date) AS date,
    o.sku,
    o.amount AS order_amount,
    o.qty,
    o.ship_city,
    o.category,
    o.sales_channel,
    o.ship_postal_code,
    o.fulfilment,
    o.ship_state,
    o.style,
    o.promotion_ids,
    se.customer,
    se.rate_per_unit,
    se.gross_amount,
    COALESCE(se.pieces_sold, o.qty) AS pieces_sold,
    se.months,
    CASE
        WHEN se.customer IS NOT NULL THEN 'Known'
        ELSE 'New/Anonymous'
    END AS customer_type,
    CASE
        WHEN se.sku IS NOT NULL THEN 'Enriched'
        ELSE 'Orders Only'
    END AS enrich_source
FROM orders o
left  JOIN summary_enriched se
    ON o.sku = se.sku
  
WHERE LOWER(o.status) IN ('shipped', 'delivered')
  AND o.qty > 0;

select * from orders;
select * from summary_enriched;
CREATE VIEW summary_enriched AS
SELECT
    sku,
    DATE(date) AS date,
    customer,
    CAST(gross_amt AS DECIMAL(10,2)) AS gross_amount,
    CAST(rate AS DECIMAL(10,2)) AS rate_per_unit,
    CAST(pcs AS DECIMAL(10,2)) AS pieces_sold,
    style,
    months,
    COALESCE(customer, 'Anonymous') AS customer_segment
FROM sales_summary;

select * from summary_enriched;
select * from orders;
select * from orders_with_summary;


drop table sales_orders;
-- amking table from enriched_orders view
CREATE TABLE sales_orders AS
SELECT *
FROM orders_with_summary;

-- after making this table droped the sales_summery and orders table
select * from sales_orders;
select * from sales_summary;
select * from orders;
-- combind table product _pice_combined + sku_stock_clean
CREATE TABLE dim_product (
    product_key SERIAL PRIMARY KEY,  -- Surrogate PK
    sku VARCHAR(50) NOT NULL UNIQUE,  -- Natural key
    style_id VARCHAR(50),
    catalog VARCHAR(50),
    category VARCHAR(50),
    color VARCHAR(50),
    size VARCHAR(20),
    design_no VARCHAR(50),
    weight VARCHAR(20),
    tp_1 FLOAT,
    tp_2 FLOAT,
    avg_tp_cost FLOAT,
    ajio_mrp FLOAT,
    amazon_mrp FLOAT,
    myntra_mrp FLOAT,
    avg_mrp FLOAT,  -- Derived
    stock DOUBLE PRECISION,
    source_flag VARCHAR(20),  -- From merge
valid_from DATETIME DEFAULT CURRENT_TIMESTAMP,
valid_to DATETIME DEFAULT '9999-12-31 23:59:59',
    is_current BOOLEAN DEFAULT TRUE
);
truncate table dim_product;
INSERT INTO dim_product (sku, style_id, catalog, category, color, size, design_no, weight, tp_1, tp_2, avg_tp_cost, ajio_mrp, amazon_mrp, myntra_mrp, avg_mrp, stock, source_flag)
SELECT DISTINCT
    ppc.sku,
    ppc.style_id,
    ppc.catalog,
    COALESCE(ppc.category, ssc.category) AS category,
    ssc.color,
    COALESCE(ssc.size, 'Unknown') AS size,
    ssc.design_no,
    ppc.weight,
    ppc.tp_1,
    ppc.tp_2,
    ppc.avg_tp_cost,
    ppc.ajio_mrp,
    ppc.amazon_mrp,
    ppc.myntra_mrp,
    ppc.avg_mrp,
    ssc.stock,
    ppc.merge_source AS source_flag
FROM product_pricing_combined ppc
LEFT JOIN sku_stock_clean ssc ON ppc.sku = ssc.sku_code;

select * from dim_product;

CREATE VIEW dim_product_missing_pricing AS
SELECT sku_code
FROM sku_stock_clean
WHERE sku_code NOT IN (SELECT sku FROM product_pricing_combined);

select * from dim_product_missing_pricing;


-- as sku_code_clean tables any sku_code does not match with product_price_combined tabel
-- so we separately rename sku_code clan not adjust with dim_product table

RENAME TABLE sku_stock_clean TO dim_sku_stock;
rename table sales_orders to fact_sales_orders;

-- after making the dim_product table drop two tables
select * from  product_pricing_combined;
drop table sku_stock_clean;
select * from dim_product;
ALTER TABLE product_pricing_combined
ADD COLUMN avg_mrp FLOAT;
select * from sku_stock_clean;
select * from sku_stock_clean;
update product_pricing_combined
set avg_mrp = (amazon_mrp +coalesce(myntra_mrp,amazon_mrp)) + (1+case when myntra_mrp is not null then 1 else 0 end);

select * from product_pricing_combined;

-- indes for dim_product
create index idx_dim_product_sku on dim_product(sku);
create index idx_dim_product_category on dim_product(category);

-- create new table for time 
create table dim_time (
date_key serial primary key,
full_date date not null unique,
year int,
quarter int,
month int,
month_name varchar(20),
day_of_week int,
day_name varchar(20),
is_weekend boolean,
fiscal_year int
);

-- populate (from min/max dates in dim_product sales_orders)
INSERT INTO dim_time (
    full_date, year, quarter, month, month_name, day_of_week, day_name, is_weekend, fiscal_year
)
SELECT DISTINCT
    `date` AS full_date,
    YEAR(`date`) AS year,
    QUARTER(`date`) AS quarter,
    MONTH(`date`) AS month,
    MONTHNAME(`date`) AS month_name,
    DAYOFWEEK(`date`) AS day_of_week,  -- 1=Sunday, 7=Saturday
    DAYNAME(`date`) AS day_name,
    CASE WHEN DAYOFWEEK(`date`) IN (1, 7) THEN TRUE ELSE FALSE END AS is_weekend,
    YEAR(`date`) AS fiscal_year
FROM fact_sales_orders
WHERE `date` IS NOT NULL
ORDER BY `date`;

select min(date ) from sales_orders;
select * from sales_orders;

create table dim_customer(
customer_key serial primary key,
customer_id varchar(100) not null unique,
customer_name varchar(200),
customer_type varchar(50),
months varchar(50),
first_order_date date,
last_order_date date,
total_orders int,
total_gross float,
segment varchar(50)
);

-- populate 
create temporary table  customer_agg 
select 
customer,
customer_type,
months,
min(date)as first_order_date,
max(date)as last_order_date,
count(distinct order_id )as total_orders,
sum(gross_amount)as total_gross,
NTILE(5) OVER (ORDER BY SUM(gross_amount) DESC) AS segment
from sales_orders group by customer,customer_type,months;


insert into dim_customer(customer_id,customer_name,customer_type,months,first_order_date,last_order_date,total_orders,total_gross,segment)
select 
COALESCE( CONCAT('Anonymous_', ROW_NUMBER() OVER (ORDER BY customer))) AS customer_id,
customer as customer_name,
customer_type,
months,
first_order_date,
last_order_date,
total_orders,
total_gross,
case segment when 1 then 'VIP' 
             when 2 then 'Loyal'
             else 'Standard' 
             end as segment
from customer_agg;
             
truncate table dim_customer;

create table dim_geography (
geo_key serial primary key,
ship_country varchar(50) default 'India',
ship_state varchar (50),
ship_city varchar(100),
ship_postal_code varchar(20),
state_code varchar(10)
);
select * from dim_geography;
insert into dim_geography(ship_country,ship_state,ship_city,ship_postal_code)
select distinct
'India' as ship_country,
ship_state,
ship_city,
ship_postal_code
from sales_orders
where ship_state is not null;
drop table dim_channel;
create table dim_channel(
channel_key serial primary key,
sales_channel varchar(50),
fulfilment varchar(50),
ship_service_level varchar(50),
increff_cost float,
shiprocket_cost float,
courier_status varchar(50),
b2b boolean
);

insert into dim_channel(sales_channel,fulfilment,ship_service_level,increff_cost,shiprocket_cost,courier_status,b2b)
select distinct 
e.sales_channel,
e.fulfilment,
ship_service_level,
cast(pc.increff as float)as increff_cost,
cast(pc.shiprocket as float)as shiprocket_cost,
courier_status,
(b2b=1) as b2b
FROM sales_orders e
LEFT JOIN price_comparison pc ON e.fulfilment = pc.increff OR e.fulfilment = pc.shiprocket  -- Fuzzy match
LEFT JOIN orders o ON e.order_id = o.order_id;

create table dim_finance_expenses(
expense_key serial primary key,
expense_type varchar(100) unique,
recived_amount float,
expense_category varchar(50) default 'Operational'
);
select * from dim_finance_expenses;
insert into dim_finance_expenses(expense_type,recived_amount)
select 
expance as expense_type,
sum(cast(recived_amount as float))as recived_amount
from finance_summary group by expance;

drop table fact_sales_transactions ;
create table fact_sales_transactions (
transaction_key serial primary key,
order_id varchar (100) not null,
product_key int references dim_product(product_key),
date_key int references dim_time(date_key),
customer_key int references dim_customer(customer_key),
geo_key int references dim_geography(geo_key),
channel_key int references dim_chaneel(channel_key),
expense_key int references dim_finance_expenses(expense_key),
order_amount float,
gross_amount float,
rate_per_unit float,
qty int,
pieces_sold int,
margin_pct float,
promotion_ids text,
status varchar(50),
size varchar(20),
load_date timestamp default current_timestamp
);

insert into fact_sales_transactions(
order_id,product_key,date_key,customer_key,geo_key,channel_key,expense_key,
order_amount,gross_amount, rate_per_unit,qty,pieces_sold,margin_pct,promotion_ids,
status,size
)
select e.order_id,dp.product_key,dt.date_key,dg.geo_key,dch.channel_key,
(select expense_key from dim_finance_expenses limit 1)as expense_key,
e.order_amount,
e.gross_amount,
e.rate_per_unit,
e.qty,
e.pieces_sold,
eu.margin_pct,
e.promotion_ids,
e.status,
e.size 
FROM sales_orders e
LEFT JOIN dim_product dp ON e.sku = dp.sku
LEFT JOIN dim_time dt ON e.date = dt.full_date
left join dim_customer on e.customer = dc.customer_id
left join dim_geography dg on e.ship_state = dg.ship_state
and e.ship_city= dg.ship_city 
left join dim_channel dch on e.sales_channel = dch.sales_channel
and e.fulfilment = dch.fulfilment
order by e.date desc;

select * from fact_sales_transactions;
drop table fact_sales_transactions;
CREATE INDEX idx_order_id_fact ON fact_sales_transactions(order_id);
CREATE INDEX idx_order_id_sales ON sales_orders(order_id);
CREATE INDEX idx_sku_sales ON sales_orders(sku);
CREATE INDEX idx_sku_product ON dim_product(sku);


-- Repeat this until affected rows = 0
UPDATE fact_sales_transactions AS ft
JOIN (
    SELECT so.order_id, dp.product_key
    FROM sales_orders so
    JOIN dim_product dp ON so.sku = dp.sku
    WHERE dp.product_key IS NOT NULL
    LIMIT 10000
) AS sub ON ft.order_id = sub.order_id
SET ft.product_key = sub.product_key
WHERE ft.product_key IS NULL;

ALTER TABLE fact_sales_orders-- To dim_product (use surrogate if added; here natural sku as string? Wait, dims use natural PKs—adjust type)
ADD COLUMN time_fk INT NULL AFTER date,
ADD COLUMN customer_fk INT NULL AFTER customer,
ADD COLUMN geo_fk INT NULL AFTER ship_state,
ADD COLUMN channel_fk INT NULL AFTER sales_channel,
ADD COLUMN stock_fk INT NULL AFTER category;

-- add the foreign key in fact_sales_orders from product table
UPDATE fact_sales_orders f
SET product_fk = (
    SELECT dp.product_key  -- Assume dim_product has AUTO_INCREMENT PK as 'product_id'; else use sku directly
    FROM dim_product dp 
    WHERE dp.sku = f.sku
    LIMIT 1
)
WHERE f.sku IS NOT NULL;

UPDATE fact_sales_orders f
JOIN dim_product dp ON f.sku = dp.sku
SET f.product_fk = dp.product_key
WHERE f.product_fk IS NULL;


-- FK 2: Time (Full match on date)
UPDATE fact_sales_orders f
SET time_fk = (
    SELECT dt.date_key  -- Assume AUTO_INCREMENT PK as 'time_id'
    FROM dim_time dt 
    WHERE dt.full_date = f.date
    LIMIT 1
)
WHERE f.date IS NOT NULL;

-- FK 3: Customer (Match on customer; handle NULLs)
UPDATE fact_sales_orders f
SET customer_fk = (
    SELECT dc.customer_key  -- AUTO_INCREMENT PK
    FROM dim_customer dc 
    WHERE dc.customer_name = f.customer
    LIMIT 1
)
WHERE f.customer IS NOT NULL;

-- FK 4: Geography (Match on ship_state)
UPDATE fact_sales_orders f
SET geo_fk = (
    SELECT dg.geo_key  -- AUTO_INCREMENT PK
    FROM dim_geography dg 
    WHERE dg.ship_state = f.ship_state
    LIMIT 1
)
WHERE f.ship_state IS NOT NULL;

-- FK 5: Channel (Composite match)
UPDATE fact_sales_orders f
SET channel_fk = (
    SELECT dch.channel_key  -- AUTO_INCREMENT PK
    FROM dim_channel dch 
    WHERE dch.sales_channel = f.sales_channel
    LIMIT 1
)
WHERE f.sales_channel IS NOT NULL;

-- FK 6: SKU Stock (Loose match on sku_code ~ category fallback)
UPDATE fact_sales_orders f
JOIN dim_sku_stock dss ON f.sku = dss.sku_code
SET f.stock_fk = dss.index;




-- FK 6: SKU Stock (Loose match on sku_code ~ category fallback)
UPDATE fact_sales_orders f
SET stock_fk = (
    SELECT dss.index  -- AUTO_INCREMENT PK
    FROM dim_sku_stock dss 
    WHERE dss.sku_code = f.sku  -- Primary try
       OR (dss.category = f.category AND f.sku IS NULL)  -- Fallback
    LIMIT 1
)
WHERE f.sku IS NOT NULL OR f.category IS NOT NULL;

ALTER TABLE dim_sku_stock
ADD COLUMN fact_fk INT;


CREATE INDEX idx_fact_sku ON fact_sales_orders(sku);
CREATE INDEX idx_fact_category ON fact_sales_orders(category);
CREATE INDEX idx_stock_sku ON dim_sku_stock(sku_code);
CREATE INDEX idx_stock_category ON dim_sku_stock(category);


-- counting the mismatch
SELECT
    (SELECT COUNT(DISTINCT sku) FROM fact_sales_orders) AS total_skus_in_fact,
    (SELECT COUNT(DISTINCT sku_code) FROM dim_sku_stock) AS total_skus_in_dim,
    (SELECT COUNT(DISTINCT f.sku)
     FROM fact_sales_orders f
     LEFT JOIN dim_sku_stock dp ON f.sku = dp.sku
     WHERE dp.sku IS NULL) AS unmatched_skus_in_fact;

CREATE TABLE sku_bridge (
    fact_sku VARCHAR(100),
    stock_sku VARCHAR(100),
    match_type VARCHAR(20)  -- e.g., 'Exact', 'Fuzzy', 'Manual'
);

INSERT INTO sku_bridge (fact_sku, stock_sku, match_type)
SELECT DISTINCT f.sku, d.sku_code, 'Fuzzy'
FROM fact_sales_orders f
JOIN dim_sku_stock d ON f.sku LIKE CONCAT('%', d.sku_code, '%')
WHERE f.sku NOT IN (SELECT fact_sku FROM sku_bridge);

drop table sku_to_fact_map;
CREATE TABLE sku_to_fact_map (
    sku_code VARCHAR(100),
    fact_id INT,
    match_type VARCHAR(20)  -- 'Exact', 'Fuzzy', etc.
);

INSERT INTO sku_to_fact_map (sku_code, fact_id, match_type)
SELECT dss.sku_code, f.order_id, 'Exact'
FROM dim_sku_stock dss
JOIN fact_sales_orders f ON dss.sku_code = f.sku;

select distinct dp.sku,dss.sku_code 
from dim_product dp 
join dim_sku_stock dss on dp.sku = dss.sku_code;

select distinct fso.sku , dss.sku_code 
from fact_sales_orders fso
join dim_sku_stock dss on fso.sku = dss.sku_code;

-- 1. SKU Format Comparison (Top 20 samples from each table)
SELECT 'fact_sales_orders' AS table_name, sku, LENGTH(sku) AS len, 
       LEFT(sku, 10) AS prefix, COUNT(*) AS freq
FROM fact_sales_orders 
WHERE sku IS NOT NULL 
GROUP BY sku 
ORDER BY freq DESC 
LIMIT 20;

-- Run separately for dim_product:
SELECT 'dim_product' AS table_name, sku, LENGTH(sku) AS len, 
       LEFT(sku, 10) AS prefix, COUNT(*) AS freq
FROM dim_product 
GROUP BY sku 
ORDER BY freq DESC 
LIMIT 20;

SELECT 'dim_sku_stock' AS table_name, sku_code, LENGTH(sku_code) AS len, 
       LEFT(sku_code, 10) AS prefix, COUNT(*) AS freq
FROM dim_sku_stock 
GROUP BY sku_code 
ORDER BY freq DESC 
LIMIT 20;

-- 2. Overlap Check (Set-based, fast—no join)
SELECT 
    (SELECT COUNT(DISTINCT sku) FROM fact_sales_order WHERE sku IS NOT NULL) AS fact_unique_skus,
    (SELECT COUNT(DISTINCT sku) FROM dim_product) AS product_unique_skus,
    (SELECT COUNT(DISTINCT sku_code) FROM dim_sku_stock) AS stock_unique_skus,
    -- Exact match count
    (SELECT COUNT(DISTINCT f.sku) 
     FROM fact_sales_order f 
     WHERE f.sku IN (SELECT sku FROM dim_product)) AS product_matches,
    (SELECT COUNT(DISTINCT f.sku) 
     FROM fact_sales_order f 
     WHERE f.sku IN (SELECT sku_code FROM dim_sku_stock));
     
     
UPDATE fact_sales_orders f
SET stock_fk = (
    SELECT s.stock_id 
    FROM dim_sku_stock s 
    WHERE s.sku_code = f.sku
    LIMIT 1
)
WHERE f.sku IN (SELECT sku_code FROM dim_sku_stock);
     
     
 alter table  sku_stock_clean 
 ADD COLUMN stock_id INT AUTO_INCREMENT PRIMARY KEY ;
     
show tables;
select * from fact_sales_orders;
select * from dim_product;
select * from dim_time;
select * from dim_channel;
select * from finance_summary;
select * from dim_sku_stock;
select * from sales_orders;
select * from dim_customer;
select * from dim_geography;
drop table sales_orders;