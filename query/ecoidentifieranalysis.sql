-- Order status distribution
SELECT 
    status,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(COUNT(DISTINCT order_id) * 100.0 / SUM(COUNT(DISTINCT order_id)) OVER(), 2) AS percentage,
    SUM(order_amount) AS total_revenue,
    ROUND(AVG(order_amount), 2) AS avg_order_value
FROM fact_sales_orders
GROUP BY status
ORDER BY total_orders DESC;

-- order fulfiment rate bu sales channel 
-- 1.2 Order Fulfillment Rate by Sales Channel
SELECT 
    sales_channel,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(CASE WHEN status = 'Shipped' THEN 1 ELSE 0 END) AS shipped_orders,
    ROUND(SUM(CASE WHEN status = 'Shipped' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT order_id), 2) AS fulfillment_rate,
    SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT order_id), 2) AS cancellation_rate
FROM fact_sales_orders
GROUP BY sales_channel;

-- top 1 daily order fulfilment trend
WITH daily_summary AS (
  SELECT 
    t.full_date,
    t.day_name,
    COUNT(DISTINCT f.order_id) AS daily_orders,
    SUM(CASE WHEN f.status = 'Shipped' THEN 2 ELSE 0 END) AS shipped_orders,
    ROUND(AVG(f.order_amount), 2) AS avg_order_value,
    SUM(f.order_amount) AS daily_revenue,
    ROW_NUMBER() OVER (PARTITION BY t.day_name ORDER BY SUM(f.order_amount) DESC) AS rn
  FROM fact_sales_orders f
  JOIN dim_time t ON f.time_fk = t.date_key
  GROUP BY t.full_date, t.day_name
)

SELECT *
FROM daily_summary
WHERE rn = 1
ORDER BY full_date;

-- average order value (aov) analysis
select 
count(distinct order_id)as total_orders,
count(*)as total_line_items,
round(count(*) * 1.0/count(distinct order_id),2)as avg,
round(sum(order_amount),2)as total_revenue,
round(avg(order_amount),2)as avg_order_value,
round(min(order_amount),2) as min_order_value,
round(max(order_amount),2)as max_order_value,
round(stddev(order_amount),2)as stddev_order_value
from fact_sales_orders;

-- aov by customer tyep
select 
customer_type,
count(distinct order_id)as total_orders,
round(avg(order_amount),2)as avg_order_value,
round(sum(order_amount),2) as total_revenue,
round(avg(qty),2) as avg_quantity_per_order,
round(avg(pieces_sold),2)as avg_pieces_per_order
from fact_sales_orders 
group by customer_type;

-- aov by product category
select 
category,
count(distinct order_id)as total_orders,
round(avg(order_amount),2)as avg_order_value,
round(sum(order_amount),2)as total_revenue,
round(sum(order_amount),0)as total_pieces_sold
from fact_sales_orders 
group by category 
order by total_revenue desc;

-- order value distribution 
select 
case 
when order_amount<500 then '0-500'
when order_amount < 1000 then '500-1000'
when order_amount <2000 then '1000-2000'
when order_amount <5000 then '2000-5000'
when order_amount <10000 then '5000-10000'
else '10000+'
end as order_value_bucket,
count(distinct order_id)as order_count,
round(count(distinct order_id) * 100/sum(count(distinct order_id)) over () ,2) as percentage,
round(sum(order_amount),2)as bucket_revenue
from fact_sales_orders
group by order_value_bucket
order by 
case order_value_bucket
when '0-500' then 1
when '500-1000' then 2
when '1000-2000' then 3
when '2000 - 5000' then 4
when '5000 - 10000' then 5
else 6 
end;

# customer analysis

-- top 10 customer by order count
select 
c.customer_name,
c.customer_type,
c.segment,
count(distinct f.order_id)as total_orders,
round(sum(f.order_amount),2)as total_revenue,
round(avg(f.order_amount),2)as avg_order_value,
c.first_order_date,
c.last_order_date,
datediff(c.last_order_date,c.first_order_date)as customer_lifetime_days 
from fact_sales_orders f 
JOIN dim_customer c ON f.customer_fk = c.customer_key
group by c.customer_name,c.customer_type,c.first_order_date,c.last_order_date
order by total_orders desc
limit 10;


