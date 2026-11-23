use blinkit_db;

-- Index
create index useridx on blinkit(user_id);
create index year_mrp_idx on blinkit(order_year,mrp_total);
CREATE INDEX idx_year_status ON blinkit(order_year, order_status);

------------------------------------------------------------ KPIS ------------------------------------------------------------------------------------------------------

-- Total GMV ( Gross Merchandise Value )

SELECT 
CONCAT('₹',
ROUND(SUM(mrp_total)/10000000),
' Cr') AS Total_GMV
FROM blinkit;

-- Total Revenue 

select 
CONCAT('₹',
ROUND(SUM(grand_total)/10000000,2),
' Cr') AS Total_Revenue
FROM blinkit;

-- Total Orders

SELECT
COUNT(ORDER_ID) AS Total_Num_Orders
FROM BLINKIT;

-- Unique Customers

SELECT
COUNT(distinct(USER_ID)) AS Unique_Customers
FROM BLINKIT;

-- Average Order Value

SELECT
CONCAT('₹',
ROUND(AVG(GRAND_TOTAL),2)) AS Avg_Order_Value
FROM BLINKIT;

-- AVERAGE RATING

SELECT
ROUND(AVG(ORDER_RATING),2) AS Average_Rating
FROM BLINKIT;

-- Avg Delivery Time

SELECT
ROUND(AVG(DELIVERY_TIME_MINS),2) AS Avg_Delivery_Time
FROM BLINKIT;

-- Cancellation Rate
SELECT ORDER_STATUS,COUNT(*) AS Cancellation_Rate,
CONCAT(ROUND(COUNT(*)*100/(SELECT COUNT(*) FROM BLINKIT),2),'%') AS Percentage
FROM blinkit 
GROUP BY order_status;

----------------------------------------------------------------   QUESTIONS -----------------------------------------------------------------------------------------------

-- Q1. How many total orders are in our dataset, and what is the date range covered?

select count(order_id) as Total_Orders,min(order_date) as First_order,
max(order_date) as Last_Order 
from blinkit; 

-- Q2. What is the total GMV (revenue) year-wise, and how has it grown each year? 

with yearly_gmv as
(
select order_year,
ROUND(SUM(mrp_total)/10000000,2) AS Total_GMV
FROM blinkit
group by order_year
)

select order_year,concat('₹',Total_GMV,'Cr') as Total_GMV,
concat('₹',lag(Total_GMV,1,Total_GMV) over (order by order_year),'Cr') as Previous_Year_GMV,
concat(round(
(Total_GMV-lag(Total_GMV) over (order by order_year))/
(lag(Total_GMV) over(order by order_year))*100,2),'%') as Year_on_Year_Growth
from yearly_gmv;

-- Q3. What is the overall order status split (Delivered, Cancelled, Returned, Partial), and how 
-- is our delivery success rate trending each year? 

select order_status,count(*) as Total_Orders,
concat(round(count(*)*100/(select count(*) from blinkit),2),'%') as Percentage	
from blinkit
group by order_status
order by Total_Orders desc;  

select order_year,
concat(round(sum(case when order_status = "delivered"
then 1 else 0 end)*100/count(*),2),'%') as Deliver_Success_rate
from blinkit
group by order_year;

-- Q4. Which top 5 cities contribute the most to our total GMV, and what is their share in percentage?

with cities as
(
select store_city,sum(mrp_total) as total_GMV
from blinkit group by store_city
)
select store_city,concat('₹',round(total_GMV/10000000,2),'Cr') as Contributed_GMV, 
concat(round(total_GMV*100/sum(total_GMV) over(),2),'%') as GMV_Share
from cities order by total_GMV desc 
limit 5;	

-- Q5. Which dark stores are the top 10 performers by revenue, and which are the bottom 10 (underperformers)? 

(select "TOP 10" as category,store_city,round(sum(grand_total)/10000000,2) as Revenue
from blinkit
group by store_city order by Revenue desc limit 10)
union
(select "BOTTOM 10" as category,store_city,round(sum(grand_total)/10000000,2) as Revenue
from blinkit
group by store_city order by Revenue  limit  10);

-- Q6. Which pincode areas have the highest order volume, and what is the average order value there? 

select  customer_pincode,count(*) as Order_Volume,round(avg(grand_total),2) as Average_Order_Value
from blinkit
group by customer_pincode order by count(*) desc;

-- Q7. What are the peak hours of the day for orders, and how does the pattern differ on weekdays vs weekends? 

select
case when order_day_of_week in("Monday","Tuesday","Wednesday","Thursday","Friday") = 1 then "Weekday" else "Weekend" end as "Day_Name",
order_hour,count(*) as Total_Orders
from blinkit group by Day_Name,order_hour order by Day_Name,order_hour desc;

