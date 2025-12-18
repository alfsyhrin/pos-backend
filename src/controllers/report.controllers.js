const { getTenantConnection } = require('../config/db');
const response = require('../utils/response');

const ReportController = {
  async summary(req, res) {
    let conn;
    try {
      const { store_id } = req.params;
      const { start, end } = req.query;
      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');

      conn = await getTenantConnection(dbName);

      // Total transaksi, pendapatan, diskon
      const [summary] = await conn.query(
        `SELECT 
            COUNT(*) AS total_transaksi, 
            COALESCE(SUM(total_cost),0) AS total_pendapatan,
            COALESCE(SUM(discount),0) AS total_diskon
         FROM transactions
         WHERE store_id = ? AND created_at BETWEEN ? AND ?`,
        [store_id, start, end]
      );

      // HPP/modal (totalCost) dari produk yang terjual
      const [hppRows] = await conn.query(
        `SELECT SUM(p.cost_price * ti.qty) AS total_hpp
         FROM transaction_items ti
         JOIN products p ON ti.product_id = p.id
         JOIN transactions t ON ti.transaction_id = t.id
         WHERE t.store_id = ? AND t.created_at BETWEEN ? AND ?`,
        [store_id, start, end]
      );
      const total_hpp = hppRows[0].total_hpp || 0;

      // Statistik harian
      const [dailyStats] = await conn.query(
        `SELECT DATE(created_at) as day, SUM(total_cost) as total
         FROM transactions
         WHERE store_id = ? AND created_at BETWEEN ? AND ?
         GROUP BY day`,
        [store_id, start, end]
      );
      const dailyTotals = dailyStats.map(r => Number(r.total));
      const bestSalesDay = dailyTotals.length ? Math.max(...dailyTotals) : 0;
      const lowestSalesDay = dailyTotals.length ? Math.min(...dailyTotals) : 0;
      const avgDaily = dailyTotals.length ? Math.round(dailyTotals.reduce((a, b) => a + b, 0) / dailyTotals.length) : 0;

      // Top produk (dengan revenue)
      const [topProducts] = await conn.query(
        `SELECT ti.product_id, p.sku, p.name, SUM(ti.qty) AS sold, SUM(ti.qty * ti.price) AS revenue
         FROM transaction_items ti
         JOIN products p ON ti.product_id = p.id
         JOIN transactions t ON ti.transaction_id = t.id
         WHERE t.store_id = ? AND t.created_at BETWEEN ? AND ?
         GROUP BY ti.product_id, p.sku, p.name
         ORDER BY sold DESC
         LIMIT 10`,
        [store_id, start, end]
      );

      // Stok menipis
      const [stokMenipis] = await conn.query(
        `SELECT id, name, stock as remaining FROM products WHERE store_id = ? AND stock <= 5`,
        [store_id]
      );

      // Margin, laba, dsb.
      const total_pendapatan = Number(summary[0].total_pendapatan) || 0;
      const total_diskon = Number(summary[0].total_diskon) || 0;
      const net_revenue = total_pendapatan - total_diskon;
      const gross_profit = net_revenue - total_hpp;
      const operational_cost = 0; // default
      const net_profit = gross_profit - operational_cost;
      const margin = total_pendapatan > 0 ? `${Math.round((net_profit / total_pendapatan) * 100)}%` : '0%';

      return response.success(res, {
        total_transaksi: summary[0].total_transaksi,
        total_pendapatan,
        total_diskon,
        net_revenue,
        total_hpp,
        gross_profit,
        operational_cost,
        net_profit,
        margin,
        best_sales_day: bestSalesDay,
        lowest_sales_day: lowestSalesDay,
        avg_daily: avgDaily,
        top_products: topProducts,
        stok_menipis: stokMenipis
      });
    } catch (err) {
      return response.error(res, err, 'Gagal mengambil laporan summary');
    } finally {
      if (conn) await conn.end();
    }
  },

  async products(req, res) {
    let conn;
    try {
      const { store_id } = req.params;
      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');

      conn = await getTenantConnection(dbName);

      // Top produk (dengan revenue)
      const [topProducts] = await conn.query(
        `SELECT ti.product_id, p.sku, p.name, SUM(ti.qty) AS sold, SUM(ti.qty * ti.price) AS revenue
         FROM transaction_items ti
         JOIN products p ON ti.product_id = p.id
         JOIN transactions t ON ti.transaction_id = t.id
         WHERE t.store_id = ?
         GROUP BY ti.product_id, p.sku, p.name
         ORDER BY sold DESC
         LIMIT 10`,
        [store_id]
      );
      // Stok menipis
      const [stokMenipis] = await conn.query(
        `SELECT id, name, stock as remaining FROM products WHERE store_id = ? AND stock <= 5`,
        [store_id]
      );
      return response.success(res, {
        top_products: topProducts,
        stok_menipis: stokMenipis
      });
    } catch (err) {
      return response.error(res, err, 'Gagal mengambil laporan produk');
    } finally {
      if (conn) await conn.end();
    }
  },

  async cashiers(req, res) {
    let conn;
    try {
      const { store_id } = req.params;
      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');

      conn = await getTenantConnection(dbName);

      // Performa kasir
      const [cashierStats] = await conn.query(
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
    } finally {
      if (conn) await conn.end();
    }
  }
};

module.exports = ReportController;