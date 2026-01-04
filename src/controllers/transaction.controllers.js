const TransactionModel = require('../models/transaction.model');
const ProductModel = require('../models/product.model');
const ActivityLogModel = require('../models/activityLog.model');
const response = require('../utils/response');
const { getTenantConnection } = require('../config/db');

function mapTransactionToFrontend(tx, items = []) {
  return {
    transaction_id: tx.id, // <-- tambahkan ini
    idShort: tx.idShort || tx.id?.toString().padStart(6, '0'),
    idFull: tx.idFull || `TX${tx.id?.toString().padStart(6, '0')}`,
    createdAt: tx.created_at,
    method: tx.payment_method,
    total: tx.total_cost,
    received: tx.received_amount,
    change: tx.change_amount,
    tax_percentage: tx.tax_percentage,
    subtotal: tx.subtotal,
    discount_total: tx.discount_total,
    tax: tx.tax,
    jenis_diskon: tx.jenis_diskon,
    nilai_diskon: tx.nilai_diskon,
    buy_qty: tx.buy_qty,
    free_qty: tx.free_qty,
    items: items.map(item => ({
      productId: item.product_id,
      name: item.product_name,
      sku: item.sku,
      price: item.price,
      qty: item.quantity,
      lineTotal: item.subtotal,
      discount_type: item.discount_type,
      discount_value: item.discount_value,
      discount_amount: item.discount_amount
    }))
  };
}

