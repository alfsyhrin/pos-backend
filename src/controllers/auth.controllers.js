const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const UserModel = require('../models/user.model');
const db = require('../config/db'); // pool
const { getTenantConnection } = require('../config/db');

const AuthController = {
  async login(req, res) {
    let tenantConn;
    try {
      const { identifier, password, owner_id } = req.body;
      if (!identifier || !password) return res.status(400).json({ success: false, message: 'Identifier dan password harus diisi' });

      let user = null;
      let db_name = null;
      let userType = 'user';

      if (identifier.includes('@')) {
        user = await UserModel.findOwnerByEmail(identifier);
        userType = 'owner';
        if (user) {
          const ownerIdForClient = user.owner_id || user.id;
          const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [ownerIdForClient]);
          db_name = clients[0]?.db_name || null;

          if (!db_name) {
            const expectedDb = `kasir_tenant_${ownerIdForClient}`;
            const [dbRows] = await db.query('SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ?', [expectedDb]);
            if (dbRows.length) {
              db_name = expectedDb;
              console.warn(`Login fallback: found DB ${expectedDb} but no clients entry for owner_id=${ownerIdForClient}. Consider running register_client to persist clients row.`);
            } else {
              console.warn(`No clients row and no DB for owner_id=${ownerIdForClient}`);
            }
          }
        }
      } else {
        if (!owner_id) return res.status(400).json({ success: false, message: 'owner_id harus diisi untuk login admin/kasir' });
        const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [owner_id]);
        db_name = clients[0]?.db_name || null;
        if (!db_name) return res.status(404).json({ success: false, message: 'Tenant tidak ditemukan' });

        tenantConn = await getTenantConnection(db_name);
        user = await UserModel.findByUsername(tenantConn, identifier);
        userType = user?.role || 'user';
      }

      if (!user) return res.status(401).json({ success: false, message: 'Username/email atau password salah' });

      const isPasswordValid = await bcrypt.compare(password, user.password);
      if (!isPasswordValid) return res.status(401).json({ success: false, message: 'Username/email atau password salah' });

      const ownerIdForToken = user.owner_id || user.id;
      const payload = {
        id: user.id,
        owner_id: ownerIdForToken,
        store_id: user.store_id || null,
        role: user.role || userType,
        username: user.username || user.email,
        name: user.name || user.business_name,
        email: user.email || null,
        db_name
      };

      const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRE || '7d' });
      res.json({ success: true, message: 'Login berhasil', token, user: payload });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ success: false, message: 'Terjadi kesalahan server', error: error.message });
    } finally {
      if (tenantConn) await tenantConn?.end();
    }
  },

  async getProfile(req, res) {
    res.json({ success: true, message: 'Profil user', user: req.user });
  },

  async testProtected(req, res) {
    res.json({ success: true, message: 'Akses endpoint protected berhasil', user: req.user });
  }
};

module.exports = AuthController;