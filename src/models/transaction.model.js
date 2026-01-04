const pool = require('../config/db');

function isConn(obj) {
  return obj && typeof obj.execute === 'function';
}

const TransactionModel = {
    // Membuat transaksi baru (conn, data) atau (data)
    async create(connOrData, maybeData) {
        const db = isConn(connOrData) ? connOrData : pool;
        const data = isConn(connOrData) ? maybeData : connOrData;
        const {
            store_id, user_id, total_cost, payment_type, payment_method, received_amount, change_amount, payment_status,
            subtotal, discount_total, tax, tax_percentage, jenis_diskon, nilai_diskon, buy_qty, free_qty
        } = data;

        const [result] = await db.execute(
            `INSERT INTO transactions (
                store_id, user_id, total_cost, payment_type, payment_method, received_amount, change_amount, payment_status,
                subtotal, discount_total, tax, tax_percentage, jenis_diskon, nilai_diskon, buy_qty, free_qty, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
            [
                store_id, user_id, total_cost, payment_type, payment_method, received_amount, change_amount, payment_status,
                subtotal, discount_total, tax, tax_percentage, jenis_diskon, nilai_diskon, buy_qty, free_qty
            ]
        );
        return result.insertId;
    },

    // Menambahkan item ke transaksi (conn, transactionId, items) atau (transactionId, items)
    async addItems(connOrId, maybeIdOrItems, maybeItems) {
        const db = isConn(connOrId) ? connOrId : pool;
        const transactionId = isConn(connOrId) ? maybeIdOrItems : connOrId;
        const items = isConn(connOrId) ? maybeItems : maybeIdOrItems;

        if (!items || !items.length) return;

        const values = items.map(item => [
            transactionId,
            item.product_id,
            item.product_name || '', // <-- tambahkan product_name
            item.quantity,
            Number(item.price),
            Number(item.discount_type) || null,
            Number(item.discount_value) || null,
            Number(item.discount_amount) || 0,
            Number(item.subtotal)
        ]);

        // Build placeholders for multi-row insert
        const placeholders = values.map(() => '(?,?,?,?,?,?,?,?,?)').join(',');

        await db.execute(
            `INSERT INTO transaction_items (transaction_id, product_id, product_name, qty, price, discount_type, discount_value, discount_amount, subtotal) VALUES ${placeholders}`,
            values.flat()
        );
    },

    // Mendapatkan transaksi berdasarkan ID (conn, transactionId, storeId) atau (transactionId, storeId)
    async findById(connOrId, maybeIdOrStore, maybeStore) {
        const db = isConn(connOrId) ? connOrId : pool;
        const transactionId = isConn(connOrId) ? maybeIdOrStore : connOrId;
        const storeId = isConn(connOrId) ? maybeStore : maybeIdOrStore;
        const query = `SELECT * FROM transactions WHERE id = ? AND store_id = ?`;
        const params = [transactionId, storeId];
        const [rows] = await db.execute(query, params);
        return rows[0] || null;
    },

    // Mendapatkan semua transaksi untuk sebuah toko (conn, storeId, filters) atau (storeId, filters)
    async findAllByStore(connOrStoreId, maybeStoreId, maybeFilters) {
        const db = isConn(connOrStoreId) ? connOrStoreId : pool;
        const storeId = isConn(connOrStoreId) ? maybeStoreId : connOrStoreId;
        const filters = isConn(connOrStoreId) ? maybeFilters || {} : maybeStoreId || {};
        let query = `SELECT t.* FROM transactions t WHERE t.store_id = ?`;
        const params = [storeId];

        // Filter status
        if (filters.payment_status) {
            query += ` AND t.payment_status = ?`;
            params.push(filters.payment_status);
        }

        // Filter search (by transaction id, idShort, idFull, product_name, product.name)
        if (filters.search) {
            query += ` AND (
                t.id LIKE ?
                OR EXISTS (
                    SELECT 1 FROM transaction_items ti 
                    LEFT JOIN products p ON ti.product_id = p.id 
                    WHERE ti.transaction_id = t.id 
                      AND (
                        ti.product_name LIKE ? 
                        OR p.name LIKE ?
                      )
                )
            )`;
            const s = `%${filters.search}%`;
            params.push(s, s, s);
        }

        // Filter by date (created_at)
        if (filters.date) {
            query += ` AND DATE(t.created_at) = ?`;
            params.push(filters.date);
        } else if (filters.start_date && filters.end_date) {
            query += ` AND DATE(t.created_at) BETWEEN ? AND ?`;
            params.push(filters.start_date, filters.end_date);
        }

        query += ` ORDER BY t.created_at DESC`;

        // Perbaikan: jangan gunakan placeholder untuk LIMIT/OFFSET — cast & inject angka yang tervalidasi
        const limitVal = Number.isFinite(Number(filters.limit)) ? parseInt(filters.limit, 10) : NaN;
        const offsetVal = Number.isFinite(Number(filters.offset)) ? parseInt(filters.offset, 10) : NaN;

        if (!isNaN(limitVal) && limitVal > 0) {
            // safe to interpolate because we've validated as integers
            query += ` LIMIT ${limitVal}`;
            if (!isNaN(offsetVal) && offsetVal >= 0) {
                query += ` OFFSET ${offsetVal}`;
            }
        }
        try {
            const [rows] = await db.execute(query, params);
            return rows;
        } catch (err) {
            // tambahkan log query + params utk debugging saat error
            console.error('TransactionModel.findAllByStore SQL Error', { query, params, err });
            throw err;
        }
    },

    // Update transaksi (conn, transactionId, storeId, updateData) atau (transactionId, storeId, updateData)
    async update(connOrId, maybeIdOrStore, maybeStoreOrData, maybeData) {
        let db, transactionId, storeId, updateData;
        if (isConn(connOrId)) {
            db = connOrId;
            transactionId = maybeIdOrStore;
            storeId = maybeStoreOrData;
            updateData = maybeData;
        } else {
            db = pool;
            transactionId = connOrId;
            storeId = maybeIdOrStore;
            updateData = maybeStoreOrData;
        }
        const { total_cost, payment_type, payment_method, received_amount, change_amount, payment_status } = updateData;
        const query = `UPDATE transactions 
                       SET total_cost = ?, payment_type = ?, payment_method = ?, received_amount = ?, change_amount = ?, payment_status = ?, updated_at = CURRENT_TIMESTAMP
                       WHERE id = ? AND store_id = ?`;
        const params = [total_cost, payment_type, payment_method, received_amount, change_amount, payment_status, transactionId, storeId];
        const [result] = await db.execute(query, params);
        return result.affectedRows > 0;
    },

    // Menghapus transaksi (conn, transactionId, storeId) atau (transactionId, storeId)
    async delete(connOrId, maybeIdOrStore, maybeStore) {
        const db = isConn(connOrId) ? connOrId : pool;
        const transactionId = isConn(connOrId) ? maybeIdOrStore : connOrId;
        const storeId = isConn(connOrId) ? maybeStore : maybeIdOrStore;
        const query = `DELETE FROM transactions WHERE id = ? AND store_id = ?`;
        const params = [transactionId, storeId];
        const [result] = await db.execute(query, params);
        return result.affectedRows > 0;
    },

    // Menghitung jumlah transaksi untuk sebuah toko (conn, storeId, filters) atau (storeId, filters)
    async countByStore(connOrStoreId, maybeStoreId, maybeFilters) {
        const db = isConn(connOrStoreId) ? connOrStoreId : pool;
        const storeId = isConn(connOrStoreId) ? maybeStoreId : connOrStoreId;
        const filters = isConn(connOrStoreId) ? maybeFilters || {} : maybeStoreId || {};
        let query = `SELECT COUNT(*) AS total FROM transactions WHERE store_id = ?`;
        const params = [storeId];

        if (filters.status) {
            query += ` AND payment_status = ?`;
            params.push(filters.status);
        }

        const [rows] = await db.execute(query, params);
        return rows[0].total;
    },

    getItemsByTransactionId: async function(conn, transactionId) {
        const [rows] = await conn.execute(
          `SELECT ti.product_id, p.name as product_name, p.sku, ti.qty as quantity, ti.price, ti.subtotal, ti.discount_type, ti.discount_value, ti.discount_amount
           FROM transaction_items ti
           LEFT JOIN products p ON ti.product_id = p.id
           WHERE ti.transaction_id = ?`,
          [transactionId]
        );
        return rows;
      },
};

module.exports = TransactionModel;
