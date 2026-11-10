-- Run in the development database restored from the course backup.
BEGIN;

DO $test$
DECLARE
    john_id integer;
    mike_id integer;
    david_id integer;
    admin_id integer;
    fixture public.review;
    edited public.review;
    parent_id integer;
    rejected record;
BEGIN
    SELECT id INTO STRICT john_id FROM public.member WHERE username = 'johnsmith';
    SELECT id INTO STRICT mike_id FROM public.member WHERE username = 'mikewong';
    SELECT id INTO STRICT david_id FROM public.member WHERE username = 'davidtan';
    SELECT id INTO STRICT admin_id FROM public.member WHERE username = 'admin';

    SELECT * INTO STRICT fixture FROM public.create_review(john_id, 1, 5, '  Good bottle.  ');
    IF fixture.member_id <> john_id OR fixture.product_id <> 1
        OR fixture.rating <> 5 OR fixture.review_text <> 'Good bottle.' THEN
        RAISE EXCEPTION 'The eligible purchase did not produce the expected review';
    END IF;

    FOR rejected IN
        SELECT * FROM (VALUES
            ('Duplicate review', john_id, 1, 5, 'Duplicate', '23505'),
            ('Packing order', mike_id, 4, 5, 'Packing', '42501'),
            ('Cancelled order', david_id, 9, 5, 'Cancelled', '42501'),
            ('Another member bought it', admin_id, 1, 5, 'Wrong buyer', '42501'),
            ('Unknown member', -1, 1, 5, 'Unknown buyer', '22023'),
            ('Unknown product', john_id, -1, 5, 'Unknown product', 'P0002'),
            ('Rating outside range', john_id, 1, 6, 'Bad rating', '22023'),
            ('Missing rating', john_id, 1, NULL, 'No rating', '22023'),
            ('Blank text', john_id, 1, 5, E' \t\n', '22023')
        ) AS cases (label, member_id, product_id, rating, review_text, expected_code)
    LOOP
        BEGIN
            PERFORM public.create_review(
                rejected.member_id, rejected.product_id, rejected.rating, rejected.review_text
            );
            RAISE EXCEPTION '% was accepted', rejected.label;
        EXCEPTION WHEN OTHERS THEN
            IF SQLSTATE <> rejected.expected_code THEN RAISE; END IF;
            RAISE NOTICE '% rejected with %', rejected.label, SQLSTATE;
        END;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1 FROM public.get_reviews(john_id)
        WHERE id = fixture.id AND product_name IS NOT NULL AND rating = 5
    ) OR EXISTS (SELECT 1 FROM public.get_reviews(mike_id) WHERE id = fixture.id) THEN
        RAISE EXCEPTION 'Review retrieval did not return the correct owner or product details';
    END IF;

    BEGIN
        PERFORM public.update_review(mike_id, fixture.id, 1, 'Unauthorized edit');
        RAISE EXCEPTION 'Another member updated the review';
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'Non-owner update rejected';
    END;

    BEGIN
        PERFORM public.delete_review(admin_id, fixture.id);
        RAISE EXCEPTION 'A non-owner administrator deleted the review';
    EXCEPTION WHEN no_data_found THEN
        RAISE NOTICE 'Non-owner deletion rejected';
    END;

    IF NOT EXISTS (
        SELECT 1 FROM public.get_reviews(john_id)
        WHERE id = fixture.id AND rating = 5 AND review_text = fixture.review_text
    ) THEN
        RAISE EXCEPTION 'The rejected actions changed the review';
    END IF;

    SELECT * INTO STRICT edited FROM public.update_review(john_id, fixture.id, 4, 'Updated review');
    IF edited.id <> fixture.id OR edited.member_id <> john_id OR edited.product_id <> 1
        OR edited.rating <> 4 OR edited.review_text <> 'Updated review'
        OR edited.created_at <> fixture.created_at OR edited.updated_at <= fixture.updated_at THEN
        RAISE EXCEPTION 'The owner update did not preserve identity or set the expected values';
    END IF;

    INSERT INTO public.comment (review_id, member_id, comment_text)
    VALUES (fixture.id, mike_id, 'Root fixture')
    RETURNING id INTO parent_id;
    INSERT INTO public.comment (review_id, member_id, parent_comment_id, comment_text)
    VALUES (fixture.id, john_id, parent_id, 'Reply fixture');

    IF public.delete_review(john_id, fixture.id) <> fixture.id THEN
        RAISE EXCEPTION 'Delete did not return the removed review ID';
    END IF;
    IF EXISTS (SELECT 1 FROM public.get_reviews(john_id) WHERE id = fixture.id)
        OR EXISTS (SELECT 1 FROM public.comment WHERE review_id = fixture.id) THEN
        RAISE EXCEPTION 'The review or its comments survived deletion';
    END IF;
    RAISE NOTICE 'Passed owner-only listing, editing, deletion, and comment cascade';
END;
$test$;

ROLLBACK;
