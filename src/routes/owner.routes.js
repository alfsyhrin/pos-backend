// src/routes/owner.routes.js
const express = require('express');
const router = express.Router();
const OwnerController = require('../controllers/owner.controllers');
const auth = require('../middleware/auth');

router.get('/owners/:id', auth(), OwnerController.getOwner);

module.exports = router;