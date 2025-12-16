const mysql = require('mysql2/promise');
const { exec } = require('child_process');
const path = require('path');
const bcrypt = require('bcryptjs'); // Tambahkan ini

// Ganti sesuai konfigurasi servermu
const DB_HOST = 'localhost';
const DB_USER = 'root';
const DB_PASSWORD = 'pipos123';
const DB_NAME = 'kasir_multi_tenant';

async function registerClient({
  owner_id,
  business_name,
  email,
  username,
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
  const [existingOwner] = await conn.query('SELECT id FROM owners WHERE id = ?', [owner_id]);
  if (existingOwner.length === 0) {
    await conn.execute(
      `INSERT INTO owners (id, business_name, email, phone, password) VALUES (?, ?, ?, ?, ?)`,
      [owner_id, business_name, email, phone, hashedPassword]
    );
  } else {
    console.log('Owner already exists in main owners table:', owner_id);
  }

  // 2a. Tambahkan owner ke tabel users (agar bisa login via API user) jika belum ada
  const [existingUser] = await conn.query('SELECT id FROM users WHERE email = ?', [email]);
  if (existingUser.length === 0) {
    await conn.execute(
      `INSERT INTO users (owner_id, store_id, name, username, email, password, role, is_active) VALUES (?, NULL, ?, ?, ?, ?, 'owner', 1)`,
      [owner_id, business_name, username || email, email, hashedPassword]
    );
  } else {
    console.log('Owner user already exists in main users table:', email);
  }
  
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

  // setelah import schema berhasil, tambahkan sinkronisasi owner ke tenant
  const tenantConn = await mysql.createConnection({
    host: DB_HOST,
    user: DB_USER,
    password: DB_PASSWORD,
    database: db_name
  });

  try {
    const [ownerRows] = await tenantConn.query('SELECT id FROM owners WHERE id = ?', [owner_id]);
    if (ownerRows.length === 0) {
      try {
        await tenantConn.execute(
          'INSERT INTO owners (id, name, email, created_at) VALUES (?, ?, ?, NOW())',
          [owner_id, business_name, email]
        );
        console.log('Owner row inserted into tenant owners table:', db_name);
      } catch (err) {
        console.warn('Insert into tenant owners (id,name,email) failed, trying alternative columns:', err.message);
        try {
          await tenantConn.execute(
            'INSERT INTO owners (id, business_name, email, phone, password, created_at) VALUES (?, ?, ?, ?, ?, NOW())',
            [owner_id, business_name, email, phone, hashedPassword]
          );
          console.log('Owner row inserted into tenant owners table (alternative columns):', db_name);
        } catch (err2) {
          console.error('Failed to insert owner into tenant owners table:', err2.message);
        }
      }
    } else {
      console.log('Owner already exists in tenant owners table:', db_name);
    }
  } finally {
    await tenantConn.end();
  }
  // --- end sinkronisasi owner ---
  
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
  owner_id: 1,
  business_name: 'betarak',
  username: "betarak",
  email: 'betarak@gmail.com',
  phone: '081234567899',
  password: '123456', // plain password!
  plan: 'Pro',
  start_date: '2025-12-17',
  end_date: '2026-12-17'
}).catch(err => {
  console.error('Gagal registrasi:', err);
});