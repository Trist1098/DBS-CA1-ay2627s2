const router = require("express").Router();
const { summary } = require("../controllers/adminController");
const { verifyToken, verifyAdmin } = require("../middleware/auth");

router.get("/sales-summary", verifyToken, verifyAdmin, summary);

module.exports = router;
