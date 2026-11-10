const { query } = require("../config/database");

async function getSummary({ startDate, endDate, gender, productType, status, groupBy, sortBy }) {
  const result = await query(
    "SELECT public.get_sale_order_summary($1, $2, $3, $4, $5, $6, $7) AS summary",
    [startDate || null, endDate || null, gender || null, productType || null,
      status === "" ? null : status ?? "COMPLETED", groupBy ?? "member", sortBy ?? "order_date"]
  );
  return result.rows[0].summary;
}

module.exports = { getSummary };
