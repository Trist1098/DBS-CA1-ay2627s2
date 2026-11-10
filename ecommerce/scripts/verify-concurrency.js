require("dotenv").config();
const assert = require("node:assert/strict");
const { Client } = require("pg");

const options = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  statement_timeout: 10000,
};

async function waitForBlock(observer, blocked, blocker) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const result = await observer.query(
      "SELECT $1::integer = ANY(pg_blocking_pids($2::integer)) AS blocked",
      [blocker.processID, blocked.processID]
    );
    if (result.rows[0].blocked) return;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  throw new Error("Expected the concurrent request to wait for the open transaction.");
}

async function verify() {
  const clients = [new Client(options), new Client(options), new Client(options)];
  const [first, second, observer] = clients;
  let reviewId;
  try {
    await Promise.all(clients.map(client => client.connect()));
    const members = await observer.query(
      "SELECT id, username FROM public.member WHERE username IN ('johnsmith', 'janetaylor', 'mikewong')"
    );
    const ids = Object.fromEntries(members.rows.map(row => [row.username, row.id]));
    const john = ids.johnsmith;
    const jane = ids.janetaylor;
    const mike = ids.mikewong;
    assert.ok(john && jane && mike, "Restore the course seed before this check.");

    await first.query("BEGIN");
    const created = await first.query(
      "SELECT id FROM public.create_review($1, 1, 5, 'Concurrency fixture')", [john]
    );
    reviewId = created.rows[0].id;
    const duplicate = second.query(
      "SELECT id FROM public.create_review($1, 1, 5, 'Concurrent duplicate')", [john]
    ).then(() => null, error => error.code);
    await waitForBlock(observer, second, first);
    await first.query("COMMIT");
    assert.equal(await duplicate, "23505");
    console.log("PASS concurrent duplicate submissions produced one review.");

    const root = await observer.query(
      "SELECT id FROM public.create_comment($1, $2, 'Root fixture')", [jane, reviewId]
    );
    const rootId = root.rows[0].id;
    await first.query("BEGIN");
    const reply = await first.query(
      "SELECT id FROM public.create_comment($1, $2, 'Reply fixture', $3)", [john, reviewId, rootId]
    );
    const deletion = second.query(
      "SELECT public.delete_comment($1, $2)", [jane, rootId]
    );
    await waitForBlock(observer, second, first);
    await first.query("COMMIT");
    await deletion;
    const thread = await observer.query("SELECT * FROM public.get_comments($1)", [reviewId]);
    assert.equal(thread.rows[0].is_deleted, true);
    assert.equal(thread.rows[1].id, reply.rows[0].id);
    assert.equal(thread.rows[1].parent_comment_id, rootId);
    console.log("PASS a committed reply survived concurrent parent deletion.");

    const liveParent = await observer.query(
      "SELECT id FROM public.create_comment($1, $2, 'Second root')", [jane, reviewId]
    );
    await first.query("BEGIN");
    await first.query("SELECT public.delete_comment($1, $2)", [jane, liveParent.rows[0].id]);
    const lateReply = second.query(
      "SELECT id FROM public.create_comment($1, $2, 'Late reply', $3)",
      [john, reviewId, liveParent.rows[0].id]
    ).then(() => null, error => error.code);
    await waitForBlock(observer, second, first);
    await first.query("COMMIT");
    assert.equal(await lateReply, "P0002");
    console.log("PASS a reply waiting behind parent deletion was rejected.");

    await first.query("BEGIN");
    await first.query("SELECT public.delete_review($1, $2)", [john, reviewId]);
    const afterReviewDeletion = second.query(
      "SELECT id FROM public.create_comment($1, $2, 'Late root')", [mike, reviewId]
    ).then(() => null, error => error.code);
    await waitForBlock(observer, second, first);
    await first.query("COMMIT");
    assert.equal(await afterReviewDeletion, "P0002");
    const remaining = await observer.query(
      "SELECT count(*)::integer AS count FROM public.comment WHERE review_id = $1", [reviewId]
    );
    assert.equal(remaining.rows[0].count, 0);
    console.log("PASS review deletion rejected a concurrent comment and removed its whole tree.");
  } finally {
    await Promise.allSettled([first.query("ROLLBACK"), second.query("ROLLBACK")]);
    if (reviewId) await observer.query("DELETE FROM public.review WHERE id = $1", [reviewId]);
    await Promise.allSettled(clients.map(client => client.end()));
  }
}

verify().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
