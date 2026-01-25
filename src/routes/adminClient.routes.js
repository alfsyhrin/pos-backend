const express = require('express');
const router = express.Router();
const AdminClientController = require('../controllers/adminClient.controllers');
const authMiddleware = require('../middleware/auth');
const adminAuth = require('../middleware/adminAuth');

router.post('/admin/clients', authMiddleware(['superadmin']), adminAuth, AdminClientController.create);
router.get('/admin/clients/stats', authMiddleware(['superadmin']), adminAuth, AdminClientController.stats);
router.get('/admin/clients', authMiddleware(['superadmin']), adminAuth, AdminClientController.list);
router.put('/admin/clients/:id', authMiddleware(['superadmin']), adminAuth, AdminClientController.update);
router.delete('/admin/clients/:id', authMiddleware(['superadmin']), adminAuth, AdminClientController.delete);
router.get('/admin/clients/:id', authMiddleware(['superadmin']), adminAuth, AdminClientController.detail);
// router.post('/admin/clients', ...) // (opsional, jika ingin trigger script dari API)

module.exports = router;