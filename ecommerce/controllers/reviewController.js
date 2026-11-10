const reviews = require("../models/reviewModel");
const { databaseAction } = require("../middleware/databaseErrors");

exports.create = databaseAction(async (req, res) => {
  const { productId, rating, reviewText } = req.body || {};
  const review = await reviews.create(req.user.id, productId, rating,
    typeof reviewText === "string" ? reviewText : null);
  res.status(201).json({ success: true, review });
});

exports.list = databaseAction(async (req, res) => {
  res.json({ success: true, reviews: await reviews.list(req.user.id) });
});

exports.update = databaseAction(async (req, res) => {
  const { rating, reviewText } = req.body || {};
  const review = await reviews.update(req.user.id, req.params.id, rating,
    typeof reviewText === "string" ? reviewText : null);
  res.json({ success: true, review });
});

exports.remove = databaseAction(async (req, res) => {
  await reviews.remove(req.user.id, req.params.id);
  res.json({ success: true });
});
