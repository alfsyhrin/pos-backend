const ProductModel = require('../models/product.model');
const ActivityLogModel = require('../models/activityLog.model');
const response = require('../utils/response');
const pool = require('../config/db');
const { getTenantConnection, databaseExists } = require('../config/db'); // pastikan import databaseExists
const path = require('path');
const { getPackageLimit, getRoleLimit } = require('../config/package_limits');

// const PRODUCT_LIMITS = {
  // 'Standard': 100,
  // 'Pro': 1000,
  // 'Eksklusif': 10000
// };


// const IMAGE_LIMITS = {
  // 'Standard': 0,
  // 'Pro': 100,
  // 'Eksklusif': 10000
// };

function sanitizeJenisDiskon(val) {
  if (typeof val !== 'string') return null;
  const allowed = ['percentage', 'nominal', 'buyxgety'];
  return allowed.includes(val) ? val : null;
}

function mapPromoType(val) {
  if (val === 'percent') return 'percentage';
  if (val === 'nominal') return 'nominal';
  // Mapping semua variasi buy x get y dari frontend ke 'buyxgety'
  if (
    val === 'buyxgety' ||
    val === 'buy_get' ||
    val === 'buyget' ||
    val === 'buyXgetY' ||
    val === 'buyXGetY'
  ) return 'buyxgety';
  return val;
}

