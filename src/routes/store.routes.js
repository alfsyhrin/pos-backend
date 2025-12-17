const express = require('express');
const router = express.Router();
const StoreController = require('../controllers/store.controllers');
const authMiddleware = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');

// Semua route di bawah ini sudah dynamic DB (controller sudah pakai getTenantConnection)

// GET /api/stores - Get all stores for current owner
router.get('/', authMiddleware(['owner', 'admin']), checkTenant, StoreController.getAll);

// GET /api/stores/search - Search stores
router.get('/search', authMiddleware(['owner', 'admin']), checkTenant, StoreController.search);

// GET /api/stores/:id - Get single store
router.get('/:id', authMiddleware(['owner', 'admin']), checkTenant, StoreController.getById);

// POST /api/stores - Create new store (owner only)
router.post('/', authMiddleware(['owner']), checkTenant, StoreController.create);

// PUT /api/stores/:id - Update store (owner only)
router.put('/:id', authMiddleware(['owner']), checkTenant, StoreController.update);

// DELETE /api/stores/:id - Delete store (owner only)
router.delete('/:id', authMiddleware(['owner']), checkTenant, StoreController.delete);

// Get store statistics
router.get('/:store_id/stats', authMiddleware(['owner', 'admin']), checkTenant, StoreController.getStats);

// Create Receipt Template
router.post('/:store_id/receipt-template', authMiddleware(['owner', 'admin']), checkTenant, StoreController.createReceiptTemplate);

// Get Receipt Template
router.get('/:store_id/receipt-template', authMiddleware(['owner', 'admin']), checkTenant, StoreController.getReceiptTemplate);

// Info bisnis (owner only)
router.get('/business-profile', authMiddleware(['owner']), checkTenant, StoreController.getBusinessProfile);
router.put('/business-profile', authMiddleware(['owner']), checkTenant, StoreController.updateBusinessProfile);

module.exports = router;