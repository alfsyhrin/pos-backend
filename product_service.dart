import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

class ProductStats {
  final int total;
  final int lowStock;
  final int categories;

  const ProductStats({
    required this.total,
    required this.lowStock,
    required this.categories,
  });
}

class ProductService {
  ProductService._();
  static final ProductService instance = ProductService._();

  final ValueNotifier<List<Product>> products = ValueNotifier<List<Product>>([]);
  ValueNotifier<List<Product>> get notifier => products;

  int _idSeq = 1;

  void bootstrapIfEmpty() {
    if (products.value.isNotEmpty) return;

    products.value = <Product>[
      Product(
        id: _idSeq++,
        name: 'Kopi Susu 250ml',
        sku: 'SKU-001',
        barcode: '8991234567890', // contoh 13 digit
        costPrice: 8000,
        sellPrice: 12500,
        stock: 10,
        category: 'Makanan & Minuman',
        description: 'Minuman siap minum',
        imageUrl: '',
      ),
      Product(
        id: _idSeq++,
        name: 'Sunscreen SPF 50',
        sku: 'SKU-002',
        barcode: '8990001112223',
        costPrice: 32000,
        sellPrice: 45000,
        stock: 6,
        category: 'Kesehatan & Kecantikan',
        description: 'Perawatan kulit',
        imageUrl: '',
      ),
    ];
  }

  void seedIfEmpty() => bootstrapIfEmpty();

  ProductStats computeStats(List<Product> items) {
    final total = items.length;
    final lowStock = items.where((p) => p.stock <= 3).length;
    final categories = items
        .map((e) => e.category.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .length;

    return ProductStats(total: total, lowStock: lowStock, categories: categories);
  }

  void _ensureUniqueOrThrow(Product p, {required bool isUpdate}) {
    final skuKey = p.sku.trim().toLowerCase();
    final bcKey = p.barcode.trim().toLowerCase();

    for (final x in products.value) {
      if (isUpdate && x.id == p.id) continue;

      if (x.sku.trim().toLowerCase() == skuKey) {
        throw Exception('SKU sudah dipakai produk lain');
      }
      if (x.barcode.trim().toLowerCase() == bcKey) {
        throw Exception('Barcode sudah dipakai produk lain');
      }
    }
  }

  Future<Product> add(Product p) async {
    _ensureUniqueOrThrow(p, isUpdate: false);

    final created = p.copyWith(id: _idSeq++);
    products.value = [...products.value, created];
    return created;
  }

  Future<Product> update(Product p) async {
    final idx = products.value.indexWhere((x) => x.id == p.id);
    if (idx < 0) throw Exception('Produk tidak ditemukan');

    _ensureUniqueOrThrow(p, isUpdate: true);

    final next = [...products.value];
    next[idx] = p;
    products.value = next;
    return p;
  }

  Future<void> remove(int id) async {
    products.value = products.value.where((p) => p.id != id).toList();
  }

  void decreaseStockByCart(Map<int, int> cart) {
    if (cart.isEmpty) return;

    products.value = products.value.map((p) {
      final qty = cart[p.id];
      if (qty == null || qty <= 0) return p;
      final newStock = (p.stock - qty);
      return p.copyWith(stock: newStock < 0 ? 0 : newStock);
    }).toList();
  }
}
