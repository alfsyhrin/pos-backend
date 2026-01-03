const ActivityLogModel = {
  // Insert log aktivitas
  async create(conn, { user_id, store_id, action, detail }) {
    await conn.execute(
      `INSERT INTO activity_logs (user_id, store_id, action, detail, created_at)
       VALUES (?, ?, ?, ?, NOW())`,
      [user_id, store_id, action, detail]
    );
  },

  // Ambil log aktivitas per store (limit default 50)
  async listByStore(conn, store_id, limit = 50) {
    const [rows] = await conn.query(
      `SELECT al.*, u.name AS user_name
       FROM activity_logs al
       LEFT JOIN users u ON al.user_id = u.id
       WHERE al.store_id = ?
       ORDER BY al.created_at DESC
       LIMIT ?`,
      [store_id, limit]
    );
    return rows;
  }
};

module.exports = ActivityLogModel;