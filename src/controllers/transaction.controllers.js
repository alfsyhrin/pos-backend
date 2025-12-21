const TransactionModel = require('../models/transaction.model');
const ProductModel = require('../models/product.model');
const ActivityLogModel = require('../models/activityLog.model');
const response = require('../utils/response');
// ganti import db agar dapat akses main pool & getTenantConnection
const dbModule = require('../config/db');
const { getTenantConnection } = dbModule;
const MainPool = dbModule.pool || dbModule; // fallback jika export berbeda

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

        // basic validations
        if (!Array.isArray(items) || items.length === 0) {
          return response.badRequest(res, 'Items transaksi tidak boleh kosong');
        }

        const dbName = req.user?.db_name;
        if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');

        conn = await getTenantConnection(dbName);

        // Pastikan user_id mengacu pada users di tenant DB.
        // Jika user_id tidak ada di tenant, coba cek di main DB (owners),
        // lalu buat user di tenant (replicate owner) dan pakai id tenant.
        let tenantUserId = user_id || req.user?.id;
        if (!tenantUserId) return response.badRequest(res, 'user_id tidak boleh kosong');

        const [tenantUserRows] = await conn.execute('SELECT id FROM users WHERE id = ?', [tenantUserId]);
        if (tenantUserRows.length === 0) {
          // cek di main DB owners
          const [ownerRows] = await MainPool.execute('SELECT id, name, email FROM owners WHERE id = ?', [tenantUserId]);
          if (ownerRows.length > 0) {
            const owner = ownerRows[0];
            // masukkan owner sebagai user di tenant (password kosong, role owner)
            const [ins] = await conn.execute(
              'INSERT INTO users (name, email, password, role, created_at) VALUES (?, ?, ?, ?, NOW())',
              [owner.name || 'Owner', owner.email || null, '', 'owner']
            );
            tenantUserId = ins.insertId;
          } else {
            return response.badRequest(res, 'Kasir/Owner tidak ditemukan', 404);
          }
        }

        // --- lanjutkan proses transaksi seperti sebelumnya, gunakan tenantUserId ---
        // contoh singkat: hitung subtotal, tax, simpan transaksi, dll.
        // pastikan TransactionModel.create dipanggil dengan user_id = tenantUserId

        // (contoh minimal untuk menghindari foreign key error — sesuaikan dengan logika app)
        let subtotal = 0;
        const processedItems = [];
        for (const it of items) {
          const product = await ProductModel.findById(conn, it.product_id, store_id);
          if (!product) return response.badRequest(res, `Product with ID ${it.product_id} not found`, 404);
          if (product.stock < it.quantity) return response.badRequest(res, `Insufficient stock for ${product.name}`, 400);

          const itemSubtotal = Number(product.price) * Number(it.quantity);
          subtotal += itemSubtotal;
          processedItems.push({
            product_id: product.id,
            quantity: it.quantity,
            price: product.price,
            subtotal: itemSubtotal
          });
        }

        // simple tax calc (jika ada)
        const tax = 0;
        const grandTotal = subtotal + tax;

        if (Number(received_amount) < grandTotal) {
          return response.badRequest(res, 'Insufficient payment amount', 400);
        }

        const txObj = {
          store_id,
          user_id: tenantUserId, // penting: gunakan tenant user id
          total_cost: grandTotal,
          payment_type,
          payment_method,
          received_amount,
          change_amount: Number(received_amount) - grandTotal,
          payment_status: 'paid'
        };

        await conn.beginTransaction();
        try {
          const txId = await TransactionModel.create(conn, txObj);
          await TransactionModel.addItems(conn, txId, processedItems);

          // update stok
          for (const it of processedItems) {
            await ProductModel.updateStock(conn, it.product_id, -it.quantity);
          }

          await conn.commit();
          await ActivityLogModel.create(conn, {
            user_id: req.user?.id,
            store_id,
            action: 'transaction',
            detail: `Transaksi dibuat oleh user tenant id ${tenantUserId}`
          });

          const txRow = await TransactionModel.findById(conn, txId, store_id);
          return response.created(res, txRow, 'Transaction created successfully');
        } catch (errTx) {
          await conn.rollback();
          throw errTx;
        }

      } catch (error) {
        console.error('CREATE TRANSACTION ERROR:', error);
        return response.error(res, 'Error creating transaction', 500, error);
      } finally {
        if (conn && typeof conn.end === 'function') await conn.end();
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
    async addItemToCart(req, res) {
        let conn;
        try {
            const { store_id } = req.params;
            const { product_id, quantity, price, discount_type, discount_value } = req.body;
            const dbName = req.user.db_name;
            if (!dbName) return response.badRequest(res, 'Tenant DB tidak ditemukan di token.');
            conn = await getTenantConnection(dbName);

            // Mendapatkan produk dari database
            const product = await ProductModel.findById(conn, product_id, store_id);
            if (!product) {
                return response.badRequest(res, 'Produk tidak ditemukan', 404);
            }

            // Memeriksa stok produk
            if (product.stock < quantity) {
                return response.badRequest(res, 'Stok produk tidak cukup', 400);
            }

            // Menghitung harga dan diskon
            const subtotal = price * quantity;
            let discountAmount = 0;
            if (discount_type === 'percentage') {
                discountAmount = (discount_value / 100) * subtotal;
            } else if (discount_type === 'nominal') {
                discountAmount = Math.min(discount_value, subtotal);
            }

            const totalAfterDiscount = subtotal - discountAmount;

            // Simulasi: kembalikan detail item
            const item = {
                product_id,
                product_name: product.name,
                sku: product.sku,
                price,
                quantity,
                discount_type,
                discount_value,
                discount_amount: discountAmount,
                subtotal,
                total_after_discount: totalAfterDiscount,
            };

            return response.success(res, item, 'Barang berhasil ditambahkan ke keranjang');
        } catch (error) {
            return response.error(res, 'Terjadi kesalahan saat menambahkan barang ke keranjang', 500, error);
        } finally {
            if (conn) await conn.end();
        }
    },

    // Menyelesaikan transaksi pembayaran (mirip create, bisa digabung)
    async completeTransaction(req, res) {
        // Untuk multi-tenant, gunakan logic dari create di atas
        return this.create(req, res);
    }
};

module.exports = TransactionController;
