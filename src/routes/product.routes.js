const express = require('express');
const router = express.Router();
const ProductController = require('../controllers/product.controllers');  // Pastikan jalur relatifnya benar
const authMiddleware = require('../middleware/auth');

// Create Product (protected route)
router.post('/:store_id/products', authMiddleware(['owner', 'admin']), ProductController.create);

// Get All Products for a Store (protected route)
router.get('/:store_id/products', authMiddleware(['owner', 'admin', 'cashier']), ProductController.getAll);

// Get Single Product by ID (protected route)
router.get('/:store_id/products/:id', authMiddleware(['owner', 'admin', 'cashier']), ProductController.getById);

// Update Product (protected route)
router.put('/:store_id/products/:id', authMiddleware(['owner', 'admin']), ProductController.update);

// Delete Product (protected route)
router.delete('/:store_id/products/:id', authMiddleware(['owner', 'admin']), ProductController.delete);

// Get Low Stock Products (protected route)
router.get('/:store_id/products/low-stock', authMiddleware(['owner', 'admin']), ProductController.getLowStock);

// **Add Endpoint for Statistics** (protected route)
router.get('/:store_id/products/stats', authMiddleware(['owner', 'admin']), ProductController.getStats); // New Route

module.exports = router;
