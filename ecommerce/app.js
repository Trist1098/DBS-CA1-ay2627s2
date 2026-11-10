require("dotenv").config();
const express = require("express");
const path = require("path");

const authRoutes = require("./routes/auth");
const productRoutes = require("./routes/products");
const reviewRoutes = require("./routes/reviews");
const commentRoutes = require("./routes/comments");
const adminRoutes = require("./routes/admin");
const { databaseErrors } = require("./middleware/databaseErrors");

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, "public")));

// API Routes
app.use("/api/auth", authRoutes);
app.use("/api/product", productRoutes);
app.use("/api/review", reviewRoutes);
app.use("/api/comment", commentRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api", databaseErrors);


// Serve HTML pages
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "auth", "login", "index.html"));
});
app.get("/auth/login", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "auth", "login", "index.html"));
});
app.get("/auth/register", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "auth", "register", "index.html"));
});
app.get("/product/retrieve", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "product", "retrieve", "index.html"));
});
app.get("/review/create", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "review", "create", "index.html"));
});
app.get("/review/retrieve/all", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "review", "retrieve", "all", "index.html"));
});
app.get("/review/update", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "review", "update", "index.html"));
});
app.get("/review/delete", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "review", "delete", "index.html"));
});
app.get("/admin/dashboard/salesOrderSummary", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "admin", "dashboard", "salesOrderSummary", "index.html"));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
