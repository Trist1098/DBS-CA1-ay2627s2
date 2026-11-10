const router = require("express").Router();
const reviews = require("../controllers/reviewController");
const { verifyToken } = require("../middleware/auth");

router.use(verifyToken);
router.get("/", reviews.list);
router.post("/", reviews.create);
router.patch("/:id", reviews.update);
router.delete("/:id", reviews.remove);

module.exports = router;
