const ProductModel = require('../models/product.model'); // Pastikan jalur relatifnya benar
const response = require('../utils/response'); // Pastikan jalur relatifnya benar


const ProductController = {
    // Create new product with discount logic
    async create(req, res) {
        try {
            const { store_id } = req.params;
            const {
                name, sku, price, stock, image_url, is_active,
                category, jenis_diskon, nilai_diskon,
                diskon_bundle_min_qty, diskon_bundle_value,
                buy_qty, free_qty, description
            } = req.body;

            // Pastikan semua field null jika tidak ada
            const productData = {
                store_id,
                name,
                sku,
                price,
                stock,
                category: category ?? null,
                description: description ?? null,
                image_url: image_url ?? null,
                is_active: is_active ?? 1,
                jenis_diskon: jenis_diskon ?? null,
                nilai_diskon: nilai_diskon ?? null,
                diskon_bundle_min_qty: diskon_bundle_min_qty ?? null,
                diskon_bundle_value: diskon_bundle_value ?? null,
                buy_qty: buy_qty ?? null,
                free_qty: free_qty ?? null
            };

            const productId = await ProductModel.create(productData);
            return response.created(res, { id: productId, ...productData }, 'Produk berhasil ditambahkan');
        } catch (error) {
            return response.error(res, error, 'Terjadi kesalahan saat membuat produk');
        }
    },


    // API untuk mendapatkan produk dengan diskon bundling (bila ada)
    async getAll(req, res) {
        try {
            const { store_id } = req.params;
            const products = await ProductModel.findAllByStore(store_id);

            // Memperhitungkan diskon bundling
            products.forEach(product => {
                if (product.diskon_bundle_min_qty && product.diskon_bundle_value) {
                    // Hitung diskon bundling jika jumlah produk yang dibeli sesuai dengan kriteria
                    if (product.stock >= product.diskon_bundle_min_qty) {
                        product.price -= product.diskon_bundle_value;  // Terapkan diskon bundling
                    }
                }
            });

            return response.success(res, products, 'Produk berhasil diambil');
        } catch (error) {
            console.error('Get all products error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil produk', 500, error);
        }
    },

    // Get single product and apply discount logic
    async getById(req, res) {
        try {
            const { store_id, id } = req.params;
            const storeId = parseInt(store_id);
            const productId = parseInt(id);

            if (isNaN(productId)) {
                return response.badRequest(res, 'ID produk tidak valid');
            }

            // Check access permission
            if (req.user.role === 'admin' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Hanya dapat mengakses produk di toko sendiri');
            }

            const product = await ProductModel.findById(productId, storeId);

            if (!product) {
                return response.notFound(res, 'Produk tidak ditemukan');
            }

            // Terapkan diskon jika ada
            if (product.jenis_diskon && product.nilai_diskon) {
                let finalPrice = product.price;
                if (product.jenis_diskon === 'percentage') {
                    finalPrice -= (finalPrice * product.nilai_diskon / 100);
                } else if (product.jenis_diskon === 'nominal') {
                    finalPrice -= product.nilai_diskon;
                }
                product.final_price = finalPrice;
            }

            return response.success(res, product, 'Data produk berhasil diambil');

        } catch (error) {
            console.error('Get product by ID error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil data produk', 500, error);
        }
    },

    // Update product with discount logic
    async update(req, res) {
        try {
            const { store_id, id } = req.params;
            const updateData = req.body;
            const storeId = parseInt(store_id);
            const productId = parseInt(id);

            if (isNaN(productId)) {
                return response.badRequest(res, 'ID produk tidak valid');
            }

            // Check permission
            if (req.user.role === 'cashier') {
                return response.forbidden(res, 'Kasir tidak dapat mengupdate produk');
            }

            if (req.user.role === 'admin' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Hanya dapat mengupdate produk di toko sendiri');
            }

            // Check if product exists
            const productExists = await ProductModel.existsInStore(productId, storeId);
            if (!productExists) {
                return response.notFound(res, 'Produk tidak ditemukan');
            }

            // Melanjutkan dengan update produk (semua field baru sudah di-handle di model)
            const isUpdated = await ProductModel.update(productId, storeId, updateData);

            if (!isUpdated) {
                return response.error(res, 'Gagal mengupdate produk', 400);
            }

            const updatedProduct = await ProductModel.findById(productId);
            return response.success(res, updatedProduct, 'Produk berhasil diupdate');

        } catch (error) {
            console.error('Update product error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengupdate produk', 500, error);
        }
    },

    // Delete product
    async delete(req, res) {
        try {
            const { store_id, id } = req.params;
            const storeId = parseInt(store_id);
            const productId = parseInt(id);

            if (isNaN(productId)) {
                return response.badRequest(res, 'ID produk tidak valid');
            }

            // Check permission
            if (req.user.role === 'cashier') {
                return response.forbidden(res, 'Kasir tidak dapat menghapus produk');
            }

            if (req.user.role === 'admin' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Hanya dapat menghapus produk di toko sendiri');
            }

            // Check if product exists
            const productExists = await ProductModel.existsInStore(productId, storeId);
            if (!productExists) {
                return response.notFound(res, 'Produk tidak ditemukan');
            }

            // Delete product
            const isDeleted = await ProductModel.delete(productId, storeId);

            if (!isDeleted) {
                return response.error(res, 'Gagal menghapus produk', 400);
            }

            return response.success(res, null, 'Produk berhasil dihapus');

        } catch (error) {
            console.error('Delete product error:', error);
            return response.error(res, 'Terjadi kesalahan saat menghapus produk', 500, error);
        }
    },

    async getLowStock(req, res) {
        try {
            const { store_id } = req.params;
            const { threshold = 10 } = req.query;  // Default threshold 10 jika tidak diberikan
            const storeId = parseInt(store_id);

            // Periksa akses pengguna
            if (req.user.role === 'admin' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Hanya dapat mengakses produk di toko sendiri');
            }

            // Ambil produk dengan stok rendah berdasarkan threshold
            const lowStockProducts = await ProductModel.getLowStock(storeId, parseInt(threshold));

            return response.success(res, {
                products: lowStockProducts,
                count: lowStockProducts.length,
                threshold: parseInt(threshold)
            }, 'Produk dengan stok rendah');
            
        } catch (error) {
            console.error('Get low stock products error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil produk stok rendah', 500, error);
        }
    },

    async updateStock(req, res) {
        try {
            const { store_id, id } = req.params;
            const { quantity_change } = req.body;
            const storeId = parseInt(store_id);
            const productId = parseInt(id);

            // Cek validitas ID produk dan perubahan kuantitas
            if (isNaN(productId)) {
                return response.badRequest(res, 'ID produk tidak valid');
            }

            if (!quantity_change || isNaN(parseInt(quantity_change))) {
                return response.badRequest(res, 'Perubahan kuantitas harus diisi dan berupa angka');
            }

            // Periksa akses pengguna
            if (req.user.role === 'cashier') {
                return response.forbidden(res, 'Kasir tidak dapat mengupdate stok produk');
            }

            if (req.user.role === 'admin' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Hanya dapat mengupdate stok produk di toko sendiri');
            }

            // Cek apakah produk ada
            const productExists = await ProductModel.existsInStore(productId, storeId);
            if (!productExists) {
                return response.notFound(res, 'Produk tidak ditemukan');
            }

            // Update stok produk
            const isUpdated = await ProductModel.updateStock(productId, storeId, parseInt(quantity_change));

            if (!isUpdated) {
                return response.error(res, 'Gagal mengupdate stok produk', 400);
            }

            // Ambil produk yang telah diperbarui
            const updatedProduct = await ProductModel.findById(productId);

            return response.success(res, updatedProduct, 'Stok produk berhasil diupdate');

        } catch (error) {
            console.error('Update product stock error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengupdate stok produk', 500, error);
        }
    },

    async getStats(req, res) {
        try {
            const { store_id } = req.params;  // Ambil store_id dari URL
            const storeId = parseInt(store_id);

            // Cek akses pengguna
            if (req.user.role === 'admin' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Hanya dapat mengakses statistik di toko sendiri');
            }

            // Ambil semua produk untuk statistik
            const allProducts = await ProductModel.findAllByStore(storeId);
            const activeProducts = allProducts.filter(p => p.is_active);
            const inactiveProducts = allProducts.filter(p => !p.is_active);

            // Hitung total nilai inventaris
            const totalInventoryValue = allProducts.reduce((sum, product) => {
                return sum + (product.price * product.stock);
            }, 0);

            // Ambil produk dengan stok rendah
            const lowStockProducts = allProducts.filter(p => p.stock <= 10 && p.is_active);

            // Kelompokkan berdasarkan status stok
            const stockStatus = {
                out_of_stock: allProducts.filter(p => p.stock === 0 && p.is_active).length,
                low_stock: lowStockProducts.length,
                in_stock: allProducts.filter(p => p.stock > 10 && p.is_active).length
            };

            const stats = {
                total_products: allProducts.length,
                active_products: activeProducts.length,
                inactive_products: inactiveProducts.length,
                total_inventory_value: totalInventoryValue,
                average_price: allProducts.length > 0 
                    ? allProducts.reduce((sum, p) => sum + p.price, 0) / allProducts.length 
                    : 0,
                stock_status: stockStatus,
                low_stock_items: lowStockProducts.map(p => ({
                    id: p.id,
                    name: p.name,
                    stock: p.stock,
                    price: p.price
                })),
                recent_products: allProducts
                    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
                    .slice(0, 5)
                    .map(p => ({
                        id: p.id,
                        name: p.name,
                        created_at: p.created_at
                    }))
            };

            return response.success(res, stats, 'Statistik produk berhasil diambil');

        } catch (error) {
            console.error('Get product stats error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil statistik produk', 500, error);
        }
    },

    async findByBarcode(req, res) {
        try {
            const { store_id, barcode } = req.params;
            const product = await ProductModel.findByBarcode(store_id, barcode);
            if (!product) {
                return response.notFound(res, 'Produk dengan barcode ini belum terdaftar');
            }
            return response.success(res, product, 'Produk ditemukan');
        } catch (error) {
            return response.error(res, error, 'Terjadi kesalahan saat mencari produk');
        }
    }
};

module.exports = ProductController;
