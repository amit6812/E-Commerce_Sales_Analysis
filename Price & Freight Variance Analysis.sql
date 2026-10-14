CREATE OR REPLACE VIEW vw_olist_price_variance AS
WITH monthly_category_summary AS (
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS sales_month,
        COALESCE(p.product_category_name, 'Others') AS category_name,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(oi.order_item_id) AS total_units_sold,
        ROUND(SUM(oi.price)::NUMERIC, 2) AS total_revenue,
        ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_unit_price,
        ROUND(AVG(oi.freight_value)::NUMERIC, 2) AS avg_freight_value,
        ROUND(SUM(oi.freight_value)::NUMERIC, 2) AS total_freight_paid
    FROM olist_order_items oi
    JOIN olist_orders o 
        ON oi.order_id = o.order_id
    LEFT JOIN olist_products p 
        ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
      AND p.product_category_name IS NOT NULL
    GROUP BY 1, 2
),
lagged_metrics AS (
    SELECT 
        sales_month,
        category_name,
        total_orders,
        total_units_sold,
        total_revenue,
        avg_unit_price,
        avg_freight_value,
        total_freight_paid,
        -- Freight burden: freight product price ka kitne percent hai
        ROUND((avg_freight_value / NULLIF(avg_unit_price, 0) * 100)::NUMERIC, 2) AS freight_to_price_pct,
        -- Previous month average price and volume
        LAG(avg_unit_price) OVER (PARTITION BY category_name ORDER BY sales_month) AS prev_month_avg_price,
        LAG(total_units_sold) OVER (PARTITION BY category_name ORDER BY sales_month) AS prev_month_units
    FROM monthly_category_summary
)
SELECT 
    sales_month,
    category_name,
    total_orders,
    total_units_sold,
    total_revenue,
    avg_unit_price,
    avg_freight_value,
    freight_to_price_pct,
    -- Price Variance (MoM % change in price)
    ROUND(((avg_unit_price - prev_month_avg_price) / NULLIF(prev_month_avg_price, 0) * 100)::NUMERIC, 2) AS price_variance_pct,
    -- Volume Variance (MoM % change in quantity)
    ROUND(((total_units_sold - prev_month_units)::NUMERIC / NULLIF(prev_month_units, 0) * 100)::NUMERIC, 2) AS volume_variance_pct
FROM lagged_metrics
ORDER BY category_name, sales_month;


SELECT * FROM vw_olist_price_variance WHERE price_variance_pct IS NOT NULL LIMIT 20;