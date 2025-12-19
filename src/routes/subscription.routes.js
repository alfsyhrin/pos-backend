const express = require('express');
const router = express.Router();
const SubscriptionController = require('../controllers/subscription.controllers');
const auth = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');

router.get('/subscription', auth(), checkTenant, SubscriptionController.getSubscription);

module.exports = router;