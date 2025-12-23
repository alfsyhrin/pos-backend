const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

const DB_HOST = 'localhost';
const DB_USER = 'root';
const DB_PASSWORD = 'pipos123';
const DB_NAME = 'kasir_multi_tenant';

async function main() {
  const conn = await mysql.createConnection({
    host: DB_HOST,
    user: DB_USER,
    password: DB_PASSWORD,
    database: DB_NAME
  });

  // 1. Buat Owner (jika belum ada)
  const ownerData = {
    business_name: 'Bisnis 1',
    email: 'abijaya@gmail.com',
    phone: '082349221050',
    password: await bcrypt.hash('Abi1317', 10)
  };
  let [rows] = await conn.query('SELECT id FROM owners WHERE email = ?', [ownerData.email]);
  let owner_id;
  if (rows.length === 0) {
    const [res] = await conn.execute(
      `INSERT INTO owners (business_name, email, phone, password) VALUES (?, ?, ?, ?)`,
      [ownerData.business_name, ownerData.email, ownerData.phone, ownerData.password]
    );
    owner_id = res.insertId;
    console.log('Owner created:', owner_id);
  } else {
    owner_id = rows[0].id;
    console.log('Owner exists:', owner_id);
  }

  // 2. Buat 3 Admin (masing-masing 1 toko, 2 Pro, 1 Standard)
// ...existing code...
  const admins = [
    {
      name: 'Abi 07',
      username: 'admin.abi07',
      email: 'abijaya@gmail.com',
      password: await bcrypt.hash('Abi1317', 10),
      plan: 'Pro'
    },
    {
      name: 'Inayah Beauty Fashion',
      username: 'admin.inayah',
      email: 'inayah@gmail.com',
      password: await bcrypt.hash('Inayah112009', 10),
      plan: 'Standard'
    },
    {
      name: 'Dflowers',
      username: 'admin.dflowers',
      email: 'dflowers@gmail.com',
      password: await bcrypt.hash('Dflowers27', 10),
      plan: 'Standard'
    }
  ];
// ...existing code...

  for (const admin of admins) {
    // Cek user admin
    [rows] = await conn.query('SELECT id FROM users WHERE username = ?', [admin.username]);
    let admin_id;
    if (rows.length === 0) {
      const [res] = await conn.execute(
        `INSERT INTO users (owner_id, name, username, email, password, role, is_active) VALUES (?, ?, ?, ?, ?, 'admin', 1)`,
        [owner_id, admin.name, admin.username, admin.email, admin.password]
      );
      admin_id = res.insertId;
      console.log('Admin created:', admin.username, 'id:', admin_id);
    } else {
      admin_id = rows[0].id;
      console.log('Admin exists:', admin.username, 'id:', admin_id);
    }

    // Buat store untuk admin
    [rows] = await conn.query('SELECT id FROM stores WHERE owner_id = ? AND name = ?', [owner_id, admin.name + ' Store']);
    let store_id;
    if (rows.length === 0) {
      const [res] = await conn.execute(
        `INSERT INTO stores (owner_id, name, type) VALUES (?, ?, 'store')`,
        [owner_id, admin.name + ' Store']
      );
      store_id = res.insertId;
      console.log('Store created:', store_id);
    } else {
      store_id = rows[0].id;
      console.log('Store exists:', store_id);
    }

    // Update admin dengan store_id
    await conn.execute(`UPDATE users SET store_id = ? WHERE id = ?`, [store_id, admin_id]);

    // Buat subscription untuk admin
    [rows] = await conn.query(
      'SELECT id FROM subscriptions WHERE owner_id = ? AND user_id = ? AND plan = ?',
      [owner_id, admin_id, admin.plan]
    );
    if (rows.length === 0) {
      await conn.execute(
        `INSERT INTO subscriptions (owner_id, user_id, status, plan, start_date, end_date) VALUES (?, ?, 'Aktif', ?, NOW(), DATE_ADD(NOW(), INTERVAL 1 YEAR))`,
        [owner_id, admin_id, admin.plan]
      );
      console.log('Subscription created for', admin.username);
    } else {
      console.log('Subscription exists for', admin.username);
    }

    // Buat client DB info (jika perlu, bisa diisi dummy)
    [rows] = await conn.query(
      'SELECT id FROM clients WHERE owner_id = ? AND user_id = ?',
      [owner_id, admin_id]
    );
    if (rows.length === 0) {
      await conn.execute(
        `INSERT INTO clients (owner_id, user_id, db_name, db_user, db_password) VALUES (?, ?, ?, ?, ?)`,
        [owner_id, admin_id, `kasir_tenant_${admin_id}`, `user_${admin_id}`, `pass${Math.floor(Math.random() * 100000)}`]
      );
      console.log('Client DB info created for', admin.username);
    } else {
      console.log('Client DB info exists for', admin.username);
    }
  }

  // 3. Buat user owner di tabel users (role: owner, tidak punya store_id)
  [rows] = await conn.query('SELECT id FROM users WHERE owner_id = ? AND role = "owner"', [owner_id]);
  if (rows.length === 0) {
    await conn.execute(
      `INSERT INTO users (owner_id, name, username, email, password, role, is_active) VALUES (?, ?, ?, ?, ?, 'owner', 1)`,
      [owner_id, 'Owner Monitoring', 'owner', ownerData.email, ownerData.password]
    );
    console.log('Owner user created');
  } else {
    console.log('Owner user exists');
  }

  await conn.end();
  console.log('\n=== Registrasi multi admin case selesai ===');
}

main().catch(err => {
  console.error('Gagal registrasi:', err);
});