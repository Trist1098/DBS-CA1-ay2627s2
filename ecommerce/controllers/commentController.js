const comments = require("../models/commentModel");
const { databaseAction } = require("../middleware/databaseErrors");

exports.create = databaseAction(async (req, res) => {
  const { reviewId, commentText, parentCommentId } = req.body || {};
  const comment = await comments.create(req.user.id, reviewId,
    typeof commentText === "string" ? commentText : null, parentCommentId);
  res.status(201).json({ success: true, comment });
});

exports.remove = databaseAction(async (req, res) => {
  await comments.remove(req.user.id, req.params.id);
  res.json({ success: true });
});