-- top 10 customer by reveniue - pareto analysis fro 10 customer
WITH customer_revenue AS (
  SELECT 
    c.customer_name,
    SUM(f.order_amount) AS customer_revenue,
    COUNT(DISTINCT f.order_id) AS order_count
  FROM fact_sales_orders f
  JOIN dim_customer c ON f.customer_fk = c.customer_key
  GROUP BY c.customer_name
),
ranked_customers AS (
  SELECT 
    customer_name,
    customer_revenue,
    order_count,
    SUM(customer_revenue) OVER (ORDER BY customer_revenue DESC) AS cumulative_revenue,
    SUM(customer_revenue) OVER () AS total_revenue,
    ROW_NUMBER() OVER (ORDER BY customer_revenue DESC) AS customer_rank
  FROM customer_revenue
),
cumulative_revenue AS (
  SELECT 
    customer_rank,
    customer_name,
    ROUND(customer_revenue, 2) AS customer_revenue,
    order_count,
    ROUND(cumulative_revenue, 2) AS cumulative_revenue,
    ROUND(cumulative_revenue * 100.0 / total_revenue, 2) AS cumulative_revenue_pct
  FROM ranked_customers
)
SELECT 
  customer_rank,
  customer_name,
  customer_revenue,
  order_count,
  cumulative_revenue,
  cumulative_revenue_pct
FROM cumulative_revenue limit 10;

-- customer concentration risk (top 10 vs total)
WITH top10_revenue AS (
    SELECT SUM(revenue) AS top10_total
    FROM (
        SELECT SUM(f.order_amount) AS revenue
        FROM fact_sales_orders f
        JOIN dim_customer c ON f.customer_fk = c.customer_key
        GROUP BY c.customer_name
        ORDER BY revenue DESC
        LIMIT 10
    ) t
),
total_revenue AS (
    SELECT SUM(order_amount) AS overall_total
    FROM fact_sales_orders
)
SELECT 
    ROUND(t10.top10_total, 2) AS top_10_customer_revenue,
    ROUND(tr.overall_total, 2) AS total_revenue,
    ROUND(t10.top10_total * 100.0 / tr.overall_total, 2) AS concentration_percentage
FROM top10_revenue t10, total_revenue tr;

# repeta purhase analysis

-- customer order frequancy distribtuin 
with customer_order_counts as(
select 
customer_fk,
count(distinct order_id )as order_count,
min(date)as first_order_date,
max(date)as last_order_date,
datediff(max(date),min(date)) as days_between_first_last
from fact_sales_orders 
group by customer_fk
)
select 
case 
when order_count between 1 and 20 then 'under 20 '
when order_count between 21 and 100 then 'Between 21 and 100'
when order_count between 101 and 500 then 'Between 101 and 500'
when order_count between 501 and 1000 then 'Between 500 and 1000'
when order_count between 1001 and 1500 then 'Between 1000 and 1500'
else 'above 1500 '
end as order_frequency_bucket,
count(*) as customer_count ,
round(count(*) * 100/sum(count(*)) over () ,2)as customer_percentage,
round(avg(days_between_first_last),1)as avg_days_between_orders
from customer_order_counts
group by order_frequency_bucket
order by 
case order_frequency_bucket
when 'under 20 ' then 1
when  'Between 21 and 100' then 2
when 'Between 101 and 500' then 3
when 'Between 500 and 1000' then 4 
when 'Between 1000 and 1500' then 4 
else 5 
end;

-- most repurchased products
with pinoint as(
select sku,category, 
count(distinct order_id)as times_orderd,
count(distinct customer_fk)as unique_customers,
sum(pieces_sold)as total_pieces_sold,
round(sum(order_amount),2)as total_revenue,
round(avg(order_amount),2)as avg_order_value
from fact_sales_orders 
group by sku,category 
HAVING COUNT(DISTINCT order_id) > 10
)

select sku,category,
times_orderd,unique_customers,total_pieces_sold,
total_revenue,avg_order_value from pinoint order by times_orderd desc limit 20;


 # promotional effectiness analysis
 select 
 case 
 when promotion_ids is null or promotion_ids = '' then 'Non - Promotional' 
 else 'Promotional'
 end as order_type,
 count(distinct order_id)as total_orders,
 round(count(distinct order_id)* 100/sum(count(distinct order_id))over(),2) as order_percentage,
 round(avg(order_amount),2) as avg_order_value,
 round(sum(order_amount),2)as total_revenue,
 round(sum(order_amount) * 100.0 /sum(sum(order_amount)) over (),2)as revenue_percentage 
 from fact_sales_orders 
 group by order_type;

