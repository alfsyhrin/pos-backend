const UserModel = require('../models/user.model');
const ActivityLogModel = require('../models/activityLog.model');
const bcrypt = require('bcryptjs');
const { getTenantConnection, getMainConnection } = require('../config/db');
const { getPackageLimit, getRoleLimit } = require('../config/package_limits');
const response = require('../utils/response');

const UserController = {
    // List user by store
    async listByStore(req, res) {
        let conn;
        try {
            const { store_id } = req.params;
            const { search } = req.query;
            const dbName = req.user?.db_name;
            if (!dbName) return res.status(400).json({ success: false, message: 'Missing db_name in token' });
            conn = await getTenantConnection(dbName);

            let users = [];
            if (req.user.role === 'owner') {
                users = await UserModel.findAllByOwner(conn, req.user.owner_id, search);
            } else if (req.user.role === 'admin') {
                users = await UserModel.findByStore(conn, req.user.store_id, search);
            } else if (req.user.role === 'cashier') {
                // Kasir: hanya bisa lihat data dirinya sendiri
                const user = await UserModel.findById(conn, req.user.id);
                users = user ? [user] : [];
            } else {
                return res.status(403).json({ success: false, message: 'Akses ditolak. Role tidak sesuai.' });
            }

            res.json({ success: true, data: users });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal mengambil data user', error: error.message });
        } finally {
            if (conn) await conn.end();
        }
    },

    // Create user
    async create(req, res) {
        let conn, mainConn;
        try {
            const storeIdFromParams = req.params.store_id;
            const { store_id: store_id_from_body, name, username, email, password, role } = req.body;
            let store_id = (store_id_from_body !== undefined) ? store_id_from_body : storeIdFromParams || null;

            const owner_id = req.user.owner_id;
            const dbName = req.user?.db_name;
            if (!dbName) return res.status(400).json({ success: false, message: 'Tenant database (db_name) tidak ditemukan di token.' });

            if ((role === 'admin' || role === 'cashier') && !store_id) {
                conn = await getTenantConnection(dbName);
                const [stores] = await conn.query('SELECT id FROM stores WHERE owner_id = ? LIMIT 1', [owner_id]);
                if (stores.length === 0) {
                    return res.status(400).json({ success: false, message: 'store_id harus diisi atau buat store terlebih dahulu.' });
                }
                store_id = stores[0].id;
            } else {
                if (!conn) conn = await getTenantConnection(dbName);
            }

            // Validasi username unik di tenant
            const existingUser = await UserModel.findByUsername(conn, username);
            if (existingUser) {
                return res.status(400).json({ success: false, message: 'Username sudah digunakan, silakan pilih username lain.' });
            }

            // Validasi username unik di global_users (database utama)
            mainConn = await getMainConnection();
            const [globalRows] = await mainConn.query(
                'SELECT id FROM global_users WHERE username = ?',
                [username]
            );
            if (globalRows.length > 0) {
                return res.status(400).json({ success: false, message: 'Username sudah digunakan, silakan pilih username lain.' });
            }

            // cek owner eksis di tenant
            const [ownerRows] = await conn.query('SELECT id FROM owners WHERE id = ?', [owner_id]);
            if (ownerRows.length === 0) {
                return res.status(500).json({ success: false, message: 'Owner tidak ditemukan di database tenant. Jalankan register client atau sinkronisasi owner.' });
            }

            // validasi store ownership
            if (store_id) {
                const [storeRows] = await conn.query('SELECT id, owner_id FROM stores WHERE id = ?', [store_id]);
                if (storeRows.length === 0) return res.status(400).json({ success: false, message: 'Store tidak ditemukan di tenant.' });
                if (storeRows[0].owner_id && storeRows[0].owner_id !== owner_id) return res.status(403).json({ success: false, message: 'Store tidak dimiliki oleh owner yang sama.' });
            }

            // ambil plan
            const pool = require('../config/db');
            const [subs] = await pool.query('SELECT plan FROM subscriptions WHERE owner_id = ?', [owner_id]);
            const plan = subs[0]?.plan || 'Standard';

            // Untuk cek limit produk
            const productLimit = getPackageLimit(plan, 'product_limit');

            // Untuk cek limit user per role
            const roleLimit = getRoleLimit(plan, role);
            const totalRole = await UserModel.countByRole(conn, store_id, role);
            if (totalRole >= roleLimit) {
              return response.badRequest(res, `Batas user role ${role} (${roleLimit}) untuk paket ${plan} telah tercapai`);
            }

            const hashed = await bcrypt.hash(password, 10);
            const userId = await UserModel.create(conn, { owner_id, store_id, name, username, email, password: hashed, role });

            // Insert ke global_users
            await mainConn.query(
                'INSERT INTO global_users (username, email, name, tenant_db, tenant_user_id) VALUES (?, ?, ?, ?, ?)',
                [username, email, name, dbName, userId]
            );

            // Logging aktivitas: tambah user
            await ActivityLogModel.create(conn, {
              user_id: req.user.id,
              store_id: store_id,
              action: 'add_user',
              detail: `Tambah user: ${name} (${role})`
            });
            res.status(201).json({ success: true, message: 'User berhasil ditambah', id: userId });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal menambah user', error: error.message });
        } finally {
            if (conn) await conn.end();
            if (mainConn) await mainConn.end();
        }
    },

    // Update user (termasuk nonaktifkan)
    async update(req, res) {
        let conn, mainConn;
        try {
            const { id } = req.params;
            const { name, username, email, password, role, is_active } = req.body;
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

            // Validasi username unik jika diubah
            if (username && username !== userToUpdate.username) {
                // Cek di tenant
                const existingUser = await UserModel.findByUsername(conn, username);
                if (existingUser && existingUser.id !== Number(id)) {
                    return res.status(400).json({ success: false, message: 'Username sudah digunakan di tenant, silakan pilih username lain.' });
                }
                // Cek di global_users
                mainConn = await getMainConnection();
                const [globalRows] = await mainConn.query(
                    'SELECT id FROM global_users WHERE username = ? AND NOT (tenant_db = ? AND tenant_user_id = ?)',
                    [username, dbName, id]
                );
                if (globalRows.length > 0) {
                    return res.status(400).json({ success: false, message: 'Username sudah digunakan di sistem, silakan pilih username lain.' });
                }
            }

            // --- Tambahan validasi limit role ---
            let newRole = role !== undefined ? role : userToUpdate.role;
            if (newRole === 'admin' || newRole === 'cashier') {
                if (userToUpdate.role !== newRole) {
                    const pool = require('../config/db');
                    const [subs] = await pool.query('SELECT plan FROM subscriptions WHERE owner_id = ?', [userToUpdate.owner_id]);
                    const plan = subs[0]?.plan || 'Standard';
                    const roleLimit = getRoleLimit(plan, newRole);
                    const totalRole = await UserModel.countByRole(conn, userToUpdate.store_id, newRole);
                    if (totalRole >= roleLimit) {
                        return res.status(400).json({ success: false, message: `Batas user role ${newRole} (${roleLimit}) untuk paket ${plan} telah tercapai` });
                    }
                }
            }
            // --- End validasi limit role ---

            let updateData = {};
            if (name !== undefined) updateData.name = name;
            if (username !== undefined) updateData.username = username;
            if (email !== undefined) updateData.email = email;
            if (role !== undefined) updateData.role = role;
            if (is_active !== undefined) updateData.is_active = is_active;
            if (password) updateData.password = await bcrypt.hash(password, 10);

            await UserModel.update(conn, id, updateData);

            // Update global_users jika username/email/name diubah
            if (username || email || name) {
                mainConn = mainConn || await getMainConnection();
                await mainConn.query(
                    'UPDATE global_users SET username = ?, email = ?, name = ? WHERE tenant_db = ? AND tenant_user_id = ?',
                    [
                        username || userToUpdate.username,
                        email || userToUpdate.email,
                        name || userToUpdate.name,
                        dbName,
                        id
                    ]
                );
            }

            // Logging aktivitas: edit user
            await ActivityLogModel.create(conn, {
                user_id: req.user.id,
                store_id: userToUpdate.store_id,
                action: 'edit_user',
                detail: `Edit user: ${name || userToUpdate.name} (${role || userToUpdate.role})`
            });
            res.json({ success: true, message: 'User berhasil diupdate' });
        } catch (error) {
            res.status(500).json({ success: false, message: 'Gagal update user', error: error.message });
        } finally {
            if (conn) await conn.end();
            if (mainConn) await mainConn.end();
        }
    },

    // Delete user (hard delete, hapus permanen)
    async delete(req, res) {
        let conn;
        try {
            const { id } = req.params;
            const dbName = req.user?.db_name;
            if (!dbName) return res.status(400).json({ success: false, message: 'Missing db_name in token' });
            conn = await getTenantConnection(dbName);
            const user = await UserModel.findById(conn, id);
            if (!user) return res.status(404).json({ success: false, message: 'User tidak ditemukan' });

            // Cek relasi sebelum hapus (contoh: transaksi)
            // const [trx] = await conn.query('SELECT id FROM transactions WHERE user_id = ?', [id]);
            // if (trx.length > 0) return res.status(400).json({ success: false, message: 'User masih memiliki transaksi, tidak bisa dihapus.' });

            await UserModel.delete(conn, id);

            // Logging aktivitas: hapus user
            await ActivityLogModel.create(conn, {
              user_id: req.user.id,
              store_id: user.store_id,
              action: 'delete_user',
              detail: `Hapus user: ${user.name} (${user.role})`
            });
            res.json({ success: true, message: 'User berhasil dihapus permanen' });
        } catch (error) {
            console.error('DELETE USER ERROR:', error);
            res.status(500).json({ success: false, message: 'Gagal hapus user', error: error.message });
        } finally {
            if (conn) await conn.end();
        }
    }
};

module.exports = UserController;