CREATE OR REPLACE FUNCTION public.create_comment(
    p_member_id integer,
    p_review_id integer,
    p_comment_text text,
    p_parent_comment_id integer DEFAULT NULL
) RETURNS public.comment
LANGUAGE plpgsql
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.get_comments(p_review_id integer)
RETURNS TABLE (
    id integer,
    parent_comment_id integer,
    member_id integer,
    member_username varchar,
    comment_text text,
    created_at timestamptz,
    is_deleted boolean,
    depth integer
)
LANGUAGE plpgsql STABLE
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.delete_comment(p_member_id integer, p_comment_id integer)
RETURNS integer
LANGUAGE plpgsql
AS $$
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
$$;
