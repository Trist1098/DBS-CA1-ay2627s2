const router = require("express").Router();
const comments = require("../controllers/commentController");
const { verifyToken } = require("../middleware/auth");

router.use(verifyToken);
router.post("/", comments.create);
router.delete("/:id", comments.remove);

module.exports = router;
