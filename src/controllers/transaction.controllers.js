const TransactionModel = require('../models/transaction.model');
const ProductModel = require('../models/product.model');
const response = require('../utils/response');

const TransactionController = {
    // Membuat transaksi baru
    async create(req, res) {
        try {
            const { store_id } = req.params;
            const { user_id, total_cost, payment_type, payment_method, received_amount, change_amount, items } = req.body;
            const userId = req.user.id;
            const userStoreId = req.user.store_id;

            // Verifikasi akses toko
            if (userStoreId && parseInt(userStoreId) !== parseInt(store_id)) {
                return response.badRequest(res, 'Unauthorized access to this store', 403);
            }

            // Verifikasi item transaksi
            let subtotal = 0;
            let discountTotal = 0;
            const processedItems = [];

            for (const item of items) {
                // Mendapatkan detail produk
                const product = await ProductModel.findById(item.product_id);
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
            const tax = 0; // Implementasi perhitungan pajak jika perlu
            const grandTotal = subtotal + tax - discountTotal;

            // Memeriksa pembayaran
            if (received_amount < grandTotal) {
                return response.badRequest(res, 'Insufficient payment amount', 400);
            }

            const changeAmount = received_amount - grandTotal;

            // Membuat objek transaksi
            const transaction = {
                store_id,
                user_id,
                total_cost,
                payment_type,
                payment_method,
                received_amount,
                change_amount: changeAmount,
                payment_status: 'paid', // <-- tambahkan ini!
                items: processedItems,
                subtotal,
                discount_total: discountTotal,
                grand_total: grandTotal
            };

            // Menyimpan transaksi
            const transactionId = await TransactionModel.create(transaction);

            console.log('transactionId:', transactionId);
            console.log('processedItems:', processedItems);

            // Menyimpan item-item transaksi
            await TransactionModel.addItems(transactionId, processedItems);

            return response.created(res, 'Transaction created successfully', transaction);
        } catch (error) {
            return response.error(res, 'Error creating transaction', 500, error);
        }
    },

    // Mendapatkan transaksi berdasarkan ID
    async getById(req, res) {
        try {
            const { store_id, id } = req.params;
            const transaction = await TransactionModel.findById(id, store_id);

            if (!transaction) {
                return response.notFound(res, 'Transaction not found', 404);
            }

            return response.success(res, transaction, 'Transaction found');
        } catch (error) {
            return response.error(res, 'Error getting transaction', 500, error);
        }
    },

    async getAll(req, res) {
        try {
            const { store_id } = req.params;
            const { page = 1, limit = 20, payment_status } = req.query;

            const pageNum = parseInt(page);
            const limitNum = parseInt(limit);

            if (isNaN(pageNum) || pageNum < 1) {
                return response.badRequest(res, 'Parameter page tidak valid');
            }

            if (isNaN(limitNum) || limitNum < 1 || limitNum > 100) {
                return response.badRequest(res, 'Parameter limit harus antara 1-100');
            }

            // Mendapatkan transaksi berdasarkan toko
            const transactions = await TransactionModel.findAllByStore(store_id, { payment_status, limit: limitNum, offset: (pageNum - 1) * limitNum });

            // Menghitung total transaksi
            const total = await TransactionModel.countByStore(store_id, { payment_status });

            return response.paginated(res, transactions, {
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
        }
    },

    // TransactionController.update
    async update(req, res) {
        try {
            const { store_id, id } = req.params;
            const { total_cost, payment_type, payment_method, received_amount, change_amount, payment_status } = req.body;
            const transactionId = parseInt(id);

            if (isNaN(transactionId)) {
            return response.badRequest(res, 'ID transaksi tidak valid');
            }

            const isUpdated = await TransactionModel.update(transactionId, store_id, {
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

            const updatedTransaction = await TransactionModel.findById(transactionId);
            return response.success(res, updatedTransaction, 'Transaksi berhasil diupdate');
        } catch (error) {
            console.error('Update transaction error:', error);
            return response.error(res, 'Terjadi kesalahan saat mengupdate transaksi', 500, error);
        }
    },
    // TransactionController.delete
    async delete(req, res) {
    try {
        const { store_id, id } = req.params;
        const transactionId = parseInt(id);

        if (isNaN(transactionId)) {
        return response.badRequest(res, 'ID transaksi tidak valid');
        }

        const isDeleted = await TransactionModel.delete(transactionId, store_id);

        if (!isDeleted) {
        return response.error(res, 'Gagal menghapus transaksi', 400);
        }

        return response.success(res, null, 'Transaksi berhasil dihapus');
    } catch (error) {
        console.error('Delete transaction error:', error);
        return response.error(res, 'Terjadi kesalahan saat menghapus transaksi', 500, error);
    }
    },

    // Menambahkan barang ke keranjang belanja
  async addItemToCart(req, res) {
    try {
      const { store_id } = req.params;
      const { product_id, quantity, price, discount_type, discount_value } = req.body;

      // Mendapatkan produk dari database
      const product = await ProductModel.findById(product_id);
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

      // Simpan item ke keranjang (misalnya menggunakan session atau temporary storage)
      // Sementara disimulasikan dengan mengembalikan detail item
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
        total_after_discount: totalAfterDiscount, // <-- perbaiki di sini
      };

      return response.success(res, item, 'Barang berhasil ditambahkan ke keranjang');
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat menambahkan barang ke keranjang', 500, error);
    }
  },

    // Menyelesaikan transaksi pembayaran
  async completeTransaction(req, res) {
    try {
      const { store_id } = req.params;
      const { total_cost, payment_type, payment_method, received_amount, items } = req.body;

      // Ambil user_id dari token autentikasi
      const user_id = req.user && req.user.id ? req.user.id : null;
      if (!user_id) {
        return response.badRequest(res, 'User tidak valid', 400);
      }

      // Validasi jika data pembayaran tidak mencukupi
      if (received_amount < total_cost) {
        return response.badRequest(res, 'Jumlah uang yang diterima tidak mencukupi', 400);
      }

      let subtotal = 0;
      let discountTotal = 0;
      const processedItems = [];

      // Proses item yang dibeli
      for (const item of items) {
        const product = await ProductModel.findById(item.product_id);
        if (!product) {
          return response.badRequest(res, `Produk dengan ID ${item.product_id} tidak ditemukan`, 404);
        }

        const itemSubtotal = item.price * item.quantity;
        let discountAmount = 0;

        // Hitung diskon berdasarkan tipe
        if (item.discount_type === 'percentage') {
          discountAmount = (item.discount_value / 100) * itemSubtotal;
        } else if (item.discount_type === 'nominal') {
          discountAmount = Math.min(item.discount_value, itemSubtotal);
        }

        const totalAfterDiscount = itemSubtotal - discountAmount;
        processedItems.push({
          ...item,
          discount_amount: discountAmount,
          subtotal: itemSubtotal,
          total_after_discount: totalAfterDiscount
        });

        subtotal += itemSubtotal;
        discountTotal += discountAmount;
      }

      const tax = 0; // Jika ada perhitungan pajak
      const grandTotal = subtotal + tax - discountTotal;

      const changeAmount = received_amount - grandTotal;

      // Membuat transaksi
      const transaction = {
        store_id,
        user_id, // <-- pastikan user_id diisi
        total_cost,
        payment_type,
        payment_method,
        received_amount,
        change_amount: changeAmount,
        payment_status: 'paid', // <-- tambahkan ini!
        items: processedItems,
        subtotal,
        discount_total: discountTotal,
        grand_total: grandTotal
      };

      // Simpan transaksi
      const transactionId = await TransactionModel.create(transaction);
      await TransactionModel.addItems(transactionId, processedItems);

      return response.created(res, 'Transaksi selesai', transaction);
    } catch (error) {
      return response.error(res, 'Terjadi kesalahan saat menyelesaikan transaksi', 500, error);
    }
  }
};

module.exports = TransactionController;
