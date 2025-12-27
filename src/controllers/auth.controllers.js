const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const UserModel = require('../models/user.model');
const ActivityLogModel = require('../models/activityLog.model');
const db = require('../config/db');
const { getTenantConnection, databaseExists } = require('../config/db');

const AuthController = {

  /* =====================================================
     LOGIN
  ===================================================== */
  async login(req, res) {
    let tenantConn;
    try {
      const { identifier, password, owner_id } = req.body;

      if (!identifier || !password) {
        return res.status(400).json({
          success: false,
          message: 'Identifier dan password harus diisi'
        });
      }

      let user = null;
      let db_name = null;
      let ownerIdForToken = null;
      let store_name = null;
      let business_name = null;
      let stores = [];

      /* ================= OWNER LOGIN ================= */
      if (identifier.includes('@')) {
        const [rows] = await db.query(
          'SELECT * FROM users WHERE email = ? AND role = "owner"',
          [identifier]
        );

        if (!rows.length) {
          return res.status(401).json({ success: false, message: 'Email atau password salah' });
        }

        user = rows[0];
        ownerIdForToken = user.owner_id;

        const [clients] = await db.query(
          'SELECT db_name FROM clients WHERE owner_id = ?',
          [ownerIdForToken]
        );

        db_name = clients[0]?.db_name || null;
      }

      /* ================= ADMIN / CASHIER LOGIN ================= */
      else {
        if (!owner_id) {
          return res.status(400).json({
            success: false,
            message: 'owner_id wajib untuk login admin/kasir'
          });
        }

        const [clients] = await db.query(
          'SELECT db_name FROM clients WHERE owner_id = ?',
          [owner_id]
        );

        db_name = clients[0]?.db_name;

        if (!db_name || !(await databaseExists(db_name))) {
          return res.status(400).json({
            success: false,
            message: 'Database tenant tidak ditemukan'
          });
        }

        tenantConn = await getTenantConnection(db_name);
        user = await UserModel.findByUsername(tenantConn, identifier);

        if (!user) {
          return res.status(401).json({
            success: false,
            message: 'Username atau password salah'
          });
        }

        ownerIdForToken = user.owner_id;
      }

      /* ================= PASSWORD CHECK ================= */
      const valid = await bcrypt.compare(password, user.password);
      if (!valid) {
        return res.status(401).json({
          success: false,
          message: 'Username/email atau password salah'
        });
      }

      /* ================= PLAN ================= */
      let plan = user.plan;
      if (!plan && ownerIdForToken) {
        const [subs] = await db.query(
          `SELECT plan FROM subscriptions
           WHERE owner_id = ? AND status = "Aktif"
           ORDER BY end_date DESC LIMIT 1`,
          [ownerIdForToken]
        );
        plan = subs[0]?.plan || 'Standard';
      }

      /* ================= DATA TAMBAHAN ================= */
      if (user.role === 'owner') {
        const [owners] = await db.query(
          'SELECT business_name FROM owners WHERE id = ?',
          [ownerIdForToken]
        );
        business_name = owners[0]?.business_name || null;

        if (db_name && await databaseExists(db_name)) {
          const conn = await getTenantConnection(db_name);
          const [storeRows] = await conn.query(
            'SELECT id, name FROM stores WHERE owner_id = ?',
            [ownerIdForToken]
          );
          stores = storeRows;
          await conn.end();
        }
      }

      if ((user.role === 'admin' || user.role === 'cashier') && tenantConn) {
        const [rows] = await tenantConn.query(
          'SELECT name FROM stores WHERE id = ?',
          [user.store_id]
        );
        store_name = rows[0]?.name || null;
      }

      /* ================= JWT ================= */
      const payload = {
        id: user.id,
        owner_id: ownerIdForToken,
        store_id: user.store_id || null,
        role: user.role,
        username: user.username,
        email: user.email,
        db_name,
        plan,
        business_name,
        store_name,
        stores
      };

      const token = jwt.sign(
        payload,
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRE || '7d' }
      );

      /* ================= LOG ================= */
      if (tenantConn) {
        await ActivityLogModel.create(tenantConn, {
          user_id: user.id,
          store_id: user.store_id,
          action: 'login',
          detail: 'Login berhasil'
        });
      }

      res.json({
        success: true,
        message: 'Login berhasil',
        token,
        user: payload
      });

    } catch (err) {
      console.error('LOGIN ERROR:', err);
      res.status(500).json({
        success: false,
        message: 'Terjadi kesalahan server'
      });
    } finally {
      if (tenantConn) await tenantConn.end();
    }
  },

  /* =====================================================
     GET PROFILE (WAJIB ADA)
  ===================================================== */
  async getProfile(req, res) {
    res.json({
      success: true,
      user: req.user
    });
  },

  /* =====================================================
     TEST PROTECTED
  ===================================================== */
  async testProtected(req, res) {
    res.json({
      success: true,
      message: 'Token valid',
      user: req.user
    });
  },

  /* =====================================================
     LOGOUT (STATELESS)
  ===================================================== */
  async logout(req, res) {
    res.json({
      success: true,
      message: 'Logout berhasil'
    });
  }
};

module.exports = AuthController;
