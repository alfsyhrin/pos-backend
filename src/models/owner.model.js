// src/models/owner.model.js
const OwnerModel = {
  async getById(conn, id) {
    const [rows] = await conn.execute(
      'SELECT id, business_name, email, phone, address, created_at FROM owners WHERE id = ?',
      [id]
    );
    return rows[0] || null;
  }
};
module.exports = OwnerModel;