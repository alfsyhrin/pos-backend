const express = require('express');
const router = express.Router();
const ProductController = require('../controllers/product.controllers');
const authMiddleware = require('../middleware/auth');
const upload = require('../middleware/upload');
const checkTenant = require('../middleware/checkTenant'); // Tambahkan ini

// Create Product (protected route)
router.post('/:store_id/products', authMiddleware(['owner', 'admin']), checkTenant, ProductController.create);

// Get All Products for a Store (protected route)
router.get('/:store_id/products', authMiddleware(['owner', 'admin', 'cashier']), checkTenant, ProductController.getAll);

// Get Single Product by ID (protected route)
router.get('/:store_id/products/:id', authMiddleware(['owner', 'admin', 'cashier']), checkTenant, ProductController.getById);

// Update Product (protected route)
router.put('/:store_id/products/:id', authMiddleware(['owner', 'admin']), checkTenant, ProductController.update);

// Delete Product (protected route)
router.delete('/:store_id/products/:id', authMiddleware(['owner', 'admin']), checkTenant, ProductController.delete);

// Get Low Stock Products (protected route)
router.get('/:store_id/products/low-stock', authMiddleware(['owner', 'admin']), checkTenant, ProductController.getLowStock);

// **Add Endpoint for Statistics** (protected route)
router.get('/:store_id/products/stats', authMiddleware(['owner', 'admin']), checkTenant, ProductController.getStats);

// Find Product by Barcode (protected route)
router.get('/:store_id/products/barcode/:barcode', authMiddleware(['owner', 'admin', 'cashier']), checkTenant, ProductController.findByBarcode);

// Search products by name, sku, barcode, or category (protected route)
router.get('/:store_id/products/search', authMiddleware(['owner', 'admin', 'cashier']), checkTenant, ProductController.search);

// Endpoint upload gambar produk
router.post('/upload-image', authMiddleware(['owner', 'admin']), checkTenant, upload.single('image'), ProductController.uploadProductImage);

module.exports = router;
