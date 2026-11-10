async function shopRequest(url, { method = "GET", body } = {}) {
  const token = localStorage.getItem("token");
  const headers = { Authorization: `Bearer ${token}` };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const response = await fetch(url, { method, headers, body: JSON.stringify(body) });
  if (response.status === 401) window.location.replace("/auth/login");
  const data = await response.json();
  if (!response.ok) throw new Error(data.message || "The request could not be completed.");
  return data;
}

function shopElement(tag, text, className) {
  const element = document.createElement(tag);
  if (text !== undefined) element.textContent = text;
  if (className) element.className = className;
  return element;
}

function shopLink(text, href) {
  const link = shopElement("a", text);
  link.href = href;
  return link;
}
