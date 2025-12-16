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

async function testConnection(retries = 3, delay = 5000) {
    for (let i = 0; i < retries; i++) {
        try {
            const connection = await pool.getConnection();
            console.log('✅ MySQL Database connected successfully');
            connection.release();
            return true;
        } catch (error) {
            console.error(`❌ MySQL connection attempt ${i + 1}/${retries} failed:`, error.message);
            if (i < retries - 1) await new Promise(r => setTimeout(r, delay));
        }
    }
    console.error('🚨 All connection attempts failed');
    return false;
}

if (process.env.NODE_ENV !== 'test') testConnection();

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

module.exports = pool;
module.exports.getTenantConnection = getTenantConnection;