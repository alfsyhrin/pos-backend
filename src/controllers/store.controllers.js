const StoreModel = require('../models/store.model');
const response = require('../utils/response');
const { getTenantConnection } = require('../config/db');

const StoreController = {
    // Create new store
    async create(req, res) {
        let conn;
        try {
            const owner_id = req.user.owner_id;
            const dbName = req.user.db_name;
            const { name, address, phone, receipt_template } = req.body;

            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            if (!name || name.trim() === '') {
                return response.badRequest(res, 'Nama toko harus diisi');
            }

            conn = await getTenantConnection(dbName);

            const storeId = await StoreModel.create(conn, {
                owner_id,
                name: name.trim(),
                address: address ? address.trim() : null,
                phone: phone ? phone.trim() : null,
                receipt_template: receipt_template ? receipt_template.trim() : null
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

    // Create receipt template
    async createReceiptTemplate(req, res) {
        let conn;
        try {
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const { store_id } = req.params;
            const { template_name, template_data } = req.body;
            if (!template_name || !template_data) {
                return response.badRequest(res, 'Template name and data are required');
            }

            const templateId = await StoreModel.createReceiptTemplate(conn, store_id, template_name, template_data);
            const template = await StoreModel.getReceiptTemplate(conn, store_id);

            return response.created(res, template, 'Receipt template created successfully');
        } catch (error) {
            console.error('Create Receipt Template Error:', error);
            return response.error(res, 'An error occurred while creating receipt template', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Get receipt template for a store
    async getReceiptTemplate(req, res) {
        let conn;
        try {
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const { store_id } = req.params;
            const template = await StoreModel.getReceiptTemplate(conn, store_id);

            if (!template) return response.notFound(res, 'Receipt template not found');
            return response.success(res, template, 'Receipt template fetched successfully');
        } catch (error) {
            console.error('Get Receipt Template Error:', error);
            return response.error(res, 'An error occurred while fetching receipt template', 500, error);
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

            const { name, address, phone, receipt_template } = req.body;
            const storeId = parseInt(id);
            if (isNaN(storeId)) return response.badRequest(res, 'ID toko tidak valid');
            if (!name || name.trim() === '') return response.badRequest(res, 'Nama toko harus diisi');

            const storeExists = await StoreModel.findById(conn, storeId, owner_id);
            if (!storeExists) return response.notFound(res, 'Toko tidak ditemukan');

            if (req.user.role !== 'owner' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Anda tidak memiliki akses untuk mengupdate toko ini');
            }

            const updateData = {
                name: name.trim(),
                address: address ? address.trim() : null,
                phone: phone ? phone.trim() : null,
                receipt_template: receipt_template ? receipt_template.trim() : null
            };

            const isUpdated = await StoreModel.update(conn, storeId, owner_id, updateData);
            if (!isUpdated) return response.error(res, 'Gagal mengupdate toko', 400);

            const updatedStore = await StoreModel.findById(conn, storeId, owner_id);
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
    }
};

module.exports = StoreController;