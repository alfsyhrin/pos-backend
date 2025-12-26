const express = require('express');
const router = express.Router();
const TransactionController = require('../controllers/transaction.controllers');
const authMiddleware = require('../middleware/auth');
const checkTenant = require('../middleware/checkTenant');
const { createTransactionSchema, updateTransactionSchema } = require('../validations/transaction.validation');

// Create Transaction (protected route)
router.post(
  '/:store_id/transactions',
  authMiddleware(['admin', 'cashier']),
  checkTenant,
  (req, res, next) => {
    const { error } = createTransactionSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ success: false, message: error.details[0].message });
    }
    next();
  },
  TransactionController.create
);

// Complete Transaction (protected route)
router.post(
  '/:store_id/transactions/complete',
  authMiddleware(['admin', 'cashier']),
  checkTenant,
  TransactionController.completeTransaction
);

// Add Item to Cart (protected route)
// router.post(
//   '/:store_id/cart/add',
//   authMiddleware(['owner', 'admin', 'cashier']),
//   checkTenant,
//   TransactionController.addItemToCart
// );

// Get All Transactions for a Store (protected route)
router.get(
  '/:store_id/transactions',
  authMiddleware(['owner', 'admin', 'cashier']),
  checkTenant,
  TransactionController.getAll
);

// Get Transaction by ID (protected route)
router.get(
  '/:store_id/transactions/:id',
  authMiddleware(['owner', 'admin', 'cashier']),
  checkTenant,
  TransactionController.getById
);

// Update Transaction (protected route)
router.put(
  '/:store_id/transactions/:id',
  authMiddleware(['owner', 'admin']),
  checkTenant,
  (req, res, next) => {
    const { error } = updateTransactionSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ success: false, message: error.details[0].message });
    }
    next();
  },
  TransactionController.update
);

// Delete Transaction (protected route)
router.delete(
  '/:store_id/transactions/:transaction_id',
  authMiddleware(['owner', 'admin', 'cashier']),
  checkTenant,
  TransactionController.delete
);

module.exports = router;
