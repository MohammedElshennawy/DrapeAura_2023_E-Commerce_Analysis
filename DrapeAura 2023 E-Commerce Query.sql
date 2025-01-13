/*====================================================================================================================================
												     Join Tables
====================================================================================================================================*/

CREATE VIEW PRODUCT_SALES AS
SELECT *
FROM USA_PRODUCT AS PD
JOIN USA_ORDER AS OD USING (PRODUCT_ID)
JOIN USA_CUSTOMERS AS CS USING (CUSTOMER_ID);


/*====================================================================================================================================
												Limit DataSet To 2023
====================================================================================================================================*/

CREATE VIEW PRODUCT_SALES23 AS
SELECT *
FROM PRODUCT_SALES AS PS
WHERE PS.TRANSACTION_DATE >= '2023-01-01'
	AND NAME IS NOT NULL
	AND BRAND IS NOT NULL
	AND CITY IS NOT NULL;
	

/*====================================================================================================================================
												Exploratory Data Analysis(EDA)
====================================================================================================================================*/

--Describe numerical columns by mean(average)
SELECT ROUND(AVG(cost)::numeric, 2) AS mean_cost, ROUND(AVG(shipping_cost_1000_mile)::numeric, 2) AS mean_ship_cost, 
	ROUND(AVG(retail_price)::numeric, 2) AS mean_price, ROUND(AVG(quantity), 2) AS mean_quantity, ROUND(AVG(age), 2) AS mean_age,
	ROUND(AVG(sales)::numeric, 2) AS mean_sales
FROM PRODUCT_SALES23;

--Describe numerical columns by standard deviation
SELECT ROUND(STDDEV(cost)::numeric, 2) AS std_cost, ROUND(STDDEV(shipping_cost_1000_mile)::numeric, 2) AS std_ship_cost, 
	ROUND(STDDEV(retail_price)::numeric, 2) AS std_price, ROUND(STDDEV(quantity), 2) AS std_quantity, ROUND(STDDEV(age), 2) AS std_age,
	ROUND(STDDEV(sales)::numeric, 2) AS std_sales
FROM PRODUCT_SALES23;

--Describe numerical columns by minimum
SELECT ROUND(MIN(cost)::numeric, 2) AS min_cost, ROUND(MIN(shipping_cost_1000_mile)::numeric, 2) AS min_ship_cost, 
	MIN(retail_price) AS min_price, MIN(quantity) AS min_quantity, MIN(age) AS min_age, MIN(sales) AS min_sales
FROM PRODUCT_SALES23;

--Describe numerical columns by maximum
SELECT ROUND(MAX(cost)::numeric, 2) AS max_cost, ROUND(MAX(shipping_cost_1000_mile)::numeric, 2) AS max_ship_cost, 
	MAX(retail_price) AS max_price, MAX(quantity) AS max_quantity, MAX(age) AS max_age, MAX(sales) AS max_sales
FROM PRODUCT_SALES23;


/*====================================================================================================================================
												Explore Customer Numbers
====================================================================================================================================*/

--Number of Customers Per State
SELECT state, COUNT(DISTINCT customer_id) AS number_of_customers
FROM PRODUCT_SALES23
GROUP BY state
ORDER BY number_of_customers DESC;

--Number of Customers By Gender
SELECT gender, COUNT(DISTINCT customer_id) AS number_of_customers
FROM PRODUCT_SALES23
GROUP BY gender
ORDER BY number_of_customers DESC;

--Number of Customers By Gender Per State
SELECT state, gender, COUNT(DISTINCT customer_id) AS number_of_customers
FROM PRODUCT_SALES23
GROUP BY state, gender
ORDER BY number_of_customers DESC;


/*====================================================================================================================================
												Analysis of Quantity Patterns
====================================================================================================================================*/

--Total Quantity Per Product
SELECT name AS product_description, SUM(quantity) AS Total_quantity_sold
FROM PRODUCT_SALES23
GROUP BY name
ORDER BY Total_quantity_sold DESC
LIMIT 20;

--Total Quantity Per Category
SELECT category, SUM(quantity) AS Total_quantity_sold
FROM PRODUCT_SALES23
GROUP BY category
ORDER BY Total_quantity_sold DESC;

--Average Quantity Per Category
SELECT category, ROUND(AVG(quantity), 1) AS Total_quantity_sold
FROM PRODUCT_SALES23
GROUP BY category
ORDER BY Total_quantity_sold DESC;


