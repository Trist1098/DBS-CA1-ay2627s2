const { Pool } = require("pg");

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

// Patch 1: Log all queries before executing
const originalQuery = pool.query.bind(pool);
pool.query = (text, params, callback) => {
  console.log("Executing query:", typeof text === "object" ? text.text : text);
  return originalQuery(text, params, callback);
};

// Patch 2: Convert snake_case field names to camelCase
const toCamelCase = (str) =>
  str.replace(/_([a-z])/g, (_, letter) => letter.toUpperCase());

const transformKeys = (obj) => {
  if (Array.isArray(obj)) return obj.map(transformKeys);
  if (obj instanceof Date) return obj;
  if (obj !== null && typeof obj === "object") {
    return Object.fromEntries(
      Object.entries(obj).map(([k, v]) => [toCamelCase(k), transformKeys(v)])
    );
  }
  return obj;
};

const query = async (text, params) => {
  const result = await pool.query(text, params);
  result.rows = transformKeys(result.rows);
  return result;
};

module.exports = { query };
