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

      const logs = await ActivityLogModel.listByStore(conn, store_id, 50);
      // Format untuk frontend
      const mapped = logs.map(log => ({
        id: log.id,
        user: log.user_name,
        action: log.action,
        title: mapActionToTitle(log.action),
        detail: log.detail,
        time: log.created_at // frontend bisa format "10 menit lalu"
      }));
      return response.success(res, mapped);
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
    default: return 'Aktivitas';
  }
}

module.exports = ActivityLogController;