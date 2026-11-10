# ST0525 Database Systems CA1

## Run the starter locally

1. Install Node.js with npm and PostgreSQL 18. The local baseline was checked with Node.js 24 and PostgreSQL 18.4.
2. Create a new development database. In pgAdmin, choose **Restore** on that database and select the supplied `ecommerce_db_restore.sql` using the **Custom or tar** format. The course file is a custom-format backup.
3. In the `ecommerce` directory, copy `.env.example` to `.env`. Set the database host, port, user, password, and name to match your local database. Set `JWT_SECRET` to a random secret. Use port 5432 for a default PostgreSQL installation or 55432 for the isolated CA1 instance.
4. Run `npm ci` and then `npm start` from `ecommerce`. Open `http://localhost:3000/` or use the port set in `.env`.
5. Use the course fixture accounts `admin` and `johnsmith` to check sign-in as an administrator and customer. The restored baseline contains 20 products.

## Add the review and comment tables

After restoring the original starter backup, open [review_comment_schema.sql](ecommerce/sql/review_comment_schema.sql) in the pgAdmin Query Tool for your development database and run it once. The script adds two tables and their indexes. See the [database design](docs/database-design.md) for the full ERD and design decisions.

The startup check covered the login page, both accounts' login responses, and the authenticated product listing. The schema check covered review uniqueness, rating and text constraints, same-review parent references, deleted placeholders, and cascade deletion of a review's comment tree.

## Install and test the review routines

1. After applying the schema, run [review_routines.sql](ecommerce/sql/review_routines.sql) in pgAdmin.
2. On a development database restored from the starter, run [test_review_routines.sql](ecommerce/sql/test_review_routines.sql). Use the **Messages** tab to inspect the outcomes. The script rolls back its test rows.

The functions take a member ID for direct SQL testing. The app will supply the member ID from its verified login when the review pages are wired up. The ownership check is part of the same database statement that changes or deletes the review. A request targeting another member's review gets the same result as a missing review.
