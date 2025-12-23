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

      if (identifier.includes('@')) {
        // owner login by email (unchanged)
        user = await UserModel.findOwnerByEmail(identifier);
        userType = 'owner';
        if (user) {
          const ownerIdForClient = user.owner_id || user.id;
          const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [ownerIdForClient]);
          db_name = clients[0]?.db_name || null;
          if (!db_name) {
            const expectedDb = `kasir_tenant_${ownerIdForClient}`;
            const [dbRows] = await db.query('SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ?', [expectedDb]);
            if (dbRows.length) db_name = expectedDb;
          }
          ownerIdForToken = user.owner_id || user.id;
        }
      } else {
        // username login (admin/kasir)
        let detectedOwnerId = ownerIdFromBody || null;

        if (!detectedOwnerId) {
          // scan clients to find which tenant has this username
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
                tenantConn = tmpConn; // keep open for password check and further queries
                tmpConn = null; // prevent double-close
                break;
              }
            } catch (err) {
              console.warn(`tenant scan failed for ${c.db_name}: ${err.message}`);
            } finally {
              if (tmpConn) await tmpConn.end();
            }
          }
        }

        // if still not found but owner_id provided, use that
        if (!user && detectedOwnerId) {
          const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [detectedOwnerId]);
          db_name = clients[0]?.db_name || null;
          if (db_name) {
            tenantConn = await getTenantConnection(db_name);
            user = await UserModel.findByUsername(tenantConn, identifier);
          }
        }

        // If user still null, return error
        if (!user) {
          console.error('User not found for username:', identifier);
          return res.status(401).json({ success: false, message: 'Username/email atau password salah' });
        }

        userType = user.role || 'user';
        ownerIdForToken = detectedOwnerId || user.owner_id || null;
      }

      // ========== TAMBAHKAN CHECK INI ==========
      // Check if user is still null (for email login case)
      if (!user) {
        console.error('User not found for identifier:', identifier);
        return res.status(401).json({ success: false, message: 'Username/email atau password salah' });
      }

      // password check
      const isPasswordValid = await bcrypt.compare(password, user.password);
      if (!isPasswordValid) {
        console.error('Invalid password for user:', identifier);
        return res.status(401).json({ success: false, message: 'Username/email atau password salah' });
      }

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

      // PATCH: pastikan tenantConn selalu ada sebelum log aktivitas
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

  async logout(req, res) {
    try {
      const user = req.user;
      
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
        } finally {
          if (tenantConn) await tenantConn.end();
        }
      }
      
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
};

module.exports = AuthController;