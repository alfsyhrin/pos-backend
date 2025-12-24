const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const UserModel = require('../models/user.model');
const ActivityLogModel = require('../models/activityLog.model');
const db = require('../config/db');
const { getTenantConnection, databaseExists } = require('../config/db');

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
              // CEK DULU ADA NGGAK
              const exists = await databaseExists(c.db_name);
              if (!exists) continue;
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
            const exists = await databaseExists(db_name);
            if (exists) {
              tenantConn = await getTenantConnection(db_name);
              user = await UserModel.findByUsername(tenantConn, identifier);
            }
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

      // --- PENYESUAIAN: Ambil data bisnis/toko sesuai role ---
      let business_name = null;
      let store_name = null;
      if (user.role === 'owner' && ownerIdForToken) {
        const [owners] = await db.query('SELECT business_name, email FROM owners WHERE id = ?', [ownerIdForToken]);
        if (owners.length > 0) {
          business_name = owners[0].business_name;
          user.email = owners[0].email; // pastikan email owner konsisten
        }
      }
      if ((user.role === 'admin' || user.role === 'cashier') && user.store_id && db_name) {
        try {
          const exists = await databaseExists(db_name);
          if (exists) {
            tenantConn = await getTenantConnection(db_name);
            const [stores] = await tenantConn.query('SELECT name FROM stores WHERE id = ?', [user.store_id]);
            if (stores.length > 0) store_name = stores[0].name;
          }
        } catch (e) { /* ignore */ }
      }

      // --- END PENYESUAIAN ---

      // --- Ambil daftar store milik owner jika role owner ---
      let stores = [];
      let store_id = null;
      // let store_name = null;
      if (user.role === 'owner' && ownerIdForToken) {
        // 1. Cek di tenant DB jika ada
        if (db_name) {
          try {
            const exists = await databaseExists(db_name);
            if (exists) {
              const tenantConn = await getTenantConnection(db_name);
              const [storeRows] = await tenantConn.query('SELECT id, name FROM stores WHERE owner_id = ?', [ownerIdForToken]);
              stores = storeRows.map(s => ({ id: s.id, name: s.name }));
              await tenantConn.end();
            }
          } catch (e) { /* ignore */ }
        }
        // 2. Fallback ke main DB jika tidak ada di tenant DB
        if (!stores.length) {
          const [storeRows] = await db.query('SELECT id, name FROM stores WHERE owner_id = ?', [ownerIdForToken]);
          stores = storeRows.map(s => ({ id: s.id, name: s.name }));
        }
        // --- Jika hanya ada satu store, isi store_id dan store_name di payload ---
        if (stores.length === 1) {
          store_id = stores[0].id;
          store_name = stores[0].name;
        }
      }

      // --- END AMBIL STORES ---

      const payload = {
        id: user.id,
        owner_id: ownerIdForToken,
        store_id: store_id || user.store_id || null,
        role: user.role || userType,
        username: user.username || user.email,
        name: user.name || user.business_name,
        email: user.email || null,
        db_name,
        plan,
        business_name, // untuk owner
        store_name: store_name || null, // untuk owner/admin/kasir
        stores // array of {id, name}
      };

      const token = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRE || '7d' });

      // Log aktivitas login
      if (!tenantConn && db_name) {
        try {
          const exists = await databaseExists(db_name);
          if (exists) {
            tenantConn = await getTenantConnection(db_name);
          } else {
            tenantConn = null;
          }
        } catch (e) {
          tenantConn = null; // Jangan error, lanjutkan saja
        }
      }
      if (tenantConn) {
        await ActivityLogModel.create(tenantConn, {
          user_id: user.id,
          store_id: user.store_id,
          action: 'login',
          detail: 'Login berhasil'
        });
      }

      // Tambahkan stores ke response jika owner
      if (user.role === 'owner') {
        res.json({ success: true, message: 'Login berhasil', token, user: payload, stores });
      } else {
        res.json({ success: true, message: 'Login berhasil', token, user: payload });
      }
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ success: false, message: 'Terjadi kesalahan server', error: error.message });
    } finally {
      if (tenantConn) await tenantConn?.end();
    }
  },

  async getProfile(req, res) {
    let user = req.user;
    let business_name = user.business_name || null;
    let store_name = user.store_name || null;

    // Ambil business_name jika owner
    if (user.role === 'owner' && user.owner_id) {
      const [owners] = await db.query('SELECT business_name, email FROM owners WHERE id = ?', [user.owner_id]);
      if (owners.length > 0) {
        business_name = owners[0].business_name;
        user.email = owners[0].email;
      }
    }

    // Ambil store_name jika admin/kasir
    if ((user.role === 'admin' || user.role === 'cashier') && user.store_id) {
      let storeRow = null;
      // 1. Cek di tenant DB jika ada db_name
      if (user.db_name) {
        try {
          const exists = await databaseExists(user.db_name);
          if (exists) {
            const tenantConn = await getTenantConnection(user.db_name);
            const [stores] = await tenantConn.query('SELECT name FROM stores WHERE id = ?', [user.store_id]);
            if (stores.length > 0) storeRow = stores[0];
            await tenantConn.end();
          }
        } catch (e) { /* ignore */ }
      }
      // 2. Fallback ke main DB jika tidak ketemu di tenant DB
      if (!storeRow) {
        try {
          const [stores] = await db.query('SELECT name FROM stores WHERE id = ?', [user.store_id]);
          if (stores.length > 0) storeRow = stores[0];
        } catch (e) { /* ignore */ }
      }
      // 3. Jika tetap tidak ketemu, isi dengan string kosong
      store_name = storeRow ? storeRow.name : '';
    }

    // Build response sesuai role
    let profile = {
      id: user.id,
      role: user.role,
      owner_id: user.owner_id,
      store_id: user.store_id,
      username: user.username,
      email: user.email,
      plan: user.plan
    };
    if (user.role === 'owner') {
      profile.business_name = business_name;
    }
    if (user.role === 'admin' || user.role === 'cashier') {
      profile.store_name = store_name;
    }

    res.json({ success: true, message: 'Profil user', user: profile });
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