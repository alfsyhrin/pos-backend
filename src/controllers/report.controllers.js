const db = require('../config/db');
const response = require('../utils/response');

const ReportController = {
  async summary(req, res) {
    try {
      const { store_id } = req.params;
      const { start, end } = req.query;

      // Total pendapatan & transaksi
      const [summary] = await db.query(
        `SELECT COUNT(*) AS total_transaksi, 
                COALESCE(SUM(total_cost),0) AS total_pendapatan
         FROM transactions
         WHERE store_id = ? AND created_at BETWEEN ? AND ?`,
        [store_id, start, end]
      );

      // Margin/laba (dummy, sesuaikan jika ada HPP)
      const margin = 0;

      // Produk terlaris
      const [topProducts] = await db.query(
        `SELECT ti.product_id, p.name, SUM(ti.qty) AS total_terjual
         FROM transaction_items ti
         JOIN products p ON ti.product_id = p.id
         JOIN transactions t ON ti.transaction_id = t.id
         WHERE t.store_id = ? AND t.created_at BETWEEN ? AND ?
         GROUP BY ti.product_id, p.name
         ORDER BY total_terjual DESC
         LIMIT 10`,
        [store_id, start, end]
      );

      // Stok menipis
      const [stokMenipis] = await db.query(
        `SELECT id, name, stock FROM products WHERE store_id = ? AND stock <= 5`,
        [store_id]
      );

      return response.success(res, {
        total_transaksi: summary[0].total_transaksi,
        total_pendapatan: summary[0].total_pendapatan,
        margin,
        top_products: topProducts,
        stok_menipis: stokMenipis
      });
    } catch (err) {
      return response.error(res, err, 'Gagal mengambil laporan summary');
    }
  },

  async products(req, res) {
    try {
      const { store_id } = req.params;
      // Top produk
      const [topProducts] = await db.query(
        `SELECT ti.product_id, p.name, SUM(ti.qty) AS total_terjual
         FROM transaction_items ti
         JOIN products p ON ti.product_id = p.id
         JOIN transactions t ON ti.transaction_id = t.id
         WHERE t.store_id = ?
         GROUP BY ti.product_id, p.name
         ORDER BY total_terjual DESC
         LIMIT 10`,
        [store_id]
      );
      // Stok menipis
      const [stokMenipis] = await db.query(
        `SELECT id, name, stock FROM products WHERE store_id = ? AND stock <= 5`,
        [store_id]
      );
      return response.success(res, {
        top_products: topProducts,
        stok_menipis: stokMenipis
      });
    } catch (err) {
      return response.error(res, err, 'Gagal mengambil laporan produk');
    }
  },

  async cashiers(req, res) {
    try {
      const { store_id } = req.params;
      // Performa kasir
      const [cashierStats] = await db.query(
        `SELECT u.id, u.name, COUNT(t.id) AS total_transaksi, COALESCE(SUM(t.total_cost),0) AS total_penjualan
         FROM users u
         LEFT JOIN transactions t ON t.user_id = u.id AND t.store_id = ?
         WHERE u.store_id = ? AND u.role = 'cashier'
         GROUP BY u.id, u.name`,
        [store_id, store_id]
      );
      return response.success(res, cashierStats);
    } catch (err) {
      return response.error(res, err, 'Gagal mengambil laporan kasir');
    }
  }
};

module.exports = ReportController;