-- top performing promotions
select 
promotion_ids,
count(distinct order_id)as order_with_promotion,
round(avg(order_amount),2) as avg_order_value,
round(sum(order_amount),2)as total_revenue,
sum(pieces_sold)as total_pieces_sold,
count(distinct customer_fk)as unique_customers
from fact_sales_orders 
where promotion_ids is not null and promotion_ids!=''
group by promotion_ids 
order by total_revenue desc
limit 15;

-- prmotion impact by category
select category,
count(distinct case when promotion_ids is not null and promotion_ids!='' then order_id end )as promotionla_orders,
count(distinct case when promotion_ids is not null or promotion_ids != '' then order_id end)as non_promotional_orders,
round(avg(case when promotion_ids is not null and promotion_ids != '' then order_amount end),2) as avg_promo_rder_value,
round(avg(case when promotion_ids is not null or  promotion_ids != '' then order_amount end),2) as avg_regular_order_value
from fact_sales_orders 
group by category ;

# geographical analysis
-- top 20 states by order value
select g.ship_state,count(distinct f.order_id)as total_orders,
round(sum(f.order_amount),2)as avg_order_value,
round(avg(f.order_amount),2)as avg_order_value,
count(distinct g.ship_city)as unique_cities,
count(distinct f.customer_fk)as unique_customers
from fact_sales_orders f join dim_geography g on f.geo_fk = g.geo_key
group by g.ship_state 
order by total_orders desc
limit 20;

-- top 20 cities by revenue
select g.ship_city,g.ship_state,
count(distinct f.order_id)as total_orders,
round(sum(f.order_amount),2)as total_revenue,
round(avg(f.order_amount),2)as avg_order_value,
count(distinct f.customer_fk)as unique_customers 
from fact_sales_orders f
join dim_geography g on f.geo_fk = g.geo_key
group by g.ship_city,g.ship_state 
order by total_revenue desc
limit 20;

-- geographic cocneatation analysis
with state_revenue as(
select g.ship_state,sum(f.order_amount)as state_revenue
from fact_sales_orders f
join dim_geography g on f.geo_fk = g.geo_key
group by g.ship_state
),
ranked_states as(
select ship_state,
state_revenue,
sum(state_revenue) over(order by state_revenue desc)as cumulative_revenue,
sum(state_revenue) over() as total_revenue,
row_number() over (order by state_revenue desc)as state_rank from state_revenue
)
select 
state_rank,
ship_state,
round(state_revenue,2)as state_revenue,
round(cumulative_revenue,2)as cumulative_revenue,
round(cumulative_revenue* 100 / total_revenue,2)as cumulative_revenue_pct 
from ranked_states 
where state_rank <=10 
order by state_rank;


# peak ordering periods 
-- daiy order volume 
select t.full_date,t.day_name,t.is_weekend ,
count(distinct f.order_id)as daily_orders,
round(sum(f.order_amount),2)as daily_revenue,
round(avg(f.order_amount),2)as avg_order_value,
sum(f.pieces_sold)as pieces_sold
from fact_sales_orders f join dim_time t on f.time_fk = t.date_key
group by t.full_date,t.day_name,t.is_weekend
order by t.full_date limit 10;


-- day of week performace
select 
t.day_name,
count(distinct f.order_id) as total_orders ,
round(avg(count(distinct f.order_id)) over (partition by t.day_name),1)as avg_orders_per_day,
round(sum(f.order_amount),2)as total_revenue,
round(avg(f.order_amount),2)as avg_order_value,
case when t.is_weekend = 1 then 'Weekend' else 'Weekday' end as day_type
from fact_sales_orders f 
join dim_time t on f.time_fk = t.date_key
group by t.day_name,t.day_of_week ,t.is_weekend
order by t.day_of_week;

-- week weekpefomace
select 
case when t.is_weekend= 1  then 'Weekend'  else 'Weekday' end as day_type,
count(distinct f.order_id)as total_orders ,
round(avg(f.order_amount),2)as avg_order_value,
round(sum(f.order_amount),2)as total_revenue,
count(distinct t.full_date)as number_of_days,
round(count(distinct f.order_id) * 1.0 /count(distinct t.full_date),1)as avg_orders_per_day
from fact_sales_orders f
join dim_time t on  f.time_fk = t.date_key
group by day_type;

SELECT 
    t.month_name,
    f.customer_type,
    COUNT(DISTINCT f.order_id) AS monthly_orders,
    ROUND(SUM(f.order_amount), 2) AS monthly_revenue,
    ROUND(AVG(f.order_amount), 2) AS avg_order_value
