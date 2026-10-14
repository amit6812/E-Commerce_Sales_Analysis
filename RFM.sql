WITH reference_date AS (
    -- Reference date: Last date of the dataset + 1 day
    SELECT MAX(order_purchase_timestamp)::DATE + INTERVAL '1 day' AS max_date
    FROM olist_orders
    WHERE order_status = 'delivered'
),
customer_rfm_raw AS (
    -- 1. Aggregate R, F, M for each unique customer
    SELECT 
        c.customer_unique_id,
        (SELECT max_date FROM reference_date)::DATE - MAX(o.order_purchase_timestamp)::DATE AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(p.payment_value)::NUMERIC, 2) AS monetary
    FROM olist_orders o
    JOIN olist_customers c 
        ON o.customer_id = c.customer_id
    JOIN olist_order_payments p 
        ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
rfm_scores AS (
    -- 2. Assigning scores (1 to 5) from NTILE(5)
    SELECT 
        customer_unique_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_rfm_raw
)
-- 3. Categorizing Business Segments
SELECT 
    customer_unique_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    (r_score::TEXT || f_score::TEXT || m_score::TEXT) AS rfm_cell,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score = 1 THEN 'New Customers'
        WHEN r_score >= 3 AND f_score <= 2 THEN 'Promising / Potential'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk (High Value)'
        WHEN r_score = 1 AND f_score = 1 THEN 'Lost Customers'
        ELSE 'Hibernating / Others'
    END AS customer_segment
FROM rfm_scores
ORDER BY monetary DESC;