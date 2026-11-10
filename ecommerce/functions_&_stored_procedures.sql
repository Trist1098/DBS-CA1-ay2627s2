CREATE OR REPLACE FUNCTION public.create_comment(p_member_id integer, p_review_id integer, p_comment_text text, p_parent_comment_id integer DEFAULT NULL::integer)
 RETURNS comment
 LANGUAGE plpgsql
AS $function$
DECLARE
    review_author_id integer;
    parent_author_id integer;
    created_comment public.comment;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.member WHERE id = p_member_id) THEN
        RAISE EXCEPTION 'Member does not exist.' USING ERRCODE = '22023';
    END IF;
    IF p_comment_text IS NULL OR p_comment_text !~ '[^[:space:]]' THEN
        RAISE EXCEPTION 'Comment text is required.' USING ERRCODE = '22023';
    END IF;

    SELECT member_id INTO review_author_id
    FROM public.review
    WHERE id = p_review_id
    FOR KEY SHARE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review does not exist.' USING ERRCODE = 'P0002';
    END IF;

    IF p_parent_comment_id IS NULL THEN
        IF review_author_id = p_member_id THEN
            RAISE EXCEPTION 'You can reply to comments on your review, but cannot start a thread.'
                USING ERRCODE = '42501';
        END IF;
    ELSE
        -- Hold the parent against soft deletion until the reply is inserted.
        SELECT member_id INTO parent_author_id
        FROM public.comment
        WHERE id = p_parent_comment_id AND review_id = p_review_id AND deleted_at IS NULL
        FOR SHARE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Choose an active comment on this review to reply to.'
                USING ERRCODE = 'P0002';
        END IF;
        IF parent_author_id = p_member_id THEN
            RAISE EXCEPTION 'You can only reply to a comment written by another member.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    INSERT INTO public.comment (review_id, member_id, parent_comment_id, comment_text)
    VALUES (p_review_id, p_member_id, p_parent_comment_id, btrim(p_comment_text))
    RETURNING * INTO created_comment;

    RETURN created_comment;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_review(p_member_id integer, p_product_id integer, p_rating integer, p_review_text text)
 RETURNS review
 LANGUAGE plpgsql
AS $function$
DECLARE
    created_review public.review;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.member WHERE id = p_member_id) THEN
        RAISE EXCEPTION 'Member does not exist.' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.product WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'Product does not exist.' USING ERRCODE = 'P0002';
    END IF;
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'Rating must be an integer from 1 to 5.' USING ERRCODE = '22023';
    END IF;
    IF p_review_text IS NULL OR p_review_text !~ '[^[:space:]]' THEN
        RAISE EXCEPTION 'Review text is required.' USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM public.sale_order AS orders
        JOIN public.sale_order_item AS items ON items.sale_order_id = orders.id
        WHERE orders.member_id = p_member_id
          AND orders.status = 'COMPLETED'
          AND items.product_id = p_product_id
    ) THEN
        RAISE EXCEPTION 'You can only review a product from your completed orders.'
            USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.review (member_id, product_id, rating, review_text)
    VALUES (p_member_id, p_product_id, p_rating, btrim(p_review_text))
    ON CONFLICT ON CONSTRAINT review_member_product_key DO NOTHING
    RETURNING * INTO created_review;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'You already reviewed this product. Edit your existing review.'
            USING ERRCODE = '23505';
    END IF;
    RETURN created_review;
END;
$function$

CREATE OR REPLACE FUNCTION public.delete_comment(p_member_id integer, p_comment_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    deleted_comment_id integer;
BEGIN
    UPDATE public.comment
    SET comment_text = NULL,
        deleted_at = clock_timestamp()
    WHERE id = p_comment_id AND member_id = p_member_id AND deleted_at IS NULL
    RETURNING id INTO deleted_comment_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No active comment was found for your account.'
            USING ERRCODE = 'P0002';
    END IF;
    RETURN deleted_comment_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.delete_review(p_member_id integer, p_review_id integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    deleted_review_id integer;
BEGIN
    DELETE FROM public.review
    WHERE id = p_review_id AND member_id = p_member_id
    RETURNING id INTO deleted_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No matching review was found for your account.'
            USING ERRCODE = 'P0002';
    END IF;
    RETURN deleted_review_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.get_comments(p_review_id integer)
 RETURNS TABLE(id integer, parent_comment_id integer, member_id integer, member_username character varying, comment_text text, created_at timestamp with time zone, is_deleted boolean, depth integer)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.review AS r WHERE r.id = p_review_id) THEN
        RAISE EXCEPTION 'Review does not exist.' USING ERRCODE = 'P0002';
    END IF;

    RETURN QUERY
    WITH RECURSIVE thread AS (
        SELECT c.id, ARRAY[c.id] AS path
        FROM public.comment AS c
        WHERE c.review_id = p_review_id AND c.parent_comment_id IS NULL

        UNION ALL

        SELECT child.id, thread.path || child.id
        FROM thread
        JOIN public.comment AS child ON child.parent_comment_id = thread.id
        WHERE child.review_id = p_review_id
    )
    SELECT c.id, c.parent_comment_id, m.id, m.username,
           CASE WHEN c.deleted_at IS NULL THEN c.comment_text ELSE 'Comment deleted' END,
           c.created_at, c.deleted_at IS NOT NULL, cardinality(thread.path) - 1
    FROM thread
    JOIN public.comment AS c ON c.id = thread.id
    LEFT JOIN public.member AS m ON m.id = c.member_id AND c.deleted_at IS NULL
    ORDER BY thread.path;
END;
$function$

CREATE OR REPLACE FUNCTION public.get_reviews(p_member_id integer)
 RETURNS TABLE(id integer, product_id integer, product_name character varying, rating smallint, review_text text, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.member AS m WHERE m.id = p_member_id) THEN
        RAISE EXCEPTION 'Member does not exist.' USING ERRCODE = '22023';
    END IF;

    RETURN QUERY
    SELECT r.id, r.product_id, p.name, r.rating, r.review_text, r.created_at, r.updated_at
    FROM public.review AS r
    JOIN public.product AS p ON p.id = r.product_id
    WHERE r.member_id = p_member_id
    ORDER BY r.updated_at DESC, r.id DESC;
END;
$function$

CREATE OR REPLACE FUNCTION public.get_sale_order_summary(p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_gender text DEFAULT NULL::text, p_product_type text DEFAULT NULL::text, p_status text DEFAULT 'COMPLETED'::text, p_group_by text DEFAULT 'member'::text, p_sort_by text DEFAULT 'order_date'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
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
$function$

CREATE OR REPLACE FUNCTION public.update_review(p_member_id integer, p_review_id integer, p_rating integer, p_review_text text)
 RETURNS review
 LANGUAGE plpgsql
AS $function$
DECLARE
    updated_review public.review;
BEGIN
    IF p_rating IS NULL OR p_rating NOT BETWEEN 1 AND 5 THEN
        RAISE EXCEPTION 'Rating must be an integer from 1 to 5.' USING ERRCODE = '22023';
    END IF;
    IF p_review_text IS NULL OR p_review_text !~ '[^[:space:]]' THEN
        RAISE EXCEPTION 'Review text is required.' USING ERRCODE = '22023';
    END IF;

    UPDATE public.review
    SET rating = p_rating,
        review_text = btrim(p_review_text),
        updated_at = clock_timestamp()
    WHERE id = p_review_id AND member_id = p_member_id
    RETURNING * INTO updated_review;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No matching review was found for your account.'
            USING ERRCODE = 'P0002';
    END IF;
    RETURN updated_review;
END;
$function$

