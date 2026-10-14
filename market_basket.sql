-- Production Market Basket View Creation:

CREATE OR REPLACE VIEW vw_olist_market_basket AS
WITH multi_item_orders AS (
    -- 1. Filter only those orders that contain more than one distinct product.
    SELECT order_id
    FROM olist_order_items
    GROUP BY order_id
    HAVING COUNT(DISTINCT product_id) > 1
),
order_product_pairs AS (
    -- 2. Self-join on order_id to find co-purchased product categories
    SELECT 
        i1.order_id,
        COALESCE(p1.product_category_name, 'Others') AS item_a,
        COALESCE(p2.product_category_name, 'Others') AS item_b
    FROM olist_order_items i1
    JOIN multi_item_orders m 
        ON i1.order_id = m.order_id
    JOIN olist_order_items i2 
        ON i1.order_id = i2.order_id 
        AND i1.product_id < i2.product_id -- Unique pairings only
    LEFT JOIN olist_products p1 
        ON i1.product_id = p1.product_id
    LEFT JOIN olist_products p2 
        ON i2.product_id = p2.product_id
    -- If you need analysis at the category level and both belong to the same category, you can use filters or include them.
    WHERE p1.product_category_name IS NOT NULL 
      AND p2.product_category_name IS NOT NULL
)
SELECT 
    item_a,
    item_b,
    COUNT(DISTINCT order_id) AS co_occurrence_count
FROM order_product_pairs
GROUP BY item_a, item_b
ORDER BY co_occurrence_count DESC;


