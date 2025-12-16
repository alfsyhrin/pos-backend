const express = require('express');
const router = express.Router();
const UserController = require('../controllers/user.controllers');
const auth = require('../middleware/auth');

// List semua user (admin/kasir) di store tertentu
router.get('/stores/:store_id/users', auth, UserController.listByStore);

// Tambah user (admin/kasir) ke store
router.post('/stores/:store_id/users', auth(['owner', 'admin']), UserController.create);

// Update user
router.put('/users/:id', auth(['owner', 'admin']), UserController.update);

// Delete (nonaktifkan) user
router.delete('/users/:id', auth(['owner', 'admin']), UserController.delete);

module.exports = router;