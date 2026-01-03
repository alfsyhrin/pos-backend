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
      await ActivityLogModel.create(conn, {
        user_id: req.user.id,
        store_id: req.user.store_id || null,
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