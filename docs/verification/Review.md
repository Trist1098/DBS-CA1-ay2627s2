# CA1 critical review

Verified on 11 November 2026, Singapore time.

## Evidence added

| Area | Check | Outcome |
|---|---|---|
| Duplicate submissions | Two connections insert the same member/product while the first transaction is open | The second connection waited, then received SQLSTATE 23505 after the first committed. |
| Reply before parent deletion | An open reply transaction holds the parent while another connection deletes it | The deletion waited. The committed reply stayed below the placeholder. |
| Parent deletion before reply | A reply waits behind deletion of its parent | After commit, the reply received P0002. |
| Whole-review deletion | A new comment waits behind deletion of its review | After commit, the new comment received P0002. The existing comment tree was removed. |
| Fresh database | Restore the final plain SQL backup into ecommerce_ca1_restore_audit | All review, comment and sales SQL checks passed. Concurrent checks passed too. |
| Packaged source | Extract Code.zip, npm ci, then normal app.js startup against the fresh database | Required pages/assets and the authenticated customer/admin APIs passed. |
| Hostile inputs | Missing/invalid tokens, spoofed member IDs, malformed JSON, object review text, fractional ratings | Rejected with an appropriate 4xx response. |
| Larger thread | Temporary 100 roots and 900 replies | All 1,000 comments returned. One local measured run took 2.109 ms. The fixture was rolled back. |

See Fresh_Restore_Verification.txt, Packaged_App_Verification.txt and Comment_Load_Check.txt for recorded results. The checked source and all eight SQL functions are published in the GitHub fork.

## Decisions to defend

- Reviews are unique per member/product. Existing reviews remain editable after a later order-status change because eligibility is checked at creation.
- Individual comment deletion clears text while retaining the comment's structural position. Placeholder responses omit the author. New direct replies to placeholders are rejected.
- Replies target another member's comment. That extra rule is an explicit design assumption.
- Dashboard orders have at least one matching line. Orders 29, 30 and 31 have no items and therefore do not count in this metric.
- Sales values use current product prices because the supplied schema has no order-line price snapshot.

## Completion items

The Lucidchart export, actual application screenshots, and final PDF layout review remain pending. The academic integrity declaration must be obtained and completed accurately. Tutor access needs the tutor's GitHub username.

The practical interview still depends on Tristan being able to explain and reproduce the work. Use Demo_and_Interview.md to rehearse it.