/*====================================================================================================================================
												Analysis of Sales Patterns
====================================================================================================================================*/

--Total Sales By State
SELECT state, SUM(sales) AS Total_sales
FROM PRODUCT_SALES23
GROUP BY state
ORDER BY Total_sales DESC;

--Top seller By Product
SELECT name AS product_description, SUM(sales) AS Total_sales
FROM PRODUCT_SALES23
GROUP BY name
ORDER BY Total_sales DESC
LIMIT 20;

--Sales By Category
SELECT category, SUM(sales) AS Total_sales
FROM PRODUCT_SALES23
GROUP BY category
ORDER BY Total_sales DESC;


--Create two temporary tables to calculate the total sales amount for each invoice by CTE expression.
--First, create a temporary table to calculate the total quantity for each invoice.
WITH invoice_total_quantity AS (SELECT invoice_no, SUM(quantity) AS Total_quantity
								FROM PRODUCT_SALES23
								GROUP BY invoice_no
							   	ORDER BY invoice_no),
								
--Second, create a temporary table to calculate the total sales for each quantity on each invoice.								
	sales_by_invoice_total_quantity AS (SELECT invoice_no, Total_quantity, sales
										FROM invoice_total_quantity AS itq
										INNER JOIN PRODUCT_SALES23 AS ps
										USING(invoice_no))


--Total sales quantity per invoice through the temporary table sales_by_invoice_total_quantity
SELECT Total_quantity AS Invoice_quantity, ROUND(SUM(sales)::numeric, 1) AS Total_sales
FROM sales_by_invoice_total_quantity
GROUP BY Total_quantity
ORDER BY Total_quantity;

--Percent of Total
SELECT Total_quantity AS Invoice_quantity, 
		ROUND((SUM(sales) * 100 / SUM(SUM(sales)) OVER ())::numeric, 1) AS persent_sales
FROM sales_by_invoice_total_quantity
GROUP BY Total_quantity
ORDER BY Total_quantity;


/*====================================================================================================================================
												Analysis of Customer Lifetime Value (CLTV)
====================================================================================================================================*/

--Create temporary table to calculate Customer Lifetime Value (CLTV) by the total sales amount for each customer_id by CTE expression.
WITH CLTV AS (SELECT customer_id, SUM(sales) AS cltv
				FROM PRODUCT_SALES23
				GROUP BY customer_id
				ORDER BY customer_id)
								
								
--CLTV By State								
SELECT product_id, state, ROUND(cltv::numeric, 2) AS cltv
FROM CLTV
INNER JOIN PRODUCT_SALES23
USING(customer_id)
ORDER BY state;


/*====================================================================================================================================
												 Time Series Analysis
====================================================================================================================================*/
/*====================================================================================================================================
										 1.Trend of Orders And Revenue Over Time
====================================================================================================================================*/

