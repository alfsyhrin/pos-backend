const express = require('express');
const router = express.Router();
const ReportController = require('../controllers/report.controllers');
const authMiddleware = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');

// Summary laporan keuangan
router.get('/:store_id/reports/summary', authMiddleware(['owner', 'admin']), checkTenant, ReportController.summary);

// Laporan produk (top produk, stok menipis)
router.get('/:store_id/reports/products', authMiddleware(['owner', 'admin']), checkTenant, ReportController.products);
router.get('/:store_id/reports/cashiers', authMiddleware(['owner', 'admin']), checkTenant, ReportController.cashiers);

// Generate & simpan laporan harian (manual/cron)
router.post('/:store_id/reports/daily/generate', authMiddleware(['owner', 'admin']), checkTenant, ReportController.generateDailyReport);

// Ambil laporan harian yang sudah disimpan
router.get('/:store_id/reports/daily', authMiddleware(['owner', 'admin']), checkTenant, ReportController.getDailyReport);

// List laporan harian dalam rentang waktu
router.get('/:store_id/reports/daily/list', authMiddleware(['owner', 'admin']), checkTenant, ReportController.listDailyReports);

// Laporan periodik (mingguan/bulanan/tahunan)
router.get('/:store_id/reports/periodic', authMiddleware(['owner', 'admin']), checkTenant, ReportController.periodicReport);

module.exports = router;