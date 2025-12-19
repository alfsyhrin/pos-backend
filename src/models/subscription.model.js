const SubscriptionModel = {
  async getByOwnerId(conn, owner_id) {
    const [rows] = await conn.execute(
      `SELECT plan, status, start_date, end_date FROM subscriptions
       WHERE owner_id = ? ORDER BY end_date DESC LIMIT 1`,
      [owner_id]
    );
    return rows[0] || null;
  }
};

module.exports = SubscriptionModel;