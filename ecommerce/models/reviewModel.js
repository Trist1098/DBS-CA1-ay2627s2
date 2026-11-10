const { query } = require("../config/database");

async function create(memberId, productId, rating, text) {
  const result = await query("SELECT * FROM public.create_review($1, $2, $3, $4)", [
    memberId, productId, rating, text,
  ]);
  return result.rows[0];
}

async function list(memberId) {
  const result = await query("SELECT * FROM public.get_reviews($1)", [memberId]);
  return result.rows;
}

async function update(memberId, reviewId, rating, text) {
  const result = await query("SELECT * FROM public.update_review($1, $2, $3, $4)", [
    memberId, reviewId, rating, text,
  ]);
  return result.rows[0];
}

async function remove(memberId, reviewId) {
  await query("SELECT public.delete_review($1, $2)", [memberId, reviewId]);
}

module.exports = { create, list, update, remove };
