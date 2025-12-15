const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const UserModel = require('../models/user.model');

const AuthController = {
    // Login untuk semua role
// Login untuk semua role
async login(req, res) {
    try {
        const { identifier, password } = req.body; // Ubah parameter

        // Validasi input
        if (!identifier || !password) {
            return res.status(400).json({
                success: false,
                message: 'Identifier (username/email) dan password harus diisi'
            });
        }

        let user = null;
        let userType = 'user';

        // Cari user: cek apakah identifier adalah email atau username
        if (identifier.includes('@')) {
            user = await UserModel.findOwnerByEmail(identifier);
            userType = 'owner';
        } else {
            user = await UserModel.findByUsername(identifier);
        }

        // Cek user exists
        if (!user) {
            return res.status(401).json({
                success: false,
                message: 'Username/email atau password salah'
            });
        }

        // Cek password
        const isPasswordValid = await UserModel.comparePassword(password, user.password);
        if (!isPasswordValid) {
            return res.status(401).json({
                success: false,
                message: 'Username/email atau password salah'
            });
        }

        // Prepare user data for JWT
        const userData = {
            id: user.id,
            owner_id: user.owner_id || user.id,
            store_id: user.store_id || null,
            role: userType === 'owner' ? 'owner' : user.role,
            username: user.username || user.email,
            name: user.name || user.business_name,
            email: user.email || null
        };

        // Generate JWT token
        const token = jwt.sign(
            userData,
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRE || '7d' }
        );

        // Get stores if owner
        let stores = [];
        if (userData.role === 'owner') {
            stores = await UserModel.getUserStores(userData.id);
        }

        // SIMPLIFIED RESPONSE - Token di root
        res.json({
            success: true,
            message: 'Login berhasil',
            token,  // Token langsung di root
            user: {
                id: userData.id,
                name: userData.name,
                email: userData.email || userData.username,
                username: userData.username,
                role: userData.role,
                store_id: userData.store_id,
                owner_id: userData.owner_id
            },
            stores: stores.length > 0 ? stores : null
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            success: false,
            message: 'Terjadi kesalahan server',
            error: process.env.NODE_ENV === 'development' ? error.message : undefined
        });
    }
},

    // Get current user profile
    async getProfile(req, res) {
        try {
            res.json({
                success: true,
                data: {
                    user: req.user
                }
            });
        } catch (error) {
            console.error('Get profile error:', error);
            res.status(500).json({
                success: false,
                message: 'Terjadi kesalahan server'
            });
        }
    },

    // Test protected route
    async testProtected(req, res) {
        try {
            res.json({
                success: true,
                message: 'Protected route accessed successfully',
                user: req.user
            });
        } catch (error) {
            console.error('Test protected error:', error);
            res.status(500).json({
                success: false,
                message: 'Terjadi kesalahan server'
            });
        }
    }
};

module.exports = AuthController;