FROM fact_sales_orders f
JOIN dim_time t ON f.time_fk = t.date_key
GROUP BY t.month_name, t.month, f.customer_type
ORDER BY t.month, f.customer_type;

SELECT 
    customer_type,
    category,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(order_amount), 2) AS total_revenue,
    ROUND(AVG(order_amount), 2) AS avg_order_value,
    SUM(pieces_sold) AS total_pieces_sold
FROM fact_sales_orders
GROUP BY customer_type, category
ORDER BY customer_type, total_revenue DESC;


SELECT 
    'Total Orders' AS metric,
    COUNT(DISTINCT order_id) AS value
FROM fact_sales_orders
UNION ALL
SELECT 
    'Total Order Lines',
    COUNT(*)
FROM fact_sales_orders
UNION ALL
SELECT 
    'Unique Customers',
    COUNT(DISTINCT customer_fk)
FROM fact_sales_orders
UNION ALL
SELECT 
    'Total Revenue',
    ROUND(SUM(order_amount), 2)
FROM fact_sales_orders
UNION ALL
SELECT 
    'Average Order Value',
    ROUND(AVG(order_amount), 2)
FROM fact_sales_orders
UNION ALL
SELECT 
    'Avg Items per Order',
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT order_id), 2)
FROM fact_sales_orders
UNION ALL
SELECT 
    'Total Days Analyzed',
    COUNT(DISTINCT date_key)
FROM dim_time
UNION ALL
SELECT 
    'Avg Daily Orders',
    ROUND(COUNT(DISTINCT order_id) * 1.0 / (SELECT COUNT(DISTINCT date_key) FROM dim_time), 1)
FROM fact_sales_orders;

SHOW COLUMNS FROM fact_sales_orders LIKE 'order_amount';


-- -------------------------------------------------------------
-- dim_product table
-- -------------------------------------------------------------
select 
round(avg(ajio_mrp),2) as avg_ajio_price,
round(avg(amazon_mrp),2) as avg_amazon_price,
round(avg(myntra_mrp),2) as avg_myntra_price
from dim_product;

-- paltform price compariso - inpivot view
-- from view table
select * from basic_calculation;

-- price variance analysis
select 
metric_name,min_value ,max_value , (max_value - min_value)as price_difference from basic_calculation;

-- gross margin analysis by palfomr
SELECT 
    metric_name,
    ROUND(AVG(avg_value), 2) AS avg_mrp,
    ROUND(AVG(max_value), 2) AS avg_max_mrp,
    ROUND(AVG(avg_value - max_value), 2) AS avg_margin,
    ROUND(AVG((avg_value - max_value) * 100 / NULLIF(avg_value, 0)), 2) AS margin_mrp
FROM basic_calculation
GROUP BY metric_name;

-- basic calcualtion by category 
select * from categorystatistics;

-- margin analysis calculation by category
SELECT 
    category,
    COUNT(*) AS product_count,
    ROUND(AVG(avg_mrp), 2) AS avg_selling_price,
    ROUND(AVG(avg_tp_cost), 2) AS avg_cost_price,
    ROUND(AVG(avg_mrp - avg_tp_cost), 2) AS avg_margin_per_unit,
    ROUND(AVG((avg_mrp - avg_tp_cost) * 100 / NULLIF(avg_mrp, 0)), 2) AS avg_margin_pct,
    ROUND(SUM(avg_mrp - avg_tp_cost), 2) AS total_margin_potential
FROM dim_product
WHERE avg_mrp > 0 AND avg_tp_cost > 0
GROUP BY category
ORDER BY avg_margin_pct DESC
LIMIT 0, 50000;


-- margin analysis by catalog
SELECT 
    catalog,
    COUNT(*) AS product_count,
    ROUND(AVG(avg_mrp), 2) AS avg_selling_price,
    ROUND(AVG(avg_tp_cost), 2) AS avg_cost_price,
    ROUND(AVG(avg_mrp - avg_tp_cost), 2) AS avg_margin_per_unit,
    ROUND(AVG((avg_mrp - avg_tp_cost) * 100 / NULLIF(avg_mrp, 0)), 2) AS avg_margin_pct,
    ROUND(SUM(avg_mrp - avg_tp_cost), 2) AS total_margin_potential
FROM dim_product
WHERE avg_mrp > 0 AND avg_tp_cost > 0
GROUP BY catalog
ORDER BY avg_margin_pct DESC
LIMIT 0, 50000;

