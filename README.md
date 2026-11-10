# ST0525 Database Systems CA1

## Run the starter locally

1. Install Node.js with npm and PostgreSQL 18. The local baseline was checked with Node.js 24 and PostgreSQL 18.4.
2. Create a new development database. In pgAdmin, choose **Restore** on that database and select the supplied `ecommerce_db_restore.sql` using the **Custom or tar** format. The course file is a custom-format backup.
3. In the `ecommerce` directory, copy `.env.example` to `.env`. Set the database host, port, user, password, and name to match your local database. Set `JWT_SECRET` to a random secret. Use port 5432 for a default PostgreSQL installation or 55432 for the isolated CA1 instance.
4. Install the schema and routines in the order below. Then run `npm ci` and `npm start` from `ecommerce`. Open `http://localhost:3000/` or use the port set in `.env`.
5. Use the course fixture accounts `admin` and `johnsmith` to check sign-in as an administrator and customer. The restored baseline contains 20 products.

## Add the review and comment tables

After restoring the original starter backup, open [review_comment_schema.sql](ecommerce/sql/review_comment_schema.sql) in the pgAdmin Query Tool for your development database and run it once. The script adds two tables and their indexes. See the [database design](docs/database-design.md) for the full ERD and design decisions.

The startup check covered the login page, both accounts' login responses, and the authenticated product listing. The schema check covered review uniqueness, rating and text constraints, same-review parent references, deleted placeholders, and cascade deletion of a review's comment tree.

## Install and test the review routines

1. After applying the schema, run [review_routines.sql](ecommerce/sql/review_routines.sql) in pgAdmin.
2. On a development database restored from the starter, run [test_review_routines.sql](ecommerce/sql/test_review_routines.sql). Use the **Messages** tab to inspect the outcomes. The script rolls back its test rows.

The functions take a member ID for direct SQL testing. The app supplies that ID from its verified login. The ownership check is part of the same database statement that changes or deletes the review. A request targeting another member's review gets the same result as a missing review.

## Install and test the comment routines

1. After installing the review routines, run [comment_routines.sql](ecommerce/sql/comment_routines.sql) in pgAdmin.
2. On a development database restored from the starter, run [test_comment_routines.sql](ecommerce/sql/test_comment_routines.sql). Check the **Messages** tab for the results. The script rolls back its test rows.

`get_comments` returns parents before their descendants, with a depth of 0 for root comments. The deleted row retains its ID and position. The result displays **Comment deleted** and omits the original author's details.

## Install and test the sales summary

Run [sales_summary.sql](ecommerce/sql/sales_summary.sql) in pgAdmin, then run [test_sales_summary.sql](ecommerce/sql/test_sales_summary.sql) against the original seed data. The tests are read-only.

```sql
SELECT jsonb_pretty(public.get_sale_order_summary(
    '2025-01-01', '2025-03-01', 'M', 'Classic Bottle', 'COMPLETED', 'product', 'order_count'
));
```

The function defaults to completed orders across all dates, grouped by member and sorted by latest order. Explicit `NULL` for status includes all statuses. The optional dates are inclusive, and gender and product type can be combined with them. Group by `member` or `product`. Sort by `order_date`, `total_amount`, `order_count`, or `name`.

The response contains overall `metrics` and a sorted `groups` array. An order or customer counts once in the overall totals if they have at least one matching line. An order can appear in several product groups. Item value is matching quantity times the current product price in the supplied schema. The completed average divides completed matching item value by the number of distinct completed matching orders. It is null when there are zero matching completed orders.

## Try the app

- Sign in as `johnsmith`. From Products, write a review for **HydroMax Classic 500ml**, which appears in one of John's completed orders. Use **My reviews** to edit it or confirm deletion.
- Sign in as `janetaylor`. Open **Read reviews** on the same product and comment on John's review. Sign in as John to reply. Sign back in as Jane and delete her original comment. The reply should still appear under **Comment deleted**.
- Sign in as `admin`. Filter **1–10 January 2025** and group by product. Expect four product groups across two distinct orders and SGD 156.30 completed item value. **Export CSV** downloads the groups from the last successful search.
