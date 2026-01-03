const StoreModel = require('../models/store.model');
const ActivityLogModel = require('../models/activityLog.model');
const response = require('../utils/response');
const { getTenantConnection } = require('../config/db');

const StoreController = {
    // Create new store
    async create(req, res) {
        let conn;
        try {
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            let { store_id } = req.params; // dari URL
            const { name, username, password, role } = req.body;

            // Jika store_id tidak ada di URL, cari otomatis
            if (!store_id) {
                // Cari semua toko milik owner
                const stores = await StoreModel.findAllByOwner(conn, req.user.owner_id);
                if (stores.length === 1) {
                    store_id = stores[0].id;
                } else if (stores.length > 1) {
                    return response.badRequest(res, 'Pilih toko/cabang untuk user baru');
                } else {
                    return response.badRequest(res, 'Owner belum punya toko/cabang');
                }
            }

            const owner_id = req.user.owner_id;
            if (!name || name.trim() === '') {
                return response.badRequest(res, 'Nama toko harus diisi');
            }

            const storeId = await StoreModel.create(conn, {
                owner_id,
                name: name.trim(),
                store_id
            });

            // Logging aktivitas: tambah toko
            await ActivityLogModel.create(conn, {
                user_id: req.user.id,
                store_id: storeId,
                action: 'add_store',
                detail: `Tambah toko: ${name.trim()}`
            });

            const store = await StoreModel.findById(conn, storeId, owner_id);
            if (!store) return response.error(res, 'Gagal membuat toko', 500);

            return response.success(res, store, 'Toko berhasil dibuat', 201);

        } catch (error) {
            console.error('Create store error:', error);
            if (error.code === 'ER_DUP_ENTRY') {
                return response.badRequest(res, 'Nama toko sudah digunakan untuk owner ini');
            }
            return response.error(res, 'Terjadi kesalahan saat membuat toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // GET /api/stores/:store_id/receipt-template
    async getReceiptTemplate(req, res) {
        let conn;
        try {
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const { store_id } = req.params;
            const [rows] = await conn.query(
                `SELECT receipt_template FROM stores WHERE id = ? LIMIT 1`,
                [store_id]
            );
            if (!rows.length) return response.notFound(res, 'Template struk tidak ditemukan');
            return response.success(res, rows[0], 'Template struk berhasil diambil');
        } catch (error) {
            return response.error(res, 'Gagal mengambil template struk', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // POST /api/stores/:store_id/receipt-template
    async createReceiptTemplate(req, res) {
        let conn;
        try {
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const { store_id } = req.params;
            const { receipt_template } = req.body;
            if (!receipt_template) return response.badRequest(res, 'receipt_template wajib diisi');

            await conn.query(
                `UPDATE stores SET receipt_template = ? WHERE id = ?`,
                [receipt_template, store_id]
            );
            return response.success(res, { receipt_template }, 'Template struk berhasil disimpan');
        } catch (error) {
            return response.error(res, 'Gagal menyimpan template struk', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Get all stores for current owner
    async getAll(req, res) {
        let conn;
        try {
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const stores = await StoreModel.findAllByOwner(conn, owner_id);

            return response.success(res, {
                stores,
                count: stores.length,
                pagination: {
                    total: stores.length,
                    page: 1,
                    limit: stores.length
                }
            });
        } catch (error) {
            console.error('Get all stores error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil data toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Get single store
    async getById(req, res) {
        let conn;
        try {
            const { id } = req.params;
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const storeId = parseInt(id);
            if (isNaN(storeId)) return response.badRequest(res, 'ID toko tidak valid');

            const store = await StoreModel.findById(conn, storeId, owner_id);
            if (!store) return response.notFound(res, 'Toko tidak ditemukan');

            return response.success(res, store, 'Data toko berhasil diambil');
        } catch (error) {
            console.error('Get store by ID error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil data toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Update store
    async update(req, res) {
        let conn;
        try {
            const { id } = req.params;
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            // PATCH: Mapping business_name ke name
            let { name, business_name, address, phone, receipt_template, tax_percentage } = req.body;
            if (!name && business_name) name = business_name;

            const storeId = parseInt(id);
            if (isNaN(storeId)) return response.badRequest(res, 'ID toko tidak valid');
            if (name !== undefined && name.trim() === '') return response.badRequest(res, 'Nama toko harus diisi');

            const storeExists = await StoreModel.findById(conn, storeId, owner_id);
            if (!storeExists) return response.notFound(res, 'Toko tidak ditemukan');

            if (req.user.role !== 'owner' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Anda tidak memiliki akses untuk mengupdate toko ini');
            }

            // PATCH: Hanya update field yang ada di tabel
            const updateData = {};
            if (name !== undefined) updateData.name = name.trim();
            if (address !== undefined) updateData.address = address.trim();
            if (phone !== undefined) updateData.phone = phone.trim();
            if (receipt_template !== undefined) updateData.receipt_template = receipt_template.trim();
            if (tax_percentage !== undefined) updateData.tax_percentage = tax_percentage;

            if (Object.keys(updateData).length === 0) {
                return response.badRequest(res, 'Tidak ada data yang diupdate');
            }

            const isUpdated = await StoreModel.update(conn, storeId, owner_id, updateData);
            if (!isUpdated) return response.error(res, 'Gagal mengupdate toko', 400);

            const updatedStore = await StoreModel.findById(conn, storeId, owner_id);

            // Logging aktivitas: update pengaturan toko
            await ActivityLogModel.create(conn, {
                user_id: req.user.id,
                store_id: storeId,
                action: 'update_setting',
                detail: 'Update pengaturan toko'
            });

            return response.success(res, updatedStore, 'Toko berhasil diupdate');
        } catch (error) {
            console.error('Update store error:', error);
            if (error.code === 'ER_DUP_ENTRY') {
                return response.badRequest(res, 'Nama toko sudah digunakan untuk owner ini');
            }
            return response.error(res, 'Terjadi kesalahan saat mengupdate toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Delete store
    async delete(req, res) {
        let conn;
        try {
            const { id } = req.params;
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const storeId = parseInt(id);
            if (isNaN(storeId)) return response.badRequest(res, 'ID toko tidak valid');

            const storeExists = await StoreModel.findById(conn, storeId, owner_id);
            if (!storeExists) return response.notFound(res, 'Toko tidak ditemukan');

            if (req.user.role !== 'owner') {
                return response.forbidden(res, 'Hanya owner yang dapat menghapus toko');
            }

            const isDeleted = await StoreModel.delete(conn, storeId, owner_id);
            if (!isDeleted) return response.error(res, 'Gagal menghapus toko', 400);

            // Logging aktivitas: hapus toko
            await ActivityLogModel.create(conn, {
                user_id: req.user.id,
                store_id: storeId,
                action: 'delete_store',
                detail: `Hapus toko: ${storeExists.name}`
            });

            return response.success(res, null, 'Toko berhasil dihapus');
        } catch (error) {
            console.error('Delete store error:', error);
            if (error.code === 'ER_ROW_IS_REFERENCED_2') {
                return response.badRequest(res, 'Toko tidak dapat dihapus karena masih memiliki data terkait (produk, transaksi, dll)');
            }
            return response.error(res, 'Terjadi kesalahan saat menghapus toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Search stores
    async search(req, res) {
        let conn;
        try {
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const { q, limit = 10, page = 1 } = req.query;
            if (!q || q.trim() === '') {
                return response.badRequest(res, 'Kata kunci pencarian harus diisi');
            }

            const searchTerm = q.trim();
            const pageNum = parseInt(page);
            const limitNum = parseInt(limit);

            if (isNaN(pageNum) || pageNum < 1) {
                return response.badRequest(res, 'Parameter page tidak valid');
            }
            if (isNaN(limitNum) || limitNum < 1 || limitNum > 100) {
                return response.badRequest(res, 'Parameter limit harus antara 1-100');
            }

            const stores = await StoreModel.search(conn, owner_id, searchTerm);

            const startIndex = (pageNum - 1) * limitNum;
            const endIndex = pageNum * limitNum;
            const paginatedStores = stores.slice(startIndex, endIndex);

            return response.success(res, {
                stores: paginatedStores,
                count: paginatedStores.length,
                total: stores.length,
                pagination: {
                    page: pageNum,
                    limit: limitNum,
                    totalPages: Math.ceil(stores.length / limitNum),
                    hasNext: endIndex < stores.length,
                    hasPrev: pageNum > 1
                }
            });

        } catch (error) {
            console.error('Search stores error:', error);
            return response.error(res, 'Terjadi kesalahan saat mencari toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Get store statistics (additional feature)
    async getStats(req, res) {
        let conn;
        try {
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const stores = await StoreModel.findAllByOwner(conn, owner_id);
            const storeCount = stores.length;

            const stats = {
                total_stores: storeCount,
                active_stores: storeCount,
                stores_by_location: {},
                recent_activity: stores.slice(0, 5).map(store => ({
                    id: store.id,
                    name: store.name,
                    last_updated: store.updated_at || store.created_at
                }))
            };

            return response.success(res, stats, 'Statistik toko berhasil diambil');
        } catch (error) {
            console.error('Get store stats error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil statistik toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Bulk update stores (optional feature)
    async bulkUpdate(req, res) {
        return response.success(res, {
            message: 'Bulk update feature coming soon',
            note: 'This feature is under development'
        });
    },

    // GET /api/business-profile (owner only)
    async getBusinessProfile(req, res) {
        let conn;
        try {
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const [rows] = await conn.query(
                `SELECT id, owner_id, name, address, phone FROM stores WHERE owner_id = ? AND type = 'business_profile' LIMIT 1`,
                [owner_id]
            );
            if (!rows.length) return response.notFound(res, 'Informasi bisnis tidak ditemukan');
            return response.success(res, rows[0], 'Informasi bisnis berhasil diambil');
        } catch (error) {
            return response.error(res, 'Gagal mengambil informasi bisnis', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // PUT /api/business-profile (owner only)
    async updateBusinessProfile(req, res) {
        let conn;
        try {
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const { name, address, phone } = req.body;
            if (!name || name.trim() === '') return response.badRequest(res, 'Nama bisnis harus diisi');

            const [result] = await conn.query(
                `UPDATE stores SET name = ?, address = ?, phone = ? WHERE owner_id = ? AND type = 'business_profile'`,
                [name.trim(), address ? address.trim() : null, phone ? phone.trim() : null, owner_id]
            );
            if (result.affectedRows === 0) return response.error(res, 'Gagal mengupdate informasi bisnis', 400);

            // Logging aktivitas: update profil bisnis
            await ActivityLogModel.create(conn, {
                user_id: req.user.id,
                store_id: null,
                action: 'update_business_profile',
                detail: `Update profil bisnis: ${name.trim()}`
            });

            const [rows] = await conn.query(
                `SELECT id, owner_id, name, address, phone FROM stores WHERE owner_id = ? AND type = 'business_profile' LIMIT 1`,
                [owner_id]
            );
            return response.success(res, rows[0], 'Informasi bisnis berhasil diupdate');
        } catch (error) {
            return response.error(res, 'Gagal mengupdate informasi bisnis', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // GET store detail
    async getStore(req, res) {
        let conn;
        try {
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const { store_id } = req.params;
            const store = await StoreModel.getStoreById(conn, store_id);
            return response.success(res, store, 'Detail toko berhasil diambil');
        } catch (error) {
            console.error('Get store detail error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil detail toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // UPDATE store detail
    async updateStore(req, res) {
        let conn;
        try {
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const { store_id } = req.params;
            const { name, address, phone, receipt_template, tax_percentage } = req.body;

            await StoreModel.updateStore(conn, store_id, {
                name,
                address,
                phone,
                receipt_template,
                tax_percentage
            });
            return response.success(res, null, 'Detail toko berhasil diupdate');
        } catch (error) {
            console.error('Update store detail error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengupdate detail toko', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },
};

module.exports = StoreController;