-- category and cataog analsyis
select 
category,catalog,
count(*) as product_count,
round(avg(avg_mrp),2)as avg_price,
round(avg((avg_mrp - avg_tp_cost) * 100.0 /NULLIF(avg_mrp,0)),2)as margin_pct
from dim_product where avg_mrp >0 and avg_tp_cost >0
group by category,catalog
order by category ,margin_pct desc;

-- price tier analysis by category
WITH calculation AS (
    SELECT  
        category,
        CASE  
            WHEN avg_mrp < 500 THEN 'Budget(0-500)'
            WHEN avg_mrp < 1000 THEN 'Economy(500-1000)'
            WHEN avg_mrp < 2000 THEN 'Mid-Range(1000-2000)'
            WHEN avg_mrp < 5000 THEN 'Premium(2000-5000)'
            ELSE 'Luxury(5000+)'  
        END AS price_tier,
        COUNT(*) AS product_count,
        ROUND(AVG(avg_mrp), 2) AS avg_price,
        ROUND(AVG((avg_mrp - avg_tp_cost) * 100 / NULLIF(avg_mrp, 0)), 2) AS avg_margin_pct
    FROM dim_product  
    WHERE avg_mrp > 0 AND avg_tp_cost > 0  
    GROUP BY category, price_tier
)
SELECT 
    category,
    price_tier,
    avg_price,
    avg_margin_pct
FROM calculation
ORDER BY category, avg_price;

-- product count by category and catalog
select 
category,
count(*) as total_products,
round(count(*) * 100.0/sum(count(*)) over (),2)as category_percentage,
count(distinct catalog)as catalogs_in_category,
count(distinct style_id)as styles_in_category
from dim_product 
group by category 
order by total_products desc;

-- catalog distribution
select
 catalog,
 count(*) as total_products,
 round(count(*) * 100/sum(count(*)) over(),2)as catalog_percentage,
 count(distinct category)as categories_in_catalog,
 round(avg(avg_mrp),2)as avg_catalog_price
 from dim_product
 group by catalog
 order by total_products desc;
 
 -- catalog distribution
select
 weight,
 count(*) as total_products,
 round(count(*) * 100/sum(count(*)) over(),2)as weight_percentage,
 count(distinct weight)as categories_in_weight,
 round(avg(avg_mrp),2)as avg_weight
 from dim_product
 group by weight
 order by total_products desc;
 
 -- style diversity analysis
 select 
 count(distinct style_id)as total_styles,
 count(*) as total_skus,
 round(count(*) * 1.0/count(distinct style_id),2)as avg_sku_per_style,
 max(sku_count)as max_skus_in_style,
 min(sku_count)as min_skus_in_style
 from (
 select style_id,count(*)as sku_count
 from dim_product 
 where style_id is not null and style_id!= ''
 group by style_id
 )style_counts;
 
 #COMPETITIVE POSITIONING ANALYSIS
 
 -- highest catgory in according to paltform 
WITH platform_prices AS (
    SELECT 
        sku,
        category,
        CASE WHEN ajio_mrp > 0 THEN ajio_mrp END AS ajio,
        CASE WHEN amazon_mrp > 0 THEN amazon_mrp END AS amazon,
        CASE WHEN myntra_mrp > 0 THEN myntra_mrp END AS myntra,
        CASE WHEN flipkart_mrp > 0 THEN flipkart_mrp END AS flipkart,
        avg_mrp
    FROM dim_product
)
SELECT 
    sku,
    category,
    ROUND(avg_mrp, 2) AS avg_price,
    ROUND(ajio, 2) AS ajio_price,
    ROUND(amazon, 2) AS amazon_price,
    ROUND(myntra, 2) AS myntra_price,
    ROUND(flipkart, 2) AS flipkart_price,
    CASE 
        WHEN ajio = (SELECT MAX(p) FROM (SELECT ajio AS p UNION SELECT amazon UNION SELECT myntra UNION SELECT flipkart) t) THEN 'Ajio'
        WHEN amazon = (SELECT MAX(p) FROM (SELECT ajio AS p UNION SELECT amazon UNION SELECT myntra UNION SELECT flipkart) t) THEN 'Amazon'
        WHEN myntra = (SELECT MAX(p) FROM (SELECT ajio AS p UNION SELECT amazon UNION SELECT myntra UNION SELECT flipkart) t) THEN 'Myntra'
        WHEN flipkart = (SELECT MAX(p) FROM (SELECT ajio AS p UNION SELECT amazon UNION SELECT myntra UNION SELECT flipkart) t) THEN 'Flipkart'
    END AS highest_price_platform
