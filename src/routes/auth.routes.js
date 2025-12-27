const express = require('express');
const router = express.Router();

const AuthController = require('../controllers/auth.controllers');
const authMiddleware = require('../middleware/auth');

/* =====================================================
   PUBLIC ROUTES
===================================================== */

// Login (owner / admin / cashier)
router.post('/login', AuthController.login);

/* =====================================================
   PROTECTED ROUTES (BUTUH TOKEN)
===================================================== */

// Ambil profile user dari token
router.get('/profile', authMiddleware(), AuthController.getProfile);

// Test token valid
router.get('/test-protected', authMiddleware(), AuthController.testProtected);

// Logout (client-side token invalidate)
router.post('/logout', authMiddleware(), AuthController.logout);

/* =====================================================
   ROLE-BASED ROUTES
===================================================== */

// Owner & Admin
router.get(
  '/admin-only',
  authMiddleware(['owner', 'admin']),
  (req, res) => {
    res.json({
      success: true,
      message: 'Akses Owner dan Admin',
      user: req.user
    });
  }
);

// Owner saja
router.get(
  '/owner-only',
  authMiddleware(['owner']),
  (req, res) => {
    res.json({
      success: true,
      message: 'Akses khusus Owner',
      user: req.user
    });
  }
);

// Kasir saja
router.get(
  '/cashier-only',
  authMiddleware(['cashier']),
  (req, res) => {
    res.json({
      success: true,
      message: 'Akses khusus Kasir',
      user: req.user
    });
  }
);

module.exports = router;
