-- Cupcakes and Coffee Analysis 
SELECT * FROM city;
SELECT * FROM products;
SELECT * FROM customers;
SELECT * FROM sales;

-- Change the sale_date data type
ALTER TABLE sales ADD COLUMN sale_date_clean DATE;
SET SQL_SAFE_UPDATES = 0;
UPDATE sales 
SET sale_date_clean = STR_TO_DATE(sale_date, '%m/%d/%Y');
SET SQL_SAFE_UPDATES = 1;
ALTER TABLE sales DROP COLUMN sale_date;
ALTER TABLE sales CHANGE sale_date_clean sale_date DATE;
--

-- 1. Cupcakes and Coffee Consumers Count: How many people in each city are estimated to consume coffee, given that 25% of 
-- the population does?
SELECT 
	city_name,
	ROUND(
	(population * 0.25)/1000000, 
	2) as cc_consumers,
	city_rank
FROM city
ORDER BY 2 DESC;

-- 2. Total Revenue from CC Sales: What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

-- Total Revenue generated in Q4 of 2023
SELECT
  ROUND(SUM(total), 2) AS total_revenue
FROM sales
WHERE
  EXTRACT(YEAR FROM sale_date) = 2023
  AND EXTRACT(QUARTER FROM sale_date) = 4;
  
-- Total Revenue generated across all cities, in Q4 of 2023
SELECT 
	ci.city_name,
	ROUND(SUM(s.total), 2) as total_revenue
FROM sales as s
JOIN customers as c
ON s.customer_id = c.customer_id
JOIN city as ci
ON ci.city_id = c.city_id
WHERE 
	EXTRACT(YEAR FROM s.sale_date)  = 2023
	AND
	EXTRACT(quarter FROM s.sale_date) = 4
GROUP BY 1
ORDER BY 2 DESC;

-- 3. Sales Count for Each Product: How many units of each CC product have been sold?
SELECT 
	p.product_name,
	COUNT(s.sale_id) as total_orders
FROM products as p
LEFT JOIN
sales as s
ON s.product_id = p.product_id
GROUP BY 1
ORDER BY 2 DESC;

-- 4. Average Sales Amount per City: What is the average sales amount per customer in each city?
-- city and total sales; number of customers in each city
SELECT
  ci.city_name,
  ROUND(SUM(s.total), 2) AS total_revenue,
  COUNT(DISTINCT s.customer_id) AS total_customers,
  ROUND(
    CAST(SUM(s.total) AS DECIMAL(10, 2)) / COUNT(DISTINCT s.customer_id), 2) AS avg_sale_per_cust
FROM sales AS s
JOIN customers AS c ON s.customer_id = c.customer_id
JOIN city AS ci ON ci.city_id = c.city_id
GROUP BY 1
ORDER BY 2 DESC;

-- 5. City Population and Coffee Consumers (25%): Provide a list of cities along with their populations and estimated coffee consumers.
-- Return the city_name, total current customers, and estimated coffee consumers (25%)
WITH city_table as 
	(SELECT 
		city_name,
		ROUND((population * 0.25)/1000000, 2) as cc_consumers
	 FROM city), customers_table
AS
	(SELECT 
		ci.city_name,
		COUNT(DISTINCT c.customer_id) as unique_cust
	 FROM sales as s
	 JOIN customers as c
	      ON c.customer_id = s.customer_id
	 JOIN city as ci
	      ON ci.city_id = c.city_id
	 GROUP BY 1
)
SELECT 
	customers_table.city_name,
	city_table.cc_consumers as cc_consumers,
	customers_table.unique_cust
FROM city_table
JOIN 
customers_table
      ON city_table.city_name = customers_table.city_name;

-- 6. Top Selling Products by City: What are the top 3 selling products in each city based on sales volume?
SELECT *
FROM (
    SELECT
        ci.city_name,
        p.product_name,
        COUNT(s.sale_id) AS total_orders,
        DENSE_RANK() OVER (
            PARTITION BY ci.city_name
            ORDER BY COUNT(s.sale_id) DESC
        ) AS city_rank
    FROM sales AS s
		JOIN products AS p ON s.product_id = p.product_id
		JOIN customers AS c ON s.customer_id = c.customer_id
		JOIN city AS ci ON ci.city_id = c.city_id
    GROUP BY ci.city_name, p.product_name
) AS ranked_products
WHERE city_rank <= 3
ORDER BY city_name, city_rank;

-- 7. Customer Segmentation by City: How many unique customers are there in each city who have purchased CC products?
SELECT * FROM products;

SELECT 
	ci.city_name,
	COUNT(DISTINCT c.customer_id) as unique_cust
