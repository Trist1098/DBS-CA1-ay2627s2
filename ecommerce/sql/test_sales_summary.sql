-- Read-only checks against the supplied ecommerce seed data.
DO $test$
DECLARE
    report jsonb;
    group_order_ids integer[];
    bad_option record;
BEGIN
    report := public.get_sale_order_summary();
    IF NOT (report->'metrics' @> '{
        "item_row_count": 46, "order_count": 23, "customer_count": 13,
        "units": 76, "item_value": 2499.40, "completed_order_count": 23,
        "completed_item_value": 2499.40, "avg_completed_order_value": 108.67
    }'::jsonb) OR jsonb_array_length(report->'groups') <> 13 THEN
        RAISE EXCEPTION 'Completed baseline did not reconcile: %', report->'metrics';
    END IF;
    RAISE NOTICE 'Completed baseline: 23 orders, 76 units, S$2,499.40';

    report := public.get_sale_order_summary(p_status => NULL);
    IF NOT (report->'metrics' @> '{
        "item_row_count": 51, "order_count": 28, "customer_count": 13,
        "units": 82, "item_value": 2653.80, "completed_order_count": 23,
        "completed_item_value": 2499.40, "avg_completed_order_value": 108.67
    }'::jsonb) THEN
        RAISE EXCEPTION 'All-status baseline mixed up matching and completed orders: %', report->'metrics';
    END IF;
    RAISE NOTICE 'All statuses: 28 matching orders, 23 completed orders, completed average S$108.67';

    report := public.get_sale_order_summary(
        '2025-01-01', '2025-01-10', p_status => NULL,
        p_group_by => 'product', p_sort_by => 'total_amount'
    );
    IF NOT (report->'metrics' @> '{
        "item_row_count": 4, "order_count": 2, "customer_count": 2,
        "units": 7, "item_value": 156.30, "avg_completed_order_value": 78.15
    }'::jsonb) OR jsonb_array_length(report->'groups') <> 4 THEN
        RAISE EXCEPTION 'January result or grouping did not reconcile: %', report;
    END IF;
    IF (report#>>'{groups,0,item_value}')::numeric IS DISTINCT FROM 44.70 THEN
        RAISE EXCEPTION 'Product groups were not sorted by value';
    END IF;
    RAISE NOTICE '1-10 January: four product groups across two distinct orders, 7 units, S$156.30';

    report := public.get_sale_order_summary(
        '2025-01-01', '2025-03-01', 'M', 'Classic Bottle', 'COMPLETED', 'product', 'order_count'
    );
    IF NOT (report->'metrics' @> '{
        "item_row_count": 2, "order_count": 2, "units": 5,
        "item_value": 94.50, "avg_completed_order_value": 47.25
    }'::jsonb) OR (report#>>'{groups,0,group_name}') IS NULL THEN
        RAISE EXCEPTION 'Combined filters or inclusive end date did not reconcile: %', report;
    END IF;
    RAISE NOTICE 'Combined dates, gender, category and status: 2 orders, 5 units, S$94.50';

    report := public.get_sale_order_summary(
        '2025-01-05', '2025-01-05', p_group_by => 'product', p_sort_by => 'order_count'
    );
    SELECT array_agg((item->>'group_id')::integer ORDER BY ordinality)
    INTO group_order_ids
    FROM jsonb_array_elements(report->'groups') WITH ORDINALITY AS groups(item, ordinality);
    IF group_order_ids IS DISTINCT FROM ARRAY[1, 5] THEN
        RAISE EXCEPTION 'Same-day filter or stable order-count tie break failed: %', group_order_ids;
    END IF;

    report := public.get_sale_order_summary('2025-01-01', '2025-01-10');
    IF (report#>>'{groups,0,group_name}') IS DISTINCT FROM 'janetaylor' THEN
        RAISE EXCEPTION 'Member groups were not sorted by latest order';
    END IF;
    report := public.get_sale_order_summary(
        '2025-01-01', '2025-01-10', p_sort_by => 'name'
    );
    IF (report#>>'{groups,0,group_name}') IS DISTINCT FROM 'janetaylor' THEN
        RAISE EXCEPTION 'Member groups were not sorted by name';
    END IF;

    report := public.get_sale_order_summary(p_status => 'PACKING');
    IF NOT (report->'metrics' @> '{
        "order_count": 3, "completed_order_count": 0,
        "completed_item_value": 0, "avg_completed_order_value": null
    }'::jsonb) THEN
        RAISE EXCEPTION 'Packing orders contributed to completed value: %', report->'metrics';
    END IF;

    report := public.get_sale_order_summary(p_start_date => '2099-01-01');
    IF report->'groups' IS DISTINCT FROM '[]'::jsonb OR NOT (report->'metrics' @> '{
        "item_row_count": 0, "order_count": 0, "customer_count": 0,
        "units": 0, "item_value": 0, "avg_completed_order_value": null
    }'::jsonb) THEN
        RAISE EXCEPTION 'Unexpected empty result: %', report;
    END IF;

    FOR bad_option IN
        SELECT * FROM (VALUES
            ('Reversed dates', DATE '2025-01-02', DATE '2025-01-01', 'M', 'COMPLETED', 'member', 'name'),
            ('Unsupported gender', NULL, NULL, 'invalid', 'COMPLETED', 'member', 'name'),
            ('Unsupported status', NULL, NULL, 'M', 'invalid', 'member', 'name'),
            ('Unsupported grouping', NULL, NULL, 'M', 'COMPLETED', 'invalid', 'name'),
            ('Unsupported sort', NULL, NULL, 'M', 'COMPLETED', 'member', 'invalid')
        ) AS cases (label, start_date, end_date, gender, status, grouping, sort)
    LOOP
        BEGIN
            PERFORM public.get_sale_order_summary(
                bad_option.start_date, bad_option.end_date, bad_option.gender, NULL,
                bad_option.status, bad_option.grouping, bad_option.sort
            );
            RAISE EXCEPTION '% was accepted', bad_option.label;
        EXCEPTION WHEN invalid_parameter_value THEN
            RAISE NOTICE '% rejected', bad_option.label;
        END;
    END LOOP;
    RAISE NOTICE 'Passed matching and completed metrics, inclusive dates, grouping, sorting and empty results';
END;
$test$;
