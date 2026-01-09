const ActivityLogModel = {
  // Insert log aktivitas
  async create(conn, { user_id, store_id = null, action, detail }) {
    await conn.query(
      `INSERT INTO activity_logs (user_id, store_id, action, detail) VALUES (?, ?, ?, ?)`,
      [user_id, store_id, action, detail]
    );
  },

  // Ambil log aktivitas per store dengan pagination
  async listByStorePaginated(conn, store_id, limit = 10, offset = 0) {
    const [rows] = await conn.query(
      `SELECT al.*, u.name AS user_name
       FROM activity_logs al
       LEFT JOIN users u ON al.user_id = u.id
       WHERE al.store_id = ?
       ORDER BY al.created_at DESC
       LIMIT ? OFFSET ?`,
      [store_id, limit, offset]
    );
    return rows;
  },

  // Hitung total log aktivitas per store
  async countByStore(conn, store_id) {
    const [[{ count }]] = await conn.query(
      `SELECT COUNT(*) AS count FROM activity_logs WHERE store_id = ?`,
      [store_id]
    );
    return count;
  }
};

module.exports = ActivityLogModel;
