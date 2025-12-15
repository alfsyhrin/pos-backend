const express = require('express');
const router = express.Router();
const AuthController = require('../controllers/auth.controllers');
const authMiddleware = require('../middleware/auth'); // HANYA INI

// Public routes
router.post('/login', AuthController.login);

// Protected routes (need token)
router.get('/profile', authMiddleware(), AuthController.getProfile);
router.get('/test-protected', authMiddleware(), AuthController.testProtected);

// Role-based protected routes
router.get('/admin-only', authMiddleware(['owner', 'admin']), (req, res) => {
    res.json({
        success: true,
        message: 'Hanya untuk Owner dan Admin',
        user: req.user
    });
});

router.get('/owner-only', authMiddleware(['owner']), (req, res) => {
    res.json({
        success: true,
        message: 'Hanya untuk Owner',
        user: req.user
    });
});

router.get('/cashier-only', authMiddleware(['cashier']), (req, res) => {
    res.json({
        success: true,
        message: 'Hanya untuk Kasir',
        user: req.user
    });
});

module.exports = router;