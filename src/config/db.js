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

// Test connection dengan auto-retry
async function testConnection(retries = 3, delay = 5000) {
    for (let i = 0; i < retries; i++) {
        try {
            const connection = await pool.getConnection();
            console.log('✅ MySQL Database connected successfully');
            connection.release();
            return true;
        } catch (error) {
            console.error(`❌ MySQL connection attempt ${i + 1}/${retries} failed:`, error.message);
            
            if (i < retries - 1) {
                console.log(`⏳ Retrying in ${delay/1000} seconds...`);
                await new Promise(resolve => setTimeout(resolve, delay));
            } else {
                console.error('🚨 All connection attempts failed');
                // Jangan exit di production, biar restart
                return false;
            }
        }
    }
}

// Jalankan test koneksi
if (process.env.NODE_ENV !== 'test') {
    testConnection();
}

const getTenantConnection = async (dbName) => {
    if (!dbName) {
        throw new Error('Tenant database name (dbName) is required');
    }

    const conn = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: dbName,
    });

    // verify database selected / exists
    const [rows] = await conn.query('SELECT DATABASE() AS db');
    if (!rows[0] || !rows[0].db) {
        await conn.end();
        throw new Error(`Database "${dbName}" does not exist or could not be selected`);
    }

    return conn;
};

module.exports = pool;
module.exports.getTenantConnection = getTenantConnection;