FROM platform_prices
WHERE avg_mrp > 0
LIMIT 20;

 -- platform Premium/Discount Analysis
select 
'Ajio' as platform,
round(avg(ajio_mrp),2)as platform_avg_price,
round(avg(avg_mrp),2)as overall_avg_price,
round(avg(ajio_mrp) - avg(avg_mrp),2)as price_differece,
round((avg(ajio_mrp)-avg(avg_mrp))* 100.0 /avg(avg_mrp),2)as premium_discount_pct
from dim_product
where ajio_mrp>0 and avg_mrp >0
union all 
select 
'Amazon',
round(avg(amazon_mrp),2),
round(avg(avg_mrp),2),
round(avg(amazon_mrp)-avg(avg_mrp),2),
round((avg(amazon_mrp) - avg(avg_mrp)) * 100.0 /avg(avg_mrp),2) from dim_product
where amazon_mrp >0 and avg_mrp >0
union all 
select 
'Myntra',
round(avg(myntra_mrp),2),
round(avg(avg_mrp),2),
round(avg(myntra_mrp)-avg(avg_mrp),2),
round((avg(myntra_mrp) - avg(avg_mrp)) * 100.0 /avg(avg_mrp),2) from dim_product
where myntra_mrp >0 and avg_mrp >0
union all 
select 
'Flipkart',
round(avg(flipkart_mrp),2),
round(avg(avg_mrp),2),
round(avg(flipkart_mrp)-avg(avg_mrp),2),
round((avg(flipkart_mrp) - avg(avg_mrp)) * 100.0 /avg(avg_mrp),2) from dim_product
where flipkart_mrp >0 and avg_mrp >0
union all 
select 
'paytm',
round(avg(paytm_mrp),2),
round(avg(avg_mrp),2),
round(avg(paytm_mrp)-avg(avg_mrp),2),
round((avg(paytm_mrp) - avg(avg_mrp)) * 100.0 /avg(avg_mrp),2) from dim_product
where paytm_mrp >0 and avg_mrp >0
union all 
select 
'snapdeal',
round(avg(snapdeal_mrp),2),
round(avg(avg_mrp),2),
round(avg(snapdeal_mrp)-avg(avg_mrp),2),
round((avg(snapdeal_mrp) - avg(avg_mrp)) * 100.0 /avg(avg_mrp),2) from dim_product
where flipkart_mrp >0 and avg_mrp >0
union all 
select 
'limeroad',
round(avg(limeroad_mrp),2),
round(avg(avg_mrp),2),
round(avg(limeroad_mrp)-avg(avg_mrp),2),
round((avg(limeroad_mrp) - avg(avg_mrp)) * 100.0 /avg(avg_mrp),2) from dim_product
where limeroad_mrp >0 and avg_mrp >0;

# HIGH Margin product identification
-- top 20 products by margin percentage
select 
sku,
category,
catalog,
style_id,
round(avg_mrp,2)as selling_price,
round(avg_tp_cost,2)as cost_price,
round(avg_mrp - avg_tp_cost,2)as margin_amount,
round((avg_mrp - avg_tp_cost) * 100 /avg_mrp ,2) as margin_pct
from dim_product
where avg_mrp> 0 and avg_tp_cost >0
order by margin_pct desc
limit 20;

-- marin distribttion by price tier
select 
case 
when avg_mrp < 500 then 'Budget(0-500)'
when avg_mrp <1000 then 'Economy(500-1000)'
when avg_mrp <2000 then 'Mid-Range(1000-2000)'
when avg_mrp < 5000 then 'Premium(2000-5000)'
else 'Luxry(5000+)'
end as price_tier,
count(*) as product_count,
round(avg(avg_mrp),2) as avg_price,
round(avg(avg_tp_cost),2)as avg_cost,
round(avg(avg_mrp - avg_tp_cost),2)as avg_margin,
round(avg((avg_mrp - avg_tp_cost) * 100/avg_mrp),2) as avg_margin_pct 
from dim_product 
where avg_mrp>0 and avg_tp_cost >0
group by price_tier
order by 
case price_tier
when 'budget(0-500)' then 1 
when 'Economy(500 - 1000)' then 2
when 'Mid- Range(1000-2000)' then 3
when 'premium(2000-500)' then 4
else 5
end;

# Style diversity analsis

