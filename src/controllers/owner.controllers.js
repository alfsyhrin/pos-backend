// src/controllers/owner.controllers.js
const OwnerModel = require('../models/owner.model');
const response = require('../utils/response');
const { getMainConnection } = require('../config/db');
const ActivityLogModel = require('../models/activityLog.model'); // tambahkan import

const OwnerController = {
  async getOwner(req, res) {
    let conn;
    try {
      conn = await getMainConnection();
      const owner = await OwnerModel.getById(conn, req.params.id);
      if (!owner) return response.notFound(res, 'Owner tidak ditemukan');
      return response.success(res, owner);
    } catch (err) {
      return response.error(res, err, 'Gagal mengambil data owner');
    } finally {
      if (conn) conn.release();
    }
  },

  async updateOwner(req, res) {
    let conn;
    try {
      conn = await getMainConnection();
      const id = req.params.id;

      await OwnerModel.updateById(conn, id, req.body);

      // Logging aktivitas: update owner
const store_id = req.user.store_id || req.body.store_id;
if (!store_id) {
  throw new Error('store_id wajib ada untuk logging');
}

await ActivityLogModel.create(conn, {
  user_id: req.user.id || null,
  store_id,
  action: 'update_owner',
  detail: `Update data owner: ${id}`
});


      const updated = await OwnerModel.getById(conn, id);
      return response.success(res, updated, 'Owner berhasil diupdate');
    } catch (err) {
      return response.error(res, err, 'Gagal update data owner');
    } finally {
      if (conn) conn.release();
    }
  }

};
module.exports = OwnerController;