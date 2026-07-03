# E-Commerce-Performance-Analysis
SQL analysis uncovering product performance, shipping inefficiencies, and payment behaviour across 38,295 orders

## Project Overview
An independent SQL project analysing an e-commerce dataset using MySQL Workbench across 5 tables - Customers, Orders, Order Items, Products, and Payments. The analysis covers best-selling categories, revenue drivers, shipping cost problems, and payment type behaviour.

**Tool Used:** MySQL Workbench  
**Dataset:** 38,295 records across 5 tables

---

## Data Cleaning & Preparation
- `df_Products`: 168 rows had blank `product_category_name` values — replaced with 'Unknown' to retain records in analysis
- `df_Orders`: `order_approved_at` column had empty string values in some rows - converted to NULL before changing column type to DATETIME
- All tables imported and verified before analysis

---

## Database Schema
| Table | Description |
|-------|-------------|
| df_Customers | Customer details including city and state |
| df_Orders | Order level data with timestamps |
| df_OrderItems | Product level data per order including price and shipping |
| df_Products | Product details including category and dimensions |
| df_Payments | Payment details including type, installments and value |

---

## Analysis & Findings

### 1. Top 10 Best-Selling Product Categories by Number of Orders
```sql
SELECT product_category_name, COUNT(DISTINCT order_id) AS Total_orders 
FROM df_OrderItems
JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP BY product_category_name  
ORDER BY Total_orders DESC 
LIMIT 10;
```
**Finding:** Toys dominated with 28,687 orders - significantly higher than all other categories. The 2nd highest, health_beauty, had only 1,038 orders. This suggests the platform may be toys-focused or toys have exceptionally strong demand compared to other categories.

---

### 2. Top 10 Categories by Total Revenue
```sql
SELECT product_category_name, ROUND(SUM(payment_value),2) AS total_revenue 
FROM df_Payments
INNER JOIN df_OrderItems ON df_OrderItems.order_id = df_Payments.order_id 
INNER JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP BY product_category_name
ORDER BY total_revenue DESC
LIMIT 10;
```
**Finding:** Toys generated the highest revenue at R$94,510,910. Notably, computers_accessories and garden_tools ranked 3rd and 4th in revenue despite not appearing prominently in order count - indicating these are high value purchases. This highlights that order volume alone does not reflect revenue contribution.

---

### 3. Categories with High Order Count but Low Revenue (and Vice Versa)
```sql
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
```
**Finding:** Categories like fashion_sport, music, and party_supplies had very low average revenue per order (under R$180), indicating low value purchases. bed_bath_table had 948 orders but a relatively low average revenue per order - high volume but low value. In contrast, garden_tools and watches_gifts had fewer orders but significantly higher average revenue, making them high value, low volume categories.

---

### 4. Product Categories with Highest Average Shipping Cost
```sql
SELECT product_category_name, 
ROUND(AVG(shipping_charges), 2) AS avg_shipping_cost
FROM df_OrderItems
JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP BY product_category_name
ORDER BY avg_shipping_cost DESC
LIMIT 10;
```
**Finding:** arts_and_craftmanship had the highest average shipping cost at R$107.30, followed by fashion_underwear_beach (R$86.34) and food and food_drink (R$78-79). High shipping costs in food categories likely reflect the need for faster or temperature-controlled delivery. The 'Unknown' category also appeared in the top 5, reinforcing the need to properly categorise all products.

---

### 5. Categories Where Shipping Cost Exceeds 50% of Product Price
```sql
SELECT product_category_name, 
ROUND(AVG(shipping_charges),2) AS avg_shipping_cost,
ROUND(AVG(price),2) AS avg_price
FROM df_OrderItems
JOIN df_Products ON df_Products.product_id = df_OrderItems.product_id
GROUP BY product_category_name
HAVING AVG(shipping_charges) > AVG(price) * 0.5;
```
**Finding:** Two categories flagged as problematic - arts_and_craftmanship (avg shipping R$107.30 vs avg product price R$37.49) and music (avg shipping R$40.47 vs avg price R$23.10). Shipping cost is nearly 3x and 2x the product price respectively. This is likely discouraging customers from completing purchases and needs urgent review of shipping strategy for these categories.

---

### 6. Revenue Breakdown by Payment Type
```sql
SELECT payment_type, ROUND(SUM(payment_value),2) AS total_revenue
FROM df_Payments
GROUP BY payment_type;
```
**Finding:** Credit card was the dominant payment method generating R$7,516,266 in revenue, followed by wallet at R$1,963,564, voucher at R$637,217, and debit card at R$130,164. The platform is heavily reliant on credit card transactions.

---

### 7. Average Order Value by Payment Type
```sql
SELECT payment_type, ROUND(SUM(payment_value)/COUNT(DISTINCT order_id),2) AS avg_order_value
FROM df_Payments
GROUP BY payment_type;
```
**Finding:** Voucher users had the highest average order value at R$304.89, despite generating the 3rd lowest total revenue. This means voucher users place fewer orders but spend more per order - suggesting they use vouchers on higher value purchases. The platform could benefit from increasing voucher promotions to drive more high value transactions.

---

### 8. Credit Card Installment Distribution
```sql
SELECT payment_type, payment_installments, COUNT(df_Payments.order_id) AS total_orders
FROM df_Payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments 
ORDER BY payment_installments ASC;
```
**Finding:** The majority of credit card users (9,112) paid in a single installment, with numbers declining steadily through 2nd to 6th installments. A small spike was observed at 8 and 10 installments, suggesting customers prefer round numbers when splitting payments. Very few customers opted for more than 12 installments.

---

### 9. Repeat Customers vs One-Time Buyers
```sql
SELECT 
  CASE 
    WHEN total_orders = 1 THEN 'One-time buyer'
    ELSE 'Repeat customer'
  END AS customer_type,
  ROUND(AVG(avg_order_value), 2) AS avg_spending,
  COUNT(customer_id) AS total_customers
FROM (
  SELECT df_Customers.customer_id, 
  COUNT(df_Orders.order_id) as total_orders,
  ROUND(AVG(price),2) AS avg_order_value
  FROM df_Customers
  INNER JOIN df_Orders ON df_Orders.customer_id = df_Customers.customer_id
  INNER JOIN df_OrderItems ON df_Orders.order_id = df_OrderItems.order_id
  GROUP BY df_Customers.customer_id
) AS customer_summary
GROUP BY customer_type;
```
**Finding:** All 38,295 customers made only one purchase - there are zero repeat customers. This points to a significant customer retention problem. Since acquiring new customers is more expensive than retaining existing ones, the business should investigate why customers are not returning - whether due to pricing, product quality, competition, or lack of loyalty programmes.

---

## Key Takeaways
- Toys category drives both order volume and revenue but the platform should diversify to reduce dependency on a single category
- Shipping costs in arts_and_craftmanship and music are unsustainably high relative to product prices
- Voucher users are high value customers - increasing voucher availability could drive more premium purchases
- Zero repeat customers is the most critical finding - customer retention should be a business priority

---

## Dashboard
*Power BI dashboard coming soon*
