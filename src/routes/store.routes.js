const express = require('express');
const router = express.Router();
const StoreController = require('../controllers/store.controllers');
const authMiddleware = require('../middleware/auth');

// ===== BASIC STORE ROUTES (WITH AUTH) =====

// Apply auth to all routes
router.use(authMiddleware());

// GET /api/stores - Get all stores for current owner
router.get('/', (req, res) => {
    res.json({
        success: true,
        message: 'Get all stores endpoint',
        user: req.user
    });
});

// GET /api/stores/search - Search stores
router.get('/search', (req, res) => {
    res.json({
        success: true,
        message: 'Search stores endpoint',
        query: req.query.q
    });
});

// GET /api/stores/:id - Get single store
router.get('/:id', (req, res) => {
    res.json({
        success: true,
        message: 'Get store by ID',
        store_id: req.params.id,
        user: req.user
    });
});

// ===== PROTECTED STORE ROUTES =====

// POST /api/stores - Create new store (owner only)
router.post('/', authMiddleware(['owner']), (req, res) => {
    res.json({
        success: true,
        message: 'Create store endpoint (owner only)',
        user: req.user,
        data: req.body
    });
});

// PUT /api/stores/:id - Update store (owner only)
router.put('/:id', authMiddleware(['owner']), (req, res) => {
    res.json({
        success: true,
        message: 'Update store endpoint (owner only)',
        store_id: req.params.id,
        user: req.user,
        data: req.body
    });
});

// DELETE /api/stores/:id - Delete store (owner only)
router.delete('/:id', authMiddleware(['owner']), (req, res) => {
    res.json({
        success: true,
        message: 'Delete store endpoint (owner only)',
        store_id: req.params.id,
        user: req.user
    });
});

// ===== STORE-SPECIFIC FEATURES =====

// Get store statistics
router.get('/:store_id/stats', 
    authMiddleware(['owner', 'admin']),
    (req, res) => {
        res.json({
            success: true,
            message: 'Store stats endpoint',
            store_id: req.params.store_id,
            user: req.user
        });
    }
);

// Create Receipt Template
router.post('/:store_id/receipt-template', 
    authMiddleware(['owner']), 
    (req, res) => {
        res.json({
            success: true,
            message: 'Receipt template created',
            store_id: req.params.store_id,
            user: req.user,
            data: req.body
        });
    }
);

// Get Receipt Template
router.get('/:store_id/receipt-template', 
    authMiddleware(['owner', 'admin']), 
    (req, res) => {
        res.json({
            success: true,
            message: 'Get receipt template',
            store_id: req.params.store_id,
            user: req.user
        });
    }
);

module.exports = router;