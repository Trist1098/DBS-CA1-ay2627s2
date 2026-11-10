const { query } = require("../config/database");

const getAllProducts = async () => {
  const result = await query("SELECT * FROM public.product ORDER BY id");
  return result.rows;
};

const getProductById = async (id) => {
  const result = await query("SELECT * FROM public.product WHERE id = $1", [id]);
  return result.rows[0];
};

const getProductWithReviews = async (id) => {
  const product = await getProductById(id);
  if (!product) return { product, reviews: [] };
  const reviews = await query(
    `SELECT r.id, r.member_id, r.rating, r.review_text, r.updated_at,
            m.username AS member_username,
            ARRAY(SELECT row_to_json(c) FROM public.get_comments(r.id) AS c) AS comments
     FROM public.review r
     JOIN public.member m ON r.member_id = m.id
     WHERE r.product_id = $1
     ORDER BY r.updated_at DESC, r.id DESC`,
    [id]
  );
  return { product, reviews: reviews.rows };
};

module.exports = { getAllProducts, getProductById, getProductWithReviews };
