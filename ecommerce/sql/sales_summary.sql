CREATE OR REPLACE FUNCTION public.get_sale_order_summary(
    p_start_date date DEFAULT NULL,
    p_end_date date DEFAULT NULL,
    p_gender text DEFAULT NULL,
    p_product_type text DEFAULT NULL,
    p_status text DEFAULT 'COMPLETED',
    p_group_by text DEFAULT 'member',
    p_sort_by text DEFAULT 'order_date'
) RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'Start date must be on or before end date.' USING ERRCODE = '22023';
    END IF;
    IF p_gender NOT IN ('M', 'F') THEN
        RAISE EXCEPTION 'Choose Male, Female, or All Genders.' USING ERRCODE = '22023';
    END IF;
    IF p_status NOT IN ('COMPLETED', 'PACKING', 'CANCELLED') THEN
        RAISE EXCEPTION 'Choose Completed, Packing, Cancelled, or All Statuses.' USING ERRCODE = '22023';
    END IF;
    IF p_group_by IS NULL OR p_group_by NOT IN ('member', 'product') THEN
        RAISE EXCEPTION 'Group by member or product.' USING ERRCODE = '22023';
    END IF;
    IF p_sort_by IS NULL OR p_sort_by NOT IN ('order_date', 'total_amount', 'order_count', 'name') THEN
        RAISE EXCEPTION 'Choose a supported sort option.' USING ERRCODE = '22023';
    END IF;

    RETURN (
        WITH matching_items AS (
            SELECT
                CASE p_group_by WHEN 'member' THEN m.id ELSE p.id END AS group_id,
                CASE p_group_by WHEN 'member' THEN m.username
                    ELSE COALESCE(p.name, 'Product #' || p.id) END AS group_name,
                m.id AS member_id,
                orders.id AS order_id,
                orders.order_datetime,
                orders.status,
                items.quantity,
                items.quantity * p.unit_price AS item_value
            FROM public.member AS m
            JOIN public.sale_order AS orders ON orders.member_id = m.id
            JOIN public.sale_order_item AS items ON items.sale_order_id = orders.id
            JOIN public.product AS p ON p.id = items.product_id
            WHERE (p_start_date IS NULL OR orders.order_datetime >= p_start_date)
              AND (p_end_date IS NULL OR orders.order_datetime < p_end_date + INTERVAL '1 day')
              AND (p_gender IS NULL OR m.gender = p_gender)
              AND (p_product_type IS NULL OR p.product_type = p_product_type)
              AND (p_status IS NULL OR orders.status = p_status)
        ),
        summary AS (
            SELECT
                group_id,
                group_name,
                COUNT(*) AS item_row_count,
                COUNT(DISTINCT order_id) AS order_count,
                COUNT(DISTINCT member_id) AS customer_count,
                COALESCE(SUM(quantity), 0) AS units,
                COALESCE(SUM(item_value), 0) AS item_value,
                COUNT(DISTINCT order_id) FILTER (WHERE status = 'COMPLETED') AS completed_order_count,
                COALESCE(SUM(item_value) FILTER (WHERE status = 'COMPLETED'), 0) AS completed_item_value,
                MAX(order_datetime) AS latest_order_at
            FROM matching_items
            GROUP BY GROUPING SETS ((group_id, group_name), ())
        ),
        with_average AS (
            SELECT summary.*,
                   ROUND(completed_item_value / NULLIF(completed_order_count, 0), 2)
                       AS avg_completed_order_value
            FROM summary
        )
        SELECT jsonb_build_object(
            'group_by', p_group_by,
            'metrics', (
                SELECT to_jsonb(totals) - ARRAY['group_id', 'group_name']
                FROM with_average AS totals
                WHERE totals.group_id IS NULL
            ),
            'groups', COALESCE((
                SELECT jsonb_agg(to_jsonb(g) ORDER BY
                    CASE WHEN p_sort_by = 'order_date' THEN g.latest_order_at END DESC,
                    CASE WHEN p_sort_by = 'total_amount' THEN g.item_value END DESC,
                    CASE WHEN p_sort_by = 'order_count' THEN g.order_count END DESC,
                    CASE WHEN p_sort_by = 'name' THEN lower(g.group_name) END,
                    g.group_id
                )
                FROM with_average AS g
                WHERE g.group_id IS NOT NULL
            ), '[]'::jsonb)
        )
    );
END;
$$;
