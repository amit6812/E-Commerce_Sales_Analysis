-- Step 1: PostgreSQL CLV Cohort View
-- Is query me hum teen core logic implement karenge:

-- Har customer ka Acquisition Cohort Month (unka sabse pehla delivered order).

-- Unke sabhi agle orders ka Month Index (LTV Month 0, 1, 2, ...).

-- Har cohort ka Cumulative Revenue per Customer (Real CLV Curve).

-- Apne pgAdmin Query Tool me yeh view execute karein:



CREATE OR REPLACE VIEW vw_olist_cohort_clv AS
WITH customer_first_purchase AS (
    -- 1. Har unique customer ka first purchase month (Acquisition Cohort)
    SELECT 
        c.customer_unique_id,
        MIN(DATE_TRUNC('month', o.order_purchase_timestamp))::DATE AS cohort_month
    FROM olist_orders o
    JOIN olist_customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
cohort_sizes AS (
    -- 2. Har cohort me total kitne new customers acquire huye
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM customer_first_purchase
    GROUP BY cohort_month
),
customer_monthly_revenue AS (
    -- 3. Har customer ka monthly spend aur unka relative month index (Month 0, Month 1, etc.)
    SELECT 
        c.customer_unique_id,
        fp.cohort_month,
        (
            (EXTRACT(YEAR FROM o.order_purchase_timestamp) - EXTRACT(YEAR FROM fp.cohort_month)) * 12 +
            (EXTRACT(MONTH FROM o.order_purchase_timestamp) - EXTRACT(MONTH FROM fp.cohort_month))
        )::INT AS period_month,
        SUM(p.payment_value) AS monthly_spend
    FROM olist_orders o
    JOIN olist_customers c ON o.customer_id = c.customer_id
    JOIN customer_first_purchase fp ON c.customer_unique_id = fp.customer_unique_id
    JOIN olist_order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, fp.cohort_month, period_month
),
cohort_period_agg AS (
    -- 4. Cohort aur Period ke hisab se total revenue aggregate karna
    SELECT 
        r.cohort_month,
        s.cohort_size,
        r.period_month,
        COUNT(DISTINCT r.customer_unique_id) AS active_customers,
        ROUND(SUM(r.monthly_spend)::NUMERIC, 2) AS period_revenue
    FROM customer_monthly_revenue r
    JOIN cohort_sizes s ON r.cohort_month = s.cohort_month
    GROUP BY r.cohort_month, s.cohort_size, r.period_month
)
-- 5. Window function se Cumulative CLV per Customer calculate karna
SELECT 
    cohort_month,
    cohort_size,
    period_month,
    active_customers,
    period_revenue,
    -- Retention rate is specific month me
    ROUND((active_customers::NUMERIC / cohort_size * 100), 2) AS retention_rate_pct,
    -- Cumulative Revenue over time
    ROUND(SUM(period_revenue) OVER (
        PARTITION BY cohort_month 
        ORDER BY period_month 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::NUMERIC, 2) AS cumulative_revenue,
    -- Real Cumulative CLV (Per Customer Average)
    ROUND((SUM(period_revenue) OVER (
        PARTITION BY cohort_month 
        ORDER BY period_month 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )::NUMERIC / cohort_size), 2) AS cumulative_clv
FROM cohort_period_agg
ORDER BY cohort_month, period_month;

SELECT * FROM vw_olist_cohort_clv WHERE period_month <= 6 LIMIT 25;


