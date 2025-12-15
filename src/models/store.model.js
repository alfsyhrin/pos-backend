const pool = require('../config/db');

const StoreModel = {
    // Create new store
    async create(storeData) {
        try {
            const { owner_id, name, address, phone, receipt_template } = storeData;
            
            const [result] = await pool.execute(
                `INSERT INTO stores (owner_id, name, address, phone, receipt_template) 
                 VALUES (?, ?, ?, ?, ?)`,
                [owner_id, name, address || null, phone || null, receipt_template || null]
            );
            
            return result.insertId;
        } catch (error) {
            throw error;
        }
    },

    // Get all stores for an owner
    async findAllByOwner(ownerId) {
        try {
            const [rows] = await pool.execute(
                `SELECT * FROM stores 
                 WHERE owner_id = ? 
                 ORDER BY created_at DESC`,
                [ownerId]
            );
            return rows;
        } catch (error) {
            throw error;
        }
    },

    // Get single store by ID (with owner validation)
    async findById(storeId, ownerId = null) {
        try {
            let query = `SELECT * FROM stores WHERE id = ?`;
            const params = [storeId];
            
            if (ownerId) {
                query += ` AND owner_id = ?`;
                params.push(ownerId);
            }
            
            const [rows] = await pool.execute(query, params);
            return rows[0] || null;
        } catch (error) {
            throw error;
        }
    },

    
    // Add new receipt template
    async createReceiptTemplate(storeId, templateName, templateData) {
        try {
            const [result] = await pool.execute(
                `INSERT INTO struck_receipt (store_id, template_name, template_data) 
                 VALUES (?, ?, ?)`,
                [storeId, templateName, templateData]
            );
            return result.insertId;
        } catch (error) {
            throw error;
        }
    },

    // Get receipt template for a store
    async getReceiptTemplate(storeId) {
        try {
            const [rows] = await pool.execute(
                `SELECT * FROM struck_receipt WHERE store_id = ?`,
                [storeId]
            );
            return rows[0] || null;  // Assume one template per store
        } catch (error) {
            throw error;
        }
    },

    // Update store
    async update(storeId, ownerId, updateData) {
        try {
            const { name, address, phone, receipt_template } = updateData;
            
            const [result] = await pool.execute(
                `UPDATE stores 
                 SET name = ?, address = ?, phone = ?, receipt_template = ?, 
                     updated_at = CURRENT_TIMESTAMP
                 WHERE id = ? AND owner_id = ?`,
                [name, address || null, phone || null, receipt_template || null, 
                 storeId, ownerId]
            );
            
            return result.affectedRows > 0;
        } catch (error) {
            throw error;
        }
    },

    // Delete store (soft delete or hard delete)
    async delete(storeId, ownerId) {
        try {
            // Hard delete (permanent)
            const [result] = await pool.execute(
                `DELETE FROM stores WHERE id = ? AND owner_id = ?`,
                [storeId, ownerId]
            );
            
            return result.affectedRows > 0;
        } catch (error) {
            throw error;
        }
    },

    // Get store count for an owner (for subscription limit)
    async countByOwner(ownerId) {
        try {
            const [rows] = await pool.execute(
                `SELECT COUNT(*) as count FROM stores WHERE owner_id = ?`,
                [ownerId]
            );
            return rows[0].count;
        } catch (error) {
            throw error;
        }
    },

    // Search stores by name
    async search(ownerId, searchTerm) {
        try {
            const [rows] = await pool.execute(
                `SELECT * FROM stores 
                 WHERE owner_id = ? 
                 AND (name LIKE ? OR address LIKE ? OR phone LIKE ?)
                 ORDER BY name`,
                [ownerId, `%${searchTerm}%`, `%${searchTerm}%`, `%${searchTerm}%`]
            );
            return rows;
        } catch (error) {
            throw error;
        }
    }

};

module.exports = StoreModel;