const TransactionController = {
    // Membuat transaksi baru
    async create(req, res) {
        let conn;
        try {
            const { store_id } = req.params;
            const {
                payment_type, payment_method, received_amount, items,
                tax_percentage: requestTaxPercentage,
                discount_type, discount_value, buy_qty, free_qty,
                jenis_diskon, nilai_diskon, buyQty, freeQty
            } = req.body;

            const dbName = req.user.db_name;
            // Ambil user_id dari JWT/session, bukan dari req.body
            const userId = req.user.id;
            const userStoreId = req.user.store_id;

            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');

            // Verifikasi akses toko
            if (userStoreId && parseInt(userStoreId) !== parseInt(store_id)) {
                return response.badRequest(res, 'Unauthorized access to this store', 403);
            }

            conn = await getTenantConnection(dbName);

            // Verifikasi item transaksi
            let grossSubtotal = 0;     // total harga sebelum diskon
            let discountTotal = 0;    // total diskon

            const processedItems = [];

            // Map promoType ke discount_type jika discount_type null
            for (const item of items) {
                if ((!item.discount_type || item.discount_type === null) && item.promoType) {
                    item.discount_type = item.promoType;
                }
                if (item.buyQty !== undefined && item.buy_qty === undefined) {
                    item.buy_qty = item.buyQty;
                }
                if (item.freeQty !== undefined && item.free_qty === undefined) {
                    item.free_qty = item.freeQty;
                }
            }

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

                // Harga produk dari database
                const itemGross = product.price * item.quantity;
                let discountAmount = 0;

                // Percentage
                if (item.discount_type === 'percentage' && item.discount_value > 0) {
                    discountAmount = itemGross * (item.discount_value / 100);
                }
                // Nominal
                else if (item.discount_type === 'nominal' && item.discount_value > 0) {
                    discountAmount = Math.min(item.discount_value, itemGross);
                }
                // Buy X Get Y
                else if (item.discount_type === 'buyxgety' && item.buy_qty > 0 && item.free_qty > 0) {
                    const x = item.buy_qty;
                    const y = item.free_qty;
                    const totalQty = item.quantity;
                    const groupQty = x + y;
                    // Paid qty = (totalQty ~/ (x + y)) * x + (totalQty % (x + y))
                    const paidQty = Math.floor(totalQty / groupQty) * x + (totalQty % groupQty);
                    // Bonus qty = totalQty - paidQty
                    discountAmount = (totalQty - paidQty) * product.price;
                    // Subtotal yang dibayar = paidQty * product.price
                }

                // Safety
                if (discountAmount > itemGross) discountAmount = itemGross;

                const netSubtotal = itemGross - discountAmount;

                processedItems.push({
                    product_id: product.id,
                    product_name: product.name,
                    sku: product.sku,
                    price: product.price,
                    quantity: item.quantity,
                    discount_type: item.discount_type,
                    discount_value: item.discount_value,
                    discount_amount: discountAmount,
                    subtotal: netSubtotal,           // ⬅️ SIMPAN YANG NET
                    notes: item.notes
                });

                grossSubtotal += itemGross;
                discountTotal += discountAmount;

            }

            // Menghitung total transaksi
            // PATCH: Ambil pajak dari request payload atau tabel stores
            let taxPercentage;
            if (requestTaxPercentage !== undefined && requestTaxPercentage !== null) {
                taxPercentage = Number(requestTaxPercentage);
            } else {
                const [storeRows] = await conn.query('SELECT tax_percentage FROM stores WHERE id = ?', [store_id]);
                taxPercentage = Number(storeRows[0]?.tax_percentage || 0);
            }
            const netSubtotal = grossSubtotal - discountTotal;
            const tax = netSubtotal * (taxPercentage / 100);
            const grandTotal = netSubtotal + tax;

            // Memeriksa pembayaran
            console.log('DEBUG TRANSAKSI BACKEND:', {
            grossSubtotal,
            discountTotal,
            netSubtotal,
            tax,
            grandTotal,
            received_amount,
            items: processedItems
            });
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
                subtotal: netSubtotal,
                discount_total: discountTotal,
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

                // Logging aktivitas: transaksi baru
                await ActivityLogModel.create(conn, {
                  user_id: req.user.id,
                  store_id: req.params.store_id,
                  action: 'transaction',
                  detail: `Transaksi baru, total: Rp${grandTotal}`
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
            let { payment_status, search, date, start_date, end_date, limit, offset, page } = req.query;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            // normalize numeric pagination params
            limit = limit !== undefined ? parseInt(limit, 10) : undefined;
            offset = offset !== undefined ? parseInt(offset, 10) : undefined;
            page = page !== undefined ? parseInt(page, 10) : undefined;

            if (!isNaN(page) && !isNaN(limit)) {
                offset = (page - 1) * limit;
            }

            if (isNaN(limit) || limit <= 0) limit = undefined;
            if (isNaN(offset) || offset < 0) offset = undefined;

            const filters = { payment_status, search, date, start_date, end_date, limit, offset };

            const transactions = await TransactionModel.findAllByStore(conn, store_id, filters);

            const mapped = await Promise.all(transactions.map(async tx => {
                const items = await TransactionModel.getItemsByTransactionId(conn, tx.id);
                return mapTransactionToFrontend(tx, items);
            }));

            return response.success(res, mapped, 'Transaksi berhasil diambil');
        } catch (error) {
            console.error('Get all transactions error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengambil data transaksi', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Update transaksi
    // Update transaksi (hanya metadata, bukan nilai)
    async update(req, res) {
        let conn;
        try {
            const { store_id, id } = req.params;
            const { payment_type, payment_method, payment_status } = req.body;

            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            const transactionId = parseInt(id);
            if (isNaN(transactionId)) {
                return response.badRequest(res, 'ID transaksi tidak valid');
            }

            const isUpdated = await TransactionModel.update(conn, transactionId, store_id, {
                payment_type,
                payment_method,
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
    delete: async function (req, res) {
        let conn;
        try {
            const { store_id, transaction_id } = req.params;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            // Pastikan transaksi ada
            const trx = await TransactionModel.findById(conn, transaction_id, store_id);
            if (!trx) return response.notFound(res, 'Transaksi tidak ditemukan');

            const deleted = await TransactionModel.delete(conn, transaction_id, store_id);
            if (deleted) {
                // Logging aktivitas: hapus transaksi
                await ActivityLogModel.create(conn, {
                  user_id: req.user.id,
                  store_id: store_id,
                  action: 'delete_transaction',
                  detail: `Hapus transaksi: ID ${transaction_id}`
                });
                return response.success(res, null, 'Transaksi berhasil dihapus');
            } else {
                return response.error(res, 'Gagal menghapus transaksi');
            }
        } catch (error) {
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
