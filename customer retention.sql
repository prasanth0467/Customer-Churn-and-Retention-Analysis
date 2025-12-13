CREATE DATABASE customer_analytics;
USE customer_analytics;


SHOW TABLES;
SELECT * FROM ORDERS;
SELECT * FROM CUSTOMER_SUMMARY;


### AVERAGE ORDER VALUE 
SELECT ROUND(SUM(TotalAmount) / COUNT(DISTINCT InvoiceNo),2) AS Avg_Order_Value
FROM orders;


### REPEAT PURCHASE RATE
SELECT ROUND(100 * COUNT(DISTINCT CASE WHEN total_orders > 1 THEN CustomerID END) 
/ COUNT(DISTINCT CustomerID), 2) AS Repeat_Purchase_Rate
FROM customer_summary;


### CHURN RATE
SET @ref_date = (SELECT DATE(MAX(InvoiceDate)) FROM orders);
SELECT ROUND(100 * SUM(CASE WHEN DATEDIFF(@ref_date, last_purchase) > 90 THEN 1 ELSE 0 END)
/ COUNT(*), 2) AS Churn_Rate
FROM customer_summary;


### CUSTOMER LIFETIME VALUE 
SELECT CustomerID,total_revenue,
CASE 
	WHEN total_revenue >= 1000 THEN 'High Value'
	WHEN total_revenue BETWEEN 500 AND 999 THEN 'Mid Value'
	ELSE 'Low Value'
END AS LTV_Bucket
FROM customer_summary;


### MONTHLY REVENUE TREND
SELECT DATE_FORMAT(InvoiceDate, '%Y-%m') AS month,
ROUND(SUM(TotalAmount), 2) AS monthly_revenue
FROM orders
GROUP BY month
ORDER BY month;



### CREATING VIEWS
CREATE VIEW v_kpi_summary AS
SELECT 
ROUND(SUM(TotalAmount)/COUNT(DISTINCT InvoiceNo),2) AS AOV,
(100 * COUNT(DISTINCT CASE WHEN total_orders > 1 THEN CustomerID END)
/ COUNT(DISTINCT CustomerID)) AS repeat_purchase_rate,
(100 * SUM(CASE WHEN DATEDIFF('2011-12-31', last_purchase) > 90 THEN 1 ELSE 0 END)
/ COUNT(*)) AS churn_rate
FROM orders
JOIN customer_summary USING (CustomerID);


SELECT * FROM v_kpi_summary;




### SETTING REFERENCE DATE
SET @ref_date = (SELECT DATE(MAX(InvoiceDate)) FROM orders);
SELECT DATE(MAX(InvoiceDate)) FROM orders;

### RFM BASE TABLE
DROP TABLE IF EXISTS rfm_base;
CREATE TABLE rfm_base;
SELECT
  cs.CustomerID AS customer_id,
  cs.first_purchase,
  cs.last_purchase,
  DATEDIFF(@ref_date, cs.last_purchase) AS recency_days,
  cs.total_orders AS frequency,
  ROUND(cs.total_revenue, 2) AS monetary
FROM customer_summary cs;

CREATE INDEX idx_rfm_customer ON rfm_base(customer_id);


### RFM QUINTILES
DROP TABLE IF EXISTS rfm_scores;
CREATE TABLE rfm_scores ;
SELECT
  customer_id,
  recency_days,
  frequency,
  monetary,
  -- Recency score: lower recency_days -> higher score (invert)
  6 - rec_recency.score AS recency_score,
  rec_recency.score AS recency_ntile, -- helper
  freq.frequency_ntile AS frequency_score,
  mon.monetary_ntile AS monetary_score,
  -- combined RFM score (string and numeric)
  CONCAT(6 - rec_recency.score, freq.frequency_ntile, mon.monetary_ntile) AS rfm_score_str,
  (6 - rec_recency.score) * 100 + freq.frequency_ntile * 10 + mon.monetary_ntile AS rfm_score_numeric
FROM rfm_base rb
JOIN (
  SELECT customer_id, score
  FROM (
    SELECT customer_id, NTILE(5) OVER (ORDER BY recency_days) AS score
    FROM rfm_base
  ) t
) rec_recency USING (customer_id)
JOIN (
  SELECT customer_id, frequency_ntile
  FROM (
    SELECT customer_id, NTILE(5) OVER (ORDER BY frequency DESC) AS frequency_ntile
    FROM rfm_base
  ) t
) freq USING (customer_id)
JOIN (
  SELECT customer_id, monetary_ntile
  FROM (
    SELECT customer_id, NTILE(5) OVER (ORDER BY monetary DESC) AS monetary_ntile
    FROM rfm_base
  ) t
) mon USING (customer_id);


