CREATE TABLE public.review (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    member_id integer NOT NULL REFERENCES public.member(id),
    product_id integer NOT NULL REFERENCES public.product(id),
    rating smallint NOT NULL,
    review_text text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT review_member_product_key UNIQUE (member_id, product_id),
    CONSTRAINT review_rating_range CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT review_text_not_blank CHECK (review_text ~ '[^[:space:]]')
);

CREATE INDEX review_product_idx ON public.review (product_id);

CREATE TABLE public.comment (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    review_id integer NOT NULL REFERENCES public.review(id) ON DELETE CASCADE,
    member_id integer NOT NULL REFERENCES public.member(id),
    parent_comment_id integer,
    comment_text text,
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at timestamptz,
    CONSTRAINT comment_review_id_key UNIQUE (review_id, id),
    CONSTRAINT comment_parent_same_review FOREIGN KEY (review_id, parent_comment_id)
        REFERENCES public.comment (review_id, id),
    CONSTRAINT comment_parent_not_self CHECK (parent_comment_id <> id),
    CONSTRAINT comment_text_matches_state CHECK (
        (deleted_at IS NULL AND comment_text IS NOT NULL
            AND comment_text ~ '[^[:space:]]')
        OR (deleted_at IS NOT NULL AND comment_text IS NULL)
    )
);

CREATE INDEX comment_review_parent_idx ON public.comment (review_id, parent_comment_id);
