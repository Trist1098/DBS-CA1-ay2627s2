const filters = document.getElementById("summaryFilters");
const message = document.getElementById("message");
const results = document.getElementById("summaryTableBody");
const exportButton = document.getElementById("exportSummary");
const currency = new Intl.NumberFormat("en-SG", { style: "currency", currency: "SGD", currencyDisplay: "code" });
const columns = ["Group", "Matching orders", "Customers", "Units", "Matching item value",
  "Completed item value", "Average completed order value", "Latest order"];
let currentSummary;

function amount(value) {
  return value === null ? "—" : currency.format(value);
}

function groupValues(group) {
  return [group.groupName, group.orderCount, group.customerCount, group.units, group.itemValue,
    group.completedItemValue, group.avgCompletedOrderValue, group.latestOrderAt];
}

function renderSummary(summary) {
  const { metrics, groups } = summary;
  const cards = {
    statTotalOrders: metrics.orderCount,
    statTotalRevenue: amount(metrics.completedItemValue),
    statTotalCustomers: metrics.customerCount,
    statAvgOrder: amount(metrics.avgCompletedOrderValue),
  };
  for (const [id, value] of Object.entries(cards)) document.getElementById(id).textContent = value;

  document.getElementById("resultCount").textContent = `${groups.length} ${summary.groupBy} groups`;
  const rows = groups.map(group => {
    const row = shopElement("tr");
    const values = groupValues(group);
    for (const [index, value] of values.entries()) {
      const display = index >= 4 && index <= 6 ? amount(value) : index === 7 ? value.replace("T", " ") : value;
      row.append(shopElement("td", display));
    }
    return row;
  });
  results.replaceChildren(...rows);
  if (!rows.length) {
    const row = shopElement("tr");
    const cell = shopElement("td", "No orders matched these filters.");
    cell.colSpan = columns.length;
    row.append(cell);
    results.append(row);
  }

  const chart = document.getElementById("summaryChart");
  chart.hidden = groups.length === 0;
  const visible = groups.slice(0, 8);
  const maxValue = Math.max(1, ...visible.map(group => Number(group.itemValue)));
  const bars = visible.map(group => {
    const item = shopElement("li");
    const bar = shopElement("meter");
    bar.min = 0;
    bar.max = maxValue;
    bar.value = Math.max(0, group.itemValue);
    bar.setAttribute("aria-label", group.groupName + " matching item value");
    item.append(shopElement("span", group.groupName), bar, shopElement("span", amount(group.itemValue)));
    return item;
  });
  chart.querySelector("ul").replaceChildren(...bars);
}

async function loadSummary() {
  const params = new URLSearchParams(new FormData(filters));
  const searchButton = filters.querySelector('[type="submit"]');
  const resetButton = filters.querySelector('[type="reset"]');
  if (searchButton.disabled) return;
  searchButton.disabled = true;
  resetButton.disabled = true;
  exportButton.disabled = true;
  message.textContent = "Loading sales summary…";
  message.className = "message";
  try {
    const { summary } = await shopRequest("/api/admin/sales-summary?" + params);
    renderSummary(summary);
    currentSummary = summary;
    message.className = "message hidden";
    message.textContent = "";
  } catch (error) {
    message.textContent = currentSummary
      ? error.message + " Showing the previous successful results."
      : error.message;
    message.className = "message error";
  } finally {
    searchButton.disabled = false;
    resetButton.disabled = false;
    exportButton.disabled = !currentSummary?.groups.length;
  }
}

function csvCell(value) {
  const text = String(value ?? "");
  const safe = typeof value === "string" && /^\s*[=+@\-]/.test(text) ? "'" + text : text;
  return '"' + safe.replaceAll('"', '""') + '"';
}

function exportCSV() {
  if (!currentSummary?.groups.length) return;
  const rows = [columns, ...currentSummary.groups.map(groupValues)];
  const csv = rows.map(row => row.map(csvCell).join(",")).join("\r\n");
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  const link = shopLink("Download sales summary", url);
  link.download = "sales-summary.csv";
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 0);
}

function logout() {
  localStorage.clear();
  window.location.href = "/auth/login";
}

if (!localStorage.getItem("token") || localStorage.getItem("role") !== "1") {
  location.replace("/auth/login");
} else {
  document.getElementById("navUsername").textContent = localStorage.getItem("username") || "Admin";
  filters.addEventListener("submit", event => {
    event.preventDefault();
    loadSummary();
  });
  filters.addEventListener("reset", () => {
    if (!filters.querySelector('[type="submit"]').disabled) setTimeout(loadSummary, 0);
  });
  exportButton.addEventListener("click", exportCSV);
  loadSummary();
}
