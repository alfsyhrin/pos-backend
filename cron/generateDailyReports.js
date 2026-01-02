const { getTenantConnection } = require('../src/config/db');
const owners = require('../src/models/owners'); // atau model client/tenant Anda

async function generateAllDailyReports(date) {
  // Ambil semua tenant/db_name
  const allTenants = await owners.getAllTenants(); // sesuaikan dengan struktur Anda
  for (const tenant of allTenants) {
    const dbName = tenant.db_name;
    const conn = await getTenantConnection(dbName);
    // Ambil semua store di tenant tsb
    const [stores] = await conn.query('SELECT id FROM stores');
    for (const store of stores) {
      // Panggil logic generateDailyReport di atas (atau refactor ke service)
      // ...
    }
    await conn.end();
  }
}

// Jalankan setiap hari jam 23:59
// Bisa pakai node-cron, pm2, atau scheduler lain