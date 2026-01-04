const { getTenantConnection } = require('../config/db');
const ActivityLogModel = require('../models/activityLog.model');
const { Parser } = require('json2csv');
const ExcelJS = require('exceljs');
const { parse } = require('csv-parse/sync'); // perbaiki import
const XLSX = require('xlsx');
const fs = require('fs');
const archiver = require('archiver');
const stream = require('stream');

function toMySQLDatetime(dt) {
  if (!dt) return null;
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(dt)) return dt;
  if (typeof dt === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(dt)) {
    const d = new Date(dt);
    if (isNaN(d)) return null;
    return d.toISOString().slice(0, 19).replace('T', ' ');
  }
  const d = new Date(dt);
  if (isNaN(d)) return null;
  return d.toISOString().slice(0, 19).replace('T', ' ');
}

function excelDateToMySQLDatetime(serial) {
  if (!serial) return null;
  if (typeof serial === 'string' && /^\d{4}-\d{2}-\d{2}/.test(serial)) return serial; // sudah ISO
  if (typeof serial === 'number') {
    // Excel epoch: 1900-01-01
    const utc_days = Math.floor(serial - 25569);
    const utc_value = utc_days * 86400;
    const date_info = new Date(utc_value * 1000);
    // Tambahkan jam, menit, detik dari pecahan
    const fractional_day = serial - Math.floor(serial);
    let totalSeconds = Math.round(86400 * fractional_day);
    const hours = Math.floor(totalSeconds / 3600);
    totalSeconds -= hours * 3600;
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds - minutes * 60;
    date_info.setHours(hours, minutes, seconds, 0);
    // Format ke MySQL
    return date_info.toISOString().slice(0, 19).replace('T', ' ');
  }
  return null;
}

function normalizeNull(val) {
  // Ubah '' atau undefined jadi null, biarkan 0 dan angka tetap
  return (val === '' || val === undefined) ? null : val;
}

function normalizeNumericFields(obj, numericFields) {
  for (const key of numericFields) {
    if (obj[key] === '' || obj[key] === undefined) obj[key] = null;
  }
}

// PATCH: Normalisasi jenis_diskon
function normalizeEnumField(obj, field, validValues) {
  if (!obj[field] || obj[field] === '' || !validValues.includes(obj[field])) {
    obj[field] = null;
  }
}

