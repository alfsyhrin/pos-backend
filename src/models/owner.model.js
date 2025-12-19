// src/models/owner.model.js
const OwnerModel = {
  async getById(conn, id) {
    const [rows] = await conn.execute(
      'SELECT id, business_name, email, phone, address, created_at FROM owners WHERE id = ?',
      [id]
    );
    return rows[0] || null;
  },
  async updateById(conn, id, data) {
    const { business_name, email, phone, address } = data;
    await conn.execute(
      'UPDATE owners SET business_name=?, email=?, phone=?, address=? WHERE id=?',
      [business_name, email, phone, address, id]
    );
  }
};
module.exports = OwnerModel;