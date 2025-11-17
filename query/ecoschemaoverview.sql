call AutoDetectColumnCategory('dim_channel');
call AutoDetectColumnCategory('dim_customer');
call AutoDetectColumnCategory('dim_finance_expenses');
call AutoDetectColumnCategory('dim_geography');
call AutoDetectColumnCategory('dim_product');
call AutoDetectColumnCategory('dim_time');
call AutoDetectColumnCategory('fact_sales_orders');
call AutoDetectColumnCategory('sku_stock_clean');
call AutoDetectColumnCategory('');


--
select count(distinct(order_id) ) from fact_sales_orders;
-- top order_id placed
select order_id, count(*) as most_order_id from fact_sales_orders 
group by order_id order by count(*) desc limit 10;

-- 


show tables;
select * from fact_sales_orders;    
select * from dim_product;
select * from dim_time;
select * from dim_channel;
select * from sku_stock_clean;
select * from sales_orders;
select * from dim_customer;
select * from dim_geography;