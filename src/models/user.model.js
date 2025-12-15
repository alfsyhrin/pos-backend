const pool = require('../config/db');
const bcrypt = require('bcryptjs');

const UserModel = {
    // Find user by username (for login)
    async findByUsername(username) {
        try {
            const [rows] = await pool.execute(
                `SELECT 
                    u.*, 
                    o.business_name,
                    s.name as store_name
                FROM users u
                LEFT JOIN owners o ON u.owner_id = o.id
                LEFT JOIN stores s ON u.store_id = s.id
                WHERE u.username = ? AND u.is_active = 1`,
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
                'SELECT * FROM owners WHERE email = ?',
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
        const [rows] = await db.execute(
            `SELECT * FROM users WHERE id = ? AND is_active = 1`,
            [id]
        );
        return rows[0] || null;
    }
};

module.exports = UserModel;