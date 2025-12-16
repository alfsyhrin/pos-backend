const UserModel = require('../models/user.model');
const bcrypt = require('bcryptjs');

const UserController = {
    // List user by store
    async listByStore(req, res) {
        try {
            const { store_id } = req.params;
            const users = await UserModel.findByStore(store_id);
            res.json({ success: true, data: users });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal mengambil data user', error: error.message });
        }
    },

    // Create user
    async create(req, res) {
        try {
            const { store_id } = req.params;
            const { name, username, password, role } = req.body;
            const owner_id = req.user.owner_id; // Ambil dari token
            const hashed = await bcrypt.hash(password, 10);
            const userId = await UserModel.create({
                owner_id, store_id, name, username, password: hashed, role
            });
            res.status(201).json({ success: true, message: 'User berhasil ditambah', id: userId });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal menambah user', error: error.message });
        }
    },

    // Update user
    async update(req, res) {
        try {
            const { id } = req.params;
            const { name, username, password, role, is_active } = req.body;
            const userToUpdate = await UserModel.findById(id);

            // Cek hak akses
            if (req.user.role === 'admin' && userToUpdate.store_id !== req.user.store_id) {
                return res.status(403).json({ success: false, message: 'Admin hanya bisa update user di tokonya.' });
            }
            if (req.user.role === 'owner' && userToUpdate.owner_id !== req.user.owner_id) {
                return res.status(403).json({ success: false, message: 'Owner hanya bisa update user di tokonya.' });
            }

            let updateData = {};
            if (name !== undefined) updateData.name = name;
            if (username !== undefined) updateData.username = username;
            if (role !== undefined) updateData.role = role;
            if (is_active !== undefined) updateData.is_active = is_active;
            if (password) updateData.password = await bcrypt.hash(password, 10);

            console.log('Update user', { id, updateData });
            await UserModel.update(id, updateData);
            res.json({ success: true, message: 'User berhasil diupdate' });
        } catch (error) {
            console.error('Update user error:', error);
            res.status(500).json({ success: false, message: 'Gagal update user', error: error.message });
        }
    },

    // Delete (nonaktifkan) user
    async delete(req, res) {
        try {
            const { id } = req.params;
            await UserModel.update(id, { is_active: 0 });
            res.json({ success: true, message: 'User berhasil dinonaktifkan' });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal hapus user', error: error.message });
        }
    }
};

module.exports = UserController;