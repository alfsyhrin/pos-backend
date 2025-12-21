const { pool } = require('../config/db');
const response = require('../utils/response'); // Pastikan jalur relatifnya benar

function cleanNullFields(obj) {
  Object.keys(obj).forEach(key => {
    if (obj[key] === undefined) obj[key] = null;
  });
  return obj;
}

function resolveDbAndArgs(first, second) {
  // Jika first adalah koneksi/pool (punya method execute/query), gunakan sebagai db
  if (first && typeof first.execute === 'function') {
    return { db: first, args: second };
  }
  // Otherwise treat first as main arg and pool as db
  return { db: pool, args: first };
}

function isConn(obj) {
  // Cek apakah obj adalah koneksi mysql2
  return obj && typeof obj.execute === 'function';
}

const ProductModel = {
  // Create new product (supports create(conn, productData) or create(productData))
  async create(connOrData, maybeData) {
    const { db, args: data } = resolveDbAndArgs(connOrData, maybeData);
    try {
      const d = cleanNullFields(data);
      const [result] = await db.execute(
        `INSERT INTO products
          (store_id, name, sku, barcode, price, cost_price, stock, category, description, image_url, is_active,
           jenis_diskon, nilai_diskon, diskon_bundle_min_qty, diskon_bundle_value, buy_qty, free_qty, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
        [
          d.store_id, d.name, d.sku, d.barcode, d.price, d.cost_price, d.stock, d.category, d.description,
          d.image_url, d.is_active ?? 1, d.jenis_diskon, d.nilai_diskon,
          d.diskon_bundle_min_qty, d.diskon_bundle_value, d.buy_qty, d.free_qty
        ]
      );
      return result.insertId;
    } catch (error) {
      throw error;
    }
  },

  // Get all products for a store (supports (conn, storeId, filters) or (storeId, filters))
  findAllByStore: async function (connOrStoreId, maybeStoreId, maybeFilters) {
    const db = isConn(connOrStoreId) ? connOrStoreId : pool;
    const storeId = isConn(connOrStoreId) ? maybeStoreId : connOrStoreId;
    const filters = isConn(connOrStoreId) ? maybeFilters || {} : maybeStoreId || {};
    let query = `SELECT * FROM products WHERE store_id = ?`;
    const params = [storeId];

    if (filters.search) {
      query += ` AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ?)`;
      const term = `%${filters.search}%`;
      params.push(term, term, term);
    }
    if (filters.category) {
      query += ` AND category = ?`;
      params.push(filters.category);
    }
    if (filters.sku) {
      query += ` AND sku = ?`;
      params.push(filters.sku);
    }

    // VALIDATE limit/offset sebagai angka, lalu masukkan langsung ke SQL (bukan sebagai placeholder)
    let limit = 20;
    if (filters.limit !== undefined && Number.isFinite(Number(filters.limit)) && Number(filters.limit) > 0) {
      limit = Math.floor(Number(filters.limit));
    }
    query += ` LIMIT ${limit}`;

    if (filters.offset !== undefined && Number.isFinite(Number(filters.offset)) && Number(filters.offset) >= 0) {
      const offset = Math.floor(Number(filters.offset));
      query += ` OFFSET ${offset}`;
    }

    const [rows] = await db.execute(query, params);
    return rows;
  },

  // Get single product by ID (supports (conn, productId, storeId?) or (productId, storeId?))
  async findById(connOrId, maybeIdOrStore, maybeStore) {
    const hasConn = connOrId && typeof connOrId.execute === 'function';
    const db = hasConn ? connOrId : pool;
    const productId = hasConn ? maybeIdOrStore : connOrId;
    const storeId = hasConn ? maybeStore : maybeIdOrStore;
    try {
      let query = `SELECT * FROM products WHERE id = ?`;
      const params = [productId];
      if (storeId) {
        query += ` AND store_id = ?`;
        params.push(storeId);
      }
      const [rows] = await db.execute(query, params);
      return rows[0] || null;
    } catch (error) {
      throw error;
    }
  },

  // Update product (supports update(conn, productId, storeId, updateData) or update(productId, storeId, updateData))
  async update(connOrId, maybeIdOrStore, maybeStoreOrData, maybeData) {
    let db, productId, storeId, updateData;
    if (connOrId && typeof connOrId.execute === 'function') {
      db = connOrId;
      productId = maybeIdOrStore;
      storeId = maybeStoreOrData;
      updateData = maybeData;
    } else {
      db = pool;
      productId = connOrId;
      storeId = maybeIdOrStore;
      updateData = maybeStoreOrData;
    }
    try {
      const fields = [];
      const values = [];
      const allowedFields = [
        'name','sku','price','stock','image_url','is_active','category',
        'jenis_diskon','nilai_diskon','diskon_bundle_min_qty','diskon_bundle_value',
        'buy_qty','free_qty','description','barcode', 'cost_price'
      ];
      allowedFields.forEach(field => {
        if (updateData[field] !== undefined) {
          fields.push(`${field} = ?`);
          values.push(updateData[field]);
        }
      });
      if (fields.length === 0) return false;
      values.push(productId, storeId);
      const [result] = await db.execute(
        `UPDATE products SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND store_id = ?`,
        values
      );
      return result.affectedRows > 0;
    } catch (error) {
      throw error;
    }
  },

  // Delete product (supports (conn, productId, storeId) or (productId, storeId))
  async delete(connOrId, maybeIdOrStore, maybeStore) {
    const hasConn = connOrId && typeof connOrId.execute === 'function';
    const db = hasConn ? connOrId : pool;
    const productId = hasConn ? maybeIdOrStore : connOrId;
    const storeId = hasConn ? maybeStore : maybeIdOrStore;
    try {
      const [result] = await db.execute(`DELETE FROM products WHERE id = ? AND store_id = ?`, [productId, storeId]);
      return result.affectedRows > 0;
    } catch (error) {
      throw error;
    }
  },

  // Count by store
  async countByStore(connOrStoreId, maybeStoreId, maybeFilters) {
    const hasConn = connOrStoreId && typeof connOrStoreId.execute === 'function';
    const db = hasConn ? connOrStoreId : pool;
    const storeId = hasConn ? maybeStoreId : connOrStoreId;
    const filters = hasConn ? maybeFilters || {} : maybeStoreId || {};
    try {
      let query = `SELECT COUNT(*) as count FROM products WHERE store_id = ?`;
      const params = [storeId];
      if (filters.is_active !== undefined) {
        query += ` AND is_active = ?`;
        params.push(filters.is_active);
      }
      if (filters.search) {
        query += ` AND (name LIKE ? OR sku LIKE ?)`;
        const searchTerm = `%${filters.search}%`;
        params.push(searchTerm, searchTerm);
      }
      const [rows] = await db.execute(query, params);
      return rows[0].count;
    } catch (error) {
      throw error;
    }
  },

  // Search
  async search(connOrStoreId, maybeStoreId, searchTerm, limit = 20) {
    const hasConn = connOrStoreId && typeof connOrStoreId.execute === 'function';
    const db = hasConn ? connOrStoreId : pool;
    const storeId = hasConn ? maybeStoreId : connOrStoreId;
    const term = hasConn ? searchTerm : maybeStoreId;
    const lim = hasConn ? limit : searchTerm || 20;

    // validate limit dan masukkan langsung
    const limVal = (lim !== undefined && Number.isFinite(Number(lim)) && Number(lim) > 0) ? Math.floor(Number(lim)) : 20;

    try {
      const sql = `SELECT * FROM products WHERE store_id = ? AND (name LIKE ? OR sku LIKE ?) AND is_active = 1 ORDER BY name LIMIT ${limVal}`;
      const [rows] = await db.execute(sql, [storeId, `%${term}%`, `%${term}%`]);
      return rows;
    } catch (error) {
      throw error;
    }
  },

  // Bulk update
  async bulkUpdate(connOrStoreId, maybeStoreId, productIds, updateData) {
    const hasConn = connOrStoreId && typeof connOrStoreId.execute === 'function';
    const db = hasConn ? connOrStoreId : pool;
    const storeId = hasConn ? maybeStoreId : connOrStoreId;
    if (!Array.isArray(productIds) || productIds.length === 0) throw new Error('Product IDs must be a non-empty array');
    try {
      const fields = [];
      const values = [];
      const allowedFields = ['price','stock','is_active'];
      allowedFields.forEach(field => {
        if (updateData[field] !== undefined) {
          fields.push(`${field} = ?`);
          values.push(updateData[field]);
        }
      });
      if (fields.length === 0) throw new Error('No valid fields to update');
      const placeholders = productIds.map(() => '?').join(',');
      values.push(storeId, ...productIds);
      const [result] = await db.execute(
        `UPDATE products SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE store_id = ? AND id IN (${placeholders})`,
        values
      );
      return result.affectedRows;
    } catch (error) {
      throw error;
    }
  },

  // Update stock (supports transactional conn)
  async updateStock(connOrProductId, maybeProductIdOrStore, maybeChange) {
    const hasConn = connOrProductId && typeof connOrProductId.execute === 'function';
    const db = hasConn ? connOrProductId : pool;
    const productId = hasConn ? maybeProductIdOrStore : connOrProductId;
    const quantityChange = hasConn ? maybeChange : maybeProductIdOrStore;
    try {
      const [result] = await db.execute(
        `UPDATE products SET stock = stock + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
        [quantityChange, productId]
      );
      return result.affectedRows > 0;
    } catch (error) {
      throw error;
    }
  },

  // Get low stock
  async getLowStock(connOrStoreId, maybeStoreId, threshold = 10) {
    const hasConn = connOrStoreId && typeof connOrStoreId.execute === 'function';
    const db = hasConn ? connOrStoreId : pool;
    const storeId = hasConn ? maybeStoreId : connOrStoreId;
    try {
      const [rows] = await db.execute(
        `SELECT * FROM products WHERE store_id = ? AND stock <= ? AND is_active = 1 ORDER BY stock ASC`,
        [storeId, threshold]
      );
      return rows;
    } catch (error) {
      throw error;
    }
  },

  // existsInStore
  async existsInStore(connOrProductId, maybeProductIdOrStore, maybeStore) {
    const hasConn = connOrProductId && typeof connOrProductId.execute === 'function';
    const db = hasConn ? connOrProductId : pool;
    const productId = hasConn ? maybeProductIdOrStore : connOrProductId;
    const storeId = hasConn ? maybeStore : maybeProductIdOrStore;
    try {
      const [rows] = await db.execute(`SELECT 1 FROM products WHERE id = ? AND store_id = ?`, [productId, storeId]);
      return rows.length > 0;
    } catch (error) {
      throw error;
    }
  },

  // findByIdForTransaction (returns product with discount info)
  async findByIdForTransaction(connOrId, maybeId) {
    const hasConn = connOrId && typeof connOrId.execute === 'function';
    const db = hasConn ? connOrId : pool;
    const id = hasConn ? maybeId : connOrId;
    try {
      const [rows] = await db.query(
        `SELECT p.*, s.name as store_name,
          CASE
            WHEN p.diskon_bundle_min_qty IS NOT NULL AND p.diskon_bundle_min_qty > 0 THEN 'bundle'
            WHEN p.jenis_diskon IS NOT NULL AND p.nilai_diskon > 0 THEN p.jenis_diskon
            ELSE 'none'
          END as discount_type,
          COALESCE(p.nilai_diskon, 0) as discount_value,
          p.diskon_bundle_min_qty,
          p.diskon_bundle_value
         FROM products p
         LEFT JOIN stores s ON p.store_id = s.id
         WHERE p.id = ? AND p.is_active = 1`,
        [id]
      );
      return rows[0] || null;
    } catch (error) {
      throw error;
    }
  },

  // find by barcode
  async findByBarcode(connOrStoreId, maybeStoreId, barcode) {
    const hasConn = connOrStoreId && typeof connOrStoreId.execute === 'function';
    const db = hasConn ? connOrStoreId : pool;
    const storeId = hasConn ? maybeStoreId : connOrStoreId;
    try {
      const [rows] = await db.execute(
        `SELECT * FROM products WHERE store_id = ? AND barcode = ? LIMIT 1`,
        [storeId, barcode]
      );
      return rows[0] || null;
    } catch (error) {
      throw error;
    }
  },

  simpleSearch: async function (conn, storeId, q, limit = 20) {
    let query = `SELECT * FROM products WHERE store_id = ?`;
    const params = [storeId];

    if (q && q.trim() !== '') {
      query += ` AND (name LIKE ? OR sku LIKE ? OR barcode LIKE ?)`;
      const term = `%${q}%`;
      params.push(term, term, term);
    }

    const lim = (limit !== undefined && Number.isFinite(Number(limit)) && Number(limit) > 0) ? Math.floor(Number(limit)) : 20;
    query += ` LIMIT ${lim}`;

    const [rows] = await conn.execute(query, params);
    return rows;
  },
};

module.exports = ProductModel;