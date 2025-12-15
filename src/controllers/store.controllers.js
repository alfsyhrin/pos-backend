const StoreModel = require('../models/store.model');
const response = require('../utils/response');

const StoreController = {
    // Create new store
    async create(req, res) {
        try {
            const owner_id = req.user.owner_id;
            const { name, address, phone, receipt_template } = req.body;

            // Validation (should be in middleware, but double check)
            if (!name || name.trim() === '') {
                return response.badRequest(res, 'Nama toko harus diisi');
            }

            // Check subscription limit (optional - for future implementation)
            // const storeCount = await StoreModel.countByOwner(owner_id);
            // if (storeCount >= maxStores) {
            //     return response.forbidden(res, 'Batas maksimal toko telah tercapai');
            // }

            // Create store
            const storeId = await StoreModel.create({
                owner_id,
                name: name.trim(),
                address: address ? address.trim() : null,
                phone: phone ? phone.trim() : null,
                receipt_template: receipt_template ? receipt_template.trim() : null
            });

            // Get created store details
            const store = await StoreModel.findById(storeId);

            if (!store) {
                return response.error(res, 'Gagal membuat toko', 500);
            }

            return response.success(res, store, 'Toko berhasil dibuat', 201);

        } catch (error) {
            console.error('Create store error:', error);
            
            // Handle duplicate store name for same owner
            if (error.code === 'ER_DUP_ENTRY') {
                return response.badRequest(res, 'Nama toko sudah digunakan untuk owner ini');
            }
            
            return response.error(res, 'Terjadi kesalahan saat membuat toko', 500, error);
        }
    },

        // Create receipt template
    async createReceiptTemplate(req, res) {
        try {
            const { store_id } = req.params;
            const { template_name, template_data } = req.body;

            // Validate input
            if (!template_name || !template_data) {
                return response.badRequest(res, 'Template name and data are required');
            }

            // Store template
            const templateId = await StoreModel.createReceiptTemplate(store_id, template_name, template_data);

            const template = await StoreModel.getReceiptTemplate(store_id);

            return response.created(res, template, 'Receipt template created successfully');
        } catch (error) {
            console.error('Create Receipt Template Error:', error);
            return response.error(res, 'An error occurred while creating receipt template', 500, error);
        }
    },

    // Get receipt template for a store
    async getReceiptTemplate(req, res) {
        try {
            const { store_id } = req.params;
            const template = await StoreModel.getReceiptTemplate(store_id);

            if (!template) {
                return response.notFound(res, 'Receipt template not found');
            }

            return response.success(res, template, 'Receipt template fetched successfully');
        } catch (error) {
            console.error('Get Receipt Template Error:', error);
            return response.error(res, 'An error occurred while fetching receipt template', 500, error);
        }
    },

    // Get all stores for current owner
    async getAll(req, res) {
        try {
            const owner_id = req.user.owner_id;
            const stores = await StoreModel.findAllByOwner(owner_id);

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
        }
    },

    // Get single store
    async getById(req, res) {
        try {
            const { id } = req.params;
            const owner_id = req.user.owner_id;

            // Parse store ID
            const storeId = parseInt(id);
            if (isNaN(storeId)) {
                return response.badRequest(res, 'ID toko tidak valid');
            }

            const store = await StoreModel.findById(storeId, owner_id);

            if (!store) {
                return response.notFound(res, 'Toko tidak ditemukan');
            }

            return response.success(res, store, 'Data toko berhasil diambil');

        } catch (error) {
            console.error('Get store by ID error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil data toko', 500, error);
        }
    },

    // Update store
    async update(req, res) {
        try {
            const { id } = req.params;
            const owner_id = req.user.owner_id;
            const { name, address, phone, receipt_template } = req.body;

            // Parse store ID
            const storeId = parseInt(id);
            if (isNaN(storeId)) {
                return response.badRequest(res, 'ID toko tidak valid');
            }

            // Validation
            if (!name || name.trim() === '') {
                return response.badRequest(res, 'Nama toko harus diisi');
            }

            // Check if store exists and belongs to owner
            const storeExists = await StoreModel.findById(storeId, owner_id);
            if (!storeExists) {
                return response.notFound(res, 'Toko tidak ditemukan');
            }

            // Check if user has permission to update this store
            // Additional permission check for admin/cashier (store-specific)
            if (req.user.role !== 'owner' && req.user.store_id !== storeId) {
                return response.forbidden(res, 'Anda tidak memiliki akses untuk mengupdate toko ini');
            }

            // Prepare update data
            const updateData = {
                name: name.trim(),
                address: address ? address.trim() : null,
                phone: phone ? phone.trim() : null,
                receipt_template: receipt_template ? receipt_template.trim() : null
            };

            // Update store
            const isUpdated = await StoreModel.update(storeId, owner_id, updateData);

            if (!isUpdated) {
                return response.error(res, 'Gagal mengupdate toko', 400);
            }

            // Get updated store
            const updatedStore = await StoreModel.findById(storeId);

            return response.success(res, updatedStore, 'Toko berhasil diupdate');

        } catch (error) {
            console.error('Update store error:', error);
            
            // Handle duplicate store name for same owner
            if (error.code === 'ER_DUP_ENTRY') {
                return response.badRequest(res, 'Nama toko sudah digunakan untuk owner ini');
            }
            
            return response.error(res, 'Terjadi kesalahan saat mengupdate toko', 500, error);
        }
    },

    // Delete store
    async delete(req, res) {
        try {
            const { id } = req.params;
            const owner_id = req.user.owner_id;

            // Parse store ID
            const storeId = parseInt(id);
            if (isNaN(storeId)) {
                return response.badRequest(res, 'ID toko tidak valid');
            }

            // Check if store exists and belongs to owner
            const storeExists = await StoreModel.findById(storeId, owner_id);
            if (!storeExists) {
                return response.notFound(res, 'Toko tidak ditemukan');
            }

            // Check if user has permission to delete this store
            if (req.user.role !== 'owner') {
                return response.forbidden(res, 'Hanya owner yang dapat menghapus toko');
            }

            // Check if store has products or transactions (optional safety check)
            // const hasProducts = await checkStoreHasData(storeId);
            // if (hasProducts) {
            //     return response.badRequest(res, 'Toko tidak dapat dihapus karena masih memiliki data produk/transaksi');
            // }

            // Delete store
            const isDeleted = await StoreModel.delete(storeId, owner_id);

            if (!isDeleted) {
                return response.error(res, 'Gagal menghapus toko', 400);
            }

            return response.success(res, null, 'Toko berhasil dihapus');

        } catch (error) {
            console.error('Delete store error:', error);
            
            // Handle foreign key constraint (if store has related data)
            if (error.code === 'ER_ROW_IS_REFERENCED_2') {
                return response.badRequest(res, 'Toko tidak dapat dihapus karena masih memiliki data terkait (produk, transaksi, dll)');
            }
            
            return response.error(res, 'Terjadi kesalahan saat menghapus toko', 500, error);
        }
    },

    // Search stores
    async search(req, res) {
        try {
            const owner_id = req.user.owner_id;
            const { q, limit = 10, page = 1 } = req.query;

            if (!q || q.trim() === '') {
                return response.badRequest(res, 'Kata kunci pencarian harus diisi');
            }

            const searchTerm = q.trim();
            
            // Parse pagination parameters
            const pageNum = parseInt(page);
            const limitNum = parseInt(limit);
            
            if (isNaN(pageNum) || pageNum < 1) {
                return response.badRequest(res, 'Parameter page tidak valid');
            }
            
            if (isNaN(limitNum) || limitNum < 1 || limitNum > 100) {
                return response.badRequest(res, 'Parameter limit harus antara 1-100');
            }

            // For now, simple search without pagination
            // In production, implement paginated search
            const stores = await StoreModel.search(owner_id, searchTerm);

            // Apply simple pagination
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
        }
    },

    // Get store statistics (additional feature)
    async getStats(req, res) {
        try {
            const owner_id = req.user.owner_id;
            
            const stores = await StoreModel.findAllByOwner(owner_id);
            const storeCount = stores.length;
            
            // Calculate statistics
            const stats = {
                total_stores: storeCount,
                active_stores: storeCount, // Assuming all are active for now
                stores_by_location: {}, // Can be enhanced with location grouping
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
        }
    },

    // Bulk update stores (optional feature)
    // Bulk update stores (simple version)
async bulkUpdate(req, res) {
    try {
        return response.success(res, {
            message: 'Bulk update feature coming soon',
            note: 'This feature is under development'
        });
    } catch (error) {
        console.error('Bulk update error:', error);
        return response.error(res, 'Terjadi kesalahan saat bulk update', 500, error);
    }
}
};

module.exports = StoreController;