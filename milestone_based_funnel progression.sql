CREATE OR REPLACE VIEW vw_olist_order_milestones AS
SELECT 
    '1. Order Placed' AS milestone_name,
    1 AS milestone_order,
    COUNT(order_id) AS orders_reached
FROM olist_orders

UNION ALL

SELECT 
    '2. Payment Approved' AS milestone_name,
    2 AS milestone_order,
    COUNT(order_id) AS orders_reached
FROM olist_orders
WHERE order_approved_at IS NOT NULL

UNION ALL

SELECT 
    '3. Shipped to Carrier' AS milestone_name,
    3 AS milestone_order,
    COUNT(order_id) AS orders_reached
FROM olist_orders
WHERE order_delivered_carrier_date IS NOT NULL

UNION ALL

SELECT 
    '4. Delivered to Customer' AS milestone_name,
    4 AS milestone_order,
    COUNT(order_id) AS orders_reached
FROM olist_orders
WHERE order_delivered_customer_date IS NOT NULL;


select * from vw_olist_order_milestones;