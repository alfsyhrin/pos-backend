const pool = require('../config/db');
const response = require('../utils/response'); // Pastikan jalur relatifnya benar

function cleanNullFields(obj) {
    // Ganti undefined jadi null, dan hapus property yang tidak dipakai
    Object.keys(obj).forEach(key => {
        if (obj[key] === undefined) obj[key] = null;
    });
    return obj;
}

const ProductModel = {
    // Create new product
    async create(productData) {
        try {
            const data = cleanNullFields(productData);

            const [result] = await pool.execute(
                `INSERT INTO products
                (store_id, name, sku, price, stock, category, description, image_url, is_active,
                 jenis_diskon, nilai_diskon, diskon_bundle_min_qty, diskon_bundle_value, buy_qty, free_qty)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [
                    data.store_id,
                    data.name,
                    data.sku,
                    data.price,
                    data.stock,
                    data.category,
                    data.description,
                    data.image_url,
                    data.is_active ?? 1,
                    data.jenis_diskon,
                    data.nilai_diskon,
                    data.diskon_bundle_min_qty,
                    data.diskon_bundle_value,
                    data.buy_qty,
                    data.free_qty
                ]
            );
            return result.insertId;
        } catch (error) {
            throw error;
        }
    },

    // Get all products for a store
    async findAllByStore(storeId, filters = {}) {
        try {
            let query = `SELECT * FROM products WHERE store_id = ?`;
            const params = [storeId];

            // Apply filters
            if (filters.is_active !== undefined) {
                query += ` AND is_active = ?`;
                params.push(filters.is_active);
            }

            if (filters.search) {
                query += ` AND (name LIKE ? OR sku LIKE ?)`;
                const searchTerm = `%${filters.search}%`;
                params.push(searchTerm, searchTerm);
            }

            if (filters.category) {
                query += ` AND category = ?`;
                params.push(filters.category);
            }

            // Sorting
            const sortField = filters.sort_by || 'name';
            const sortOrder = filters.sort_order || 'ASC';
            query += ` ORDER BY ${sortField} ${sortOrder}`;

            // Pagination
            if (filters.limit) {
                query += ` LIMIT ?`;
                params.push(parseInt(filters.limit));

                if (filters.offset) {
                    query += ` OFFSET ?`;
                    params.push(parseInt(filters.offset));
                }
            }

            const [rows] = await pool.execute(query, params);
            return rows;
        } catch (error) {
            throw error;
        }
    },

    // Get single product by ID
    async findById(productId, storeId = null) {
        try {
            let query = `SELECT * FROM products WHERE id = ?`;
            const params = [productId];

            if (storeId) {
                query += ` AND store_id = ?`;
                params.push(storeId);
            }

            const [rows] = await pool.execute(query, params);
            return rows[0] || null;
        } catch (error) {
            throw error;
        }
    },

    // Update product
    async update(productId, storeId, updateData) {
        try {
            const fields = [];
            const values = [];

            // Dynamic field updates
            const allowedFields = [
                'name',
                'sku',
                'price',
                'stock',
                'image_url',
                'is_active',
                'category',
                'jenis_diskon',
                'nilai_diskon',
                'diskon_bundle_min_qty',
                'diskon_bundle_value',
                'buy_qty',
                'free_qty',
                'description'
            ];

            // Iterate over each field and add them to the query if present in updateData
            allowedFields.forEach(field => {
                if (updateData[field] !== undefined) {
                    fields.push(`${field} = ?`);
                    values.push(updateData[field]);
                }
            });

            // If no valid fields to update, return false
            if (fields.length === 0) {
                return false;
            }

            // Add productId and storeId to values for WHERE condition
            values.push(productId, storeId);

            // Execute the update query
            const [result] = await pool.execute(
                `UPDATE products 
                SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP
                WHERE id = ? AND store_id = ?`,
                values
            );

            // Check if rows were affected and return true if update was successful
            return result.affectedRows > 0;
        } catch (error) {
            throw error;
        }
    },

    // Delete product
    async delete(productId, storeId) {
        try {
            const [result] = await pool.execute(
                `DELETE FROM products WHERE id = ? AND store_id = ?`,
                [productId, storeId]
            );
            
            return result.affectedRows > 0;
        } catch (error) {
            throw error;
        }
    },

    // Get product count for a store
    async countByStore(storeId, filters = {}) {
        try {
            let query = `SELECT COUNT(*) as count FROM products WHERE store_id = ?`;
            const params = [storeId];
            
            if (filters.is_active !== undefined) {
                query += ` AND is_active = ?`;
                params.push(filters.is_active);
            }
            
            if (filters.search) {
                query += ` AND (name LIKE ? OR sku LIKE ?)`;
                const searchTerm = `%${filters.search}%`;
                params.push(searchTerm, searchTerm);
            }
            
            const [rows] = await pool.execute(query, params);
            return rows[0].count;
        } catch (error) {
            throw error;
        }
    },

    // Search products
    async search(storeId, searchTerm, limit = 20) {
        try {
            const [rows] = await pool.execute(
                `SELECT * FROM products 
                 WHERE store_id = ? 
                 AND (name LIKE ? OR sku LIKE ?)
                 AND is_active = 1
                 ORDER BY name
                 LIMIT ?`,
                [storeId, `%${searchTerm}%`, `%${searchTerm}%`, limit]
            );
            return rows;
        } catch (error) {
            throw error;
        }
    },

    // Bulk update products
    async bulkUpdate(storeId, productIds, updateData) {
        try {
            // Validate productIds array
            if (!Array.isArray(productIds) || productIds.length === 0) {
                throw new Error('Product IDs must be a non-empty array');
            }
            
            const fields = [];
            const values = [];
            
            // Dynamic field updates
            const allowedFields = ['price', 'stock', 'is_active'];
            
            allowedFields.forEach(field => {
                if (updateData[field] !== undefined) {
                    fields.push(`${field} = ?`);
                    values.push(updateData[field]);
                }
            });
            
            if (fields.length === 0) {
                throw new Error('No valid fields to update');
            }
            
            // Create placeholders for product IDs
            const placeholders = productIds.map(() => '?').join(',');
            
            // Add storeId and productIds to values
            values.push(storeId, ...productIds);
            
            const [result] = await pool.execute(
                `UPDATE products 
                 SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP
                 WHERE store_id = ? AND id IN (${placeholders})`,
                values
            );
            
            return result.affectedRows;
        } catch (error) {
            throw error;
        }
    },

    // Update stock (for transactions)
    async updateStock(productId, storeId, quantityChange) {
        try {
            const [result] = await pool.execute(
                `UPDATE products 
                 SET stock = stock + ?, updated_at = CURRENT_TIMESTAMP
                 WHERE id = ? AND store_id = ?`,
                [quantityChange, productId, storeId]
            );
            
            return result.affectedRows > 0;
        } catch (error) {
            throw error;
        }
    },

    // Get low stock products
    async getLowStock(storeId, threshold = 10) {
        try {
            const [rows] = await pool.execute(
                `SELECT * FROM products 
                 WHERE store_id = ? 
                 AND stock <= ? 
                 AND is_active = 1
                 ORDER BY stock ASC`,
                [storeId, threshold]
            );
            return rows;
        } catch (error) {
            throw error;
        }
    },

    // Check if product exists in store
    async existsInStore(productId, storeId) {
        try {
            const [rows] = await pool.execute(
                `SELECT 1 FROM products WHERE id = ? AND store_id = ?`,
                [productId, storeId]
            );
            return rows.length > 0;
        } catch (error) {
            throw error;
        }
    },
    // Tambahkan method ini ke product.model.js
 async findByIdForTransaction(id) {
  const [rows] = await db.query(
    `SELECT p.*, 
     s.name as store_name,
     CASE 
       WHEN p.diskon_bundle_min_qty IS NOT NULL AND p.diskon_bundle_min_qty > 0
       THEN 'bundle'
       WHEN p.jenis_diskon IS NOT NULL AND p.nilai_diskon > 0
       THEN p.jenis_diskon
       ELSE 'none'
     END as discount_type,
     COALESCE(p.nilai_diskon, 0) as discount_value,
     p.diskon_bundle_min_qty,
     p.diskon_bundle_value
     FROM products p
     JOIN stores s ON p.store_id = s.id
     WHERE p.id = ? AND p.is_active = 1`,
    [id]
  );
  return rows[0] || null;
},

// Dan method untuk update stock
async updateStock(productId, quantityChange) {
  const [result] = await db.query(
    `UPDATE products 
     SET stock = stock + ?, updated_at = CURRENT_TIMESTAMP 
     WHERE id = ? AND is_active = 1`,
    [quantityChange, productId]
  );
  return result.affectedRows > 0;
}
};

module.exports = ProductModel;