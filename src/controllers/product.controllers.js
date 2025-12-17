const ProductModel = require('../models/product.model');
const response = require('../utils/response');
const pool = require('../config/db'); // main DB (subscriptions, clients)
const { getTenantConnection } = require('../config/db');
const path = require('path');

const PRODUCT_LIMITS = {
  'Standard': 100,
  'Pro': 1000,
  'Eksklusif': 10000
};

const IMAGE_LIMITS = {
  'Standard': 0,
  'Pro': 100,
  'Eksklusif': 10000
};

const ProductController = {
  // Create new product with discount logic
  async create(req, res) {
    let conn;
    try {
      const { store_id } = req.params;
      const {
        name, sku, price, stock, image_url, is_active,
        category, jenis_diskon, nilai_diskon,
        diskon_bundle_min_qty, diskon_bundle_value,
        buy_qty, free_qty, description
      } = req.body;

      const owner_id = req.user.owner_id;
      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');

      conn = await getTenantConnection(dbName);

      // --- PEMBATASAN JUMLAH PRODUK BERDASARKAN PLAN (subscriptions di main DB) ---
      const [subs] = await pool.query('SELECT plan FROM subscriptions WHERE owner_id = ?', [owner_id]);
      const plan = subs[0]?.plan || 'Standard';
      const maxProduct = PRODUCT_LIMITS[plan];

      // Hitung jumlah produk di tenant
      const [productsCountRows] = await conn.query('SELECT COUNT(*) AS total FROM products WHERE owner_id = ?', [owner_id]);
      if (productsCountRows[0].total >= maxProduct) {
        return res.status(400).json({ message: 'Batas jumlah produk sudah tercapai untuk paket ini.' });
      }

      // --- PEMBATASAN PRODUK BERGAMBAR ---
      if (image_url) {
        const maxImage = IMAGE_LIMITS[plan];
        const [count] = await conn.query(
          'SELECT COUNT(*) AS total FROM products WHERE owner_id = ? AND image_url IS NOT NULL AND image_url != ""',
          [owner_id]
        );
        if (count[0].total >= maxImage) {
          return res.status(400).json({ message: 'Batas produk bergambar sudah tercapai untuk paket ini.' });
        }
      }

      const productData = {
        owner_id,
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

      const productId = await ProductModel.create(conn, productData);
      return response.created(res, { id: productId, ...productData }, 'Produk berhasil ditambahkan');
    } catch (error) {
      return response.error(res, error, 'Terjadi kesalahan saat membuat produk');
    } finally {
      if (conn) await conn.end();
    }
  },

  // Get all products (tenant)
  async getAll(req, res) {
    let conn;
    try {
      const { store_id } = req.params;
      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');

      conn = await getTenantConnection(dbName);
      const products = await ProductModel.findAllByStore(conn, store_id);

      products.forEach(product => {
        if (product.diskon_bundle_min_qty && product.diskon_bundle_value) {
          if (product.stock >= product.diskon_bundle_min_qty) {
            product.price -= product.diskon_bundle_value;
          }
        }
      });

      return response.success(res, products, 'Produk berhasil diambil');
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat mengambil produk', 500, error);
    } finally {
      if (conn) await conn.end();
    }
  },

  // Get single product
  async getById(req, res) {
    let conn;
    try {
      const { store_id, id } = req.params;
      const storeId = parseInt(store_id, 10);
      const productId = parseInt(id, 10);
      if (isNaN(productId)) return response.badRequest(res, 'ID produk tidak valid');

      if (req.user.role === 'admin' && req.user.store_id !== storeId) return response.forbidden(res, 'Hanya dapat mengakses produk di toko sendiri');

      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
      conn = await getTenantConnection(dbName);

      const product = await ProductModel.findById(conn, productId, storeId);
      if (!product) return response.notFound(res, 'Produk tidak ditemukan');

      if (product.jenis_diskon && product.nilai_diskon) {
        let finalPrice = product.price;
        if (product.jenis_diskon === 'percentage') finalPrice -= (finalPrice * product.nilai_diskon / 100);
        else if (product.jenis_diskon === 'nominal') finalPrice -= product.nilai_diskon;
        product.final_price = finalPrice;
      }

      return response.success(res, product, 'Data produk berhasil diambil');
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat mengambil data produk', 500, error);
    } finally {
      if (conn) await conn.end();
    }
  },

  // Update product
  async update(req, res) {
    let conn;
    try {
      const { store_id, id } = req.params;
      const storeId = parseInt(store_id, 10);
      const productId = parseInt(id, 10);
      const updateData = req.body;
      if (isNaN(productId)) return response.badRequest(res, 'ID produk tidak valid');

      if (req.user.role === 'cashier') return response.forbidden(res, 'Kasir tidak dapat mengupdate produk');
      if (req.user.role === 'admin' && req.user.store_id !== storeId) return response.forbidden(res, 'Hanya dapat mengupdate produk di toko sendiri');

      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
      conn = await getTenantConnection(dbName);

      const exists = await ProductModel.existsInStore(conn, productId, storeId);
      if (!exists) return response.notFound(res, 'Produk tidak ditemukan');

      const isUpdated = await ProductModel.update(conn, productId, storeId, updateData);
      if (!isUpdated) return response.error(res, 'Gagal mengupdate produk', 400);

      const updatedProduct = await ProductModel.findById(conn, productId, storeId);
      return response.success(res, updatedProduct, 'Produk berhasil diupdate');
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat mengupdate produk', 500, error);
    } finally {
      if (conn) await conn.end();
    }
  },

  // Delete product
  async delete(req, res) {
    let conn;
    try {
      const { store_id, id } = req.params;
      const storeId = parseInt(store_id, 10);
      const productId = parseInt(id, 10);
      if (isNaN(productId)) return response.badRequest(res, 'ID produk tidak valid');

      if (req.user.role === 'cashier') return response.forbidden(res, 'Kasir tidak dapat menghapus produk');
      if (req.user.role === 'admin' && req.user.store_id !== storeId) return response.forbidden(res, 'Hanya dapat menghapus produk di toko sendiri');

      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
      conn = await getTenantConnection(dbName);

      const exists = await ProductModel.existsInStore(conn, productId, storeId);
      if (!exists) return response.notFound(res, 'Produk tidak ditemukan');

      const isDeleted = await ProductModel.delete(conn, productId, storeId);
      if (!isDeleted) return response.error(res, 'Gagal menghapus produk', 400);

      return response.success(res, null, 'Produk berhasil dihapus');
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat menghapus produk', 500, error);
    } finally {
      if (conn) await conn.end();
    }
  },

  async getLowStock(req, res) {
    let conn;
    try {
      const { store_id } = req.params;
      const threshold = parseInt(req.query.threshold || '10', 10);
      const storeId = parseInt(store_id, 10);

      if (req.user.role === 'admin' && req.user.store_id !== storeId) return response.forbidden(res, 'Hanya dapat mengakses produk di toko sendiri');

      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
      conn = await getTenantConnection(dbName);

      const lowStockProducts = await ProductModel.getLowStock(conn, storeId, threshold);
      return response.success(res, { products: lowStockProducts, count: lowStockProducts.length, threshold }, 'Produk dengan stok rendah');
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat mengambil produk stok rendah', 500, error);
    } finally {
      if (conn) await conn.end();
    }
  },

  async updateStock(req, res) {
    let conn;
    try {
      const { store_id, id } = req.params;
      const { quantity_change } = req.body;
      const storeId = parseInt(store_id, 10);
      const productId = parseInt(id, 10);

      if (isNaN(productId)) return response.badRequest(res, 'ID produk tidak valid');
      if (!quantity_change || isNaN(parseInt(quantity_change))) return response.badRequest(res, 'Perubahan kuantitas harus diisi dan berupa angka');

      if (req.user.role === 'cashier') return response.forbidden(res, 'Kasir tidak dapat mengupdate stok produk');
      if (req.user.role === 'admin' && req.user.store_id !== storeId) return response.forbidden(res, 'Hanya dapat mengupdate stok produk di toko sendiri');

      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
      conn = await getTenantConnection(dbName);

      const exists = await ProductModel.existsInStore(conn, productId, storeId);
      if (!exists) return response.notFound(res, 'Produk tidak ditemukan');

      const isUpdated = await ProductModel.updateStock(conn, productId, parseInt(quantity_change, 10));
      if (!isUpdated) return response.error(res, 'Gagal mengupdate stok produk', 400);

      const updatedProduct = await ProductModel.findById(conn, productId, storeId);
      return response.success(res, updatedProduct, 'Stok produk berhasil diupdate');
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat mengupdate stok produk', 500, error);
    } finally {
      if (conn) await conn.end();
    }
  },

  async getStats(req, res) {
    let conn;
    try {
      const { store_id } = req.params;
      const storeId = parseInt(store_id, 10);

      if (req.user.role === 'admin' && req.user.store_id !== storeId) return response.forbidden(res, 'Hanya dapat mengakses statistik di toko sendiri');

      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
      conn = await getTenantConnection(dbName);

      const allProducts = await ProductModel.findAllByStore(conn, storeId);
      const activeProducts = allProducts.filter(p => p.is_active);
      const inactiveProducts = allProducts.filter(p => !p.is_active);
      const totalInventoryValue = allProducts.reduce((sum, p) => sum + (p.price * p.stock), 0);
      const lowStockProducts = allProducts.filter(p => p.stock <= 10 && p.is_active);

      const stats = {
        total_products: allProducts.length,
        active_products: activeProducts.length,
        inactive_products: inactiveProducts.length,
        total_inventory_value: totalInventoryValue,
        average_price: allProducts.length > 0 ? allProducts.reduce((sum, p) => sum + p.price, 0) / allProducts.length : 0,
        stock_status: {
          out_of_stock: allProducts.filter(p => p.stock === 0 && p.is_active).length,
          low_stock: lowStockProducts.length,
          in_stock: allProducts.filter(p => p.stock > 10 && p.is_active).length
        },
        low_stock_items: lowStockProducts.map(p => ({ id: p.id, name: p.name, stock: p.stock, price: p.price })),
        recent_products: allProducts.sort((a,b)=> new Date(b.created_at)-new Date(a.created_at)).slice(0,5).map(p=>({ id: p.id, name: p.name, created_at: p.created_at }))
      };

      return response.success(res, stats, 'Statistik produk berhasil diambil');
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat mengambil statistik produk', 500, error);
    } finally {
      if (conn) await conn.end();
    }
  },

  async findByBarcode(req, res) {
    let conn;
    try {
      const { store_id, barcode } = req.params;
      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
      conn = await getTenantConnection(dbName);

      const product = await ProductModel.findByBarcode(conn, store_id, barcode);
      if (!product) return response.notFound(res, 'Produk dengan barcode ini belum terdaftar');
      return response.success(res, product, 'Produk ditemukan');
    } catch (error) {
      return response.error(res, error, 'Terjadi kesalahan saat mencari produk');
    } finally {
      if (conn) await conn.end();
    }
  },

  async uploadProductImage(req, res) {
    let conn;
    try {
      const owner_id = req.user.owner_id;
      const { product_id } = req.body;
      if (!req.file) return response.badRequest(res, 'File gambar tidak ditemukan');

      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
      conn = await getTenantConnection(dbName);

      const imagePath = path.relative(path.join(__dirname, '../../'), req.file.path).replace(/\\/g, '/');
      await conn.execute('UPDATE products SET image_url = ? WHERE id = ?', [imagePath, product_id]);

      return response.success(res, { image_url: imagePath }, 'Gambar produk berhasil diupload');
    } catch (error) {
      return response.error(res, 'Gagal upload gambar', 500, error);
    } finally {
      if (conn) await conn.end();
    }
  }
};

module.exports = ProductController;
