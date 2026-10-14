-- Using this logic, we will calculate two things:

-- 1. Funnel Volume & Conversion %: The number of orders reaching each stage and the drop-off rate.

-- 2. Fulfillment Cycle Time (Bottlenecks): The average time taken from approval to carrier handover,
--    and from carrier handover to customer delivery.



CREATE OR REPLACE VIEW vw_olist_funnel_metrics AS
WITH stage_aggregation AS (
    SELECT 
        order_status,
        COUNT(order_id) AS total_orders,
        -- Average cycle durations (in days)
        ROUND(AVG(EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp))/86400)::NUMERIC, 2) AS avg_approval_days,
        ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at))/86400)::NUMERIC, 2) AS avg_dispatch_days,
        ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_delivered_carrier_date))/86400)::NUMERIC, 2) AS avg_transit_days
    FROM olist_orders
    GROUP BY order_status
),
total_pool AS (
    SELECT COUNT(*) AS global_orders FROM olist_orders
)
SELECT 
    s.order_status,
    -- Funnel sequence mapping
    CASE 
        WHEN s.order_status = 'created' THEN 1
        WHEN s.order_status = 'approved' THEN 2
        WHEN s.order_status = 'invoiced' THEN 3
        WHEN s.order_status = 'processing' THEN 4
        WHEN s.order_status = 'shipped' THEN 5
        WHEN s.order_status = 'delivered' THEN 6
        WHEN s.order_status = 'unavailable' THEN 7
        WHEN s.order_status = 'canceled' THEN 8
        ELSE 9
    END AS stage_sequence,
    s.total_orders,
    ROUND((s.total_orders::NUMERIC / t.global_orders * 100), 2) AS pct_of_total_orders,
    s.avg_approval_days,
    s.avg_dispatch_days,
    s.avg_transit_days
FROM stage_aggregation s
CROSS JOIN total_pool t
ORDER BY stage_sequence ASC;