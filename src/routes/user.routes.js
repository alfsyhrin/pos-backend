const express = require('express');
const router = express.Router();
const UserController = require('../controllers/user.controllers');
const authMiddleware = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');

router.get('/stores/:store_id/users', authMiddleware(['owner', 'admin']), checkTenant, UserController.listByStore);
router.post('/stores/:store_id/users', authMiddleware(['owner', 'admin']), checkTenant, UserController.create);
router.put('/stores/:store_id/users/:id', authMiddleware(['owner', 'admin']), checkTenant, UserController.update);
router.delete('/stores/:store_id/users/:id', authMiddleware(['owner', 'admin']), checkTenant, UserController.delete);

module.exports = router;