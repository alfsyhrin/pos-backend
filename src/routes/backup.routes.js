const express = require('express');
const router = express.Router();
const backupController = require('../controllers/backup.controllers');
const authMiddleware = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');
const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() }); // untuk upload file JSON

router.get('/export', authMiddleware(), checkTenant, backupController.exportData);
router.post('/import', authMiddleware(), checkTenant, upload.single('file'), backupController.importData);

module.exports = router;