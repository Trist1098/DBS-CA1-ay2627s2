-- Run in the development database restored from the course backup.
BEGIN;

DO $test$
DECLARE
    john_id integer;
    jane_id integer;
    mike_id integer;
    review_id_to_test integer;
    other_review_id integer;
    root_id integer;
    reply_id integer;
    nested_id integer;
    sibling_root_id integer;
    rejected record;
BEGIN
    SELECT id INTO STRICT john_id FROM public.member WHERE username = 'johnsmith';
    SELECT id INTO STRICT jane_id FROM public.member WHERE username = 'janetaylor';
    SELECT id INTO STRICT mike_id FROM public.member WHERE username = 'mikewong';
    SELECT id INTO STRICT review_id_to_test FROM public.create_review(john_id, 1, 5, 'Comment test');
    INSERT INTO public.review (member_id, product_id, rating, review_text)
    VALUES (jane_id, 1, 4, 'Separate review fixture')
    RETURNING id INTO other_review_id;

    IF EXISTS (SELECT 1 FROM public.get_comments(review_id_to_test)) THEN
        RAISE EXCEPTION 'A new review should return an empty thread';
    END IF;

    SELECT id INTO STRICT root_id
    FROM public.create_comment(jane_id, review_id_to_test, '  Root comment.  ');
    SELECT id INTO STRICT reply_id
    FROM public.create_comment(john_id, review_id_to_test, 'Author reply.', root_id);
    SELECT id INTO STRICT nested_id
    FROM public.create_comment(mike_id, review_id_to_test, 'Nested reply.', reply_id);
    SELECT id INTO STRICT sibling_root_id
    FROM public.create_comment(mike_id, review_id_to_test, 'Another root.');

    IF (
        SELECT array_agg(id ORDER BY ordinality)
        FROM public.get_comments(review_id_to_test) WITH ORDINALITY
    ) IS DISTINCT FROM ARRAY[root_id, reply_id, nested_id, sibling_root_id] THEN
        RAISE EXCEPTION 'The thread is not returned in depth-first order';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.get_comments(review_id_to_test)
        WHERE id = root_id AND depth = 0 AND member_username = 'janetaylor'
            AND comment_text = 'Root comment.' AND NOT is_deleted
    ) OR NOT EXISTS (
        SELECT 1 FROM public.get_comments(review_id_to_test)
        WHERE id = nested_id AND depth = 2 AND parent_comment_id = reply_id
    ) THEN
        RAISE EXCEPTION 'Thread depth, author or content did not match';
    END IF;

    FOR rejected IN
        SELECT * FROM (VALUES
            ('Author starting a thread', john_id, review_id_to_test, 'Root', NULL, '42501'),
            ('Replying to own comment', jane_id, review_id_to_test, 'Reply', root_id, '42501'),
            ('Cross-review parent', mike_id, other_review_id, 'Reply', root_id, 'P0002'),
            ('Missing parent', jane_id, review_id_to_test, 'Reply', -1, 'P0002'),
            ('Missing review', jane_id, -1, 'Root', NULL, 'P0002'),
            ('Missing member', -1, review_id_to_test, 'Root', NULL, '22023'),
            ('Blank text', jane_id, review_id_to_test, E' \t\n', NULL, '22023')
        ) AS cases (label, member_id, review_id, body, parent_id, expected_code)
    LOOP
        BEGIN
            PERFORM public.create_comment(rejected.member_id, rejected.review_id, rejected.body, rejected.parent_id);
            RAISE EXCEPTION '% was accepted', rejected.label;
        EXCEPTION WHEN OTHERS THEN
            IF SQLSTATE <> rejected.expected_code THEN RAISE; END IF;
            RAISE NOTICE '% rejected with %', rejected.label, SQLSTATE;
        END;
    END LOOP;

    BEGIN
        PERFORM public.delete_comment(john_id, root_id);
        RAISE EXCEPTION 'The review author deleted another member''s comment';
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'Non-owner deletion rejected';
    END;
    IF NOT EXISTS (
        SELECT 1 FROM public.get_comments(review_id_to_test)
        WHERE id = root_id AND NOT is_deleted AND comment_text = 'Root comment.'
    ) THEN
        RAISE EXCEPTION 'The rejected deletion changed the comment';
    END IF;

    IF public.delete_comment(jane_id, root_id) IS DISTINCT FROM root_id THEN
        RAISE EXCEPTION 'Deletion did not return the targeted comment ID';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM public.comment WHERE id = root_id AND deleted_at IS NOT NULL AND comment_text IS NULL
    ) OR NOT EXISTS (
        SELECT 1 FROM public.get_comments(review_id_to_test)
        WHERE id = root_id AND is_deleted AND comment_text = 'Comment deleted'
            AND member_id IS NULL AND member_username IS NULL
    ) OR NOT EXISTS (
        SELECT 1 FROM public.get_comments(review_id_to_test)
        WHERE id = reply_id AND parent_comment_id = root_id AND comment_text = 'Author reply.'
    ) OR NOT EXISTS (
        SELECT 1 FROM public.get_comments(review_id_to_test)
        WHERE id = nested_id AND parent_comment_id = reply_id AND depth = 2
    ) THEN
        RAISE EXCEPTION 'Placeholder or surviving replies did not match';
    END IF;

    BEGIN
        PERFORM public.create_comment(mike_id, review_id_to_test, 'Late reply', root_id);
        RAISE EXCEPTION 'A reply was added directly to the deleted comment';
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'Reply to placeholder rejected';
    END;
    BEGIN
        PERFORM public.delete_comment(jane_id, root_id);
        RAISE EXCEPTION 'A second deletion of the placeholder was accepted';
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'Repeated deletion rejected';
    END;
    PERFORM public.create_comment(jane_id, review_id_to_test, 'Still active.', nested_id);

    PERFORM public.delete_review(john_id, review_id_to_test);
    IF EXISTS (SELECT 1 FROM public.comment WHERE review_id = review_id_to_test) THEN
        RAISE EXCEPTION 'Comments survived deletion of the whole review';
    END IF;
    RAISE NOTICE 'Passed depth-first retrieval, placeholder redaction, surviving replies, and review cascade';
END;
$test$;

ROLLBACK;
