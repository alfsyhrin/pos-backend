const { getTenantConnection } = require('../config/db');
const ActivityLogModel = require('../models/activityLog.model');
const { Parser } = require('json2csv');
const ExcelJS = require('exceljs');

function toMySQLDatetime(dt) {
  if (!dt) return null;
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(dt)) return dt;
  const d = new Date(dt);
  if (isNaN(d)) return null;
  return d.toISOString().slice(0, 19).replace('T', ' ');
}

exports.exportData = async (req, res) => {
  let conn;
  try {
    const dbName = req.user.db_name;
    if (!dbName) return res.status(400).json({ success: false, message: 'Tenant DB not found' });
    conn = await getTenantConnection(dbName);

    const type = req.query.type || 'all';
    const format = req.query.format || 'json'; // <-- tambahkan format
    let data = {};

    if (type === 'users' || type === 'all') {
      const [users] = await conn.query('SELECT * FROM users');
      data.users = users;
    }
    if (type === 'products' || type === 'all') {
      const [products] = await conn.query('SELECT * FROM products');
      data.products = products;
    }
    if (type === 'transactions' || type === 'all') {
      const [transactions] = await conn.query('SELECT * FROM transactions');
      const [transaction_items] = await conn.query('SELECT * FROM transaction_items');
      data.transactions = transactions;
      data.transaction_items = transaction_items;
    }

    // Export as JSON
    if (format === 'json') {
      res.setHeader('Content-Disposition', `attachment; filename=backup_${type}_${Date.now()}.json`);
      res.setHeader('Content-Type', 'application/json');
      res.json(data);
    }
    // Export as CSV (per table, zip not implemented here)
    else if (format === 'csv') {
      // Pilih satu tabel saja untuk CSV, atau gabungkan semua jadi satu file
      // Contoh: jika type=products, export products.csv
      let csv, filename;
      if (type === 'users') {
        const parser = new Parser();
        csv = parser.parse(data.users || []);
        filename = 'users.csv';
      } else if (type === 'products') {
        const parser = new Parser();
        csv = parser.parse(data.products || []);
        filename = 'products.csv';
      } else if (type === 'transactions') {
        // Gabungkan transactions dan transaction_items ke dua file CSV (simple: hanya transactions)
        const parser = new Parser();
        csv = parser.parse(data.transactions || []);
        filename = 'transactions.csv';
      } else {
        // Default: export semua tabel sebagai satu file CSV (hanya products sebagai contoh)
        const parser = new Parser();
        csv = parser.parse(data.products || []);
        filename = 'backup.csv';
      }
      res.setHeader('Content-Disposition', `attachment; filename=${filename}`);
      res.setHeader('Content-Type', 'text/csv');
      res.send(csv);
    }
    // Export as Excel
    else if (format === 'excel' || format === 'xlsx') {
      const workbook = new ExcelJS.Workbook();

      // Tambahkan sheet per tabel
      if (data.users) {
        const ws = workbook.addWorksheet('users');
        if (data.users.length > 0) ws.columns = Object.keys(data.users[0]).map(key => ({ header: key, key }));
        data.users.forEach(row => ws.addRow(row));
      }
      if (data.products) {
        const ws = workbook.addWorksheet('products');
        if (data.products.length > 0) ws.columns = Object.keys(data.products[0]).map(key => ({ header: key, key }));
        data.products.forEach(row => ws.addRow(row));
      }
      if (data.transactions) {
        const ws = workbook.addWorksheet('transactions');
        if (data.transactions.length > 0) ws.columns = Object.keys(data.transactions[0]).map(key => ({ header: key, key }));
        data.transactions.forEach(row => ws.addRow(row));
      }
      if (data.transaction_items) {
        const ws = workbook.addWorksheet('transaction_items');
        if (data.transaction_items.length > 0) ws.columns = Object.keys(data.transaction_items[0]).map(key => ({ header: key, key }));
        data.transaction_items.forEach(row => ws.addRow(row));
      }

      res.setHeader('Content-Disposition', `attachment; filename=backup_${type}_${Date.now()}.xlsx`);
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      await workbook.xlsx.write(res);
      res.end();
    } else {
      return res.status(400).json({ success: false, message: 'Format tidak didukung' });
    }

    // Log activity
    await ActivityLogModel.create(conn, {
      user_id: req.user.id,
      store_id: req.user.store_id || null,
      action: 'backup_data',
      detail: 'Backup data dilakukan'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Gagal export data', error: error.message });
  } finally {
    if (conn) await conn.end();
  }
};

exports.importData = async (req, res) => {
  let conn;
  try {
    const dbName = req.user.db_name;
    if (!dbName) return res.status(400).json({ success: false, message: 'Tenant DB not found' });
    conn = await getTenantConnection(dbName);

    // Ambil file JSON dari upload
    if (!req.file) return res.status(400).json({ success: false, message: 'File backup tidak ditemukan' });
    let data;
    try {
      data = JSON.parse(req.file.buffer.toString());
    } catch (e) {
      return res.status(400).json({ success: false, message: 'Format file tidak valid (bukan JSON)' });
    }

    // Import users
    if (data.users) {
      for (const user of data.users) {
        await conn.query(
          `INSERT INTO users (id, owner_id, store_id, name, username, password, role, is_active, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE name=VALUES(name), username=VALUES(username), role=VALUES(role), is_active=VALUES(is_active)`,
          [user.id, user.owner_id, user.store_id, user.name, user.username, user.password, user.role, user.is_active, toMySQLDatetime(user.created_at)]
        );
      }
    }
    // Import products
    if (data.products) {
      for (const product of data.products) {
        await conn.query(
          `INSERT INTO products (id, store_id, name, sku, barcode, price, cost_price, stock, category, description, image_url, is_active, created_at, updated_at, jenis_diskon, nilai_diskon, diskon_bundle_min_qty, diskon_bundle_value, buy_qty, free_qty)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE name=VALUES(name), sku=VALUES(sku), price=VALUES(price), stock=VALUES(stock), is_active=VALUES(is_active)`,
          [
            product.id, product.store_id, product.name, product.sku, product.barcode, product.price, product.cost_price, product.stock,
            product.category, product.description, product.image_url, product.is_active,
            toMySQLDatetime(product.created_at), toMySQLDatetime(product.updated_at),
            product.jenis_diskon, product.nilai_diskon, product.diskon_bundle_min_qty, product.diskon_bundle_value, product.buy_qty, product.free_qty
          ]
        );
      }
    }
    // Import transactions
    if (data.transactions) {
      for (const trx of data.transactions) {
        await conn.query(
          `INSERT INTO transactions (id, store_id, user_id, total_cost, payment_type, payment_method, received_amount, change_amount, customer_name, customer_phone, payment_status, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE total_cost=VALUES(total_cost), payment_status=VALUES(payment_status), updated_at=VALUES(updated_at)`,
          [trx.id, trx.store_id, trx.user_id, trx.total_cost, trx.payment_type, trx.payment_method, trx.received_amount, trx.change_amount, trx.customer_name, trx.customer_phone, trx.payment_status, trx.created_at, trx.updated_at]
        );
      }
    }
    // Import transaction_items
    if (data.transaction_items) {
      for (const item of data.transaction_items) {
        await conn.query(
          `INSERT INTO transaction_items (id, transaction_id, product_id, qty, price, subtotal)
           VALUES (?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE qty=VALUES(qty), price=VALUES(price), subtotal=VALUES(subtotal)`,
          [item.id, item.transaction_id, item.product_id, item.qty, item.price, item.subtotal]
        );
      }
    }

    res.json({ success: true, message: 'Import data berhasil' });

    // Log activity
    await ActivityLogModel.create(conn, {
      user_id: req.user.id,
      store_id: req.user.store_id || null,
      action: 'import_data',
      detail: 'Import data dilakukan'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Gagal import data', error: error.message });
  } finally {
    if (conn) await conn.end();
  }
};

exports.resetData = async (req, res) => {
  let conn;
  try {
    const dbName = req.user.db_name;
    if (!dbName) return res.status(400).json({ success: false, message: 'Tenant DB not found' });
    conn = await getTenantConnection(dbName);

    // Hapus semua data, kecuali owner
    // Urutan penting karena foreign key!
    await conn.query('DELETE FROM transaction_items');
    await conn.query('DELETE FROM transactions');
    await conn.query('DELETE FROM products');
    await conn.query('DELETE FROM users WHERE role != "owner"');
    // Jika ada tabel lain (misal: categories, struck_receipt), tambahkan juga di sini

    res.json({ success: true, message: 'Semua data berhasil direset, kecuali data owner.' });

    // Log activity
    await ActivityLogModel.create(conn, {
      user_id: req.user.id,
      store_id: req.user.store_id || null,
      action: 'reset_data',
      detail: 'Reset data dilakukan'
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Gagal reset data', error: error.message });
  } finally {
    if (conn) await conn.end();
  }
};