CREATE OR REPLACE FUNCTION public.create_review(
    p_member_id integer,
    p_product_id integer,
    p_rating integer,
    p_review_text text
) RETURNS public.review
LANGUAGE plpgsql
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.get_reviews(p_member_id integer)
RETURNS TABLE (
    id integer,
    product_id integer,
    product_name varchar,
    rating smallint,
    review_text text,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE plpgsql STABLE
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.update_review(
    p_member_id integer,
    p_review_id integer,
    p_rating integer,
    p_review_text text
) RETURNS public.review
LANGUAGE plpgsql
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.delete_review(p_member_id integer, p_review_id integer)
RETURNS integer
LANGUAGE plpgsql
AS $$
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
$$;
