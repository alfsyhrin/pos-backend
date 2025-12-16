const pool = require('../config/db');
const bcrypt = require('bcryptjs');

const UserModel = {
    // Find user by username (for login)
    async findByUsername(username) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM users WHERE username = ?',
                [username]
            );
            return rows[0] || null;
        } catch (error) {
            throw error;
        }
    },

    // Find user by email (for owner login)
    async findOwnerByEmail(email) {
        try {
            const [rows] = await pool.execute(
                'SELECT * FROM users WHERE email = ? AND role = "owner"',
                [email]
            );
            return rows[0] || null;
        } catch (error) {
            throw error;
        }
    },


    // Compare password
    async comparePassword(inputPassword, hashedPassword) {
        return await bcrypt.compare(inputPassword, hashedPassword);
    },

    // Get user stores (for owner)
    async getUserStores(userId) {
        try {
            const [rows] = await pool.execute(
                `SELECT * FROM stores WHERE owner_id = ?`,
                [userId]
            );
            return rows;
        } catch (error) {
            throw error;
        }
    },

        // Find user by ID
    async findById(id) {
        const [rows] = await pool.execute(`SELECT * FROM users WHERE id = ?`, [id]);
        return rows[0] || null;
    },

    // List user by store
    async findByStore(store_id) {
        const [rows] = await pool.execute(
            `SELECT * FROM users WHERE store_id = ? AND is_active = 1 AND role IN ('admin','cashier')`,
            [store_id]
        );
        return rows;
    },

    // Create user
    async create(data) {
        const [result] = await pool.execute(
            `INSERT INTO users (owner_id, store_id, name, username, password, role, is_active) VALUES (?, ?, ?, ?, ?, ?, 1)`,
            [data.owner_id, data.store_id, data.name, data.username, data.password, data.role]
        );
        return result.insertId;
    },

    // Update user by id
    async update(id, data) {
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
        await pool.execute(
            `UPDATE users SET ${fields.join(', ')} WHERE id = ?`,
            values
        );
    }
};

module.exports = UserModel;