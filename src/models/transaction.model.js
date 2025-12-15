const pool = require('../config/db');

const TransactionModel = {
    // Membuat transaksi baru
    async create(transactionData) {
        try {
            const { store_id, user_id, total_cost, payment_type, payment_method, received_amount, change_amount, payment_status } = transactionData;

            const [result] = await pool.query(
                `INSERT INTO transactions (store_id, user_id, total_cost, payment_type, payment_method, received_amount, change_amount, payment_status) 
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
                [store_id, user_id, total_cost, payment_type, payment_method, received_amount, change_amount, payment_status]
            );

            return result.insertId;  // Mengembalikan ID transaksi yang baru dibuat
        } catch (error) {
            throw error;
        }
    },

    // Menambahkan item ke transaksi
    async addItems(transactionId, items) {
        try {
            const values = items.map(item => [
                transactionId,
                item.product_id,
                item.quantity, // Ganti qty jadi quantity
                Number(item.price), // Pastikan number
                Number(item.quantity) * Number(item.price) // Hitung subtotal dengan benar
            ]);

            await pool.query(
                `INSERT INTO transaction_items (transaction_id, product_id, qty, price, subtotal) 
                 VALUES ?`, [values]
            );
        } catch (error) {
            throw error;
        }
    },

    // Mendapatkan transaksi berdasarkan ID
    async findById(transactionId, storeId) {
        try {
            const query = `SELECT * FROM transactions WHERE id = ? AND store_id = ?`;
            const params = [transactionId, storeId];
            const [rows] = await pool.execute(query, params);
            return rows[0] || null;
        } catch (error) {
            throw error;
        }
    },

    // Mendapatkan semua transaksi untuk sebuah toko
    async findAllByStore(storeId, filters = {}) {
        try {
            let query = `SELECT * FROM transactions WHERE store_id = ?`;
            const params = [storeId];

            if (filters.status) {
                query += ` AND payment_status = ?`;
                params.push(filters.status);
            }

            const [rows] = await pool.execute(query, params);
            return rows;
        } catch (error) {
            throw error;
        }
    },

    // Update transaksi
    async update(transactionId, storeId, updateData) {
        try {
            const { total_cost, payment_type, payment_method, received_amount, change_amount, payment_status } = updateData;
            const query = `UPDATE transactions 
                           SET total_cost = ?, payment_type = ?, payment_method = ?, received_amount = ?, change_amount = ?, payment_status = ?, updated_at = CURRENT_TIMESTAMP
                           WHERE id = ? AND store_id = ?`;
            const params = [total_cost, payment_type, payment_method, received_amount, change_amount, payment_status, transactionId, storeId];
            const [result] = await pool.execute(query, params);
            return result.affectedRows > 0;
        } catch (error) {
            throw error;
        }
    },

    // Menghapus transaksi
    async delete(transactionId, storeId) {
        try {
            const query = `DELETE FROM transactions WHERE id = ? AND store_id = ?`;
            const params = [transactionId, storeId];
            const [result] = await pool.execute(query, params);
            return result.affectedRows > 0;
        } catch (error) {
            throw error;
        }
    },
    // Menambahkan fungsi countByStore di TransactionModel
    async countByStore(storeId, filters) {
        try {
            let query = `SELECT COUNT(*) AS total FROM transactions WHERE store_id = ?`;
            const params = [storeId];

            if (filters.status) {
                query += ` AND payment_status = ?`; // Ganti status jadi payment_status
                params.push(filters.status);
            }

            const [rows] = await pool.execute(query, params);
            return rows[0].total;
        } catch (error) {
            throw error;
        }
    }

};

module.exports = TransactionModel;
