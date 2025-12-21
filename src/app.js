const express = require('express');
const cors = require('cors');
const path = require('path');
const { pool } = require('./config/db'); // gunakan destructure agar jelas kita pakai promise pool

(async function init() {
  try {
    // contoh cek koneksi DB (promise API)
    const [rows] = await pool.query('SELECT 1 AS ok');
    console.log('DB CONNECTED', rows);
  } catch (err) {
    console.error('DB ERROR', err);
    process.exit(1);
  }
})();

// Import routes
const authRoutes = require('./routes/auth.routes');
const storeRoutes = require('./routes/store.routes');
const productRoutes = require('./routes/product.routes');
const transactionRoutes = require('./routes/transaction.routes'); // Tambahkan ini
const userRoutes = require('./routes/user.routes');
const reportRoutes = require('./routes/report.routes');
const backupRoutes = require('./routes/backup.routes');
const activityLogRoutes = require('./routes/activityLog.routes');
const subscriptionRoutes = require('./routes/subscription.routes');
const ownerRoutes = require('./routes/owner.routes');

const app = express();

// Middleware
app.use(cors({
    origin: '*', // Untuk development, allow semua origin
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept']
}));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/stores', storeRoutes);
app.use('/api/stores', transactionRoutes); // Tambahkan ini
app.use('/api/stores', reportRoutes);
app.use('/api/stores', productRoutes);
app.use('/api', userRoutes);
app.use('/api/backup', backupRoutes);
app.use('/api', activityLogRoutes);
app.use('/api', subscriptionRoutes);
app.use('/api', ownerRoutes);

// Default route
app.get('/', (req, res) => {
    res.json({
        message: 'Kasir Multi-Tenant API',
        version: '1.0.0',
        endpoints: {
            auth: {
                login: 'POST /api/auth/login',
                profile: 'GET /api/auth/profile',
                test_protected: 'GET /api/auth/test-protected',
                admin_only: 'GET /api/auth/admin-only',
                owner_only: 'GET /api/auth/owner-only',
                cashier_only: 'GET /api/auth/cashier-only'
            },
            stores: {
                get_all: 'GET /api/stores',
                get_single: 'GET /api/stores/:id',
                search: 'GET /api/stores/search?q=keyword',
                create: 'POST /api/stores',
                update: 'PUT /api/stores/:id',
                delete: 'DELETE /api/stores/:id',
                stats: 'GET /api/stores/stats',
                bulk_update: 'POST /api/stores/bulk-update'
            },
            products: {
                get_all: 'GET /api/stores/:store_id/products',
                get_single: 'GET /api/stores/:store_id/products/:id',
                search: 'GET /api/stores/:store_id/products/search?q=keyword',
                create: 'POST /api/stores/:store_id/products',
                update: 'PUT /api/stores/:store_id/products/:id',
                delete: 'DELETE /api/stores/:store_id/products/:id',
                stats: 'GET /api/stores/:store_id/products/stats',
                low_stock: 'GET /api/stores/:store_id/products/low-stock?threshold=10',
                bulk_update: 'POST /api/stores/:store_id/products/bulk-update',
                update_stock: 'PUT /api/stores/:store_id/products/:id/stock',
                upload_image: 'POST /api/stores/upload-image'
            }
        },
        documentation: 'API menggunakan JWT authentication. Include header: Authorization: Bearer <token>'
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        message: 'Endpoint tidak ditemukan',
        requested_url: req.originalUrl
    });
});

// Error handler
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        success: false,
        message: 'Terjadi kesalahan server',
        error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

module.exports = app;