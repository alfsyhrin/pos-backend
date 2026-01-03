const { getTenantConnection } = require('../config/db');
const ActivityLogModel = require('../models/activityLog.model');
const response = require('../utils/response');

const ActivityLogController = {
  async list(req, res) {
    let conn;
    try {
      const { store_id } = req.params;
      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
      conn = await getTenantConnection(dbName);

      // Ambil pagination dari query
      const page = parseInt(req.query.page, 10) || 1;
      const limit = parseInt(req.query.limit, 10) || 10;
      const offset = (page - 1) * limit;

      // Query log & total
      const items = await ActivityLogModel.listByStorePaginated(conn, store_id, limit, offset);
      const total = await ActivityLogModel.countByStore(conn, store_id);

      // Format untuk frontend
      const mapped = items.map(log => ({
        id: log.id,
        user: log.user_name,
        action: log.action,
        title: mapActionToTitle(log.action),
        detail: log.detail,
        time: log.created_at
      }));

      return response.success(res, {
        items: mapped,
        total,
        page,
        limit,
        pages: Math.ceil(total / limit)
      });
    } catch (err) {
      return response.error(res, err, 'Gagal mengambil log aktivitas');
    } finally {
      if (conn) await conn.end();
    }
  }
};

function mapActionToTitle(action) {
  switch (action) {
    case 'login': return 'Login berhasil';
    case 'add_product': return 'Produk ditambahkan';
    case 'transaction': return 'Transaksi dibuat';
    case 'update_setting': return 'Pengaturan diubah';
    // ...tambahkan mapping lain sesuai kebutuhan...
    default: return 'Aktivitas';
  }
}

module.exports = ActivityLogController;