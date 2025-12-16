const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const UserModel = require('../models/user.model');
const db = require('../config/db');
const { getTenantConnection } = require('../config/db');

const AuthController = {
    async login(req, res) {
        try {
            const { identifier, password, owner_id } = req.body;
            if (!identifier || !password) {
                return res.status(400).json({ success: false, message: 'Identifier dan password harus diisi' });
            }

            let user = null;
            let dbName = null;
            let userType = 'user';

            // === OWNER LOGIN ===
            if (identifier.includes('@')) {
                // Cek ke database utama
                user = await UserModel.findOwnerByEmail(identifier);
                userType = 'owner';

                // Ambil db_name tenant dari tabel clients
                if (user) {
                    const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [user.id]);
                    dbName = clients[0]?.db_name;
                }
            } else {
                // === ADMIN/KASIR LOGIN ===
                if (!owner_id) {
                    return res.status(400).json({ success: false, message: 'owner_id harus diisi untuk login admin/kasir' });
                }
                // Ambil db_name tenant
                const [clients] = await db.query('SELECT db_name FROM clients WHERE owner_id = ?', [owner_id]);
                dbName = clients[0]?.db_name;
                if (!dbName) {
                    return res.status(404).json({ success: false, message: 'Tenant tidak ditemukan' });
                }
                // Cek user di database tenant
                const tenantConn = await getTenantConnection(dbName);
                user = await UserModel.findByUsername(tenantConn, identifier);
                userType = user?.role || 'user';
            }

            if (!user) {
                return res.status(401).json({ success: false, message: 'Username/email atau password salah' });
            }

            const isPasswordValid = await bcrypt.compare(password, user.password);
            if (!isPasswordValid) {
                return res.status(401).json({ success: false, message: 'Username/email atau password salah' });
            }

            const userData = {
                id: user.id,
                owner_id: user.owner_id || user.id,
                store_id: user.store_id || null,
                role: userType,
                username: user.username || user.email,
                name: user.name || user.business_name,
                email: user.email || null,
                db_name: dbName
            };

            const token = jwt.sign(
                userData,
                process.env.JWT_SECRET,
                { expiresIn: process.env.JWT_EXPIRE || '7d' }
            );

            res.json({
                success: true,
                message: 'Login berhasil',
                token,
                user: userData
            });

        } catch (error) {
            console.error('Login error:', error);
            res.status(500).json({ success: false, message: 'Terjadi kesalahan server', error: error.message });
        }
    },

    async getProfile(req, res) {
        res.json({
            success: true,
            message: 'Profil user',
            user: req.user
        });
    },

    async testProtected(req, res) {
        res.json({
            success: true,
            message: 'Akses endpoint protected berhasil',
            user: req.user
        });
    }
};

module.exports = AuthController;