### MAP RFM STRINGS TO SEGMENTS
DROP TABLE IF EXISTS rfm_segment;
CREATE TABLE rfm_segment;
SELECT
  customer_id,
  recency_score,
  frequency_score,
  monetary_score,
  rfm_score_str,
  rfm_score_numeric,
  CASE
    WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'

    WHEN (recency_score >= 3 AND frequency_score >= 3)
         OR (frequency_score >= 4 AND monetary_score >= 3)
         THEN 'Loyal'

    WHEN recency_score BETWEEN 2 AND 3 
         AND frequency_score BETWEEN 2 AND 3
         THEN 'Need Attention'

    WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score <= 2
         THEN 'At Risk'

    ELSE 'Lost'
  END AS rfm_segment
FROM rfm_scores;


SELECT RFM_SEGMENT,COUNT(*) AS COUNT FROM RFM_SEGMENT GROUP BY RFM_SEGMENT ORDER BY COUNT DESC;

### Revenue by RFM segments
SELECT 
    rs.rfm_segment,
    COUNT(*) AS Total_Customers,
    ROUND(SUM(rb.monetary), 2) AS Total_Revenue
FROM rfm_segment rs
JOIN rfm_base rb 
    ON rs.customer_id = rb.customer_id
GROUP BY rs.rfm_segment
ORDER BY Total_Revenue DESC;


### ACQUISITION MONTH AND LAST PURCHASE MONTH
DROP TABLE IF EXISTS customer_cohort;
CREATE TABLE customer_cohort;
SELECT
  CustomerID AS customer_id,
  DATE_FORMAT(first_purchase, '%Y-%m-01') AS cohort_month,  
  DATE_FORMAT(last_purchase, '%Y-%m-01') AS last_purchase_month,
  first_purchase, last_purchase
FROM customer_summary;


### FLAG ACTIVITY MONTH PER CUSTOMER
DROP TABLE IF EXISTS orders_months;
CREATE TABLE orders_months ;
SELECT DISTINCT
  CustomerID AS customer_id,
  DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS activity_month
FROM orders ORDER BY CUSTOMER_ID,ACTIVITY_MONTH;

CREATE INDEX idx_orders_months ON orders_months(customer_id, activity_month);


### COHORT RETENTION COUNTS
DROP TABLE IF EXISTS cohort_retention;
CREATE TABLE cohort_retention ;
SELECT
  cc.cohort_month,
  om.activity_month,
  TIMESTAMPDIFF(MONTH, cc.cohort_month, om.activity_month) AS months_since_cohort,
  COUNT(DISTINCT om.customer_id) AS active_customers
FROM customer_cohort cc
JOIN orders_months om ON cc.customer_id = om.customer_id
WHERE om.activity_month >= cc.cohort_month
GROUP BY cc.cohort_month, om.activity_month
ORDER BY cc.cohort_month, months_since_cohort;



### CONVERTING TO RETENTION RATES
DROP TABLE IF EXISTS cohort_sizes;
CREATE TABLE cohort_sizes ;
SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
FROM customer_cohort
GROUP BY cohort_month;


### MONTH OVER MONTH RETENTION RATE
DROP TABLE IF EXISTS cohort_retention_rate;
CREATE TABLE cohort_retention_rate ;
SELECT
  cr.cohort_month,
  cr.months_since_cohort,
  cr.active_customers,
  cs.cohort_size,
  ROUND(100 * cr.active_customers / cs.cohort_size, 2) AS retention_rate_pct
FROM cohort_retention cr
JOIN cohort_sizes cs USING (cohort_month)
ORDER BY cr.cohort_month, cr.months_since_cohort;



### 3 MONTH RETENTION FOR THE LAST COHORT
SELECT cohort_month,
       SUM(CASE WHEN months_since_cohort = 0 THEN active_customers ELSE 0 END) AS month_0,
       SUM(CASE WHEN months_since_cohort = 1 THEN active_customers ELSE 0 END) AS month_1,
       SUM(CASE WHEN months_since_cohort = 2 THEN active_customers ELSE 0 END) AS month_2
FROM cohort_retention
WHERE cohort_month >= DATE_FORMAT(DATE_SUB(@ref_date, INTERVAL 6 MONTH), '%Y-%m-01')
GROUP BY cohort_month
ORDER BY cohort_month;


### AT RISK CUSTOMERS
SELECT rs.customer_id, rb.recency_days, rb.frequency, rb.monetary, rfm_segment
FROM rfm_segment rs
JOIN rfm_base rb ON rs.customer_id = rb.customer_id
WHERE rfm_segment IN ('At Risk','Lost')
ORDER BY rb.recency_days DESC
LIMIT 500;




### CREATING VIEWS 
CREATE VIEW v_rfm_segment AS
SELECT rs.customer_id, rs.rfm_score_str, rs.rfm_score_numeric, rs.rfm_segment,
       rb.recency_days, rb.frequency, rb.monetary
FROM rfm_segment rs
JOIN rfm_base rb USING (customer_id);

CREATE VIEW v_cohort_retention AS
SELECT * FROM cohort_retention_rate;
