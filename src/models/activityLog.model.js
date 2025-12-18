const ActivityLogModel = {
  async create(conn, { user_id, store_id, action, detail }) {
    await conn.execute(
      `INSERT INTO activity_logs (user_id, store_id, action, detail) VALUES (?, ?, ?, ?)`,
      [user_id, store_id, action, detail]
    );
  },
  async listByStore(conn, store_id, limit = 50) {
    const [rows] = await conn.execute(
      `SELECT l.*, u.name as user_name FROM activity_logs l
       LEFT JOIN users u ON l.user_id = u.id
       WHERE l.store_id = ?
       ORDER BY l.created_at DESC
       LIMIT ?`,
      [store_id, limit]
    );
    return rows;
  }
};
module.exports = ActivityLogModel;