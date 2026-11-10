const page = document.body.dataset.reviewPage;
const params = new URLSearchParams(location.search);
const reviewId = params.get("id");
const message = document.getElementById("message");
const form = document.getElementById("reviewForm");

function reviewCard(review, showActions) {
  const card = shopElement("article", undefined, "review-card");
  card.append(
    shopElement("h2", review.productName || "Product"),
    shopElement("p", `${review.rating}/5 · Updated ${new Date(review.updatedAt).toLocaleString()}`),
    shopElement("p", review.reviewText)
  );
  if (showActions) {
    const actions = shopElement("div", undefined, "review-actions");
    actions.append(
      shopLink("View product", `/product/retrieve/?id=${review.productId}`),
      shopLink("Edit", `/review/update/?id=${review.id}`),
      shopLink("Delete", `/review/delete/?id=${review.id}`)
    );
    card.append(actions);
  }
  return card;
}

async function loadReviewPage() {
  if (!localStorage.getItem("token")) {
    location.replace("/auth/login");
    return;
  }

  if (page === "create") {
    const { products } = await shopRequest("/api/product/retrieve/all");
    const select = document.getElementById("product");
    for (const product of products) select.add(new Option(product.name || "Product", product.id));
    if (products.some(product => String(product.id) === params.get("productId"))) {
      select.value = params.get("productId");
    }
  } else {
    const { reviews } = await shopRequest("/api/review");
    if (page === "retrieve/all") {
      document.getElementById("reviews").replaceChildren(...reviews.map(review => reviewCard(review, true)));
      const saved = { created: "Review posted.", updated: "Review updated.", deleted: "Review deleted." };
      const status = saved[params.get("status")];
      message.textContent = typeof status === "string" ? status : reviews.length ? "" : "You have no reviews yet.";
      return;
    }
    const review = reviews.find(item => String(item.id) === reviewId);
    if (!review) throw new Error("No matching review was found for your account.");
    if (page === "update") {
      document.getElementById("productName").textContent = review.productName;
      document.getElementById("rating").value = review.rating;
      document.getElementById("reviewText").value = review.reviewText;
    } else {
      document.getElementById("reviews").append(reviewCard(review, false));
    }
  }
  message.textContent = "";
  form.hidden = false;
}

form?.addEventListener("submit", async event => {
  event.preventDefault();
  const button = form.querySelector("button");
  button.disabled = true;
  message.textContent = "Saving…";
  try {
    if (page === "delete") {
      await shopRequest(`/api/review/${encodeURIComponent(reviewId)}`, { method: "DELETE" });
      location.assign("/review/retrieve/all/?status=deleted");
      return;
    }
    const body = {
      rating: Number(document.getElementById("rating").value),
      reviewText: document.getElementById("reviewText").value,
    };
    if (page === "create") {
      body.productId = Number(document.getElementById("product").value);
      await shopRequest("/api/review", { method: "POST", body });
    } else {
      await shopRequest(`/api/review/${encodeURIComponent(reviewId)}`, { method: "PATCH", body });
    }
    location.assign(`/review/retrieve/all/?status=${page === "create" ? "created" : "updated"}`);
  } catch (error) {
    message.textContent = error.message;
    button.disabled = false;
  }
});

loadReviewPage().catch(error => { message.textContent = error.message; });
