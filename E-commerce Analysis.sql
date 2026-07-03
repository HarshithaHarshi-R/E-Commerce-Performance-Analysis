USE ecommerce_analysis;

CREATE TABLE df_Customers (
customer_id VARCHAR (50) PRIMARY KEY,
customer_zip_code_prefix INT,
customer_city VARCHAR (50),
customer_state  VARCHAR(10)
);

CREATE TABLE df_OrderItems (
order_id  VARCHAR(50),
product_id VARCHAR(50),
seller_id VARCHAR(50),
price DECIMAL (10,2),
shipping_charges DECIMAL (10,2),
PRIMARY KEY (order_id, product_id)
);

CREATE TABLE df_Orders (
order_id  VARCHAR(50) PRIMARY KEY,
customer_id VARCHAR (50),
order_purchase_timestamp VARCHAR (50),
order_approved_at VARCHAR (50)
);

CREATE TABLE df_Payments (
order_id  VARCHAR(50),
payment_sequential INT,
payment_type VARCHAR(50),
payment_installments INT,
payment_value   DECIMAL(10,2),
PRIMARY KEY (order_id , payment_sequential) 
);
 
CREATE TABLE df_Products (
product_id VARCHAR(50) PRIMARY KEY,
product_category_name VARCHAR(50),
product_weight_g INT,
product_length_cm INT,
product_height_cm INT,
product_width_cm INT
);

ALTER TABLE df_Products 
MODIFY product_weight_g DECIMAL(10,2),
MODIFY product_length_cm DECIMAL(10,2),
MODIFY product_height_cm DECIMAL(10,2),
MODIFY product_width_cm DECIMAL(10,2);

SELECT * FROM df_Orders
WHERE order_approved_at = '';

SET SQL_SAFE_UPDATES = 0;
UPDATE df_Orders SET order_approved_at = NULL WHERE order_approved_at = '';
SET SQL_SAFE_UPDATES = 1;

ALTER TABLE df_Orders 
MODIFY order_purchase_timestamp DATETIME,
MODIFY order_approved_at DATETIME;

SET SQL_SAFE_UPDATES = 0;
UPDATE df_Products 
SET product_category_name = 'Unknown' 
WHERE product_category_name = '' OR product_category_name IS NULL;

SET SQL_SAFE_UPDATES = 1;


-- 1. Top 10 best-selling product categories by number of orders
SELECT product_category_name, COUNT(DISTINCT order_id) AS Total_orders 
FROM df_OrderItems
JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP BY product_category_name  
ORDER BY Total_orders DESC 
LIMIT 10;

-- 2. Top 10 categories by total revenue
SELECT product_category_name, ROUND(SUM(payment_value),2) AS total_revenue FROM df_Payments
INNER JOIN df_OrderItems ON df_OrderItems.order_id = df_Payments.order_id 
INNER JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP BY product_category_name
ORDER BY total_revenue DESC
LIMIT 10;

-- 3. Which categories have high order count but low revenue (or vice versa)?
SELECT product_category_name, 
COUNT(DISTINCT df_OrderItems.order_id) AS total_orders,
ROUND(SUM(payment_value), 2) AS total_revenue,
ROUND(SUM(payment_value)/COUNT(DISTINCT df_OrderItems.order_id), 2) AS avg_revenue_per_order
FROM df_Payments
INNER JOIN df_OrderItems ON df_OrderItems.order_id = df_Payments.order_id 
INNER JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP BY product_category_name
ORDER BY avg_revenue_per_order ASC
LIMIT 10;

-- 4. Which product categories have the highest average shipping cost?
SELECT product_category_name, 
ROUND(AVG(shipping_charges), 2) AS avg_shipping_cost
FROM df_OrderItems
JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP By product_category_name
ORDER BY avg_shipping_cost DESC
LIMIT 10;

-- 5. For which categories does shipping cost exceed 50% of product price? 
SELECT product_category_name, 
ROUND(AVG(shipping_charges),2) AS avg_shipping_cost,
ROUND(AVG(price),2) AS avg_price
FROM df_OrderItems
JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP BY product_category_name
HAVING AVG(shipping_charges) > AVG(price) * 0.5;

-- 6. Revenue breakdown by payment type
SELECT payment_type, ROUND(SUM(payment_value),2) AS total_revenue
FROM df_Payments
GROUP BY payment_type;

-- 7. Average order value by payment type 
SELECT payment_type, ROUND(SUM(payment_value)/COUNT(DISTINCT order_id),2) AS avg_order_value
FROM df_Payments
GROUP BY payment_type;

-- 8. Credit card users: distribution of installment counts — are people mostly paying in 1 instalment or splitting into 6+?
SELECT payment_type, payment_installments, COUNT(df_Payments.order_id) AS total_orders
FROM df_Payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments 
ORDER BY payment_installments ASC;

-- 9. Do repeat customers (same customer_id appearing in multiple orders) spend more per order than one-time buyers?
SELECT 
  CASE 
    WHEN total_orders = 1 THEN 'One-time buyer'
    ELSE 'Repeat customer'
  END AS customer_type,
  ROUND(AVG(avg_order_value), 2) AS avg_spending,
  COUNT(customer_id) AS total_customers
FROM (SELECT df_Customers.customer_id, 
COUNT(df_Orders.order_id) as total_orders,
ROUND(AVG(price),2) AS avg_order_value
FROM df_Customers
INNER JOIN df_Orders ON df_Orders.customer_id = df_Customers.customer_id
INNER JOIN df_OrderItems ON df_Orders.order_id = df_OrderItems.order_id
GROUP BY df_Customers.customer_id
 ) AS customer_summary
GROUP BY customer_type;