-- Q8. Which month of the year gives us the highest GMV, and which festive months show clear spikes? 

WITH monthly_gmv AS (
    SELECT
        order_year,
        order_month,
        order_month_name,
        SUM(mrp_total) AS gmv
    FROM blinkit
    GROUP BY order_year, order_month, order_month_name
)

SELECT
    order_year,
    order_month_name,
    CONCAT('₹', ROUND(gmv/10000000,2), ' Cr') AS GMV,
    RANK() OVER(PARTITION BY order_year ORDER BY gmv DESC) AS Month_Rank
FROM monthly_gmv
ORDER BY order_year, Month_Rank;

-- Q9. What is the weekend effect — how much more do we sell on Fri-Sat-Sun compared to Mon-Thu? 

with sales as
(
select case when order_day_of_week in("Friday","Saturday","Sunday") = 1 then "Weekend" else "Weekday" end as "Day_Type",
sum(mrp_total) as total_gmv
from blinkit
group by Day_Type
)
select Day_type,concat('₹',round(total_gmv/10000000,2),'Cr') as GMV,
concat(round(total_gmv*100/sum(total_gmv) over(),2),'%') as Percentage
from sales order by GMV desc;

WITH sales AS
(
SELECT
CASE WHEN order_day_of_week IN ('Friday','Saturday','Sunday')THEN 'Weekend' ELSE 'Weekday' END AS Day_Type,
SUM(mrp_total) AS total_gmv
FROM blinkit
GROUP BY Day_Type
)
SELECT
Day_Type,
concat('₹',ROUND(CASE WHEN Day_Type='Weekend' THEN total_gmv/3 ELSE total_gmv/4 END /10000000,2),'Cr')AS Avg_GMV_Per_Day
FROM sales order by Avg_GMV_Per_Day desc;

-- Q10. What is the payment method mix (UPI, COD, Card, etc.), and how has UPI adoption grown over the years? 

with method as
(
select payment_method,round(sum(grand_total)/10000000,2) as  Revenue
from blinkit
group by payment_method
)
select payment_method,concat('₹',Revenue,'Cr') as Total_Revenue from method order by Revenue desc;


WITH payment AS
(
SELECT order_year,COUNT(*) AS Total_Orders,
SUM(payment_method='UPI') AS UPI_Orders,
concat(ROUND(SUM(payment_method='UPI')*100/COUNT(*),2),'%') AS UPI_Adoption
FROM blinkit
GROUP BY order_year
)
SELECT*,
CONCAT(LAG(UPI_Adoption) OVER(ORDER BY order_year)) AS Previous_Year,
CONCAT(ROUND(UPI_Adoption-LAG(UPI_Adoption)OVER(ORDER BY order_year),2),'%') AS Growth
FROM payment;

-- Q11. Which delivery slot is most popular (10-min Express, Turbo, Scheduled), and what is the average delivery time per slot? 

select delivery_slot,count(*) as Count,avg(delivery_time_mins) as Avg_Delivery_Time_Per_Slot
from blinkit group by delivery_slot order by avg(delivery_time_mins) desc;

-- Q12. What is the platform split between Android, iOS, and Web, and which platform users spend more per order? 

with platform as
(
select platform,count(*) as Total_Orders,round(sum(grand_total)/10000000,2) as Spendings,
round(avg(grand_total),2) as Avg_Order_Value
from blinkit
group by platform
)
select platform,concat('₹',Spendings,'Cr') as Total_Spendings,Avg_Order_Value
from platform order by Spendings desc;

-- Q13. How do the four user tiers (Bronze, Silver, Gold, Platinum) compare in terms of average order value, order frequency, and cancellation rate?

select user_tier,count(*) as Total_Orders,
round(avg(grand_total),2) as Avg_Order_Value,
round(count(*)/count(distinct user_id),2) as order_Frequency,
concat(round(sum(case when order_status = "Cancelled" then 1 else 0 end)*100/count(*),2),'%') as Cancellation_Rate
from blinkit group by user_tier order by Avg_Order_Value desc; 

-- Q14. What percentage of our orders are from repeat customers vs first-time customers, and how has this changed year-on-year? 

with first_c as 
(
select order_year,count(*) as Year,
sum(case when is_first_order = 1 then 1 else 0 end) as First_time_Customer,
sum( case when is_reorder = 1 then 1 else 0 end) as Repeated_Customer,
concat(round(sum(case when is_first_order = 1 then 1 else 0 end)*100/count(*),2),'%') as First_Time_Percentage,
concat(round(sum(case when is_reorder = 1 then 1 else 0 end)*100/count(*),2),'%') as Repeat_Percentage
from blinkit group by order_year
)
select order_year,First_time_Customer,Repeated_Customer,First_Time_Percentage,Repeat_Percentage
from first_c ;

