const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const UserModel = require('../models/user.model');
const ActivityLogModel = require('../models/activityLog.model');
const db = require('../config/db'); // pool
const { getTenantConnection } = require('../config/db');

const AuthController = {
  async login(req, res) {
    let tenantConn;
    try {
      const { identifier, password, owner_id: ownerIdFromBody } = req.body;
      if (!identifier || !password) return res.status(400).json({ success: false, message: 'Identifier dan password harus diisi' });

      let user = null;
      let db_name = null;
      let userType = 'user';
      let ownerIdForToken = null;

      // 1. Cek di database utama dulu
      if (identifier.includes('@')) {
        // Owner login by email
        const [mainUserRows] = await db.query('SELECT * FROM users WHERE email = ?', [identifier]);
        if (mainUserRows.length > 0) {
          user = mainUserRows[0];
          userType = user.role;
          ownerIdForToken = user.owner_id;
          // Cek info tenant
          const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [ownerIdForToken]);
          db_name = clients[0]?.db_name || null;
        }
      } else {
        // Admin login by username
        const [mainUserRows] = await db.query('SELECT * FROM users WHERE username = ?', [identifier]);
        if (mainUserRows.length > 0) {
          user = mainUserRows[0];
          userType = user.role;
          ownerIdForToken = user.owner_id;
          // Cek info tenant
          const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [ownerIdForToken]);
          db_name = clients[0]?.db_name || null;
        }
      }

      // 2. Jika tidak ditemukan di main DB, scan tenant DB seperti sebelumnya
      if (!user && !identifier.includes('@')) {
        let detectedOwnerId = ownerIdFromBody || null;
        if (!detectedOwnerId) {
          const [clients] = await db.query('SELECT owner_id, db_name FROM clients');
          for (const c of clients) {
            let tmpConn;
            try {
              tmpConn = await getTenantConnection(c.db_name);
              const found = await UserModel.findByUsername(tmpConn, identifier);
              if (found) {
                user = found;
                detectedOwnerId = c.owner_id;
                db_name = c.db_name;
                tenantConn = tmpConn;
                tmpConn = null;
                break;
              }
            } catch (err) {
              console.warn(`tenant scan failed for ${c.db_name}: ${err.message}`);
            } finally {
              if (tmpConn) await tmpConn.end();
            }
          }
        }
        if (!user && detectedOwnerId) {
          const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [detectedOwnerId]);
          db_name = clients[0]?.db_name || null;
          if (db_name) {
            tenantConn = await getTenantConnection(db_name);
            user = await UserModel.findByUsername(tenantConn, identifier);
          }
        }
        userType = user?.role || 'user';
        ownerIdForToken = detectedOwnerId || user?.owner_id || null;
      }

      if (!user) return res.status(401).json({ success: false, message: 'Username/email atau password salah' });

      // password check
      const isPasswordValid = await bcrypt.compare(password, user.password);
      if (!isPasswordValid) return res.status(401).json({ success: false, message: 'Username/email atau password salah' });

      // Ambil plan dari user, atau dari tabel subscriptions jika perlu
      let plan = user.plan;
      if (!plan && ownerIdForToken) {
        const [subs] = await db.query('SELECT plan FROM subscriptions WHERE owner_id = ? AND status = "Aktif" ORDER BY end_date DESC LIMIT 1', [ownerIdForToken]);
        plan = subs[0]?.plan || 'Standard';
      }

      const payload = {
        id: user.id,
        owner_id: ownerIdForToken,
        store_id: user.store_id || null,
        role: user.role || userType,
        username: user.username || user.email,
        name: user.name || user.business_name,
        email: user.email || null,
        db_name,
        plan
      };

      const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRE || '7d' });

      // Log aktivitas login
      if (!tenantConn && db_name) {
        tenantConn = await getTenantConnection(db_name);
      }
      if (tenantConn) {
        await ActivityLogModel.create(tenantConn, {
          user_id: user.id,
          store_id: user.store_id,
          action: 'login',
          detail: 'Login berhasil'
        });
      }

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
  },

  // ==================== TAMBAHKAN METHOD LOGOUT ====================
  async logout(req, res) {
    try {
      const user = req.user;
      
      // Log aktivitas logout ke database tenant
      if (user.db_name) {
        let tenantConn;
        try {
          tenantConn = await getTenantConnection(user.db_name);
          await ActivityLogModel.create(tenantConn, {
            user_id: user.id,
            store_id: user.store_id,
            action: 'logout',
            detail: 'User logout dari sistem'
          });
        } catch (logError) {
          console.error('Gagal mencatat aktivitas logout:', logError);
          // Lanjutkan proses logout meskipun log gagal
        } finally {
          if (tenantConn) await tenantConn.end();
        }
      }
      
      // Catat juga di log server
      console.log(`User ${user.username} (ID: ${user.id}, Role: ${user.role}) logout pada ${new Date().toISOString()}`);
      
      res.json({ 
        success: true, 
        message: 'Logout berhasil',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Logout error:', error);
      res.status(500).json({ 
        success: false, 
        message: 'Terjadi kesalahan saat logout',
        error: error.message 
      });
    }
  }
  // ==================== END OF LOGOUT METHOD ====================
};

module.exports = AuthController;