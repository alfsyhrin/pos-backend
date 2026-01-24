const express = require('express');
const router = express.Router();
const UserController = require('../controllers/user.controllers');
const authMiddleware = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');
const checkSubscription = require('../middleware/checkSubscription');

router.get('/stores/:store_id/users', authMiddleware(['owner', 'admin']), checkTenant, checkSubscription, UserController.listByStore);
router.post('/stores/:store_id/users', authMiddleware(['owner', 'admin']), checkTenant, checkSubscription, UserController.create);
router.put('/stores/:store_id/users/:id', authMiddleware(['owner', 'admin']), checkTenant, checkSubscription, UserController.update);
router.delete('/stores/:store_id/users/:id', authMiddleware(['owner', 'admin']), checkTenant, checkSubscription, UserController.delete);

module.exports = router;