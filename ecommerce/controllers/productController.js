const productModel = require("../models/productModel");
const { databaseAction } = require("../middleware/databaseErrors");

const getAllProducts = async (req, res) => {
  try {
    const products = await productModel.getAllProducts();
    res.json({ success: true, products });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Server error." });
  }
};

const getProductById = databaseAction(async (req, res) => {
  const data = await productModel.getProductWithReviews(req.params.id);
  if (!data.product) {
    return res.status(404).json({ success: false, message: "Product not found." });
  }
  res.json({ success: true, ...data, viewerId: req.user.id });
});

module.exports = { getAllProducts, getProductById };
