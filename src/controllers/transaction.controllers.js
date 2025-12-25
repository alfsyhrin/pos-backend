const TransactionModel = require('../models/transaction.model');
const ProductModel = require('../models/product.model');
const ActivityLogModel = require('../models/activityLog.model');
const response = require('../utils/response');
const { getTenantConnection } = require('../config/db');

function mapTransactionToFrontend(tx, items = []) {
  return {
    idShort: tx.id ? String(tx.id).padStart(6, '0') : '',
    idFull: tx.id ? `TX${String(tx.id).padStart(6, '0')}` : '',
    createdAt: tx.created_at ? new Date(tx.created_at) : new Date(),
    method: tx.payment_method || tx.method || '',
    total: Math.round(tx.total_cost || tx.total || 0),
    received: Math.round(tx.received_amount || tx.received || 0),
    change: Math.round(tx.change_amount || tx.change || 0),
    items: items.map(it => ({
      productId: it.product_id,
      name: it.product_name || it.name,
      sku: it.sku,
      price: Number(it.price),
      qty: it.quantity || it.qty,
      lineTotal: Number(it.subtotal || it.lineTotal || (it.price * (it.quantity || it.qty))),
    })),
  };
}

const TransactionController = {
    // Membuat transaksi baru
    async create(req, res) {
        let conn;
        try {
            const { store_id } = req.params;
            const { user_id, total_cost, payment_type, payment_method, received_amount, change_amount, items } = req.body;
            const dbName = req.user.db_name;
            const userId = req.user.id;
            const userStoreId = req.user.store_id;

            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');

            // Verifikasi akses toko
            if (userStoreId && parseInt(userStoreId) !== parseInt(store_id)) {
                return response.badRequest(res, 'Unauthorized access to this store', 403);
            }

            conn = await getTenantConnection(dbName);

            // Verifikasi item transaksi
            let subtotal = 0;
            let discountTotal = 0;
            const processedItems = [];

            for (const item of items) {
                // Mendapatkan detail produk
                const product = await ProductModel.findById(conn, item.product_id, store_id);
                if (!product) {
                    return response.badRequest(res, `Product with ID ${item.product_id} not found`, 404);
                }

                // Memeriksa stok produk
                if (product.stock < item.quantity) {
                    return response.badRequest(res, `Insufficient stock for ${product.name}. Available: ${product.stock}`, 400);
                }

                // Menghitung detail item
                const itemSubtotal = product.price * item.quantity;
                let discountAmount = 0;

                // Menambahkan diskon jika ada
                if (item.discount_type === 'percentage' && item.discount_value > 0) {
                    discountAmount = itemSubtotal * (item.discount_value / 100);
                } else if (item.discount_type === 'nominal' && item.discount_value > 0) {
                    discountAmount = Math.min(item.discount_value, itemSubtotal);
                }

                const totalAfterDiscount = itemSubtotal - discountAmount;

                processedItems.push({
                    product_id: product.id,
                    product_name: product.name,
                    sku: product.sku,
                    price: product.price,
                    quantity: item.quantity,
                    discount_type: item.discount_type,
                    discount_value: item.discount_value,
                    discount_amount: discountAmount,
                    subtotal: itemSubtotal,
                    total_after_discount: totalAfterDiscount,
                    notes: item.notes
                });

                subtotal += itemSubtotal;
                discountTotal += discountAmount;
            }

            // Menghitung total transaksi
            // PATCH: Ambil pajak dari tabel stores
            const [storeRows] = await conn.query('SELECT tax_percentage FROM stores WHERE id = ?', [store_id]);
            const taxPercentage = Number(storeRows[0]?.tax_percentage || 0);
            const tax = subtotal * (taxPercentage / 100);
            const grandTotal = subtotal + tax - discountTotal;

            // Memeriksa pembayaran
            if (received_amount < grandTotal) {
                return response.badRequest(res, 'Insufficient payment amount', 400);
            }

            const changeAmountFinal = received_amount - grandTotal;

            // Membuat objek transaksi
            const transaction = {
                store_id,
                user_id: userId,
                total_cost: grandTotal,
                payment_type,
                payment_method,
                received_amount,
                change_amount: changeAmountFinal,
                payment_status: 'paid',
                items: processedItems,
                subtotal,
                discount_total: discountTotal,
                grand_total: grandTotal,
                tax,
                tax_percentage: taxPercentage
            };

            // Simpan transaksi dan item dalam transaksi
            await conn.beginTransaction();
            try {
                const transactionId = await TransactionModel.create(conn, transaction);
                await TransactionModel.addItems(conn, transactionId, processedItems);

                // Update stok produk
                for (const item of processedItems) {
                    await ProductModel.updateStock(conn, item.product_id, -item.quantity);
                }

                await conn.commit();
                const txId = transactionId;
                const txRow = await TransactionModel.findById(conn, txId, store_id);
                const mapped = mapTransactionToFrontend(txRow, processedItems);

                // Setelah transaksi berhasil
                await ActivityLogModel.create(conn, {
                  user_id: req.user.id,
                  store_id: req.params.store_id,
                  action: 'transaction',
                  detail: `Transaksi baru, total: Rp${total_cost}`
                });

                return response.created(res, mapped, 'Transaction created successfully');
            } catch (errTx) {
                await conn.rollback();
                throw errTx;
            }
        } catch (error) {
            console.error('Error creating transaction:', error); // Tambahkan ini
            return response.error(res, 'Error creating transaction', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Mendapatkan transaksi berdasarkan ID
    async getById(req, res) {
        let conn;
        try {
            const { store_id, id } = req.params;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const tx = await TransactionModel.findById(conn, id, store_id);
            if (!tx) return response.notFound(res, 'Transaction not found', 404);

            const items = await TransactionModel.getItemsByTransactionId(conn, id);
            const mapped = mapTransactionToFrontend(tx, items);
            return response.success(res, mapped, 'Transaction found');
        } catch (error) {
            return response.error(res, 'Error getting transaction', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    async getAll(req, res) {
        let conn;
        try {
            const { store_id } = req.params;
            const { page = 1, limit = 20, payment_status } = req.query;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const pageNum = parseInt(page);
            const limitNum = parseInt(limit);

            if (isNaN(pageNum) || pageNum < 1) {
                return response.badRequest(res, 'Parameter page tidak valid');
            }

            if (isNaN(limitNum) || limitNum < 1 || limitNum > 100) {
                return response.badRequest(res, 'Parameter limit harus antara 1-100');
            }

            // Mendapatkan transaksi berdasarkan toko
            const transactions = await TransactionModel.findAllByStore(conn, store_id, { payment_status, limit: limitNum, offset: (pageNum - 1) * limitNum });

            // Menghitung total transaksi
            const total = await TransactionModel.countByStore(conn, store_id, { payment_status });

            const mapped = await Promise.all(transactions.map(async tx => {
                const items = await TransactionModel.getItemsByTransactionId(conn, tx.id);
                return mapTransactionToFrontend(tx, items);
            }));

            return response.paginated(res, mapped, {
                total,
                page: pageNum,
                limit: limitNum,
                totalPages: Math.ceil(total / limitNum),
                hasNext: pageNum < Math.ceil(total / limitNum),
                hasPrev: pageNum > 1
            }, 'Transaksi berhasil diambil');
        } catch (error) {
            console.error('Get all transactions error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil data transaksi', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Update transaksi
    async update(req, res) {
        let conn;
        try {
            const { store_id, id } = req.params;
            const { total_cost, payment_type, payment_method, received_amount, change_amount, payment_status } = req.body;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const transactionId = parseInt(id);

            if (isNaN(transactionId)) {
                return response.badRequest(res, 'ID transaksi tidak valid');
            }

            const isUpdated = await TransactionModel.update(conn, transactionId, store_id, {
                total_cost,
                payment_type,
                payment_method,
                received_amount,
                change_amount,
                payment_status
            });

            if (!isUpdated) {
                return response.error(res, 'Gagal mengupdate transaksi', 400);
            }

            const updatedTransaction = await TransactionModel.findById(conn, transactionId, store_id);
            return response.success(res, updatedTransaction, 'Transaksi berhasil diupdate');
        } catch (error) {
            console.error('Update transaction error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengupdate transaksi', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Delete transaksi
    async delete(req, res) {
        let conn;
        try {
            const { store_id, id } = req.params;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const transactionId = parseInt(id);

            if (isNaN(transactionId)) {
                return response.badRequest(res, 'ID transaksi tidak valid');
            }

            const isDeleted = await TransactionModel.delete(conn, transactionId, store_id);

            if (!isDeleted) {
                return response.error(res, 'Gagal menghapus transaksi', 400);
            }

            return response.success(res, null, 'Transaksi berhasil dihapus');
        } catch (error) {
            console.error('Delete transaction error:', error);
            return response.error(res, 'Terjadi kesalahan saat menghapus transaksi', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Menambahkan barang ke keranjang belanja (simulasi)
    // async addItemToCart(req, res) {
    //     let conn;
    //     try {
    //         const { store_id } = req.params;
    //         const { product_id, quantity, price, discount_type, discount_value } = req.body;
    //         const dbName = req.user.db_name;
    //         if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
    //         conn = await getTenantConnection(dbName);

    //         // Mendapatkan produk dari database
    //         const product = await ProductModel.findById(conn, product_id, store_id);
    //         if (!product) {
    //             return response.badRequest(res, 'Produk tidak ditemukan', 404);
    //         }

    //         // Memeriksa stok produk
    //         if (product.stock < quantity) {
    //             return response.badRequest(res, 'Stok produk tidak cukup', 400);
    //         }

    //         // Menghitung harga dan diskon
    //         const subtotal = price * quantity;
    //         let discountAmount = 0;
    //         if (discount_type === 'percentage') {
    //             discountAmount = (discount_value / 100) * subtotal;
    //         } else if (discount_type === 'nominal') {
    //             discountAmount = Math.min(discount_value, subtotal);
    //         }

    //         const totalAfterDiscount = subtotal - discountAmount;

    //         // Simulasi: kembalikan detail item
    //         const item = {
    //             product_id,
    //             product_name: product.name,
    //             sku: product.sku,
    //             price,
    //             quantity,
    //             discount_type,
    //             discount_value,
    //             discount_amount: discountAmount,
    //             subtotal,
    //             total_after_discount: totalAfterDiscount,
    //         };

    //         return response.success(res, item, 'Barang berhasil ditambahkan ke keranjang');
    //     } catch (error) {
    //         return response.error(res, 'Terjadi kesalahan saat menambahkan barang ke keranjang', 500, error);
    //     } finally {
    //         if (conn) await conn.end();
    //     }
    // },

    // Menyelesaikan transaksi pembayaran (mirip create, bisa digabung)
    async completeTransaction(req, res) {
        // Untuk multi-tenant, gunakan logic dari create di atas
        return this.create(req, res);
    }
};

module.exports = TransactionController;
