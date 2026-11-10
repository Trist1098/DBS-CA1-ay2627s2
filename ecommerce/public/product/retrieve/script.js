let allProducts = [];

document.addEventListener("DOMContentLoaded", () => {
  const username = localStorage.getItem("username") || "User";
  document.getElementById("navUsername").textContent = username;

  const token = localStorage.getItem("token");
  if (!token) {
    window.location.href = "/auth/login";
    return;
  }
  const productId = new URLSearchParams(location.search).get("id");
  if (productId === null) {
    loadProducts();
  } else {
    for (const selector of [".filter-bar", ".stats-bar", "#productGrid"]) {
      document.querySelector(selector).hidden = true;
    }
    document.querySelector(".page-header h1").textContent = "Product discussion";
    document.querySelector(".page-header p").textContent = "Read reviews and join the conversation";
    loadDiscussion(productId).catch(error => showError(error.message));
  }
});

async function loadProducts() {
  const token = localStorage.getItem("token");
  try {
    const res = await fetch("/api/product/retrieve/all", {
      headers: { Authorization: `Bearer ${token}` },
    });
    const data = await res.json();
    if (data.success) {
      allProducts = data.products;
      renderProducts(allProducts);
    } else {
      showError(data.message);
    }
  } catch (err) {
    showError("Failed to load products. Please try again.");
  }
}

function renderProducts(products) {
  const grid = document.getElementById("productGrid");
  const countEl = document.getElementById("productCount");

  countEl.textContent = `Showing ${products.length} product${products.length !== 1 ? "s" : ""}`;

  if (products.length === 0) {
    grid.innerHTML = `
      <div class="no-results">
        <div class="no-results-icon">🔍</div>
        <h3>No products found</h3>
        <p>Try adjusting your search or filter.</p>
      </div>`;
    return;
  }

  grid.innerHTML = products.map((p) => {
    const stock = Number(p.stockQuantity);
    const stockClass = stock === 0 ? "out" : stock < 20 ? "low" : "";
    const stockLabel = stock === 0 ? "Out of Stock" : `${stock} in stock`;
    const escape = value => shopElement("span", value).innerHTML;
    return `
      <div class="product-card">
        <div class="product-image-wrapper">
          <div class="product-image-placeholder">🍶</div>
          <span class="product-type-badge">${escape(p.productType || "Bottle")}</span>
        </div>
        <div class="product-body">
          <div class="product-name">${escape(p.name || "Product")}</div>
          <div class="product-description">${escape(p.description || "No description available.")}</div>
          <div class="product-country">🌏 Made in ${escape(p.country || "N/A")}</div>
          <div class="product-meta">
            <span class="product-price">S$${parseFloat(p.unitPrice).toFixed(2)}</span>
            <span class="product-stock ${stockClass}">${stockLabel}</span>
          </div>
          <div class="review-actions">
            <a href="/product/retrieve/?id=${p.id}">Read reviews</a>
            <a href="/review/create/?productId=${p.id}">Write a review</a>
          </div>
        </div>
      </div>`;
  }).join("");
}

function filterProducts() {
  const search = document.getElementById("searchInput").value.toLowerCase();
  const category = document.getElementById("categoryFilter").value;
  const sort = document.getElementById("sortFilter").value;

  let filtered = allProducts.filter((p) => {
    const matchSearch =
      (p.name || "").toLowerCase().includes(search) ||
      (p.description && p.description.toLowerCase().includes(search));
    const matchCategory = !category || p.productType === category;
    return matchSearch && matchCategory;
  });

  if (sort === "price-asc") filtered.sort((a, b) => a.unitPrice - b.unitPrice);
  else if (sort === "price-desc") filtered.sort((a, b) => b.unitPrice - a.unitPrice);
  else if (sort === "name-asc") filtered.sort((a, b) => (a.name || "").localeCompare(b.name || ""));

  renderProducts(filtered);
}

function logout() {
  localStorage.clear();
  window.location.href = "/auth/login";
}

function showError(msg) {
  const el = document.getElementById("message");
  el.textContent = msg;
  el.className = "message error";
}