-- Q15. Who are our top 20 customers by lifetime GMV, and which cities/tiers do they belong to?

select user_id,max(store_city) as City,max(user_tier) as User_Tier,count(*) as Total_Orders,
concat('₹',round(sum(grand_total),2),'Cr') as Lifetime_GMV
from blinkit group by user_id order by sum(grand_total) desc limit 20;


-- Q16. Which promo codes are used most, and what is the average discount given per code?

select promo_code,count(*),round(avg(promo_discount),2) as Avg_discount_given
from blinkit where promo_code is not null
group by promo_code order by count(*) desc limit 22 offset 1;

-- Q17. What percentage of our GMV is being lost to promo discounts and cashback, broken down by user tier? 

select user_tier, concat('₹',round(sum(mrp_total)/10000000,2),'Cr') as GMV,
concat('₹',round(sum(promo_discount+cashback_earned)/10000000,2),'Cr') as Promo_Cashback,
concat(round(sum(promo_discount+cashback_earned)*100/sum(mrp_total),2),'%') as GMV_Loss_Percentage
from blinkit  group by user_tier order by GMV desc;

-- Q18. What are the top 5 reasons for cancellation and return, and which cities have the highest cancellation rates? 

select cancellation_return_reason,count(*) as Count,
concat(round(count(*)*100/sum(count(*)) over(),2),'%') as Cancellation_Percent
from blinkit 
where order_status in ("Cancelled","Returned") and cancellation_return_reason is not null
group by cancellation_return_reason order by Count desc limit 5  ;

select store_city,count(*) as Count,
concat(round(count(*)*100/sum(count(*)) over(),2),'%') as Cancellation_Percent
from blinkit where order_status in ("Cancelled","Returned") 
group by store_city order by count(*) desc limit 5;

select order_status,cancellation_return_reason,count(*) as Cases
from blinkit where order_status in ("Cancelled","returned")
group by order_status,cancellation_return_reason
order by Cases desc;

-- Q19. What is the average delivery time by city and delivery slot, and which stores consistently deliver faster or slower than average? 

-- Average_Delivery_Time = 18.98 sec

select store_city,delivery_slot,avg(delivery_time_mins) as Avg_Delivery_time
from blinkit where order_status = "Delivered"
 group by store_city,delivery_slot;
 
 with con as
 (
 select store_city,round(avg(delivery_time_mins),2) as Average_Delivery_Time
 from blinkit where order_status = "Delivered"
 group by store_city
 )
 select store_city,Average_Delivery_Time,
 case when Average_Delivery_Time <
 (select avg(delivery_time_mins) from blinkit where order_status = "Delivered")
 then '⚡ Faster than Average' else '🐢 Slower than Average' end as Performance
 from con order by Average_Delivery_Time desc;
 
 select avg(delivery_time_mins) from blinkit where order_status = "Delivered";
 
-- 20) What is the month-over-month GMV growth, and can we identify any month where growth stalled or reversed — and why (linked to cancellations, low promos, or city issues)?

-- Calculate Monthly GMV and MoM Growth
WITH monthly_gmv AS (
    SELECT
        order_year,
        order_month,order_month_name,
        SUM(mrp_total) AS total_gmv
    FROM blinkit
    GROUP BY order_year, order_month,order_month_name
)

SELECT
    order_year,
    order_month,order_month_name,
    ROUND(total_gmv,2) AS total_gmv,
    ROUND(
        (total_gmv - LAG(total_gmv) OVER(ORDER BY order_year, order_month))
        *100/
        LAG(total_gmv) OVER(ORDER BY order_year, order_month)
    ,2) AS mom_growth_percentage
FROM monthly_gmv
ORDER BY order_year, order_month;

-- check cancellation rate
SELECT
    order_year,
    order_month,order_month_name,
    COUNT(*) total_orders,
    SUM(CASE
            WHEN order_status='Cancelled'
            THEN 1
            ELSE 0
        END) cancelled_orders,
    ROUND(
        SUM(CASE
                WHEN order_status='Cancelled'
                THEN 1
                ELSE 0
            END)*100/COUNT(*)
    ,2) cancellation_rate
FROM blinkit
GROUP BY order_year,order_month,order_month_name
ORDER BY order_year,order_month;

-- B. Promo Discounts

SELECT
    order_year,
    order_month,
    ROUND(SUM(promo_discount),2) AS total_promo_discount,
    ROUND(AVG(promo_discount),2) AS avg_promo_discount
FROM blinkit
GROUP BY order_year,order_month
ORDER BY order_year,order_month;


-- Check Which City Dropped
SELECT
    order_year,
    order_month,
    store_city,
    ROUND(SUM(mrp_total),2) city_gmv
FROM blinkit
GROUP BY
    order_year,
    order_month,
    store_city
ORDER BY
    order_year,
    order_month,
    city_gmv DESC;


