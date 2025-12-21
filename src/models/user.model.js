const { pool } = require('./config/db');
const bcrypt = require('bcryptjs');

const UserModel = {
    // Find user by username (for login)
    async findByUsername(conn, username) {
        const [rows] = await conn.execute(
            'SELECT * FROM users WHERE username = ?',
            [username]
        );
        return rows[0] || null;
    },

    // Find user by email (for owner login, database utama)
    async findOwnerByEmail(email) {
        // Tetap pakai pool global, karena owner login ke db utama
        const pool = require('./config/db');
        const [rows] = await pool.execute(
            'SELECT * FROM users WHERE email = ? AND role = "owner"',
            [email]
        );
        return rows[0] || null;
    },

    // Find user by ID (tenant)
    async findById(conn, id) {
        const [rows] = await conn.execute(`SELECT * FROM users WHERE id = ?`, [id]);
        return rows[0] || null;
    },

    // List user by store (tenant)
    async findByStore(conn, store_id) {
        const [rows] = await conn.execute(
            `SELECT * FROM users WHERE store_id = ? AND is_active = 1 AND role IN ('admin','cashier')`,
            [store_id]
        );
        return rows;
    },

    // List semua user milik owner (semua toko)
    async findAllByOwner(conn, owner_id) {
        const [rows] = await conn.execute(
            `SELECT * FROM users WHERE owner_id = ? AND is_active = 1 AND role IN ('admin','cashier')`,
            [owner_id]
        );
        return rows;
    },

    // Create user (tenant)
    async create(conn, data) {
        const [result] = await conn.execute(
            `INSERT INTO users (owner_id, store_id, name, username, password, role, is_active) VALUES (?, ?, ?, ?, ?, ?, 1)`,
            [data.owner_id, data.store_id, data.name, data.username, data.password, data.role]
        );
        return result.insertId;
    },

    // Update user by id (tenant)
    async update(conn, id, data) {
        const fields = [];
        const values = [];
        for (const key in data) {
            if (data[key] !== undefined) {
                fields.push(`${key} = ?`);
                values.push(data[key]);
            }
        }
        if (fields.length === 0) return;
        values.push(id);
        await conn.execute(
            `UPDATE users SET ${fields.join(', ')} WHERE id = ?`,
            values
        );
    },

    // Hitung jumlah user per role di store tertentu
    async countByRole(conn, store_id, role) {
        const [rows] = await conn.execute(
            `SELECT COUNT(*) AS total FROM users WHERE store_id = ? AND role = ? AND is_active = 1`,
            [store_id, role]
        );
        return rows[0].total || 0;
    },
};

module.exports = UserModel;