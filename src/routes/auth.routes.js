const express = require('express');
const router = express.Router();

const AuthController = require('../controllers/auth.controllers');
const authMiddleware = require('../middleware/auth');

// Public
router.post('/login', AuthController.login);

// Protected
router.get('/profile', authMiddleware(), AuthController.getProfile);
router.get('/test-protected', authMiddleware(), AuthController.testProtected);
router.post('/logout', authMiddleware(), AuthController.logout);

// Role based
router.get('/admin-only', authMiddleware(['owner','admin']), (req, res) => {
  res.json({ success: true });
});

router.get('/owner-only', authMiddleware(['owner']), (req, res) => {
  res.json({ success: true });
});

router.get('/cashier-only', authMiddleware(['cashier']), (req, res) => {
  res.json({ success: true });
});

module.exports = router;
