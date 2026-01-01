// src/models/owner.model.js
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
    const fields = [];
    const values = [];

    for (const [key, value] of Object.entries(data)) {
      if (value !== undefined) {
        fields.push(`${key} = ?`);
        values.push(value);
      }
    }

    // Tidak ada field yang diupdate → hentikan
    if (!fields.length) return;

    values.push(id);

    const sql = `
      UPDATE owners
      SET ${fields.join(', ')}
      WHERE id = ?
    `;

    await conn.execute(sql, values);
  }
};

module.exports = OwnerModel;
