// config/db.js
const mysql = require('mysql2/promise');
require('dotenv').config();

const createPool = () => {
    // Jika ada DATABASE_URL (untuk PlanetScale/Aiven)
    if (process.env.DATABASE_URL) {
        return mysql.createPool(process.env.DATABASE_URL);
    }
    
    // Local development
    return mysql.createPool({
        host: process.env.DB_HOST || 'localhost',
        port: process.env.DB_PORT || 3306,
        user: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || '',
        database: process.env.DB_NAME || 'kasir_multi_tenant',
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
        ssl: process.env.NODE_ENV === 'production' 
            ? { rejectUnauthorized: false }  // Untuk external DB SSL
            : undefined
    });
};

const pool = createPool();

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

module.exports = pool;