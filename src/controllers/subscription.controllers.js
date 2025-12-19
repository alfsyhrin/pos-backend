const SubscriptionModel = require('../models/subscription.model');
const response = require('../utils/response');

const SubscriptionController = {
  async getSubscription(req, res) {
    let conn;
    try {
      const owner_id = req.user.owner_id;
      const dbName = req.user.db_name;
      if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');

      conn = await require('../config/db').getTenantConnection(dbName);
      const data = await SubscriptionModel.getByOwnerId(conn, owner_id);

      if (!data) {
        // Default jika tidak ada subscription
        return response.success(res, {
          plan: 'FREE',
          status: 'inactive',
          start_date: new Date(),
          end_date: new Date()
        });
      }

      // Patch: mapping status
      data.status = (data.status && data.status.toLowerCase() === 'aktif') ? 'active' : data.status;
      return response.success(res, data);
    } catch (err) {
      return response.error(res, err, 'Gagal mengambil data subscription');
    } finally {
      if (conn) await conn.end();
    }
  }
};

module.exports = SubscriptionController;