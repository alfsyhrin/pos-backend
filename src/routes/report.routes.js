const express = require('express');
const router = express.Router();
const ReportController = require('../controllers/report.controllers');
const authMiddleware = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');

// Summary laporan keuangan
router.get('/:store_id/reports/summary', authMiddleware(['owner', 'admin']), checkTenant, ReportController.summary);

// Laporan produk (top produk, stok menipis)
router.get('/:store_id/reports/products', authMiddleware(['owner', 'admin']), checkTenant, ReportController.products);

// Laporan kasir/karyawan
router.get('/:store_id/reports/cashiers', authMiddleware(['owner', 'admin']), checkTenant, ReportController.cashiers);

module.exports = router;