FROM city as ci
	LEFT JOIN customers as c
      ON c.city_id = ci.city_id
	JOIN sales as s
      ON s.customer_id = c.customer_id
WHERE 
	s.product_id IN (1, 2, 3, 4, 5, 6, 7)
GROUP BY 1;

-- 8. Avg Sale vs Rent: Find each city and their avg sale per customer and avg rent per customer

WITH city_table AS (
	SELECT 
		ci.city_name,
		SUM(s.total) AS total_revenue,
		COUNT(DISTINCT s.customer_id) AS total_cust,
		ROUND(
			CAST(SUM(s.total) AS DECIMAL(10, 2)) / 
			CAST(COUNT(DISTINCT s.customer_id) AS DECIMAL(10, 2)), 2
		) AS avg_sale_per_cust
	FROM sales AS s
		JOIN customers AS c 
             ON s.customer_id = c.customer_id
		JOIN city AS ci 
             ON ci.city_id = c.city_id
	GROUP BY ci.city_name
),
city_rent AS (
	SELECT 
		city_name, 
		est_rent AS estimated_rent
	FROM city
)
SELECT 
	cr.city_name,
	cr.estimated_rent,
	ct.total_cust,
	ct.avg_sale_per_cust,
	ROUND(
		CAST(cr.estimated_rent AS DECIMAL(10, 2)) / 
		CAST(ct.total_cust AS DECIMAL(10, 2)), 2
	) AS avg_rent_per_cust
FROM city_rent AS cr
	JOIN city_table AS ct 
         ON cr.city_name = ct.city_name
ORDER BY avg_sale_per_cust DESC;

-- 9. Monthly Sales Growth:
-- Sales growth rate: Calculate the % growth (or decline) in sales over different time periods (monthly) by each city
WITH monthly_sales AS (
	SELECT 
		ci.city_name,
		MONTH(s.sale_date) AS month,
		YEAR(s.sale_date) AS year,
		SUM(s.total) AS total_sale
	FROM sales AS s
	JOIN customers AS c ON c.customer_id = s.customer_id
	JOIN city AS ci ON ci.city_id = c.city_id
	GROUP BY ci.city_name, MONTH(s.sale_date), YEAR(s.sale_date)
),
growth_ratio AS (
	SELECT
		city_name,
		month,
		year,
		ROUND(total_sale, 2) AS cur_month_sale,
		ROUND(
			LAG(total_sale, 1) OVER (
				PARTITION BY city_name ORDER BY year, month
			), 2
		) AS last_month_sale
	FROM monthly_sales
)

SELECT
	city_name,
	month,
	year,
	cur_month_sale,
	last_month_sale,
	ROUND(
		(CAST(cur_month_sale AS DECIMAL(10, 2)) - CAST(last_month_sale AS DECIMAL(10, 2)))
		/ CAST(last_month_sale AS DECIMAL(10, 2)) * 100, 2
	) AS growth_ratio
FROM growth_ratio
WHERE last_month_sale IS NOT NULL;

-- 10. Market Potential Analysis: Identify top 3 cities based on highest sales. Return the city name, total sales, 
-- total rent, total customers, estimated CC consumers
WITH city_table AS (
	SELECT 
		ci.city_name,
		ROUND(SUM(s.total), 2) AS total_revenue,
		COUNT(DISTINCT s.customer_id) AS total_cust,
		ROUND(
			CAST(SUM(s.total) AS DECIMAL(10, 2)) / 
			CAST(COUNT(DISTINCT s.customer_id) AS DECIMAL(10, 2)), 2
		) AS avg_sale_per_cust
	FROM sales AS s
		JOIN customers AS c 
             ON s.customer_id = c.customer_id
		JOIN city AS ci 
             ON ci.city_id = c.city_id
	GROUP BY ci.city_name
),
city_rent AS (
	SELECT 
		city_name, 
		est_rent AS estimated_rent,
		ROUND((population * 0.25) / 1000000, 3) AS est_cc_consumers
	FROM city
)

SELECT 
	cr.city_name,
	ct.total_revenue,
	cr.estimated_rent AS total_rent,
	ct.total_cust,
	cr.est_cc_consumers,
	ct.avg_sale_per_cust,
	ROUND(
		CAST(cr.estimated_rent AS DECIMAL(10, 2)) / 
		CAST(ct.total_cust AS DECIMAL(10, 2)), 2
	) AS avg_rent_per_cust
FROM city_rent AS cr
	JOIN city_table AS ct 
         ON cr.city_name = ct.city_name
ORDER BY ct.total_revenue DESC;