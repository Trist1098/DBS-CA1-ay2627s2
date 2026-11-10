const { query } = require("../config/database");

async function create(memberId, reviewId, text, parentId) {
  const result = await query("SELECT * FROM public.create_comment($1, $2, $3, $4)", [
    memberId, reviewId, text, parentId,
  ]);
  return result.rows[0];
}

async function remove(memberId, commentId) {
  await query("SELECT public.delete_comment($1, $2)", [memberId, commentId]);
}

module.exports = { create, remove };
