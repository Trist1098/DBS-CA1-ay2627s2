const { getSummary } = require("../models/adminModel");
const { databaseAction } = require("../middleware/databaseErrors");

exports.summary = databaseAction(async (req, res) => {
  res.json({ success: true, summary: await getSummary(req.query) });
});
