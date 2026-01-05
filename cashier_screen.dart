import 'package:flutter/material.dart';

import 'transaction_detail_screen.dart';
import 'payment_screen.dart';

import '../shared/app_colors.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../services/transaction_service.dart';

// Dipakai untuk sanitizeScan() (menghapus whitespace/enter dari scanner)
import '../widgets/barcode_tools.dart';

class CashierScreen extends StatefulWidget {
  final bool embedded;
  const CashierScreen({super.key, this.embedded = false});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  static const List<String> _categories = <String>[
    'Kesehatan & Kecantikan',
    'Rumah Tangga & Gaya Hidup',
    'Fashion & Aksesoris',
    'Elektronik',
    'Bayi & Anak',
    'Makanan & Minuman',
  ];

  final FocusNode _scanFocus = FocusNode();
  final TextEditingController _scanController = TextEditingController();
  final ScrollController _cartScroll = ScrollController();

  bool _ready = true;
  String _query = '';
  String _selectedCategory = _categories.first;

  final Map<int, int> _cart = <int, int>{};

  @override
  void initState() {
    super.initState();
    ProductService.instance.seedIfEmpty();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusScope.of(context).requestFocus(_scanFocus);
    });
  }

  @override
  void dispose() {
    _scanFocus.dispose();
    _scanController.dispose();
    _cartScroll.dispose();
    super.dispose();
  }

  String _norm(String v) => sanitizeScan(v).trim().toLowerCase();

  List<Product> _filteredProducts(List<Product> products) {
    final q = _norm(_query);

    final byCategory = products.where((p) => p.category == _selectedCategory).toList();
    if (q.isEmpty) return byCategory;

    return byCategory.where((p) {
      final nameOk = p.name.toLowerCase().contains(q);
      final skuOk = p.sku.toLowerCase().contains(q);
      final barcodeOk = p.barcode.toLowerCase().contains(q);
      final catOk = p.category.toLowerCase().contains(q);
      return nameOk || skuOk || barcodeOk || catOk;
    }).toList();
  }

  // Harga normal per item (harga jual)
  int _unitPriceInt(Product p) => p.sellPrice.round();

  int _displayUnitPriceInt(Product p) {
    switch (p.promoType) {
      case PromoType.percent:
      case PromoType.amount:
        return p.discountedUnitPrice.round();
      case PromoType.none:
      case PromoType.buyXGetY:
      case PromoType.bundlePrice:
        return _unitPriceInt(p);
    }
  }

  int _lineTotal(Product p, int qty) {
    if (qty <= 0) return 0;

    switch (p.promoType) {
      case PromoType.none:
        return _unitPriceInt(p) * qty;

      case PromoType.percent:
      case PromoType.amount:
        return (p.discountedUnitPrice * qty).round();

      case PromoType.buyXGetY:
        final x = p.buyQty;
        final y = p.freeQty;
        if (x <= 0 || y <= 0) return _unitPriceInt(p) * qty;

        final group = x + y;
        final freeItems = (qty ~/ group) * y;
        final payQty = (qty - freeItems) < 0 ? 0 : (qty - freeItems);
        return _unitPriceInt(p) * payQty;

      case PromoType.bundlePrice:
        final bundleQty = p.bundleQty;
        final bundleTotal = p.bundleTotalPrice;
        if (bundleQty <= 0 || bundleTotal <= 0) return _unitPriceInt(p) * qty;

        final groups = qty ~/ bundleQty;
        final remain = qty % bundleQty;

        final total = (groups * bundleTotal) + (remain * p.sellPrice);
        return total.round();
    }
  }

  int _subtotal(Map<int, Product> index) {
    int sum = 0;
    for (final entry in _cart.entries) {
      final p = index[entry.key];
      if (p == null) continue;
      sum += _lineTotal(p, entry.value);
    }
    return sum;
  }

  void _addToCart(Product p, {int qty = 1}) {
    if (!_ready) return;
    if (p.stock <= 0) return;

    setState(() {
      final current = _cart[p.id] ?? 0;
      final nextQty = current + qty;
      _cart[p.id] = nextQty > p.stock ? p.stock : nextQty;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cartScroll.hasClients) {
        _cartScroll.animateTo(
          _cartScroll.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _incQty(int productId, Map<int, Product> index) {
    final p = index[productId];
    if (p == null) return;
    if (p.stock <= 0) return;

    setState(() {
      final current = _cart[productId] ?? 0;
      final next = current + 1;
      _cart[productId] = next > p.stock ? p.stock : next;
    });
  }

  void _decQty(int productId) {
    final current = _cart[productId] ?? 0;
    if (current <= 1) {
      setState(() => _cart.remove(productId));
      return;
    }
    setState(() => _cart[productId] = current - 1);
  }

  void _removeItem(int productId) => setState(() => _cart.remove(productId));

  // Scan: cari BARCODE dulu, lalu SKU. Jika ketemu, add ke cart (kategori ikut pindah).
  void _onSubmitScan(List<Product> products, String value) {
    if (!_ready) return;

    final raw = sanitizeScan(value);
    final q = raw.trim();
    if (q.isEmpty) return;

    final key = q.toLowerCase();

    // 1) exact match barcode
    final byBarcode = products.where((p) => p.barcode.toLowerCase() == key).toList();
    if (byBarcode.isNotEmpty) {
      final found = byBarcode.first;

      if (_categories.contains(found.category)) {
        setState(() => _selectedCategory = found.category);
      }

      _addToCart(found);
      _scanController.clear();
      setState(() => _query = '');
      return;
    }

    // 2) exact match SKU
    final bySku = products.where((p) => p.sku.toLowerCase() == key).toList();
    if (bySku.isNotEmpty) {
      final found = bySku.first;

      if (_categories.contains(found.category)) {
        setState(() => _selectedCategory = found.category);
      }

      _addToCart(found);
      _scanController.clear();
      setState(() => _query = '');
      return;
    }

    // 3) fallback: jadikan query untuk filter list
    setState(() => _query = q);
    final filtered = _filteredProducts(products);
    if (filtered.length == 1) {
      _addToCart(filtered.first);
      _scanController.clear();
      setState(() => _query = '');
    }
  }

  Future<void> _goToPayment() async {
    if (_cart.isEmpty) return;

    final products = ProductService.instance.notifier.value;
    final index = {for (final p in products) p.id: p};
    final total = _subtotal(index);

    final result = await Navigator.of(context).push<PaymentResult>(
      MaterialPageRoute(builder: (_) => PaymentScreen(total: total)),
    );

    if (!mounted || result == null) return;

    if (result.status == PaymentStatus.paid) {
      final tx = TransactionService.instance.addFromCashier(
        cart: Map<int, int>.from(_cart),
        products: products,
        method: 'Tunai',
        received: result.paidAmount,
        additionalDiscounts: null, // Tidak ada diskon tambahan
      );

      if (tx == null) return;

      // Update stok produk
      ProductService.instance.decreaseStockByCart(Map<int, int>.from(_cart));

      // Kosongkan keranjang
      setState(() => _cart.clear());

      if (!mounted) return;

      // Tampilkan detail transaksi
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(
            transaction: tx,
            autoPrintOnOpen: true,
            autoPrintMode: ReceiptAutoPrintMode.directThermal58,
          ),
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pembayaran berhasil. Diterima: ${formatRupiah(result.paidAmount)} | Kembalian: ${formatRupiah(tx.change)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final bool desktopLayout = width >= 1100;

    return Container(
      color: kDarkBg,
      child: Column(
        children: [
          Container(height: 2, color: kMaroon.withOpacity(0.9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              children: [
                const Text(
                  'Kasir POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ValueListenableBuilder<List<Product>>(
                valueListenable: ProductService.instance.notifier,
                builder: (context, products, _) {
                  final active = products;

                  return desktopLayout
                      ? Row(
                    children: [
                      Expanded(child: _buildLeftPane(active)),
                      const SizedBox(width: 16),
                      SizedBox(width: 420, child: _buildCartPane(active)),
                    ],
                  )
                      : _buildMobileLayout(active);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(List<Product> products) {
    return Stack(
      children: [
        _buildLeftPane(products),
        Positioned(
          right: 10,
          bottom: 10,
          child: SafeArea(
            top: false,
            child: FloatingActionButton.extended(
              onPressed: () => _openCartBottomSheet(products),
              backgroundColor: kMaroon,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text('Keranjang (${_cart.length})'),
            ),
          ),
        )
      ],
    );
  }

  void _openCartBottomSheet(List<Product> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kDarkBg,
      builder: (_) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildCartPane(products),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftPane(List<Product> products) {
    return Column(
      children: [
        _buildCategoryBar(),
        const SizedBox(height: 12),
        _buildScanBar(products),
        const SizedBox(height: 14),
        Expanded(child: _buildProductGrid(products)),
      ],
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final selected = cat == _selectedCategory;

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = cat;
                  _query = '';
                  _scanController.clear();
                });
                FocusScope.of(context).requestFocus(_scanFocus);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? kMaroon.withOpacity(0.35) : kDarkBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? kMaroon : kDarkBorder),
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScanBar(List<Product> products) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              focusNode: _scanFocus,
              controller: _scanController,
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (v) => _onSubmitScan(products, v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Kategori: $_selectedCategory | Scan BARCODE / ketik SKU / cari produk...',
                hintStyle: const TextStyle(color: Colors.white38),
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _ready ? const Color(0xFF052E1B) : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _ready ? const Color(0xFF22C55E) : Colors.white24,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    final items = _filteredProducts(products);

    if (items.isEmpty) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kDarkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kDarkBorder),
        ),
        child: const Text(
          'Produk tidak ditemukan',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      );
    }

    final mq = MediaQuery.of(context);
    final width = mq.size.width;
    final isLandscape = mq.orientation == Orientation.landscape;

    final int crossAxisCount = width >= 1500
        ? 4
        : (width >= 1200 ? 3 : (width >= 900 ? 3 : (isLandscape && width >= 700 ? 3 : 2)));

    final double tileHeight = (width >= 1200 ? 170 : (isLandscape ? 166 : 156));

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        mainAxisExtent: tileHeight,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final p = items[i];
        final disabled = !_ready || p.stock <= 0;
        final displayPrice = _displayUnitPriceInt(p);

        return _ProductCard(
          product: p,
          priceInt: displayPrice,
          disabled: disabled,
          onTap: disabled ? null : () => _addToCart(p),
        );
      },
    );
  }

  Widget _buildCartPane(List<Product> products) {
    final index = {for (final p in products) p.id: p};
    final subtotal = _subtotal(index);

    return Container(
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kMaroon.withOpacity(0.85), width: 1.2),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Keranjang Belanja',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _cart.isEmpty ? null : () => setState(() => _cart.clear()),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Kosongkan'),
                  style: TextButton.styleFrom(
                    foregroundColor: _cart.isEmpty ? Colors.white24 : Colors.redAccent,
                  ),
                )
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
              child: Text(
                'Keranjang masih kosong',
                style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
              ),
            )
                : ListView(
              controller: _cartScroll,
              padding: const EdgeInsets.all(12),
              children: _cart.entries.map((e) {
                final product = index[e.key];
                if (product == null) return const SizedBox.shrink();

                final qty = e.value;
                final lineTotal = _lineTotal(product, qty);
                final unitNormal = _unitPriceInt(product);
                final promoText = product.hasPromo ? product.promoLabel() : '';

                return _CartItemRow(
                  name: product.name,
                  sku: product.sku,
                  barcode: product.barcode,
                  promo: promoText,
                  unitPrice: unitNormal,
                  qty: qty,
                  lineTotal: lineTotal,
                  onInc: () => _incQty(product.id, index),
                  onDec: () => _decQty(product.id),
                  onRemove: () => _removeItem(product.id),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: kDarkBg,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Subtotal', style: TextStyle(color: Colors.white60)),
                    const Spacer(),
                    Text(
                      formatRupiah(subtotal),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatRupiah(subtotal),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _cart.isEmpty ? null : _goToPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMaroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.payment_rounded),
                    label: const Text('Proses Pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int priceInt;
  final bool disabled;
  final VoidCallback? onTap;

  const _ProductCard({
    required this.product,
    required this.priceInt,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final barcode = product.barcode.trim();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: disabled ? 0.55 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: kDarkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kDarkBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StockBadge(value: product.stock),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatRupiah(priceInt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMaroon, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                if (product.hasPromo) ...[
                  const SizedBox(height: 6),
                  Text(
                    product.promoLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
                const Expanded(child: SizedBox()),
                Text(
                  'SKU: ${product.sku}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  'Barcode: ${barcode.isEmpty ? '-' : barcode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int value;
  const _StockBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kMaroon,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$value',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final String name;
  final String sku;
  final String barcode;
  final String promo;

  final int unitPrice;
  final int qty;
  final int lineTotal;

  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.name,
    required this.sku,
    required this.barcode,
    required this.promo,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bc = barcode.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kDarkBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU: $sku',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Barcode: ${bc.isEmpty ? '-' : bc}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w600, fontSize: 12),
                ),
                if (promo.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Promo: $promo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Harga jual: ${formatRupiah(unitPrice)}',
                  style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDec,
            icon: const Icon(Icons.remove_circle, color: kMaroon),
            splashRadius: 18,
          ),
          Text(
            '$qty',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: onInc,
            icon: const Icon(Icons.add_circle, color: kMaroon),
            splashRadius: 18,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 120,
            child: Text(
              formatRupiah(lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(color: kMaroon, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

String formatRupiah(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  int count = 0;

  for (int i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    count++;
    if (count == 3 && i != 0) {
      buf.write('.');
      count = 0;
    }
  }

  final reversed = buf.toString().split('').reversed.join();
  return 'Rp $reversed';
}