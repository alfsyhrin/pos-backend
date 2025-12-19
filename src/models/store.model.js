const pool = require('../config/db');

function isConn(obj) {
  return obj && typeof obj.execute === 'function';
}

const StoreModel = {
  // create(conn, data) or create(data)
  async create(connOrData, maybeData) {
    const db = isConn(connOrData) ? connOrData : pool;
    const data = isConn(connOrData) ? maybeData : connOrData;
    const { owner_id, name, address, phone, receipt_template } = data;
    const [result] = await db.execute(
      `INSERT INTO stores (owner_id, name, address, phone, receipt_template, created_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [owner_id, name, address || null, phone || null, receipt_template || null]
    );
    return result.insertId;
  },

  // findAllByOwner(conn, ownerId) or findAllByOwner(ownerId)
  async findAllByOwner(connOrOwnerId, maybeOwnerId) {
    const db = isConn(connOrOwnerId) ? connOrOwnerId : pool;
    const ownerId = isConn(connOrOwnerId) ? maybeOwnerId : connOrOwnerId;
    const [rows] = await db.execute(
      `SELECT * FROM stores WHERE owner_id = ? ORDER BY created_at DESC`,
      [ownerId]
    );
    return rows;
  },

  // findById(conn, storeId, ownerId?) or findById(storeId, ownerId?)
  async findById(connOrStoreId, maybeStoreId, maybeOwnerId) {
    const db = isConn(connOrStoreId) ? connOrStoreId : pool;
    const storeId = isConn(connOrStoreId) ? maybeStoreId : connOrStoreId;
    const ownerId = isConn(connOrStoreId) ? maybeOwnerId : maybeStoreId;
    let query = `SELECT * FROM stores WHERE id = ?`;
    const params = [storeId];
    if (ownerId) {
      query += ` AND owner_id = ?`;
      params.push(ownerId);
    }
    const [rows] = await db.execute(query, params);
    return rows[0] || null;
  },

  // createReceiptTemplate(conn, storeId, templateName, templateData) or createReceiptTemplate(storeId, templateName, templateData)
  async createReceiptTemplate(connOrStoreId, maybeStoreId, templateName, templateData) {
    let db, storeId;
    if (isConn(connOrStoreId)) {
      db = connOrStoreId; storeId = maybeStoreId;
    } else {
      db = pool; storeId = connOrStoreId;
      templateName = maybeStoreId; templateData = templateName;
    }
    const [result] = await db.execute(
      `INSERT INTO struck_receipt (store_id, template_name, template_data, created_at) VALUES (?, ?, ?, NOW())`,
      [storeId, templateName, templateData]
    );
    return result.insertId;
  },

  // getReceiptTemplate(conn, storeId) or getReceiptTemplate(storeId)
  async getReceiptTemplate(connOrStoreId, maybeStoreId) {
    const db = isConn(connOrStoreId) ? connOrStoreId : pool;
    const storeId = isConn(connOrStoreId) ? maybeStoreId : connOrStoreId;
    const [rows] = await db.execute(`SELECT * FROM struck_receipt WHERE store_id = ?`, [storeId]);
    return rows[0] || null;
  },

  // update(conn, storeId, ownerId, updateData) or update(storeId, ownerId, updateData)
  async update(connOrStoreId, maybeStoreId, maybeOwnerId, maybeData) {
    let db, storeId, ownerId, updateData;
    if (isConn(connOrStoreId)) {
      db = connOrStoreId; storeId = maybeStoreId; ownerId = maybeOwnerId; updateData = maybeData;
    } else {
      db = pool; storeId = connOrStoreId; ownerId = maybeStoreId; updateData = maybeOwnerId;
    }
    const fields = [];
    const params = [];
    ['name','address','phone','receipt_template','tax_percentage'].forEach(k => {
      if (updateData[k] !== undefined) {
        fields.push(`${k} = ?`);
        params.push(updateData[k] || null);
      }
    });
    if (fields.length === 0) return false;
    params.push(storeId, ownerId);
    const [result] = await db.execute(
      `UPDATE stores SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND owner_id = ?`,
      params
    );
    return result.affectedRows > 0;
  },

  // delete(conn, storeId, ownerId) or delete(storeId, ownerId)
  async delete(connOrStoreId, maybeStoreId, maybeOwnerId) {
    const db = isConn(connOrStoreId) ? connOrStoreId : pool;
    const storeId = isConn(connOrStoreId) ? maybeStoreId : connOrStoreId;
    const ownerId = isConn(connOrStoreId) ? maybeOwnerId : maybeStoreId;
    const [result] = await db.execute(`DELETE FROM stores WHERE id = ? AND owner_id = ?`, [storeId, ownerId]);
    return result.affectedRows > 0;
  },

  // countByOwner(conn, ownerId) or countByOwner(ownerId)
  async countByOwner(connOrOwnerId, maybeOwnerId) {
    const db = isConn(connOrOwnerId) ? connOrOwnerId : pool;
    const ownerId = isConn(connOrOwnerId) ? maybeOwnerId : connOrOwnerId;
    const [rows] = await db.execute(`SELECT COUNT(*) as count FROM stores WHERE owner_id = ?`, [ownerId]);
    return rows[0].count;
  },

  // search(conn, ownerId, term) or search(ownerId, term)
  async search(connOrOwnerId, maybeOwnerId, maybeTerm) {
    const db = isConn(connOrOwnerId) ? connOrOwnerId : pool;
    const ownerId = isConn(connOrOwnerId) ? maybeOwnerId : connOrOwnerId;
    const term = isConn(connOrOwnerId) ? maybeTerm : maybeOwnerId;
    const [rows] = await db.execute(
      `SELECT * FROM stores WHERE owner_id = ? AND (name LIKE ? OR address LIKE ? OR phone LIKE ?) ORDER BY name`,
      [ownerId, `%${term}%`, `%${term}%`, `%${term}%`]
    );
    return rows;
  },

  // Additional methods
  async getStoreById(conn, storeId) {
    const [rows] = await conn.execute(
      'SELECT id, owner_id, name, address, phone, receipt_template, tax_percentage, created_at, updated_at FROM stores WHERE id = ?',
      [storeId]
    );
    return rows[0];
  },

  async updateStore(conn, storeId, data) {
    const { name, address, phone, receipt_template, tax_percentage } = data;

    // Pastikan tax_percentage tidak undefined
    const taxValue = (typeof tax_percentage === 'number' && !isNaN(tax_percentage))
      ? tax_percentage
      : (tax_percentage ? Number(tax_percentage) : 0);

    await conn.execute(
      'UPDATE stores SET name=?, address=?, phone=?, receipt_template=?, tax_percentage=? WHERE id=?',
      [
        name,
        address ?? null,
        phone ?? null,
        receipt_template ?? null,
        taxValue,
        storeId
      ]
    );
  }
};

module.exports = StoreModel;