# CA1 database design

The [seven-table ERD](ecommerce-erd.mmd) represents the schema restored from the supplied backup plus the new review and comment tables. It shows optional participation where the database allows it. For instance, `sale_order.member_id` is nullable and the starter contains orders with zero line items. The original five tables retain their supplied definitions.

## Review

| Field | Rule |
|---|---|
| `id` | Generated primary key |
| `member_id`, `product_id` | Required foreign keys. The pair is unique, so repeat purchases share one editable review. |
| `rating` | Required integer from 1 to 5 |
| `review_text` | Required text containing at least one non-whitespace character |
| `created_at`, `updated_at` | Required timestamps with time zone. Both start at creation time. The update routine will maintain `updated_at`. |

A review's ID determines its author, product, rating, text, and timestamps. The member and product pair also determines the entire row and is a candidate key. The member ID alone and product ID alone do not determine any review details. Member names, product names, and purchase status remain in their source tables. The review creation routine will check for a matching completed purchase. Edits will apply to rating and text.

## Comment

| Field | Rule |
|---|---|
| `id` | Generated primary key |
| `review_id`, `member_id` | Required foreign keys to the review and the author |
| `parent_comment_id` | Optional. The foreign key uses `(review_id, parent_comment_id)` to enforce that any parent belongs to the same review. A comment cannot parent itself. |
| `comment_text`, `deleted_at` | A visible comment has nonblank text and no deletion timestamp. A deleted comment has a deletion timestamp and its text is cleared. |
| `created_at` | Required timestamp with time zone |

A review has zero or more comments, and a comment belongs to exactly one review. Each comment has at most one parent and can have many replies. The comment ID determines the author, review, parent, text and timestamps. The unique pair `(review_id, id)` supports the parent foreign key. It is a superkey because the ID is already unique. Each reply is a row, so the design can store multiple replies and levels without repeating fields.

Deleting an individual comment clears its text and shows **Comment deleted** in the original thread position. Replies keep their parent references. The placeholder display omits the deleted comment's author. The routines enforce ownership, disallow new replies directly to deleted placeholders, and leave a comment's parent fixed after creation. Members reply to comments written by other members. The review author may reply to someone else's comment on their review, while other members can also start threads there. Deleting an entire review physically deletes every comment and placeholder under it through the review foreign key.

The review and comment tables keep the facts for their own entity. Apart from the parent link, the comment table stores no attributes of the parent. In particular, its required review reference also identifies the review for root comments, whose parent is absent. The composite foreign key keeps that reference consistent with the parent link for replies.

## Prepare the report diagram

Paste the ERD source into **Diagram as code** in Lucidchart if that feature is available. With a free plan, use Lucidchart's PostgreSQL ERD import and use the source diagram as a reference for cardinality and optionality. Export the resulting diagram as an image and check the text at report size.
