// config/db.js
const mysql = require('mysql2/promise');
require('dotenv').config();

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
});

const getTenantConnection = async (dbName) => {
    if (!dbName) throw new Error('Tenant database name (dbName) is required');
    const conn = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: dbName,
    });
    const [rows] = await conn.query('SELECT DATABASE() AS db');
    if (!rows[0] || !rows[0].db) {
        await conn.end();
        throw new Error(`Database "${dbName}" does not exist or could not be selected`);
    }
    return conn;
};

const withTenantConnection = async (dbName, fn) => {
    const conn = await getTenantConnection(dbName);
    try {
        return await fn(conn);5
    } finally {
        await conn.end();
    }
};

const getMainConnection = async () => {
    return await pool.getConnection();
};

module.exports = pool;
module.exports.getTenantConnection = getTenantConnection;
module.exports.withTenantConnection = withTenantConnection;
module.exports.getMainConnection = getMainConnection;

// Untuk koneksi dari pool (getMainConnection)
if (conn) conn.release();

// Untuk koneksi tenant (getTenantConnection)
if (conn) await conn.end();