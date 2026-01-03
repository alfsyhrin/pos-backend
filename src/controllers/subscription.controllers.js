const SubscriptionModel = require('../models/subscription.model');
const ActivityLogModel = require('../models/activityLog.model');
const response = require('../utils/response');
const { getMainConnection } = require('../config/db'); // pastikan ada fungsi ini

const SubscriptionController = {
  async getSubscription(req, res) {
    let conn;
    try {
      const owner_id = req.user.owner_id;
      // PATCH: gunakan koneksi utama, bukan tenant
      conn = await getMainConnection();
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
  },

  async updateSubscription(req, res) {
    let conn;
    try {
      const owner_id = req.user.owner_id;
      conn = await getMainConnection();

      // ...existing logic update/purchase subscription...
      const { plan, status } = req.body;
      await SubscriptionModel.updateByOwnerId(conn, owner_id, { plan, status });

      // Logging aktivitas: update/purchase subscription
      await ActivityLogModel.create(conn, {
        user_id: req.user.id,
        store_id: null,
        action: 'update_subscription',
        detail: `Update/purchase paket: ${plan} (${status})`
      });

      return response.success(res, { plan, status }, 'Subscription berhasil diupdate');
    } catch (err) {
      return response.error(res, err, 'Gagal update subscription');
    } finally {
      if (conn) await conn.end();
    }
  }
};

module.exports = SubscriptionController;