-- top 20 styles by sku count
select 
style_id,
count(*) as sku_count,
count(distinct category)as categoris,
count(distinct catalog)as catalogs,
round(avg(avg_mrp),2)as avg_style_price,
round(avg((avg_mrp - avg_tp_cost) * 100 / nullif(avg_mrp,0)),1)as avg_margin
from dim_product
where style_id is not null and style_id !=""
group by style_id
order by sku_count desc
limit 10;

-- style distribution by category
select 
category,
count(distinct style_id)as unique_styles,
count(*) as total_skus,
round(count(*) * 1.0 /count(distinct style_id),2)as avg_skus_per_style from dim_product 
where style_id is not null and style_id!=''
group by category
order by unique_styles desc;


#	Sku_stock_clean section
#inventpry health and stock analysis
-- overall inventory summary
select 
count(*) as total_records,
count(distinct sku_code)as unique_skus,
count(*) - count(distinct sku_code)as duplicate_records,
round(sum(stock),0)as total_units_in_stock,
round(avg(stock),2)as avg_stock_per_sku,
round(min(stock),0) as min_stock,
round(max(stock),0)as max_stock,
round(stddev(stock),2)as stock_stddev,
count(case when stock=0  then 1 end)as zero_stock_items,
count(case when stock >0 then 1 end )as ittems_in_stcok,
round(count(case when stock = 0 then 1 end)* 100 /count(*),2) as stockout_rate_pct
from sku_stock_clean;

-- stock distribution by quartiles
SELECT 
    'Q1 (0-25%)' AS quartile,
    ROUND(MIN(stock), 0) AS min_stock,
    ROUND(MAX(stock), 0) AS max_stock,
    COUNT(*) AS sku_count
FROM (
    SELECT stock, NTILE(4) OVER (ORDER BY stock) AS quartile_num
    FROM sku_stock_clean
) t
WHERE quartile_num = 1
UNION ALL
SELECT 
    'Q2 (25-50%)',
    ROUND(MIN(stock), 0),
    ROUND(MAX(stock), 0),
    COUNT(*)
FROM (
    SELECT stock, NTILE(4) OVER (ORDER BY stock) AS quartile_num
    FROM sku_stock_clean
) t
WHERE quartile_num = 2
UNION ALL
SELECT 
    'Q3 (50-75%)',
    ROUND(MIN(stock), 0),
    ROUND(MAX(stock), 0),
    COUNT(*)
FROM (
    SELECT stock, NTILE(4) OVER (ORDER BY stock) AS quartile_num
    FROM sku_stock_clean
) t
WHERE quartile_num = 3
UNION ALL
SELECT 
    'Q4 (75-100%)',
    ROUND(MIN(stock), 0),
    ROUND(MAX(stock), 0),
    COUNT(*)
FROM (
    SELECT stock, NTILE(4) OVER (ORDER BY stock) AS quartile_num
    FROM sku_stock_clean
) t
WHERE quartile_num = 4;

-- top 50 skus by stock quantity
select 
sku_code,
category,
color,
design_no,
size,
round(stock,0)as stock_units
from sku_stock_clean 
order by stock desc
limit 5;


-- stoc level distribition
select 
case 
when stock = 0 then 'A .out of stock(0)'
when stock between 1 and 10 then 'B.Critical low(1-10)'
when stock between 11 and 50 then 'C.Low Stock(11-51)'
when stock between 51 and 100  then 'D.Moderate(51-100)'
when stock between 101 and 200 then 'E.Good(101 - 200)'
when stock between 201 and 500 then 'F.High(201-500)'
else 'G.Overstcok'
end as stock_level,
count(*) as sku_count,
round(count(*) * 100 /sum(count(*)) over(),2)as percent,
round(sum(stock),0)as total_units,
round(avg(stock),2)as avg_stock
from sku_stock_clean 
group by stock_level;

-- top 20 skusby stock quality
select sku_code,category,color,size,
round(stock,0) as stock_units 
from sku_stock_clean 
order by stock desc
limit 10;

-- stock concentration analysis
with stock_ranking as(
select 
sku_code,
stock,
sum(stock) over (order by stock desc)as cumulative_stock,
sum(stock) over()as total_stock,
row_number() over(order by stock desc) as rank_num from sku_stock_clean 
where stock >0
),
cumulative as(
select
rank_num,
sku_code,
round(stock,0)as stock_units,
round(cumulative_stock,0)as cumulative_stock,
round(cumulative_stock*100/total_stock,2)as cumulative_stock_pct
from stock_ranking 
)
select 
rank_num,sku_code, stock_units, 
cumulative_stock,cumulative_stock  from cumulative
where cumulative_stock_pct <= 80
order by rank_num limit 15;

