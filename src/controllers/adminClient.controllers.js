const { getMainConnection, getTenantConnection } = require('../config/db');
const { exec } = require('child_process');
const path = require('path');
const moment = require('moment');

const AdminClientController = {
  // List all clients
  async list(req, res) {
    const conn = await getMainConnection();
    try {
      const [rows] = await conn.query(`
        SELECT 
          o.id, o.business_name, o.email, o.phone, o.created_at,
          o.status AS owner_status,
          c.db_name, c.db_user, c.db_password, c.db_status,
          -- ambil subscription terakhir walau status bukan 'Aktif'
          (SELECT s.plan FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS plan,
          (SELECT s.status FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS subscription_status,
          (SELECT s.start_date FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS start_date,
          (SELECT s.end_date FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS end_date
        FROM owners o
        LEFT JOIN clients c ON o.id = c.owner_id
        ORDER BY o.id DESC
      `);
      res.json({ success: true, data: rows });
    } catch (err) {
      res.status(500).json({ success: false, message: err.message });
    } finally {
      await conn.end();
    }
  },

  // Update client info (plan, masa aktif, dll)
  async update(req, res) {
    const { id } = req.params;
    const { business_name, email, phone, plan, start_date, end_date, status } = req.body;
    const conn = await getMainConnection();
    try {
      // Update owners
      await conn.execute(
        `UPDATE owners SET business_name=?, email=?, phone=? WHERE id=?`,
        [business_name, email, phone, id]
      );
      // Update subscriptions (hanya update yang aktif)
      await conn.execute(
        `UPDATE subscriptions SET plan=?, start_date=?, end_date=?, status=? WHERE owner_id=? AND status='Aktif'`,
        [plan, start_date, end_date, status, id]
      );
      res.json({ success: true, message: 'Client updated.' });
    } catch (err) {
      res.status(500).json({ success: false, message: err.message });
    } finally {
      await conn.end();
    }
  },

  // Delete client (dan database tenant)
  async delete(req, res) {
    const { id } = req.params;
    const conn = await getMainConnection();
    try {
      // Get db_name
      const [[client]] = await conn.query(`SELECT db_name FROM clients WHERE owner_id=?`, [id]);
      if (!client) return res.status(404).json({ success: false, message: 'Client not found.' });

      // Hapus database tenant
      await conn.query(`DROP DATABASE IF EXISTS \`${client.db_name}\``);

      // Hapus data di main DB
      await conn.query(`DELETE FROM clients WHERE owner_id=?`, [id]);
      await conn.query(`DELETE FROM subscriptions WHERE owner_id=?`, [id]);
      await conn.query(`DELETE FROM users WHERE owner_id=?`, [id]);
      await conn.query(`DELETE FROM owners WHERE id=?`, [id]);

      res.json({ success: true, message: 'Client & tenant DB deleted.' });
    } catch (err) {
      res.status(500).json({ success: false, message: err.message });
    } finally {
      await conn.end();
    }
  },

  // (Opsional) Trigger script register_client.js via endpoint (hanya jika ingin)
  async create(req, res) {
    const {
      owner_id, business_name, username, email, phone,
      password, plan, start_date, end_date
    } = req.body;

    // Validasi sederhana
    if (!owner_id || !business_name || !username || !email || !password || !plan || !start_date || !end_date) {
      return res.status(400).json({ success: false, message: 'Data tidak lengkap.' });
    }

    // Path ke script register_client.js
    const scriptPath = path.resolve(__dirname, '../../register_client.js');
    // Buat argumen CLI (atau gunakan child_process.fork untuk passing object)
    const args = [
      '--owner_id', owner_id,
      '--business_name', `"${business_name}"`,
      '--username', `"${username}"`,
      '--email', `"${email}"`,
      '--phone', `"${phone}"`,
      '--password', `"${password}"`,
      '--plan', `"${plan}"`,
      '--start_date', `"${start_date}"`,
      '--end_date', `"${end_date}"`
    ].join(' ');

    exec(`node ${scriptPath} ${args}`, (error, stdout, stderr) => {
      if (error) {
        return res.status(500).json({ success: false, message: 'Gagal membuat client', error: stderr || error.message });
      }
      res.json({ success: true, message: 'Client berhasil dibuat', output: stdout });
    });
  },

    async stats(req, res) {
    const conn = await getMainConnection();
    try {
      // Ambil semua subscriptions & owners
      const [clients] = await conn.query(`
        SELECT o.id, o.business_name, o.email, o.phone, o.created_at,
               s.plan, s.status AS subscription_status, s.start_date, s.end_date
        FROM owners o
        LEFT JOIN subscriptions s ON o.id = s.owner_id AND s.status IN ('Aktif', 'Suspend', 'Expired')
      `);

      const now = moment();
      let total = 0, aktif = 0, suspend = 0, expired = 0, akan_expired = 0;
      const akan_expired_list = [];

      clients.forEach(c => {
        total++;
        if (!c.end_date) return;
        const sisa_hari = moment(c.end_date).diff(now, 'days');
        if (c.subscription_status === 'Aktif') {
          aktif++;
          if (sisa_hari <= 10 && sisa_hari > 0) {
            akan_expired++;
            akan_expired_list.push({ ...c, sisa_hari });
          }
        } else if (c.subscription_status === 'Suspend') {
          suspend++;
        } else if (c.subscription_status === 'Expired' || sisa_hari <= 0) {
          expired++;
        }
      });
        
      res.json({
        success: true,
        data: {
          total,
          aktif,
          suspend,
          expired,
          akan_expired,
          akan_expired_list: akan_expired_list.slice(0, 5) // 5 teratas
        }
      });
    } catch (err) {
      res.status(500).json({ success: false, message: err.message });
    } finally {
      await conn.end();
    }
  },

  async detail(req, res) {
    const { id } = req.params;
    const conn = await getMainConnection();
    try {
      // Ambil data client (owner, client, subscription terakhir)
      const [[client]] = await conn.query(`
        SELECT 
          o.id, o.business_name, o.email, o.phone, o.created_at, o.status AS owner_status,
          c.db_name, c.db_user, c.db_password, c.db_status,
          (SELECT s.plan FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS plan,
          (SELECT s.status FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS subscription_status,
          (SELECT s.start_date FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS start_date,
          (SELECT s.end_date FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS end_date,
          (SELECT s.payment_status FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS payment_status,
          (SELECT s.auto_renew FROM subscriptions s WHERE s.owner_id = o.id ORDER BY s.end_date DESC LIMIT 1) AS auto_renew
        FROM owners o
        LEFT JOIN clients c ON o.id = c.owner_id
        WHERE o.id = ?
        LIMIT 1
      `, [id]);

      if (!client) {
        return res.status(404).json({ success: false, message: 'Client tidak ditemukan.' });
      }
 
      // Statistik user: cek global_users dulu, fallback ke tenant.users
      let total_user = 0, total_user_aktif = 0;
      if (client.db_name) {
        const [[globalCount]] = await conn.query(
          `SELECT COUNT(*) AS cnt FROM global_users WHERE tenant_db = ?`, [client.db_name]
        );
        total_user = globalCount?.cnt || 0;

        // cek apakah kolom is_active ada di global_users
        const [[hasIsActive]] = await conn.query(
          `SELECT COUNT(*) AS cnt FROM INFORMATION_SCHEMA.COLUMNS 
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'global_users' AND COLUMN_NAME = 'is_active'`
        );
        const [[hasStatus]] = await conn.query(
          `SELECT COUNT(*) AS cnt FROM INFORMATION_SCHEMA.COLUMNS 
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'global_users' AND COLUMN_NAME = 'status'`
        );

        if (hasIsActive?.cnt > 0) {
          const [[r]] = await conn.query(
            `SELECT SUM(is_active = 1) AS cnt FROM global_users WHERE tenant_db = ?`, [client.db_name]
          );
          total_user_aktif = r?.cnt || 0;
        } else if (hasStatus?.cnt > 0) {
          const [[r]] = await conn.query(
            `SELECT SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS cnt FROM global_users WHERE tenant_db = ?`, [client.db_name]
          );
          total_user_aktif = r?.cnt || 0;
        } else {
          // coba hitung langsung dari tenant DB users (lebih akurat)
          try {
            const tenantConn = await getTenantConnection(client.db_name);
            const [[hasIsActiveTenant]] = await tenantConn.query(
              `SELECT COUNT(*) AS cnt FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'users' AND COLUMN_NAME = 'is_active'`,
              [client.db_name]
            );
            const [[hasStatusTenant]] = await tenantConn.query(
              `SELECT COUNT(*) AS cnt FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = 'users' AND COLUMN_NAME = 'status'`,
              [client.db_name]
            );
            if (hasIsActiveTenant?.cnt > 0) {
              const [[r]] = await tenantConn.query(`SELECT COUNT(*) AS cnt FROM users WHERE is_active = 1`);
              total_user_aktif = r?.cnt || 0;
            } else if (hasStatusTenant?.cnt > 0) {
              const [[r]] = await tenantConn.query(`SELECT COUNT(*) AS cnt FROM users WHERE status = 'active'`);
              total_user_aktif = r?.cnt || 0;
            } else {
              const [[r]] = await tenantConn.query(`SELECT COUNT(*) AS cnt FROM users`);
              total_user_aktif = r?.cnt || 0;
            }
            await tenantConn.end();
          } catch (e) {
            // ignore, keep fallback values
          }
        }
      }
 
      // Sisa hari
      let sisa_hari = null;
      if (client.end_date) {
        const now = moment();
        sisa_hari = moment(client.end_date).diff(now, 'days');
      }
 
      res.json({
        success: true,
        data: {
          ...client,
          sisa_hari,
          total_user,
          total_user_aktif
         }
       });
     } catch (err) {
       res.status(500).json({ success: false, message: err.message });
     } finally {
       await conn.end();
     }
   }
 };

module.exports = AdminClientController;