const ProductController = {
  // Create new product with discount logic
// Create new product with discount logic
async create(req, res) {
  let conn;
  let isTenant = false;
  try {
    const { store_id } = req.params;

    // =======================
    // NORMALISASI FIELD FLUTTER
    // =======================
    if (req.body.sellPrice !== undefined) req.body.price = req.body.sellPrice;
    if (req.body.costPrice !== undefined) req.body.cost_price = req.body.costPrice;

    // Mapping promoType dari frontend ke value database
    if (req.body.promoType !== undefined) req.body.promoType = mapPromoType(req.body.promoType);
    if (req.body.promoType !== undefined) req.body.jenis_diskon = req.body.promoType;

    if (req.body.jenis_diskon === 'buyxgety') {
      req.body.nilai_diskon = null;
      if (req.body.buyQty !== undefined) req.body.buy_qty = req.body.buyQty;
      if (req.body.freeQty !== undefined) req.body.free_qty = req.body.freeQty;
    } else {
      if (req.body.promoPercent !== undefined) req.body.nilai_diskon = req.body.promoPercent;
      if (req.body.promoAmount !== undefined) req.body.nilai_diskon = req.body.promoAmount;
      req.body.buy_qty = null;
      req.body.free_qty = null;
    }

    if (req.body.jenis_diskon !== undefined) req.body.jenis_diskon = sanitizeJenisDiskon(req.body.jenis_diskon);

    const {
      name, sku, barcode, price, cost_price, stock, is_active,
      category, description,
      promoType, promoPercent, promoAmount, buyQty, freeQty, bundleQty, bundleTotalPrice,
      jenis_diskon, nilai_diskon, diskon_bundle_min_qty, diskon_bundle_value, buy_qty, free_qty
    } = req.body;

    // Ambil path gambar dari upload jika ada
    let image_url = null;
    if (req.file) {
      image_url = path.relative(path.join(__dirname, '../../'), req.file.path).replace(/\\/g, '/');
    } else if (req.body.image_url) {
      image_url = req.body.image_url;
    }

    const owner_id = req.user.owner_id;
    const dbName = req.user.db_name;
    if (dbName) {
      const exists = await databaseExists(dbName);
      if (exists) {
        conn = await getTenantConnection(dbName);
        isTenant = true;
      }
    }
    if (!conn) {
      conn = pool;
    }

    // Validasi barcode unik per store
    if (barcode) {
      const existing = await ProductModel.findByBarcode(conn, store_id, barcode);
      if (existing) return response.badRequest(res, 'Barcode sudah terdaftar di toko ini');
    }

    // Mapping promo/diskon
    const promoMapping = {
      jenis_diskon: req.body.jenis_diskon || null,
      nilai_diskon: req.body.nilai_diskon || null,
      buy_qty: buyQty || buy_qty || null,
      free_qty: freeQty || free_qty || null,
      diskon_bundle_min_qty: bundleQty || diskon_bundle_min_qty || null,
      diskon_bundle_value: bundleTotalPrice || diskon_bundle_value || null
    };

    // Data produk
    const productData = {
      owner_id,
      store_id,
      name,
      sku: sku || null,
      barcode: barcode || null,
      price: price || 0,
      cost_price: cost_price || 0,
      stock: stock || 0,
      category: category ?? null,
      description: description ?? null,
      image_url: image_url ?? null,
      is_active: is_active ?? 1,
      ...promoMapping
    };

    // Cek limit produk berdasarkan paket
    const plan = req.user.plan;
    const productLimit = getPackageLimit(plan, 'product_limit');
    const totalProduct = await ProductModel.countByStore(conn, store_id);
    if (totalProduct >= productLimit) {
      return response.badRequest(res, `Batas produk (${productLimit}) untuk paket ${plan} telah tercapai`);
    }

    const productId = await ProductModel.create(conn, productData);
    const created = await ProductModel.findById(conn, productId, store_id);

    // Mapping response agar cocok dengan frontend
    const mapped = {
      id: created.id,
      name: created.name,
      sku: created.sku,
      barcode: created.barcode,
      costPrice: Number(created.cost_price || 0),
      sellPrice: Number(created.price || 0),
      stock: created.stock,
      category: created.category,
      description: created.description,
      imageUrl: created.image_url,
      promoType: created.jenis_diskon,
      promoPercent: Number(created.nilai_diskon || 0),
      promoAmount: Number(created.nilai_diskon || 0),
      buyQty: created.buy_qty,
      freeQty: created.free_qty,
      bundleQty: created.diskon_bundle_min_qty,
      bundleTotalPrice: Number(created.diskon_bundle_value || 0),
      isActive: created.is_active,
      createdAt: created.created_at,
      updatedAt: created.updated_at
    };

    // Log aktivitas
    await ActivityLogModel.create(conn, {
      user_id: req.user.id,
      store_id: store_id,
      action: 'add_product',
      detail: `Tambah produk: ${name}`
    });

    return response.created(res, mapped, 'Produk berhasil ditambahkan');
  } catch (error) {
    console.error("❌ ERROR CREATE PRODUK:", error);
    return response.error(res, error, 'Terjadi kesalahan saat membuat produk');
  } finally {
    if (conn && isTenant) await conn.end();
  }
},

  // Get all products (tenant)
  async getAll(req, res) {
    let conn;
    let isTenant = false;
    try {
      const { store_id } = req.params;
      const dbName = req.user.db_name;
      if (dbName) {
        const exists = await databaseExists(dbName);
        if (exists) {
          conn = await getTenantConnection(dbName);
          isTenant = true;
        }
      }
      // Jika tidak ada tenant DB, fallback ke main DB
      if (!conn) {
        conn = pool;
      }

      const products = await ProductModel.findAllByStore(conn, store_id);

      // Mapping agar cocok dengan frontend
      const mapped = products.map(product => ({
        id: product.id,
        name: product.name,
        sku: product.sku,
        barcode: product.barcode,
        costPrice: Number(product.cost_price || 0),
        sellPrice: Number(product.price || 0),
        stock: product.stock,
        category: product.category,
        description: product.description,
        imageUrl: product.image_url,
        promoType: product.jenis_diskon,
        promoPercent: Number(product.nilai_diskon || 0),
        promoAmount: Number(product.nilai_diskon || 0),
        buyQty: product.buy_qty,
        freeQty: product.free_qty,
        bundleQty: product.diskon_bundle_min_qty,
        bundleTotalPrice: Number(product.diskon_bundle_value || 0),
        isActive: product.is_active,
        createdAt: product.created_at,
        updatedAt: product.updated_at
      }));

      return response.success(res, mapped, 'Produk berhasil diambil');
    } catch (error) {
      console.error('GetAll Products Error:', error);
      return response.error(res, 'Terjadi kesalahan saat mengambil produk', 500, error);
    } finally {
      if (conn && isTenant) await conn.end();
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

      const exists = await databaseExists(dbName);
      if (!exists) return response.badRequest(res, `Database tenant (${dbName}) tidak ditemukan. Silakan hubungi admin.`);

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

async update(req, res) {
  let conn;
  try {
    const { store_id, id } = req.params;
    const storeId = parseInt(store_id, 10);
    const productId = parseInt(id, 10);

    if (isNaN(productId)) return response.badRequest(res, 'ID produk tidak valid');
    if (req.user.role === 'cashier') return response.forbidden(res, 'Kasir tidak dapat mengupdate produk');
    if (req.user.role === 'admin' && req.user.store_id !== storeId) return response.forbidden(res, 'Hanya dapat mengupdate produk di toko sendiri');

    const dbName = req.user.db_name;
    if (!dbName) return response.badRequest(res, 'Tenant DB not available in token.');
    const exists = await databaseExists(dbName);
    if (!exists) return response.badRequest(res, `Database tenant (${dbName}) tidak ditemukan. Silakan hubungi admin.`);
    conn = await getTenantConnection(dbName);

    const product = await ProductModel.findById(conn, productId, storeId);
    if (!product) return response.notFound(res, 'Produk tidak ditemukan');

    // =======================
    // NORMALISASI FIELD FLUTTER
    // =======================
    if (req.body.sellPrice !== undefined) req.body.price = req.body.sellPrice;
    if (req.body.costPrice !== undefined) req.body.cost_price = req.body.costPrice;

    // Mapping promoType dari frontend ke value database
    if (req.body.promoType !== undefined) req.body.promoType = mapPromoType(req.body.promoType);
    if (req.body.promoType !== undefined) req.body.jenis_diskon = req.body.promoType;

    if (req.body.jenis_diskon === 'buyxgety') {
      req.body.nilai_diskon = null;
      if (req.body.buyQty !== undefined) req.body.buy_qty = req.body.buyQty;
      if (req.body.freeQty !== undefined) req.body.free_qty = req.body.freeQty;
    } else {
      if (req.body.promoPercent !== undefined) req.body.nilai_diskon = req.body.promoPercent;
      if (req.body.promoAmount !== undefined) req.body.nilai_diskon = req.body.promoAmount;
      req.body.buy_qty = null;
      req.body.free_qty = null;
    }

    if (req.body.jenis_diskon !== undefined) req.body.jenis_diskon = sanitizeJenisDiskon(req.body.jenis_diskon);

    const allowedFields = [
      'name', 'sku', 'barcode', 'price', 'cost_price', 'stock', 'is_active',
      'category', 'description', 'jenis_diskon', 'nilai_diskon',
      'buy_qty', 'free_qty', 'diskon_bundle_min_qty', 'diskon_bundle_value', 'image_url'
    ];
    const updateData = {};

    if (req.file) {
      updateData.image_url = path.relative(path.join(__dirname, '../../'), req.file.path).replace(/\\/g, '/');
    }

    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) updateData[field] = req.body[field];
    });

    // Validasi tipe data
    if (updateData.price !== undefined) {
      const priceVal = parseFloat(updateData.price);
      if (isNaN(priceVal) || priceVal < 0) return response.badRequest(res, 'Harga harus berupa angka positif');
      updateData.price = priceVal;
    }
    if (updateData.cost_price !== undefined) {
      const costVal = parseFloat(updateData.cost_price);
      if (isNaN(costVal) || costVal < 0) return response.badRequest(res, 'Harga modal harus berupa angka positif');
      updateData.cost_price = costVal;
    }
    if (updateData.stock !== undefined) {
      const stockVal = parseInt(updateData.stock, 10);
      if (isNaN(stockVal) || stockVal < 0) return response.badRequest(res, 'Stok harus berupa angka positif');
      updateData.stock = stockVal;
    }

    const isUpdated = await ProductModel.update(conn, productId, storeId, updateData);
    if (!isUpdated) return response.error(res, 'Gagal mengupdate produk', 400);

    const updatedProduct = await ProductModel.findById(conn, productId, storeId);

    // Log aktivitas
    await ActivityLogModel.create(conn, {
      user_id: req.user.id,
      store_id: req.params.store_id,
      action: 'edit_product',
      detail: `Edit produk: ${updatedProduct.name}`
    });

    return response.success(res, updatedProduct, 'Produk berhasil diupdate');
  } catch (error) {
    console.error('❌ ERROR UPDATE PRODUK:', error);
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

      const exists = await databaseExists(dbName);
      if (!exists) return response.badRequest(res, `Database tenant (${dbName}) tidak ditemukan. Silakan hubungi admin.`);

      conn = await getTenantConnection(dbName);

      const product = await ProductModel.findById(conn, productId, storeId);
      if (!product) return response.notFound(res, 'Produk tidak ditemukan');

      const isDeleted = await ProductModel.delete(conn, productId, storeId);
      if (!isDeleted) return response.error(res, 'Gagal menghapus produk', 400);

      // Log aktivitas
      await ActivityLogModel.create(conn, {
        user_id: req.user.id,
        store_id: req.params.store_id,
        action: 'delete_product',
        detail: `Hapus produk: ${id}`
      });

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

      const exists = await databaseExists(dbName);
      if (!exists) return response.badRequest(res, `Database tenant (${dbName}) tidak ditemukan. Silakan hubungi admin.`);

      conn = await getTenantConnection(dbName);

      const lowStockProducts = await ProductModel.getLowStock(conn, storeId, threshold);
      const safeProducts = lowStockProducts.map(p => ({
        id: p.id,
        name: p.name,
        sku: p.sku,
        barcode: p.barcode,
        stock: p.stock,
        category: p.category,
        image_url: p.image_url,
        price: p.price,
        // Jangan kirim cost_price ke kasir!
      }));
      return response.success(res, { products: safeProducts, count: safeProducts.length, threshold }, 'Produk dengan stok rendah');
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

      const exists = await databaseExists(dbName);
      if (!exists) return response.badRequest(res, `Database tenant (${dbName}) tidak ditemukan. Silakan hubungi admin.`);

      conn = await getTenantConnection(dbName);

      const existsInStore = await ProductModel.existsInStore(conn, productId, storeId);
      if (!existsInStore) return response.notFound(res, 'Produk tidak ditemukan');

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

      const exists = await databaseExists(dbName);
      if (!exists) return response.badRequest(res, `Database tenant (${dbName}) tidak ditemukan. Silakan hubungi admin.`);

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

      const exists = await databaseExists(dbName);
      if (!exists) return response.badRequest(res, `Database tenant (${dbName}) tidak ditemukan. Silakan hubungi admin.`);

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
    let isTenant = false;
    try {
      const { store_id } = req.params;
      const owner_id = req.user.owner_id;
      if (!req.file) return response.badRequest(res, 'File gambar tidak ditemukan');

      const dbName = req.user.db_name;
      if (dbName) {
        const exists = await databaseExists(dbName);
        if (exists) {
          conn = await getTenantConnection(dbName);
          isTenant = true;
        }
      }
      if (!conn) {
        conn = pool;
      }

      // --- VALIDASI LIMIT GAMBAR PRODUK ---
      const plan = req.user.plan;
      const imageLimit = getPackageLimit(plan, 'image_limit');
      // Hitung produk yang sudah punya gambar
      const [rows] = await conn.execute('SELECT COUNT(*) as total FROM products WHERE image_url IS NOT NULL AND image_url != "" AND store_id = ?', [store_id]);
      const totalImage = rows[0].total || 0;
      if (totalImage >= imageLimit) {
        return response.badRequest(res, `Batas upload gambar (${imageLimit}) untuk paket ${plan} telah tercapai`);
      }
      // --- END VALIDASI ---

      // Hanya upload file, tidak update ke produk manapun
      const imagePath = path.relative(path.join(__dirname, '../../'), req.file.path).replace(/\\/g, '/');

      return response.success(res, { image_url: imagePath }, 'Gambar produk berhasil diupload');
    } catch (error) {
      return response.error(res, 'Gagal upload gambar', 500, error);
    } finally {
      if (conn && isTenant) await conn.end();
    }
  },

search: async function (req, res) {
  let conn;
  let isTenant = false;
  try {
    const { store_id } = req.params;
    const q = (req.query.q || req.query.query || '').toString();
    const category = req.query.category;
    const dbName = req.user && req.user.db_name;
    if (dbName) {
      const exists = await databaseExists(dbName);
      if (exists) {
        conn = await getTenantConnection(dbName);
        isTenant = true;
      }
    }
    if (!conn) {
      conn = pool;
    }

    // Build filter object
    const filters = {};
    if (q) filters.search = q;
    if (category) filters.category = category;
    if (req.query.limit) filters.limit = req.query.limit;

    // Gunakan filter category meskipun q kosong
    const products = await ProductModel.findAllByStore(conn, store_id, filters);

    const mapped = products.map(product => ({
      id: product.id,
      name: product.name,
      sku: product.sku,
      barcode: product.barcode,
      costPrice: Number(product.cost_price || 0),
      sellPrice: Number(product.price || 0),
      stock: product.stock,
      category: product.category,
      description: product.description,
      imageUrl: product.image_url,
      promoType: product.jenis_diskon,
      promoPercent: Number(product.nilai_diskon || 0),
      promoAmount: Number(product.nilai_diskon || 0),
      buyQty: product.buy_qty,
      freeQty: product.free_qty,
      bundleQty: product.diskon_bundle_min_qty,
      bundleTotalPrice: Number(product.diskon_bundle_value || 0),
      isActive: product.is_active,
      createdAt: product.created_at,
      updatedAt: product.updated_at
    }));

    return response.success(res, mapped, 'Hasil pencarian produk');
  } catch (error) {
    console.error('Search Products Error:', error);
    return response.error(res, 'Terjadi kesalahan saat mencari produk', 500, error);
  } finally {
    if (conn && isTenant) await conn.end();
  }
},
};

module.exports = ProductController;