--Total Number of Orders Over Time
SELECT (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') AS transaction_month_end, 
		COUNT(DISTINCT invoice_no) AS Total_orders
FROM PRODUCT_SALES23
GROUP BY (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day')
ORDER BY transaction_month_end;

--Total Revenue Over Time
SELECT (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') AS transaction_month_end, 
		SUM(sales) AS Total_revnue
FROM PRODUCT_SALES23
GROUP BY (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day')
ORDER BY transaction_month_end;


/*====================================================================================================================================
										        2.Repeat Customers & Revenue
====================================================================================================================================*/

--Create temporary tables to calculate both the number of repeat customers and revenue over time using a CTE expression.
--First, create a temporary table to calculate the total sales for each customer on each invoice.
WITH INVOICES_CUSTOMER AS (SELECT invoice_no, transaction_date, SUM(sales) AS Total_sales, MAX(customer_id) AS customer_id
						   FROM PRODUCT_SALES23
						   GROUP BY invoice_no, transaction_date
						   ORDER BY invoice_no),

/*Second, create a temporary table to calculate the number of transactions per month for each customer 
and their total sales using the temporary table INVOICES_CUSTOMER.*/
	GROUPED_DATA AS (SELECT (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') AS transaction_month, 
					 customer_id, COUNT(invoice_no) AS transaction_count, SUM(Total_sales) AS Total_sales
					 FROM INVOICES_CUSTOMER
					 GROUP BY DATE_TRUNC('month', transaction_date), customer_id),

/*Third, create a temporary table to filter on customers 
who have made more than 1 transaction per month using the temporary table GROUPED_DATA.*/
	REPEAT_CUSTOMERS AS (SELECT transaction_month, customer_id, Total_sales
						 FROM GROUPED_DATA
						 WHERE transaction_count > 1
						 ORDER BY customer_id),

--Fourth, Calculate the number of repeat customers over time using the temporary table REPEAT_CUSTOMERS.
	MONTHLY_REPEAT_CUSTOMERS AS (SELECT transaction_month, COUNT(DISTINCT customer_id) AS unique_repeat_customers
								 FROM REPEAT_CUSTOMERS
								 GROUP BY transaction_month
								 ORDER BY transaction_month),
								 
--Fifth, Calculate the number of customers over time.
	MONTHLY_UNIQUE_CUSTOMERS AS (SELECT (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') AS transaction_month, 
								 COUNT(DISTINCT customer_id) AS unique_customers
								 FROM PRODUCT_SALES23
								 GROUP BY DATE_TRUNC('month', transaction_date)),
								 
--Sixth, Calculate total revenue for repeat customers over time using the temporary table REPEAT_CUSTOMERS.	
	MONTHLY_REV_REPEAT_CUSTOMERS AS (SELECT transaction_month, ROUND(SUM(Total_sales)::numeric, 2) AS rev_repeat_customers
									 FROM REPEAT_CUSTOMERS
									 GROUP BY transaction_month
									 ORDER BY transaction_month),
									 
--Seventh, Calculate total revenue  over time.								 
	MONTHLY_REVENUE AS (SELECT (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') AS transaction_month, 
						SUM(sales) AS Total_revenue
						FROM PRODUCT_SALES23
						GROUP BY (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day')
						ORDER BY transaction_month)


--Number of All vs. Repeat Customers Over Time.
SELECT transaction_month, unique_repeat_customers, unique_customers,
		ROUND(unique_repeat_customers * 100 / unique_customers ::numeric, 2) AS repeat_percent
FROM MONTHLY_REPEAT_CUSTOMERS
INNER JOIN MONTHLY_UNIQUE_CUSTOMERS
USING(transaction_month);

--Total Revenue", "Repeat Customers Revenue.
SELECT transaction_month, rev_repeat_customers, Total_revenue,
		ROUND((rev_repeat_customers * 100 / Total_revenue)::numeric, 2) AS rev_repeat_percent
FROM MONTHLY_REV_REPEAT_CUSTOMERS
INNER JOIN MONTHLY_REVENUE
USING(transaction_month);


/*====================================================================================================================================
										       3.Trend of Elements Over Time
====================================================================================================================================*/

--Create tow temporary tables to calculate trend of top 5 categories Over Time using a CTE expression.
--First, create a temporary table to calculate the top 5 selling categories during the month of November.
WITH LAST_MONTH_SALES AS(SELECT (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') AS transaction_month, 
						  category, SUM(quantity) AS Total_quantity
						  FROM PRODUCT_SALES23
						  WHERE (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') = DATE '2023-11-30'
						  GROUP BY DATE_TRUNC('month', transaction_date), category
						  ORDER BY Total_quantity DESC
						  LIMIT 5),
						  
--Second, create a temporary table to calculate the quantity sold for each of the five categories over time.						  
	FILTERED_MONTHLY_SALES AS (SELECT (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') AS transaction_month, 
							   category, SUM(quantity) AS Total_quantity
							   FROM PRODUCT_SALES23
							   WHERE category IN (SELECT category
												  FROM LAST_MONTH_SALES)
							   GROUP BY DATE_TRUNC('month', transaction_date), category
							   ORDER BY transaction_month, category)
					  

--Convert FILTERED_MONTHLY_SALES temporary table to pivot_table.
SELECT 
    transaction_month,
    MAX(CASE WHEN category = 'Accessories' THEN total_quantity ELSE 0 END) AS Accessories,
    MAX(CASE WHEN category = 'Active' THEN total_quantity ELSE 0 END) AS Active,
    MAX(CASE WHEN category = 'Intimates' THEN total_quantity ELSE 0 END) AS Intimates,
    MAX(CASE WHEN category = 'Jeans' THEN total_quantity ELSE 0 END) AS Jeans,
    MAX(CASE WHEN category = 'Tops & Tees' THEN total_quantity ELSE 0 END) AS "Tops & Tees"
FROM FILTERED_MONTHLY_SALES
GROUP BY transaction_month
ORDER BY transaction_month;



/*====================================================================================================================================
										          Market Basket Analysis
====================================================================================================================================*/

--Create temporary tables to calculate how each category correlation to the other using a CTE expression.
--First, create a temporary table to perform self-join on stored data
WITH SELF_JOIN AS(SELECT ps.invoice_no AS invoice_no, ps.category AS category, ps_self.category AS category_self, 
				  ps.quantity AS quantity, ps_self.quantity AS quantity_self 
				  FROM PRODUCT_SALES23 AS ps
				  INNER JOIN PRODUCT_SALES23 AS ps_self
				  ON ps.invoice_no = ps_self.invoice_no
				  AND ps.category < ps_self.category), -- This helps remove excess or unwanted buildup

--Second, create a temporary table to calculate the total quantity for each category based on the invoice using the temporary table SELF_JOIN.	.
	AGG_PAIRS AS(SELECT invoice_no, category, category_self, 
				 SUM(quantity) AS Total_quantity, SUM(quantity_self) AS Total_quantity_self
				 FROM SELF_JOIN
				 GROUP BY invoice_no, category, category_self
				 ORDER BY invoice_no),

--Third, create a temporary table to calculate categories correlation using the temporary table AGG_PAIRS.
	CORRELATIONS AS(SELECT category, category_self, 
					ROUND(CORR(total_quantity, total_quantity_self)::numeric, 1) AS correlation
					FROM AGG_PAIRS
					GROUP BY category, category_self
					ORDER BY category_self, category)

SELECT *
FROM CORRELATIONS;



/*====================================================================================================================================
										              Shipping Costs
====================================================================================================================================*/
/*====================================================================================================================================
								     1.shipping cost per thousand miles for each product
====================================================================================================================================*/

SELECT name, ROUND(AVG(shipping_cost_1000_mile)::numeric, 2) AS ship_cost
FROM PRODUCT_SALES23
GROUP BY name
ORDER BY ship_cost DESC
LIMIT 20;


/*====================================================================================================================================
										             2.Shipping Distance
====================================================================================================================================*/

/*calculate the average shipping distance to customers in each state, 
compared to our warehouse location in Los Angeles (latitude and longitude: 34.05, -118.25)*/

WITH SHIP_DISTANC AS(SELECT *, (3958.8 * -- Radius of Earth in miles
								ACOS(COS(RADIANS(34.05)) * COS(RADIANS(latitude)) * 
									 COS(RADIANS(longitude) - RADIANS(-118.25)) + 
									 SIN(RADIANS(34.05)) * SIN(RADIANS(latitude)))) AS distance_LAX_mi
					 FROM PRODUCT_SALES23)


--Shipping Distance From Los Angeles (CA) Wearhouse
SELECT state, ROUND(AVG(distance_LAX_mi)::numeric, 2) AS ship_distance
FROM SHIP_DISTANC
GROUP BY state
ORDER BY state;



/*====================================================================================================================================
								                    3.What-if Analysis
====================================================================================================================================*/

--Create temporary tables to calculate the base shipping cost and the cost reduction factor when shipping quantities of 5. 
--First, create a temporary table to calculate Cost of goods, baseline shipping, shipping if 5.
WITH SHIP_COST_COGS AS(SELECT *, (cost * quantity) AS cogs,
				  		CASE WHEN quantity <= 1 THEN shipping_cost_1000_mile 
					     ELSE shipping_cost_1000_mile + ((quantity - 1) * shipping_cost_1000_mile * 0.7) END As shipping_baseline,
				  		CASE WHEN quantity <= 1 THEN shipping_cost_1000_mile 
				  		 ELSE shipping_cost_1000_mile + ((quantity - 1) * shipping_cost_1000_mile * 0.5) END As ship_what_if_5
					   FROM PRODUCT_SALES23),


/*Second, create a temporary table to Calculate trend of baseline Shipping and What-If Cost by Product Over Time 
using the temporary table SHIP_COST_COGS.*/
	SHIP_CUM AS (SELECT (DATE_TRUNC('month', transaction_date) + INTERVAL '1 month' - INTERVAL '1 day') AS transaction_month,
				 		ROUND(SUM(shipping_baseline)::numeric, 2) AS Total_baseline, 
				 		ROUND(SUM(ship_what_if_5)::numeric, 2) AS Total_what_if_5,
						ROUND(SUM(shipping_baseline - ship_what_if_5)::numeric, 2) AS Total_save_ship
				 FROM SHIP_COST_COGS
				 GROUP BY DATE_TRUNC('month', transaction_date)
				 ORDER BY transaction_month)
				 
				
--Shipping Costs By State
SELECT state, ROUND(SUM(shipping_baseline)::numeric, 2) AS ship_cost_beasline
FROM SHIP_COST_COGS
GROUP BY state
ORDER BY ship_cost_beasline DESC;

--Shipping Costs By Categories
SELECT category, ROUND(SUM(shipping_baseline)::numeric, 2) AS ship_cost_beasline
FROM SHIP_COST_COGS
GROUP BY category
ORDER BY ship_cost_beasline DESC;


--Shipping Saving if Quantity 5
SELECT ROUND(SUM(shipping_baseline)::numeric, 2) AS ship_beasline, 
		ROUND(SUM(ship_what_if_5)::numeric, 2) AS ship_what_if_5,
		ROUND(SUM(shipping_baseline - ship_what_if_5)::numeric, 2) AS save_shipping
FROM SHIP_COST_COGS;


--Shipping Saving if Quantity 5 By Product
SELECT name,
		ROUND(SUM(shipping_baseline)::numeric, 2) AS ship_beasline, 
		ROUND(SUM(ship_what_if_5)::numeric, 2) AS ship_what_if_5,
		ROUND(SUM(shipping_baseline - ship_what_if_5)::numeric, 2) AS save_shipping
FROM SHIP_COST_COGS
GROUP BY name
ORDER BY ship_beasline DESC, ship_what_if_5 DESC
LIMIT 20;


--How Quantity Affects Shipping Costs Over Time
SELECT transaction_month,
		SUM(Total_baseline) OVER (ORDER BY transaction_month) AS cum_baseline,
		SUM(Total_what_if_5) OVER (ORDER BY transaction_month) AS cum_what_if_5,
		SUM(Total_save_ship) OVER (ORDER BY transaction_month) AS cum_save_ship
FROM SHIP_CUM;



/*====================================================================================================================================
										              Profit Baseline
====================================================================================================================================*/

--Beasline profit from sales for each state by using the temporary table SHIP_COST_COGS.
SELECT state, ROUND(SUM(sales - cogs - shipping_baseline)::numeric, 2) AS profit_baseline,
		ROUND((SUM(sales - cogs - shipping_baseline) * 100 / SUM(sales))::numeric, 2) AS profit_percent
FROM SHIP_COST_COGS
GROUP BY state
ORDER BY profit_percent DESC;

--Beasline profit from sales for each category by using the temporary table SHIP_COST_COGS.
SELECT category, ROUND(SUM(sales - cogs - shipping_baseline)::numeric, 2) AS profit_baseline,
		ROUND((SUM(sales - cogs - shipping_baseline) * 100 / SUM(sales))::numeric, 2) AS profit_percent
FROM SHIP_COST_COGS
GROUP BY category
ORDER BY profit_percent DESC;



/*====================================================================================================================================
										       Key Performance Indicators (KPIs)
====================================================================================================================================*/

--KPIs for Executive Summary by using the temporary table SHIP_COST_COGS.
SELECT ROUND(SUM(sales)::numeric, 2) AS sales, ROUND(SUM(cogs)::numeric, 2) As cogs, 
		ROUND(SUM(sales - cogs - shipping_baseline)::numeric, 2) AS profit_baseline,
		ROUND((SUM(sales - cogs - shipping_baseline) * 100 / SUM(sales))::numeric, 2) AS profit_percent
FROM SHIP_COST_COGS;


--KPIs for Shipping Costs by using the temporary table SHIP_COST_COGS.
SELECT ROUND(SUM(shipping_baseline)::numeric, 2) AS shipping_baseline, 
		ROUND(SUM(ship_what_if_5)::numeric, 2) As ship_what_if_5, 
		ROUND(SUM(shipping_baseline - ship_what_if_5)::numeric, 2) AS save_shipping
FROM SHIP_COST_COGS;

