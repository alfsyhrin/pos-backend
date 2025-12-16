module.exports = (req, res, next) => {
  if (!req.user || !req.user.db_name) {
    console.error('checkTenant: missing db_name in token', { user: req.user });
    return res.status(400).json({
      success: false,
      message: 'Tenant database (db_name) tidak ditemukan di token. Pastikan login owner dan gunakan token yang benar.'
    });
  }
  next();
};