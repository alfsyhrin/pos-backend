import 'package:flutter/foundation.dart';
import 'dart:math';

import '../models/product_model.dart';
import '../models/transaction_model.dart';

class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  final ValueNotifier<List<TransactionData>> transactions =
  ValueNotifier<List<TransactionData>>([]);

  String _genIdShort() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _genIdFull(String shortId) {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return 'TX$year$month$day$shortId';
  }

  // Fungsi untuk menghitung harga setelah promo berdasarkan tipe promo
  Map<String, dynamic> _calculateItemPriceWithPromo(Product product, int qty) {
    double normalPrice = product.sellPrice * qty;
    double finalPrice = 0.0;
    double discountAmount = 0.0;
    int effectiveQty = qty;

    switch (product.promoType) {
      case PromoType.none:
        finalPrice = normalPrice;
        discountAmount = 0.0;
        break;

      case PromoType.percent:
        final discountPercent = product.promoPercent.clamp(0, 100);
        discountAmount = normalPrice * (discountPercent / 100);
        finalPrice = normalPrice - discountAmount;
        break;

      case PromoType.amount:
        final discount = product.promoAmount * qty;
        discountAmount = discount.clamp(0, normalPrice);
        finalPrice = normalPrice - discountAmount;
        break;

      case PromoType.buyXGetY:
        final buyQty = product.buyQty;
        final freeQty = product.freeQty;

        if (buyQty > 0 && freeQty > 0) {
          // Hitung kelompok yang mendapatkan promo
          final groupSize = buyQty + freeQty;
          final fullGroups = qty ~/ groupSize;
          final remainder = qty % groupSize;

          final paidQty = (fullGroups * buyQty) + (remainder > buyQty ? buyQty : remainder);
          finalPrice = paidQty * product.sellPrice;
          discountAmount = normalPrice - finalPrice;

          // Untuk item gratis, kita kurangi dari total qty yang dibayar
          effectiveQty = paidQty;
        } else {
          finalPrice = normalPrice;
          discountAmount = 0.0;
        }
        break;

      case PromoType.bundlePrice:
        final bundleQty = product.bundleQty;
        final bundlePrice = product.bundleTotalPrice;

        if (bundleQty > 0) {
          final fullBundles = qty ~/ bundleQty;
          final remainder = qty % bundleQty;

          finalPrice = (fullBundles * bundlePrice) + (remainder * product.sellPrice);
          discountAmount = normalPrice - finalPrice;
        } else {
          finalPrice = normalPrice;
          discountAmount = 0.0;
        }
        break;
    }

    return {
      'finalPrice': finalPrice,
      'discountAmount': discountAmount,
      'effectiveQty': effectiveQty,
    };
  }

  // Fungsi untuk membuat item transaksi dari produk dengan promo
  TxItem _createTxItemFromProduct(Product product, int qty) {
    final calculation = _calculateItemPriceWithPromo(product, qty);
    final finalPrice = calculation['finalPrice'] as double;
    final discountAmount = calculation['discountAmount'] as double;

    return TxItem(
      idShort: product.id.toString(),
      productId: product.id.toString(),
      name: product.name,
      price: product.sellPrice.round(), // Harga normal per unit
      qty: qty,
      lineTotal: finalPrice.round(), // Total setelah diskon
      sku: product.sku,
      discountAmount: discountAmount.round(),
    );
  }

  TransactionData? addFromCashier({
    required Map<int, int> cart, // Map<productId, quantity>
    required List<Product> products,
    required String method,
    required int received,
    Map<int, double>? additionalDiscounts, // Diskon tambahan (jika ada)
  }) {
    if (cart.isEmpty) return null;

    // Buat map untuk akses cepat ke produk
    final productMap = {for (final p in products) p.id: p};

    final items = <TxItem>[];
    int subtotal = 0;

    // Proses setiap item di cart
    for (final entry in cart.entries) {
      final productId = entry.key;
      final qty = entry.value;

      final product = productMap[productId];
      if (product == null || qty <= 0) continue;

      // Buat item transaksi dengan mempertimbangkan promo produk
      final item = _createTxItemFromProduct(product, qty);

      // Terapkan diskon tambahan jika ada
      final additionalDiscount = additionalDiscounts?[productId] ?? 0.0;
      if (additionalDiscount > 0) {
        // Hitung diskon tambahan dalam rupiah
        final additionalDiscountRp = additionalDiscount.round();
        final newLineTotal = item.lineTotal - additionalDiscountRp;

        // Update item dengan diskon tambahan
        final updatedItem = TxItem(
          idShort: item.idShort,
          productId: item.productId,
          name: item.name,
          price: item.price,
          qty: item.qty,
          lineTotal: newLineTotal.clamp(0, item.lineTotal), // Pastikan tidak negatif
          sku: item.sku,
          discountAmount: item.discountAmount + additionalDiscountRp,
        );

        items.add(updatedItem);
        subtotal += updatedItem.lineTotal;
      } else {
        items.add(item);
        subtotal += item.lineTotal;
      }
    }

    if (items.isEmpty) return null;

    // Hitung total transaksi
    final total = subtotal;

    // Hitung kembalian
    final change = received - total;
    if (change < 0) {
      // Jika uang tidak cukup, kembalikan null
      return null;
    }

    // Generate ID transaksi
    final shortId = _genIdShort();
    final tx = TransactionData(
      idShort: shortId,
      idFull: _genIdFull(shortId),
      createdAt: DateTime.now(),
      method: method,
      total: total,
      received: received,
      change: change,
      items: items,
    );

    // Tambahkan ke daftar transaksi
    final current = transactions.value;
    transactions.value = [tx, ...current];

    return tx;
  }

  // Fungsi untuk mendapatkan detail promo dari item
  String _getPromoDetails(Product product) {
    if (!product.hasPromo) return '';

    switch (product.promoType) {
      case PromoType.percent:
        return 'Diskon ${product.promoPercent.round()}%';
      case PromoType.amount:
        return 'Potongan Rp ${product.promoAmount.round()}';
      case PromoType.buyXGetY:
        return 'Beli ${product.buyQty} Gratis ${product.freeQty}';
      case PromoType.bundlePrice:
        return 'Paket ${product.bundleQty} Rp ${product.bundleTotalPrice.round()}';
      default:
        return '';
    }
  }

  // Fungsi untuk menghitung total diskon dalam transaksi
  int calculateTotalDiscount(List<TxItem> items) {
    return items.fold<int>(0, (sum, item) => sum + item.discountAmount);
  }

  // Fungsi untuk menghitung total margin/laba kotor
  double calculateGrossProfit(TransactionData tx, Map<int, Product> productMap) {
    double profit = 0.0;

    for (final item in tx.items) {
      final product = productMap[int.tryParse(item.productId) ?? 0];
      if (product != null) {
        final cost = product.costPrice * item.qty;
        final revenue = item.lineTotal;
        profit += revenue - cost;
      }
    }

    return profit;
  }

  void addFromCashierVoid({
    required Map<int, int> cart,
    required List<Product> products,
    required String method,
    required int received,
    Map<int, double>? additionalDiscounts,
  }) {
    addFromCashier(
      cart: cart,
      products: products,
      method: method,
      received: received,
      additionalDiscounts: additionalDiscounts,
    );
  }

  void deleteByIdFull(String idFull) {
    transactions.value =
        transactions.value.where((t) => t.idFull != idFull).toList();
  }

  void deleteByIdShort(String idShort) {
    transactions.value =
        transactions.value.where((t) => t.idShort != idShort).toList();
  }

  TransactionData? findByIdFull(String idFull) {
    try {
      return transactions.value.firstWhere((t) => t.idFull == idFull);
    } catch (_) {
      return null;
    }
  }

  TransactionData? findByIdShort(String idShort) {
    try {
      return transactions.value.firstWhere((t) => t.idShort == idShort);
    } catch (_) {
      return null;
    }
  }

  List<TransactionData> searchByQuery(String query) {
    if (query.isEmpty) return transactions.value;

    final searchTerm = query.toLowerCase();
    return transactions.value.where((tx) {
      return tx.idFull.toLowerCase().contains(searchTerm) ||
          tx.idShort.toLowerCase().contains(searchTerm) ||
          tx.method.toLowerCase().contains(searchTerm) ||
          tx.items.any((item) =>
          item.name.toLowerCase().contains(searchTerm) ||
              item.sku.toLowerCase().contains(searchTerm));
    }).toList();
  }

  List<TransactionData> getTransactionsByDate(DateTime date) {
    return transactions.value.where((tx) {
      return tx.createdAt.year == date.year &&
          tx.createdAt.month == date.month &&
          tx.createdAt.day == date.day;
    }).toList();
  }

  List<TransactionData> getTransactionsByDateRange(DateTime start, DateTime end) {
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day + 1); // +1 untuk inklusif

    return transactions.value.where((tx) {
      final txDate = tx.createdAt;
      return txDate.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          txDate.isBefore(endDate);
    }).toList();
  }

  // Statistik transaksi
  Map<String, dynamic> getTransactionStats(DateTime? date) {
    final targetDate = date ?? DateTime.now();
    final dailyTransactions = getTransactionsByDate(targetDate);

    int totalTransactions = dailyTransactions.length;
    int totalRevenue = 0;
    int totalItemsSold = 0;
    int totalDiscounts = 0;

    for (final tx in dailyTransactions) {
      totalRevenue += tx.total;
      for (final item in tx.items) {
        totalItemsSold += item.qty;
        totalDiscounts += item.discountAmount;
      }
    }

    return {
      'date': targetDate,
      'totalTransactions': totalTransactions,
      'totalRevenue': totalRevenue,
      'totalItemsSold': totalItemsSold,
      'totalDiscounts': totalDiscounts,
      'averageTransaction': totalTransactions > 0
          ? totalRevenue ~/ totalTransactions
          : 0,
    };
  }

  // Statistik produk terlaris
  Map<int, Map<String, dynamic>> getBestSellingProducts(DateTime? startDate, DateTime? endDate) {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
    final end = endDate ?? DateTime.now();

    final transactionsInRange = getTransactionsByDateRange(start, end);

    final productStats = <int, Map<String, dynamic>>{};

    for (final tx in transactionsInRange) {
      for (final item in tx.items) {
        final productId = int.tryParse(item.productId) ?? 0;

        if (productId > 0) {
          if (!productStats.containsKey(productId)) {
            productStats[productId] = {
              'productId': productId,
              'name': item.name,
              'sku': item.sku,
              'totalSold': 0,
              'totalRevenue': 0,
              'totalQty': 0,
            };
          }

          final stats = productStats[productId]!;
          stats['totalQty'] = (stats['totalQty'] as int) + item.qty;
          stats['totalRevenue'] = (stats['totalRevenue'] as int) + item.lineTotal;
          stats['totalSold'] = (stats['totalSold'] as int) + 1; // Hitung berapa kali terjual
        }
      }
    }

    return productStats;
  }

  // Export data transaksi
  List<Map<String, dynamic>> exportTransactions() {
    return transactions.value.map((tx) {
      return {
        'idFull': tx.idFull,
        'idShort': tx.idShort,
        'date': tx.createdAt.toIso8601String(),
        'method': tx.method,
        'total': tx.total,
        'received': tx.received,
        'change': tx.change,
        'items': tx.items.map((item) => {
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'qty': item.qty,
          'lineTotal': item.lineTotal,
          'discount': item.discountAmount,
          'sku': item.sku,
        }).toList(),
      };
    }).toList();
  }

  // Import data transaksi
  void importTransactions(List<Map<String, dynamic>> data) {
    final imported = <TransactionData>[];

    for (final item in data) {
      try {
        final items = (item['items'] as List<dynamic>).map((i) {
          return TxItem(
            idShort: i['idShort']?.toString() ?? i['productId']?.toString() ?? '',
            productId: i['productId']?.toString() ?? '',
            name: i['name'] ?? '',
            price: (i['price'] ?? 0).toInt(),
            qty: (i['qty'] ?? 0).toInt(),
            lineTotal: (i['lineTotal'] ?? 0).toInt(),
            sku: i['sku'] ?? '',
            discountAmount: (i['discount'] ?? 0).toInt(),
          );
        }).toList();

        final tx = TransactionData(
          idShort: item['idShort'] ?? '',
          idFull: item['idFull'] ?? '',
          createdAt: DateTime.parse(item['date']),
          method: item['method'] ?? 'Tunai',
          total: (item['total'] ?? 0).toInt(),
          received: (item['received'] ?? 0).toInt(),
          change: (item['change'] ?? 0).toInt(),
          items: items,
        );

        imported.add(tx);
      } catch (e) {
        print('Error importing transaction: $e');
      }
    }

    transactions.value = [...imported, ...transactions.value];
  }

  // Clear all transactions
  void clearAll() {
    transactions.value = [];
  }

  // Get recent transactions
  List<TransactionData> getRecentTransactions({int limit = 10}) {
    final sorted = List<TransactionData>.from(transactions.value)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted.take(limit).toList();
  }

  // Update transaction (misalnya untuk koreksi)
  bool updateTransaction(String idFull, TransactionData updatedTx) {
    final index = transactions.value.indexWhere((t) => t.idFull == idFull);
    if (index != -1) {
      final newList = List<TransactionData>.from(transactions.value);
      newList[index] = updatedTx;
      transactions.value = newList;
      return true;
    }
    return false;
  }

  // Get total revenue for period
  int getTotalRevenue(DateTime? startDate, DateTime? endDate) {
    final start = startDate ?? DateTime(2000);
    final end = endDate ?? DateTime.now();

    final transactionsInRange = getTransactionsByDateRange(start, end);

    return transactionsInRange.fold<int>(0, (sum, tx) => sum + tx.total);
  }

  // Get transaction count for period
  int getTransactionCount(DateTime? startDate, DateTime? endDate) {
    final start = startDate ?? DateTime(2000);
    final end = endDate ?? DateTime.now();

    final transactionsInRange = getTransactionsByDateRange(start, end);

    return transactionsInRange.length;
  }
}