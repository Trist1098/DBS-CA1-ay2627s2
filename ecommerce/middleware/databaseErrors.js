const routineStatus = {
  "22023": 400,
  "42501": 403,
  P0002: 404,
  "23505": 409,
};

function databaseErrors(err, req, res, next) {
  if (res.headersSent) return next(err);
  if (err.type === "entity.parse.failed") {
    return res.status(400).json({ success: false, message: "Send a valid JSON request." });
  }
  if (err.code === "22P02" || err.code === "22007" || err.code === "22008" || err.code === "22003") {
    return res.status(400).json({ success: false, message: "Check the IDs, rating, and dates provided." });
  }
  const status = routineStatus[err.code];
  if (status && err.routine === "exec_stmt_raise") {
    return res.status(status).json({ success: false, message: err.message });
  }
  console.error(err);
  return res.status(500).json({ success: false, message: "The request could not be completed." });
}

function databaseAction(action) {
  return (req, res, next) => Promise.resolve().then(() => action(req, res)).catch(next);
}

module.exports = { databaseErrors, databaseAction };
