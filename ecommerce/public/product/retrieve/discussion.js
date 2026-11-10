async function loadDiscussion(productId) {
  const container = document.getElementById("productDiscussion");
  container.hidden = false;
  if (!container.hasChildNodes()) container.textContent = "Loading product…";
  const { product, reviews, viewerId } = await shopRequest(
    `/api/product/retrieve/${encodeURIComponent(productId)}`
  );
  const refresh = () => loadDiscussion(productId);
  container.replaceChildren(
    shopLink("Back to products", "/product/retrieve/"),
    shopElement("h2", product.name || "Product"),
    shopElement("p", product.description || "No description available."),
    shopLink("Write a review", `/review/create/?productId=${product.id}`),
    shopElement("h2", "Reviews")
  );
  if (!reviews.length) container.append(shopElement("p", "No reviews yet."));
  for (const review of reviews) {
    const card = shopElement("article", undefined, "review-card");
    card.append(
      shopElement("h3", `${review.memberUsername} · ${review.rating}/5`),
      shopElement("p", review.reviewText),
      shopElement("small", `Updated ${new Date(review.updatedAt).toLocaleString()}`)
    );
    if (review.memberId !== viewerId) card.append(commentForm(review.id, null, refresh));
    card.append(commentThread(review, viewerId, refresh));
    container.append(card);
  }
}

function commentThread(review, viewerId, refresh) {
  const roots = shopElement("ul", undefined, "comment-list");
  const items = new Map();
  for (const comment of review.comments) {
    const item = shopElement("li", undefined, "comment-card");
    if (!comment.isDeleted) item.append(shopElement("strong", comment.memberUsername));
    item.append(shopElement("p", comment.commentText));

    if (!comment.isDeleted && comment.memberId !== viewerId) {
      item.append(commentForm(review.id, comment.id, refresh));
    }
    if (!comment.isDeleted && comment.memberId === viewerId) {
      const button = shopElement("button", "Delete comment");
      const status = shopElement("p");
      status.setAttribute("role", "status");
      button.addEventListener("click", async () => {
        button.disabled = true;
        try {
          await shopRequest(`/api/comment/${comment.id}`, { method: "DELETE" });
          await refresh();
        } catch (error) {
          status.textContent = error.message;
          button.disabled = false;
        }
      });
      item.append(button, status);
    }

    items.set(comment.id, item);
    const parent = items.get(comment.parentCommentId);
    if (parent) {
      let replies = parent.querySelector(":scope > .comment-list");
      if (!replies) {
        replies = shopElement("ul", undefined, "comment-list");
        parent.append(replies);
      }
      replies.append(item);
    } else {
      roots.append(item);
    }
  }
  return roots;
}

function commentForm(reviewId, parentCommentId, refresh) {
  const title = parentCommentId === null ? "Add a comment" : "Reply";
  const disclosure = shopElement("details");
  const form = shopElement("form");
  const label = shopElement("label", title);
  const text = shopElement("textarea");
  text.required = true;
  text.rows = 3;
  const submit = shopElement("button", "Post");
  const status = shopElement("p");
  status.setAttribute("role", "status");
  label.append(text);
  form.append(label, submit, status);
  disclosure.append(shopElement("summary", title), form);
  form.addEventListener("submit", async event => {
    event.preventDefault();
    submit.disabled = true;
    try {
      await shopRequest("/api/comment", {
        method: "POST",
        body: { reviewId, parentCommentId, commentText: text.value },
      });
      text.value = "";
      await refresh();
    } catch (error) {
      status.textContent = error.message;
      submit.disabled = false;
    }
  });
  return disclosure;
}