exports.exportData = async (req, res) => {
  let conn;
  try {
    const dbName = req.user.db_name;
    if (!dbName) return res.status(400).json({ success: false, message: 'Tenant DB not found' });
    conn = await getTenantConnection(dbName);

    // Ambil parameter dari frontend
    let dataParam = (req.query.data || 'all').toLowerCase();
    const typeParam = (req.query.type || 'json').toLowerCase();
    const startDate = req.query.start_date;
    const endDate = req.query.end_date;

    // Multi-data support
    const dataList = dataParam.split(',').map(x => x.trim()).filter(Boolean);

    // Helper untuk filter tanggal
    function buildDateFilter(field) {
      if (startDate && endDate) return `WHERE ${field} BETWEEN '${startDate} 00:00:00' AND '${endDate} 23:59:59'`;
      if (startDate) return `WHERE ${field} >= '${startDate} 00:00:00'`;
      if (endDate) return `WHERE ${field} <= '${endDate} 23:59:59'`;
      return '';
    }

    // Mapping kategori ke query
    const dataMap = {
      'karyawan': async () => {
        const [users] = await conn.query('SELECT * FROM users WHERE role != "owner"');
        return { users };
      },
      'users': async () => {
        const [users] = await conn.query('SELECT * FROM users WHERE role != "owner"');
        return { users };
      },
      'produk': async () => {
        const [products] = await conn.query('SELECT * FROM products');
        return { products };
      },
      'products': async () => {
        const [products] = await conn.query('SELECT * FROM products');
        return { products };
      },
      'transaksi': async () => {
        const [transactions] = await conn.query(`SELECT * FROM transactions ${buildDateFilter('created_at')}`);
        const [transaction_items] = await conn.query(`SELECT * FROM transaction_items`);
        return { transactions, transaction_items };
      },
      'transactions': async () => {
        const [transactions] = await conn.query(`SELECT * FROM transactions ${buildDateFilter('created_at')}`);
        const [transaction_items] = await conn.query(`SELECT * FROM transaction_items`);
        return { transactions, transaction_items };
      },
      'item_transaksi': async () => {
        const [transaction_items] = await conn.query('SELECT * FROM transaction_items');
        return { transaction_items };
      },
      'transaction_items': async () => {
        const [transaction_items] = await conn.query('SELECT * FROM transaction_items');
        return { transaction_items };
      },
      'pelanggan': async () => {
        const [customers] = await conn.query('SELECT * FROM customers');
        return { customers };
      },
      'customers': async () => {
        const [customers] = await conn.query('SELECT * FROM customers');
        return { customers };
      }
    };

    let data = {};

    if (dataParam === 'all') {
      // Semua data
      const [users] = await conn.query('SELECT * FROM users');
      const [products] = await conn.query('SELECT * FROM products');
      const [transactions] = await conn.query(`SELECT * FROM transactions ${buildDateFilter('created_at')}`);
      const [transaction_items] = await conn.query(`SELECT * FROM transaction_items`);
      data = { users, products, transactions, transaction_items };
    } else if (dataList.length > 1) {
      // Multi-data, hasilkan ZIP
      for (const key of dataList) {
        if (dataMap[key]) {
          const result = await dataMap[key]();
          Object.assign(data, result);
        }
      }
      if (Object.keys(data).length === 0) {
        return res.status(400).json({ success: false, message: 'Data kategori tidak didukung' });
      }
      // ZIP export
      res.setHeader('Content-Disposition', `attachment; filename=backup_multi_${typeParam}_${Date.now()}.zip`);
      res.setHeader('Content-Type', 'application/zip');
      const archive = archiver('zip');
      archive.pipe(res);

      for (const [table, rows] of Object.entries(data)) {
        let buffer, filename;
        if (typeParam === 'excel' || typeParam === 'xlsx') {
          const workbook = new ExcelJS.Workbook();
          const ws = workbook.addWorksheet(table);
          if (rows.length > 0) ws.columns = Object.keys(rows[0]).map(key => ({ header: key, key }));
          rows.forEach(row => ws.addRow(row));
          buffer = await workbook.xlsx.writeBuffer();
          filename = `${table}.xlsx`;
        } else if (typeParam === 'csv') {
          const parser = new Parser();
          const csv = parser.parse(rows || []);
          buffer = Buffer.from(csv, 'utf-8');
          filename = `${table}.csv`;
        } else if (typeParam === 'json') {
          buffer = Buffer.from(JSON.stringify(rows, null, 2), 'utf-8');
          filename = `${table}.json`;
        }
        archive.append(buffer, { name: filename });
      }
      archive.finalize();
      await ActivityLogModel.create(conn, {
        user_id: req.user.id,
        store_id: req.user.store_id || null,
        action: 'backup_data',
        detail: `Backup data kategori ${dataList.join(',')} dalam format zip (${typeParam})`
      });
      return;
    } else if (dataMap[dataParam]) {
      // Single data
      data = await dataMap[dataParam]();
    } else {
      return res.status(400).json({ success: false, message: 'Data kategori tidak didukung' });
    }

    // === SINGLE FILE EXPORT ===
    if (typeParam === 'json') {
      res.setHeader('Content-Disposition', `attachment; filename=backup_${dataParam}_${Date.now()}.json`);
      res.setHeader('Content-Type', 'application/json');
      res.json(data);
    } else if (typeParam === 'csv') {
      const tableName = Object.keys(data)[0];
      const parser = new Parser();
      const csv = parser.parse(data[tableName] || []);
      res.setHeader('Content-Disposition', `attachment; filename=${tableName}_${Date.now()}.csv`);
      res.setHeader('Content-Type', 'text/csv');
      res.send(csv);
    } else if (typeParam === 'excel' || typeParam === 'xlsx') {
      const workbook = new ExcelJS.Workbook();
      for (const [table, rows] of Object.entries(data)) {
        const ws = workbook.addWorksheet(table);
        if (rows.length > 0) ws.columns = Object.keys(rows[0]).map(key => ({ header: key, key }));
        rows.forEach(row => ws.addRow(row));
      }
      res.setHeader('Content-Disposition', `attachment; filename=backup_${dataParam}_${Date.now()}.xlsx`);
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      await workbook.xlsx.write(res);
      res.end();
    } else {
      return res.status(400).json({ success: false, message: 'Format file tidak didukung' });
    }

    // Log activity
    await ActivityLogModel.create(conn, {
      user_id: req.user.id,
      store_id: req.user.store_id || null,
      action: 'backup_data',
      detail: `Backup data kategori ${dataParam} dalam format ${typeParam}`
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Gagal export data', error: error.message });
  } finally {
    if (conn) await conn.end();
  }
};

exports.importData = async (req, res) => {
  let conn;
  let importLogId = null;
  try {
    const dbName = req.user.db_name;
    if (!dbName) return res.status(400).json({ success: false, message: 'Tenant DB not found' });
    conn = await getTenantConnection(dbName);

    if (!req.file) return res.status(400).json({ success: false, message: 'File backup tidak ditemukan' });

    // Catat log import (status pending)
    const [result] = await conn.query(
      `INSERT INTO import_logs (store_id, user_id, filename, size, status) VALUES (?, ?, ?, ?, ?)`,
      [req.user.store_id, req.user.id, req.file.originalname, req.file.size, 'pending']
    );
    importLogId = result.insertId;

    let data;
    const mimetype = req.file.mimetype;
    const originalname = req.file.originalname.toLowerCase();

    // === JSON ===
    if (originalname.endsWith('.json')) {
      try {
        data = JSON.parse(req.file.buffer.toString());
      } catch (e) {
        return res.status(400).json({ success: false, message: 'Format file tidak valid (bukan JSON)' });
      }
    }
    // === CSV ===
    else if (originalname.endsWith('.csv')) {
      const csvRows = parse(req.file.buffer.toString(), { columns: true, skip_empty_lines: true });
      // Deteksi tipe dari nama file
      if (originalname.includes('product')) data = { products: csvRows };
      else if (originalname.includes('user')) data = { users: csvRows };
      else if (originalname.includes('transaction_item')) data = { transaction_items: csvRows };
      else if (originalname.includes('transaction')) data = { transactions: csvRows };
      else {
        // Fallback: deteksi dari kolom
        const columns = Object.keys(csvRows[0] || {});
        if (columns.includes('price') && columns.includes('stock')) data = { products: csvRows };
        else if (columns.includes('username') && columns.includes('role')) data = { users: csvRows };
        else if (columns.includes('total_cost') && columns.includes('payment_type')) data = { transactions: csvRows };
        else if (columns.includes('qty') && columns.includes('price') && columns.includes('transaction_id')) data = { transaction_items: csvRows };
        else return res.status(400).json({ success: false, message: 'Tidak bisa mendeteksi tipe data CSV. Pastikan nama file atau kolom sesuai.' });
      }
    }
    // === Excel/XLSX ===
    else if (originalname.endsWith('.xlsx') || originalname.endsWith('.xls')) {
      const workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
      data = {};
      workbook.SheetNames.forEach(sheetName => {
        const rows = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName]);
        if (sheetName.toLowerCase().includes('product')) data.products = rows;
        else if (sheetName.toLowerCase().includes('user')) data.users = rows;
        else if (sheetName.toLowerCase().includes('transaction_item')) data.transaction_items = rows;
        else if (sheetName.toLowerCase().includes('transaction')) data.transactions = rows;
      });
    }
    else {
      return res.status(400).json({ success: false, message: 'Format file tidak didukung (hanya .json, .csv, .xlsx)' });
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
      const numericFields = [
        'price', 'cost_price', 'stock', 'nilai_diskon', 'diskon_bundle_min_qty',
        'diskon_bundle_value', 'buy_qty', 'free_qty'
      ];
      for (const product of data.products) {
        normalizeNumericFields(product, numericFields);
        normalizeEnumField(product, 'jenis_diskon', ['percentage', 'nominal', 'buyxgety']);
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
          [trx.id, trx.store_id, trx.user_id, trx.total_cost, trx.payment_type, trx.payment_method, trx.received_amount, trx.change_amount, trx.customer_name, trx.customer_phone, trx.payment_status, toMySQLDatetime(trx.created_at), toMySQLDatetime(trx.updated_at)]
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

    // Jika sukses, update status ke success
    await conn.query(`UPDATE import_logs SET status='success' WHERE id=?`, [importLogId]);

    res.json({ success: true, message: 'Import data berhasil' });

    // Log activity
    await ActivityLogModel.create(conn, {
      user_id: req.user.id,
      store_id: req.user.store_id || null,
      action: 'import_data',
      detail: 'Import data dilakukan'
    });
  } catch (error) {
    // Jika gagal, update status ke failed
    if (conn && importLogId) {
      await conn.query(`UPDATE import_logs SET status='failed' WHERE id=?`, [importLogId]);
    }
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

exports.importHistory = async (req, res) => {
  let conn;
  try {
    const dbName = req.user.db_name;
    if (!dbName) return res.status(400).json({ success: false, message: 'Tenant DB not found' });
    conn = await getTenantConnection(dbName);

    const [rows] = await conn.query(
      `SELECT filename, size, created_at as date, status FROM import_logs WHERE store_id=? ORDER BY created_at DESC LIMIT 50`,
      [req.user.store_id]
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ success: false, message: 'Gagal mengambil riwayat import', error: error.message });
  } finally {
    if (conn) await conn.end();
  }
};

exports.importStats = async (req, res) => {
  let conn;
  try {
    const dbName = req.user.db_name;
    if (!dbName) return res.status(400).json({ success: false, message: 'Tenant DB not found' });
    conn = await getTenantConnection(dbName);

    const [[stats]] = await conn.query(
      `SELECT COUNT(*) as total_files,
              SUM(size) as total_size,
              SUM(status='success') as success_count,
              MAX(created_at) as last_import
         FROM import_logs WHERE store_id=?`,
      [req.user.store_id]
    );
    res.json({
      total_files: stats.total_files || 0,
      success_count: stats.success_count || 0,
      total_size: stats.total_size || 0,
      last_import: stats.last_import
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Gagal mengambil statistik import', error: error.message });
  } finally {
    if (conn) await conn.end();
  }
};