-- stock distribution by category
select 
category ,
count(*) as sku_count,
round(count(*)*100.0/sum(count(*)) over(),2)as sku_count,
round(sum(stock),0)as total_stock_units,
round(sum(stock)*100/sum(sum(stock)) over(),2)as stock_percentage,
round(avg(stock),2)as avg_stock_per_sku,
round(min(stock),2)as min_stock,
round(max(stock),2)as max_stock
from sku_stock_clean
group by category
order by total_stock_units desc;

-- stock distribution by category
select 
color ,
count(*) as sku_count,
round(count(*)*100.0/sum(count(*)) over(),2)as sku_count,
round(sum(stock),0)as total_stock_units,
round(sum(stock)*100/sum(sum(stock)) over(),2)as stock_percentage,
round(avg(stock),2)as avg_stock_per_sku,
round(min(stock),2)as min_stock,
round(max(stock),2)as max_stock
from sku_stock_clean
group by color
order by total_stock_units desc;


-- stock distribution by category
select 
size,
count(*) as sku_count,
round(count(*)*100.0/sum(count(*)) over(),2)as sku_count,
round(sum(stock),0)as total_stock_units,
round(sum(stock)*100/sum(sum(stock)) over(),2)as stock_percentage,
round(avg(stock),2)as avg_stock_per_sku,
round(min(stock),2)as min_stock,
round(max(stock),2)as max_stock
from sku_stock_clean
group by design_no
order by total_stock_units desc limit 10;

-- category -colr cross analysis
with cross_stock as(
select 
category,
color,
count(*) as sku_count,
round(sum(stock),0)as total_stock,
round(avg(stock),2)as avg_stock
from sku_stock_clean 
group by category,color
having count(*) >5
)
select category,color,sku_count,total_stock,avg_stock from cross_stock
order by category,total_stock desc;

-- top 10 design s by stock uantity

SELECT 
    design_no,
    COUNT(DISTINCT sku_code) AS sku_variants,
    ROUND(SUM(stock), 0) AS total_stock,
    ROUND(AVG(stock), 2) AS avg_stock_per_variant,
    COUNT(DISTINCT color) AS color_options,
    COUNT(DISTINCT size) AS size_options,
    COUNT(DISTINCT category) AS category_count,
    ROUND(MAX(stock), 0) AS max_variant_stock,
    ROUND(MIN(stock), 0) AS min_variant_stock
FROM sku_stock_clean
WHERE design_no IS NOT NULL AND design_no != ''
GROUP BY design_no
ORDER BY total_stock DESC
LIMIT 10;


# stockout risk analysis
-- zero stock items 
SELECT category, COUNT(*) AS zero_stock_count
FROM sku_stock_clean
WHERE stock = 0
GROUP BY category
ORDER BY zero_stock_count DESC;


-- critical low stock
with priority_level as(
select sku_code, category,color,design_no,size,
round(stock,0)as stock_units,
case 
when stock = 0 then 'URGENT:out of stock'
when stock <= 5 then 'Critical:Immediate Recorder'
when stock <= 10 then 'Warning:Low Stock'
end as priority_level
from sku_stock_clean
where stock <= 10 
order by stock asc, category
)
select priority_level,count(*) as priority_count from priority_level
group by priority_level ;

-- stockout rate by category
select 
size,
count(*) as total_skus,
count(case when stock = 0 then 1 end)as zero_stock_count,
count(case when stock between  1 and 10 then 1 end)as low_stock,
count(case when stock>10 then 1 end ) as healthey_stock_count,
round(count(case when stock = 0 then 1 end) * 100 /count(*),2) as stockout_rate_pct,
round(count(case when stock <= 0 then 1 end) * 100 /count(*),2)as at_risk_rate_pct
from sku_stock_clean 
group by category
order by stockout_rate_pct desc;


# 
-- Count of rows per expense_type
SELECT expense_type, COUNT(*) AS count_of_expense_type
FROM dim_finance_expenses
GROUP BY expense_type;

select distinct(count(expense_type)) from dim_finance_expenses;

-- Count of rows per expense_category
SELECT expense_category, COUNT(*) AS count_of_expense_category
FROM dim_finance_expenses
GROUP BY expense_category;


select * from dim_finance_expenses;
select * from sku_stock_clean;
select * from dim_product;
select * from fact_sales_orders ;
show tables;