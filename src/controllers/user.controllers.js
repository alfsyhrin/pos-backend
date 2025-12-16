const UserModel = require('../models/user.model');
const bcrypt = require('bcryptjs');
const { getTenantConnection } = require('../config/db');

const USER_LIMITS = {
  'Standard': 1,
  'Pro': 6,
  'Eksklusif': 11
};

const UserController = {
    // List user by store
    async listByStore(req, res) {
        let conn;
        try {
            const { store_id } = req.params;
            const dbName = req.user?.db_name;
            if (!dbName) return res.status(400).json({ success: false, message: 'Missing db_name in token' });
            console.log('Listing users in tenant:', dbName);
            conn = await getTenantConnection(dbName);
            const users = await UserModel.findByStore(conn, store_id);
            res.json({ success: true, data: users });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal mengambil data user', error: error.message });
        } finally {
            if (conn) await conn.end();
        }
    },

    // Create user
    async create(req, res) {
        let conn;
        try {
            const storeIdFromParams = req.params.store_id;
            const { store_id: store_id_from_body, name, username, password, role } = req.body;
            const store_id = (store_id_from_body !== undefined) ? store_id_from_body : storeIdFromParams || null;

            const owner_id = req.user.owner_id;
            const dbName = req.user?.db_name;
            if (!dbName) return res.status(400).json({ success: false, message: 'Tenant database (db_name) tidak ditemukan di token.' });

            if ((role === 'admin' || role === 'cashier') && !store_id) {
                return res.status(400).json({ success: false, message: 'store_id harus diisi untuk role admin atau cashier.' });
            }

            console.log('Creating user in tenant:', dbName, 'owner_id:', owner_id, 'store_id:', store_id);
            conn = await getTenantConnection(dbName);

            const [ownerRows] = await conn.query('SELECT id FROM owners WHERE id = ?', [owner_id]);
            if (ownerRows.length === 0) {
                return res.status(500).json({
                    success: false,
                    message: 'Owner tidak ditemukan di database tenant. Jalankan register client atau sinkronisasi owner terlebih dahulu.'
                });
            }

            if (store_id) {
                const [storeRows] = await conn.query('SELECT id, owner_id FROM stores WHERE id = ?', [store_id]);
                if (storeRows.length === 0) {
                    return res.status(400).json({ success: false, message: 'Store tidak ditemukan di tenant.' });
                }
                if (storeRows[0].owner_id && storeRows[0].owner_id !== owner_id) {
                    return res.status(403).json({ success: false, message: 'Store tidak dimiliki oleh owner yang sama.' });
                }
            }

            const pool = require('../config/db');
            const [subs] = await pool.query('SELECT plan FROM subscriptions WHERE owner_id = ?', [owner_id]);
            const plan = subs[0]?.plan || 'Standard';
            const maxUser = USER_LIMITS[plan];

            const [users] = await conn.query('SELECT COUNT(*) AS total FROM users WHERE owner_id = ?', [owner_id]);
            if (users[0].total >= maxUser) {
                return res.status(400).json({ message: 'Batas jumlah user sudah tercapai untuk paket ini.' });
            }

            const hashed = await bcrypt.hash(password, 10);
            const userId = await UserModel.create(conn, {
                owner_id, store_id, name, username, password: hashed, role
            });
            res.status(201).json({ success: true, message: 'User berhasil ditambah', id: userId });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal menambah user', error: error.message });
        } finally {
            if (conn) await conn.end();
        }
    },

    // Update user
    async update(req, res) {
        let conn;
        try {
            const { id } = req.params;
            const { name, username, password, role, is_active } = req.body;
            const dbName = req.user?.db_name;
            if (!dbName) return res.status(400).json({ success: false, message: 'Missing db_name in token' });
            conn = await getTenantConnection(dbName);

            const userToUpdate = await UserModel.findById(conn, id);
            if (!userToUpdate) return res.status(404).json({ success: false, message: 'User tidak ditemukan' });

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

            await UserModel.update(conn, id, updateData);
            res.json({ success: true, message: 'User berhasil diupdate' });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal update user', error: error.message });
        } finally {
            if (conn) await conn.end();
        }
    },

    // Delete (nonaktifkan) user
    async delete(req, res) {
        let conn;
        try {
            const { id } = req.params;
            const dbName = req.user?.db_name;
            if (!dbName) return res.status(400).json({ success: false, message: 'Missing db_name in token' });
            conn = await getTenantConnection(dbName);
            await UserModel.update(conn, id, { is_active: 0 });
            res.json({ success: true, message: 'User berhasil dinonaktifkan' });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal hapus user', error: error.message });
        } finally {
            if (conn) await conn.end();
        }
    }
};

module.exports = UserController;