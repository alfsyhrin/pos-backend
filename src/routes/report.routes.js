const express = require('express');
const router = express.Router();
const ReportController = require('../controllers/report.controllers');
const authMiddleware = require('../middleware/auth');

// Summary laporan keuangan
router.get('/:store_id/reports/summary', authMiddleware(['owner', 'admin']), ReportController.summary);

// Laporan produk (top produk, stok menipis)
router.get('/:store_id/reports/products', authMiddleware(['owner', 'admin']), ReportController.products);

// Laporan kasir/karyawan
router.get('/:store_id/reports/cashiers', authMiddleware(['owner', 'admin']), ReportController.cashiers);

module.exports = router;