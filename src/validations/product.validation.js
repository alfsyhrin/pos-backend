const productValidation = {
    create: (req, res, next) => {
        const { name, price, stock, category, jenis_diskon, buy_qty, free_qty } = req.body;
        const errors = [];

        // Required fields
        if (!name || name.trim() === '') {
            errors.push('Nama produk harus diisi');
        }

        if (!price || isNaN(parseFloat(price))) {
            errors.push('Harga produk harus diisi dan berupa angka');
        } else if (parseFloat(price) < 0) {
            errors.push('Harga produk tidak boleh negatif');
        }

        if (stock !== undefined && isNaN(parseInt(stock))) {
            errors.push('Stok harus berupa angka');
        } else if (parseInt(stock) < 0) {
            errors.push('Stok tidak boleh negatif');
        }

        // Field length validations
        if (name && name.length > 200) {
            errors.push('Nama produk maksimal 200 karakter');
        }

        if (req.body.sku && req.body.sku.length > 50) {
            errors.push('SKU maksimal 50 karakter');
        }

        // Validate category as enum
        const allowedCategories = [
            'Kesehatan & Kecantikan',
            'Rumah Tangga & Gaya Hidup',
            'Fashion & Aksesoris',
            'Elektronik',
            'Bayi & Anak',
            'Makanan & Minuman'
        ];
        if (category && !allowedCategories.includes(category)) {
            errors.push('Kategori produk tidak valid');
        }

        // Validate jenis_diskon as enum
        const allowedJenisDiskon = [null, undefined, '', 'percentage', 'nominal', 'buyxgety', 'bundle'];
        if (jenis_diskon && !allowedJenisDiskon.includes(jenis_diskon)) {
            errors.push('Jenis diskon tidak valid');
        }

        // Validate buyxgety fields
        if (jenis_diskon === 'buyxgety') {
            if (!buy_qty || isNaN(parseInt(buy_qty)) || parseInt(buy_qty) <= 0) {
                errors.push('Beli (X) harus diisi dan > 0 untuk promo Beli X Gratis Y');
            }
            if (!free_qty || isNaN(parseInt(free_qty)) || parseInt(free_qty) <= 0) {
                errors.push('Gratis (Y) harus diisi dan > 0 untuk promo Beli X Gratis Y');
            }
        }

        if (errors.length > 0) {
            return res.status(400).json({
                success: false,
                message: 'Validasi gagal',
                errors
            });
        }

        // Trim and parse values
        req.body.name = name.trim();
        req.body.price = parseFloat(price);
        req.body.stock = stock !== undefined ? parseInt(stock) : 0;
        if (req.body.sku) req.body.sku = req.body.sku.trim();
        if (req.body.image_url) req.body.image_url = req.body.image_url.trim();
        if (category) req.body.category = category;
        if (jenis_diskon) req.body.jenis_diskon = jenis_diskon;
        if (buy_qty !== undefined) req.body.buy_qty = parseInt(buy_qty);
        if (free_qty !== undefined) req.body.free_qty = parseInt(free_qty);

        next();
    },
    
    update: (req, res, next) => {
        const { name, price, stock } = req.body;
        const errors = [];
        
        // Optional fields but validate if provided
        if (name !== undefined) {
            if (name.trim() === '') {
                errors.push('Nama produk tidak boleh kosong');
            } else if (name.length > 200) {
                errors.push('Nama produk maksimal 200 karakter');
            }
        }
        
        if (price !== undefined) {
            if (isNaN(parseFloat(price))) {
                errors.push('Harga harus berupa angka');
            } else if (parseFloat(price) < 0) {
                errors.push('Harga tidak boleh negatif');
            }
        }
        
        if (stock !== undefined) {
            if (isNaN(parseInt(stock))) {
                errors.push('Stok harus berupa angka');
            } else if (parseInt(stock) < 0) {
                errors.push('Stok tidak boleh negatif');
            }
        }
        
        if (req.body.sku && req.body.sku.length > 50) {
            errors.push('SKU maksimal 50 karakter');
        }
        
        if (errors.length > 0) {
            return res.status(400).json({
                success: false,
                message: 'Validasi gagal',
                errors
            });
        }
        
        // Parse values
        if (name !== undefined) req.body.name = name.trim();
        if (price !== undefined) req.body.price = parseFloat(price);
        if (stock !== undefined) req.body.stock = parseInt(stock);
        if (req.body.sku !== undefined) req.body.sku = req.body.sku.trim();
        if (req.body.image_url !== undefined) req.body.image_url = req.body.image_url.trim();
        
        next();
    },
    
    bulkUpdate: (req, res, next) => {
        const { product_ids, update_data } = req.body;
        const errors = [];
        
        // Validate product_ids
        if (!Array.isArray(product_ids) || product_ids.length === 0) {
            errors.push('Daftar ID produk harus berupa array tidak kosong');
        } else {
            product_ids.forEach((id, index) => {
                if (isNaN(parseInt(id))) {
                    errors.push(`ID produk ke-${index + 1} tidak valid`);
                }
            });
        }
        
        // Validate update_data
        if (!update_data || typeof update_data !== 'object' || Object.keys(update_data).length === 0) {
            errors.push('Data update harus diisi');
        } else {
            // Only allow certain fields for bulk update
            const allowedFields = ['price', 'stock', 'is_active'];
            const providedFields = Object.keys(update_data);
            
            providedFields.forEach(field => {
                if (!allowedFields.includes(field)) {
                    errors.push(`Field '${field}' tidak diperbolehkan untuk bulk update`);
                }
            });
            
            // Validate price if provided
            if (update_data.price !== undefined) {
                if (isNaN(parseFloat(update_data.price)) || parseFloat(update_data.price) < 0) {
                    errors.push('Harga harus berupa angka positif');
                }
            }
            
            // Validate stock if provided
            if (update_data.stock !== undefined) {
                if (isNaN(parseInt(update_data.stock)) || parseInt(update_data.stock) < 0) {
                    errors.push('Stok harus berupa angka positif');
                }
            }
            
            // Validate is_active if provided
            if (update_data.is_active !== undefined) {
                if (typeof update_data.is_active !== 'boolean') {
                    errors.push('is_active harus berupa boolean');
                }
            }
        }
        
        if (errors.length > 0) {
            return res.status(400).json({
                success: false,
                message: 'Validasi bulk update gagal',
                errors
            });
        }
        
        // Parse values
        req.body.product_ids = product_ids.map(id => parseInt(id));
        if (update_data.price !== undefined) update_data.price = parseFloat(update_data.price);
        if (update_data.stock !== undefined) update_data.stock = parseInt(update_data.stock);
        
        next();
    }
};

module.exports = productValidation;