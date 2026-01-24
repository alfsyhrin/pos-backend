const { getMainConnection } = require('../config/db');
const SubscriptionModel = require('../models/subscription.model');

module.exports = async function checkSubscription(req, res, next) {
  try {
    const owner_id = req.user.owner_id;
    if (!owner_id) {
      return res.status(403).json({ success: false, message: 'Akses ditolak: owner_id tidak ditemukan.' });
    }
    const conn = await getMainConnection();
    const sub = await SubscriptionModel.getByOwnerId(conn, owner_id);
    await conn.end();

    const now = new Date();
    if (
      !sub ||
      (sub.status && sub.status.toLowerCase() !== 'active') ||
      (sub.end_date && new Date(sub.end_date) < now)
    ) {
      return res.status(403).json({
        success: false,
        message: 'Paket Anda sudah tidak aktif atau sudah expired. Silakan perpanjang langganan.'
      });
    }
    next();
  } catch (err) {
    return res.status(500).json({ success: false, message: 'Gagal validasi subscription', error: err.message });
  }
};