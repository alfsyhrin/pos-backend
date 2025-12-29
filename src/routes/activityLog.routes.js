const express = require('express');
const router = express.Router();
const ActivityLogController = require('../controllers/activityLog.controllers');
const authMiddleware = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');

router.get('/stores/:store_id/activity-logs', authMiddleware(['owner', 'admin']), checkTenant, ActivityLogController.list);

module.exports = router;