const mysql = require('mysql2/promise');
const { exec } = require('child_process');
const path = require('path');
const bcrypt = require('bcryptjs'); // Tambahkan ini

// Ganti sesuai konfigurasi servermu
const DB_HOST = 'localhost';
const DB_USER = 'root';
const DB_PASSWORD = '';
const DB_NAME = 'kasir_multi_tenant';

async function registerClient({
  owner_id,
  business_name,
  email,
  phone,
  password, // Plain password!
  plan,
  start_date,
  end_date
}) {
  const db_name = `kasir_tenant_${owner_id}`;
  const db_user = `user_${owner_id}`;
  const db_password = `pass${Math.floor(Math.random() * 100000)}`;

  // Hash password sebelum simpan ke database
  const hashedPassword = await bcrypt.hash(password, 10);

  // 1. Koneksi ke database utama
  const conn = await mysql.createConnection({
    host: DB_HOST,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME
  });

  // 2. Tambahkan owner ke tabel owners (jika belum ada)
  await conn.execute(
    `INSERT INTO owners (id, business_name, email, phone, password) VALUES (?, ?, ?, ?, ?)`,
    [owner_id, business_name, email, phone, hashedPassword]
  );

  // 2a. Tambahkan owner ke tabel users (agar bisa login via API user)
  await conn.execute(
    `INSERT INTO users (owner_id, store_id, name, username, password, role, is_active) VALUES (?, NULL, ?, ?, ?, 'owner', 1)`,
    [owner_id, business_name, email, hashedPassword]
  );

  // 3. Buat database tenant baru
  await conn.execute(`CREATE DATABASE ${db_name}`);

  // 4. Import schema ke database tenant
  const schemaPath = path.resolve(__dirname, 'kasir_multi_tenant.sql');
  await new Promise((resolve, reject) => {
    exec(
      `mysql -u ${DB_USER} -p${DB_PASSWORD} ${db_name} < ${schemaPath}`,
      (error, stdout, stderr) => {
        if (error) return reject(error);
        resolve();
      }
    );
  });

  // 5. (Opsional) Buat user MySQL khusus tenant
  await conn.execute(`CREATE USER IF NOT EXISTS '${db_user}'@'%' IDENTIFIED BY '${db_password}'`);
  await conn.execute(`GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'%'`);

  // 6. Simpan info tenant ke tabel clients
  await conn.execute(
    `INSERT INTO clients (owner_id, db_name, db_user, db_password) VALUES (?, ?, ?, ?)`,
    [owner_id, db_name, db_user, db_password]
  );

  // 7. Simpan info langganan ke tabel subscriptions
  await conn.execute(
    `INSERT INTO subscriptions (owner_id, status, plan, start_date, end_date) VALUES (?, 'Aktif', ?, ?, ?)`,
    [owner_id, plan, start_date, end_date]
  );

  await conn.end();

  console.log('Registrasi klien & database tenant berhasil!');
  console.log({ db_name, db_user, db_password });
}

// ==== SIMULASI PEMBELIAN MANUAL ====
// Ganti data di bawah sesuai pembeli baru
registerClient({
  owner_id: 3,
  business_name: 'Betarak',
  email: 'betarak@gmail.com',
  phone: '081234567899',
  password: 'password123', // plain password!
  plan: 'Pro',
  start_date: '2025-12-17',
  end_date: '2026-12-17'
}).catch(err => {
  console.error('Gagal registrasi:', err);
});