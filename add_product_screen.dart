import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import '../shared/app_colors.dart';
import '../widgets/app_bar.dart';
import '../widgets/barcode_tools.dart';

class AddProductScreen extends StatefulWidget {
  final Product? initial;
  const AddProductScreen({super.key, this.initial});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();

  // SKU manual dipisah dari barcode
  final _sku = TextEditingController();
  final _barcode = TextEditingController();

  final _costPrice = TextEditingController(); // harga modal
  final _sellPrice = TextEditingController(); // harga jual
  final _stock = TextEditingController();

  final _desc = TextEditingController();
  final _img = TextEditingController();

  PromoType _promoType = PromoType.none;
  final _promoPercent = TextEditingController();
  final _promoAmount = TextEditingController();
  final _buyQty = TextEditingController();
  final _freeQty = TextEditingController();
  final _bundleQty = TextEditingController();
  final _bundleTotal = TextEditingController();

  bool _scannerEnabled = false;
  BarcodeKind _barcodeKind = BarcodeKind.code128;

  static const List<String> _categories = <String>[
    'Kesehatan & Kecantikan',
    'Rumah Tangga & Gaya Hidup',
    'Fashion & Aksesoris',
    'Elektronik',
    'Bayi & Anak',
    'Makanan & Minuman',
  ];

  late String _category = 'Makanan & Minuman';
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();

    _barcode.addListener(() => setState(() {}));

    final p = widget.initial;
    if (p != null) {
      _name.text = p.name;
      _sku.text = p.sku;
      _barcode.text = p.barcode;

      _costPrice.text = p.costPrice.round().toString();
      _sellPrice.text = p.sellPrice.round().toString();

      _stock.text = p.stock.toString();
      _desc.text = p.description;
      _img.text = p.imageUrl;

      _category = _categories.contains(p.category) ? p.category : 'Makanan & Minuman';

      _promoType = p.promoType;
      _promoPercent.text = p.promoPercent > 0 ? p.promoPercent.toStringAsFixed(0) : '';
      _promoAmount.text = p.promoAmount > 0 ? p.promoAmount.round().toString() : '';
      _buyQty.text = p.buyQty > 0 ? p.buyQty.toString() : '';
      _freeQty.text = p.freeQty > 0 ? p.freeQty.toString() : '';
      _bundleQty.text = p.bundleQty > 0 ? p.bundleQty.toString() : '';
      _bundleTotal.text = p.bundleTotalPrice > 0 ? p.bundleTotalPrice.round().toString() : '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _costPrice.dispose();
    _sellPrice.dispose();
    _stock.dispose();
    _desc.dispose();
    _img.dispose();

    _promoPercent.dispose();
    _promoAmount.dispose();
    _buyQty.dispose();
    _freeQty.dispose();
    _bundleQty.dispose();
    _bundleTotal.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Edit Produk' : 'Tambah Produk';

    return Scaffold(
      backgroundColor: kDarkBg,
      appBar: KimposAppBar(
        title: 'PIPos',
        subtitle: title,
        showBack: true,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: _actionBar(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final isWide = w >= 980; // tablet landscape / desktop
          final padH = isWide ? 22.0 : 16.0;
          final padV = isWide ? 16.0 : 14.0;

          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerCard(),
              const SizedBox(height: 14),
              _barcodeToolsCard(),
              const SizedBox(height: 14),
              _marginHintCard(),
            ],
          );

          final right = _formCard(isWide);

          return SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
                        child: isWide
                            ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 380, child: left),
                            const SizedBox(width: 14),
                            Expanded(child: right),
                          ],
                        )
                            : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            left,
                            const SizedBox(height: 14),
                            right,
                            const SizedBox(height: 90), // ruang bottom bar
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // WP2DW keyboard scanner: isi ke barcode (bukan SKU)
                ScannerSink(
                  enabled: _scannerEnabled,
                  onScan: (value) {
                    final cleaned = sanitizeScan(value);
                    setState(() => _barcode.text = cleaned);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Barcode masuk: $cleaned')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder),
        boxShadow: [kSoftShadow()],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(shape: BoxShape.circle, color: kMaroon.withOpacity(0.15)),
            child: Icon(_isEdit ? Icons.edit_rounded : Icons.add_box_rounded, color: kMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Produk' : 'Tambah Produk',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'SKU manual. Barcode dari scan. EAN-13 boleh input 12 digit, sistem menambah checksum.',
                  style: TextStyle(color: kTextMuted.withOpacity(0.95), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barcodeToolsCard() {
    final normalized = _normalizeBarcodeForPreview(_barcode.text, _barcodeKind);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder),
        boxShadow: [kSoftShadow()],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Barcode Tools', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pillButton(
                icon: _scannerEnabled ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                label: _scannerEnabled ? 'WP2DW Aktif' : 'WP2DW Off',
                onTap: () => setState(() => _scannerEnabled = !_scannerEnabled),
              ),
              _pillButton(
                icon: Icons.photo_camera_rounded,
                label: 'Scan Kamera',
                onTap: () async {
                  final v = await openCameraScanner(context);
                  if (!mounted) return;
                  if (v == null || v.trim().isEmpty) return;
                  setState(() => _barcode.text = sanitizeScan(v));
                },
              ),
              _pillButton(
                icon: Icons.auto_awesome_rounded,
                label: 'Generate',
                onTap: () {
                  final candidate = _uniqueBarcodeCandidate();
                  setState(() => _barcode.text = candidate);
                },
              ),
              _pillButton(
                icon: Icons.visibility_rounded,
                label: 'Preview',
                onTap: () async {
                  final data = normalized.dataForWidget;
                  if (data == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(normalized.message ?? 'Barcode belum valid')),
                    );
                    return;
                  }
                  await showBarcodePreviewDialog(
                    context: context,
                    value: data,
                    kind: _barcodeKind,
                    title: 'Preview Barcode',
                  );
                },
              ),
              _barcodeKindDropdown(),
            ],
          ),
          const SizedBox(height: 12),
          _inlinePreview(normalized),
        ],
      ),
    );
  }

  Widget _marginHintCard() {
    final cost = _parseDouble(_costPrice.text);
    final sell = _parseDouble(_sellPrice.text);

    String text;
    if (cost <= 0 || sell <= 0) {
      text = 'Isi Harga Modal dan Harga Jual untuk melihat estimasi margin.';
    } else {
      final margin = sell - cost;
      final percent = sell <= 0 ? 0 : (margin / sell) * 100;
      text = 'Estimasi margin: Rp ${_fmtInt(margin.round())} (${percent.toStringAsFixed(1)}%).';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kMaroon.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMaroon.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formCard(bool isWide) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDarkBorder),
        boxShadow: [kSoftShadow()],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.03), Colors.transparent],
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _grid2(
              isWide: isWide,
              left: _field(
                controller: _name,
                label: 'Nama Produk',
                hint: 'Contoh: Sunscreen SPF 50',
                icon: Icons.shopping_bag_rounded,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama produk wajib diisi' : null,
              ),
              right: _field(
                controller: _sku,
                label: 'SKU (Manual)',
                hint: 'Contoh: SKU-001',
                icon: Icons.tag_rounded,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'SKU wajib diisi' : null,
              ),
            ),
            const SizedBox(height: 12),
            _grid2(
              isWide: isWide,
              left: _field(
                controller: _barcode,
                label: 'Barcode (Scan)',
                hint: 'Scan WP2DW / kamera atau generate',
                icon: Icons.qr_code_rounded,
                validator: (v) {
                  final raw = sanitizeScan(v ?? '');
                  if (raw.isEmpty) return 'Barcode wajib diisi';
                  final res = _normalizeBarcodeForSave(raw, _barcodeKind);
                  if (res.error != null) return res.error;
                  return null;
                },
              ),
              right: _field(
                controller: _stock,
                label: 'Stok',
                hint: 'Contoh: 10',
                icon: Icons.inventory_2_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final raw = (v ?? '').trim();
                  final x = int.tryParse(raw);
                  if (x == null) return 'Stok harus angka';
                  if (x < 0) return 'Stok tidak boleh negatif';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            _grid2(
              isWide: isWide,
              left: _field(
                controller: _costPrice,
                label: 'Harga Modal',
                hint: 'Contoh: 8000',
                icon: Icons.shopping_cart_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final x = double.tryParse((v ?? '').trim());
                  if (x == null) return 'Harga modal harus angka';
                  if (x < 0) return 'Harga modal tidak boleh negatif';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              right: _field(
                controller: _sellPrice,
                label: 'Harga Jual',
                hint: 'Contoh: 10000',
                icon: Icons.payments_rounded,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final x = double.tryParse((v ?? '').trim());
                  if (x == null) return 'Harga jual harus angka';
                  if (x <= 0) return 'Harga jual harus > 0';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // FIX overflow kategori: pakai Column + DropdownButton isExpanded
            _categoryBox(),
            const SizedBox(height: 12),

            _promoBox(isWide),
            const SizedBox(height: 12),
            _field(
              controller: _desc,
              label: 'Deskripsi (opsional)',
              hint: 'Catatan produk',
              icon: Icons.notes_rounded,
              maxLines: 3,
              validator: (_) => null,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _img,
              label: 'Image URL (opsional)',
              hint: 'https://...',
              icon: Icons.image_rounded,
              keyboardType: TextInputType.url,
              validator: (_) => null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid2({
    required bool isWide,
    required Widget left,
    required Widget right,
  }) {
    if (!isWide) return Column(children: [left, const SizedBox(height: 12), right]);
    return Row(children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)]);
  }

  Widget _barcodeKindDropdown() {
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BarcodeKind>(
          isExpanded: true,
          dropdownColor: kSecondary,
          value: _barcodeKind,
          iconEnabledColor: Colors.white,
          items: BarcodeKind.values
              .map(
                (e) => DropdownMenuItem(
              value: e,
              child: Text(
                e.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _barcodeKind = v);
          },
        ),
      ),
    );
  }

  Widget _inlinePreview(_BarcodeNormalizeResult normalized) {
    if (normalized.dataForWidget == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Text(
          normalized.message ?? 'Preview akan muncul setelah barcode valid.',
          style: TextStyle(color: kTextMuted.withOpacity(0.95), fontWeight: FontWeight.w800),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: BarcodeWidget(
        barcode: _barcodeKind.barcode,
        data: normalized.dataForWidget!,
        drawText: true,
        errorBuilder: (context, error) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.25)),
            ),
            child: Text(
              'Barcode tidak valid untuk ${_barcodeKind.label}. Pastikan format sesuai (mis. EAN-13 wajib 12 atau 13 digit angka).',
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
            ),
          );
        },
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kMaroon.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kMaroon.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _categoryBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategori', style: TextStyle(color: kTextMuted, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.category_rounded, color: kTextMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: kSecondary,
                    value: _category,
                    iconEnabledColor: Colors.white,
                    items: _categories
                        .map(
                          (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(
                          e,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _category = v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _promoBox(bool isWide) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Promo / Diskon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),

          // FIX overflow: gunakan Wrap (bukan Row panjang)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_offer_rounded, color: kTextMuted, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Tipe Promo',
                    style: TextStyle(color: kTextMuted.withOpacity(0.95), fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<PromoType>(
                  dropdownColor: kSecondary,
                  value: _promoType,
                  iconEnabledColor: Colors.white,
                  items: const [
                    DropdownMenuItem(value: PromoType.none, child: Text('Tidak ada promo')),
                    DropdownMenuItem(value: PromoType.percent, child: Text('Diskon Persen (%)')),
                    DropdownMenuItem(value: PromoType.amount, child: Text('Potong Harga (Rp)')),
                    DropdownMenuItem(value: PromoType.buyXGetY, child: Text('Beli X Gratis Y')),
                    DropdownMenuItem(value: PromoType.bundlePrice, child: Text('Beli X Total Harga Jadi Y')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _promoType = v);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _promoFields(isWide),
          ),
        ],
      ),
    );
  }

  Widget _promoFields(bool isWide) {
    switch (_promoType) {
      case PromoType.none:
        return Text(
          'Tidak ada promo untuk produk ini.',
          key: const ValueKey('none'),
          style: TextStyle(color: kTextMuted.withOpacity(0.95), fontWeight: FontWeight.w700),
        );

      case PromoType.percent:
        return _grid2(
          isWide: isWide,
          left: _field(
            controller: _promoPercent,
            label: 'Diskon (%)',
            hint: 'Contoh: 10',
            icon: Icons.percent_rounded,
            keyboardType: TextInputType.number,
            validator: (_) => null,
          ),
          right: _helperCard('Contoh: Diskon 10% dari harga jual per item.'),
        );

      case PromoType.amount:
        return _grid2(
          isWide: isWide,
          left: _field(
            controller: _promoAmount,
            label: 'Potong Harga (Rp)',
            hint: 'Contoh: 2000',
            icon: Icons.money_off_csred_rounded,
            keyboardType: TextInputType.number,
            validator: (_) => null,
          ),
          right: _helperCard('Contoh: Potong Rp 2.000 dari harga jual per item.'),
        );

      case PromoType.buyXGetY:
        return Column(
          key: const ValueKey('buyxgety'),
          children: [
            _grid2(
              isWide: isWide,
              left: _field(
                controller: _buyQty,
                label: 'Beli (X)',
                hint: 'Contoh: 2',
                icon: Icons.shopping_cart_checkout_rounded,
                keyboardType: TextInputType.number,
                validator: (_) => null,
              ),
              right: _field(
                controller: _freeQty,
                label: 'Gratis (Y)',
                hint: 'Contoh: 1',
                icon: Icons.card_giftcard_rounded,
                keyboardType: TextInputType.number,
                validator: (_) => null,
              ),
            ),
            const SizedBox(height: 10),
            _helperCard('Contoh: B2G1 = beli 2 gratis 1.'),
          ],
        );

      case PromoType.bundlePrice:
        return Column(
          key: const ValueKey('bundle'),
          children: [
            _grid2(
              isWide: isWide,
              left: _field(
                controller: _bundleQty,
                label: 'Beli (X) item',
                hint: 'Contoh: 3',
                icon: Icons.widgets_rounded,
                keyboardType: TextInputType.number,
                validator: (_) => null,
              ),
              right: _field(
                controller: _bundleTotal,
                label: 'Total harga jadi (Rp)',
                hint: 'Contoh: 25000',
                icon: Icons.sell_rounded,
                keyboardType: TextInputType.number,
                validator: (_) => null,
              ),
            ),
            const SizedBox(height: 10),
            _helperCard('Contoh: Beli 3 total jadi Rp 25.000 (paket).'),
          ],
        );
    }
  }

  Widget _helperCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kMaroon.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kMaroon.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withOpacity(0.92), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Batal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Menyimpan...' : (_isEdit ? 'Update' : 'Simpan')),
            style: ElevatedButton.styleFrom(
              backgroundColor: kMaroon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextMuted, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: kTextMuted, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  validator: validator,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(color: kTextMuted.withOpacity(0.75), fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final promoError = _validatePromo();
    if (promoError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(promoError)));
      return;
    }

    final normalizedSave = _normalizeBarcodeForSave(sanitizeScan(_barcode.text), _barcodeKind);
    if (normalizedSave.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(normalizedSave.error!)));
      return;
    }

    setState(() => _saving = true);

    final base = widget.initial;

    final product = Product(
      id: base?.id ?? 0,
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      barcode: normalizedSave.value ?? sanitizeScan(_barcode.text),
      costPrice: double.parse(_costPrice.text.trim()),
      sellPrice: double.parse(_sellPrice.text.trim()),
      stock: int.parse(_stock.text.trim()),
      category: _category,
      description: _desc.text.trim(),
      imageUrl: _img.text.trim(),
      promoType: _promoType,
      promoPercent: _promoType == PromoType.percent ? _parseDouble(_promoPercent.text) : 0,
      promoAmount: _promoType == PromoType.amount ? _parseDouble(_promoAmount.text) : 0,
      buyQty: _promoType == PromoType.buyXGetY ? _parseInt(_buyQty.text) : 0,
      freeQty: _promoType == PromoType.buyXGetY ? _parseInt(_freeQty.text) : 0,
      bundleQty: _promoType == PromoType.bundlePrice ? _parseInt(_bundleQty.text) : 0,
      bundleTotalPrice: _promoType == PromoType.bundlePrice ? _parseDouble(_bundleTotal.text) : 0,
    );

    try {
      final result = _isEdit ? await ProductService.instance.update(product) : await ProductService.instance.add(product);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  String? _validatePromo() {
    switch (_promoType) {
      case PromoType.none:
        return null;

      case PromoType.percent:
        final v = _parseDouble(_promoPercent.text);
        if (v <= 0 || v > 100) return 'Diskon persen harus 1–100';
        return null;

      case PromoType.amount:
        final v = _parseDouble(_promoAmount.text);
        if (v <= 0) return 'Potong harga harus > 0';
        final price = double.tryParse(_sellPrice.text.trim()) ?? 0;
        if (price <= 0) return 'Harga jual belum valid';
        if (v >= price) return 'Potong harga tidak boleh >= harga jual';
        return null;

      case PromoType.buyXGetY:
        final x = _parseInt(_buyQty.text);
        final y = _parseInt(_freeQty.text);
        if (x <= 0 || y <= 0) return 'Beli X dan Gratis Y harus > 0';
        return null;

      case PromoType.bundlePrice:
        final x = _parseInt(_bundleQty.text);
        final total = _parseDouble(_bundleTotal.text);
        if (x <= 0 || total <= 0) return 'Beli X dan Total harga jadi Y harus > 0';
        return null;
    }
  }

  _BarcodeNormalizeResult _normalizeBarcodeForPreview(String raw, BarcodeKind kind) {
    final v = sanitizeScan(raw);
    if (v.isEmpty) return _BarcodeNormalizeResult(message: 'Preview akan muncul setelah barcode terisi.');

    if (kind == BarcodeKind.ean13) {
      final digits = v.replaceAll(RegExp(r'\s+'), '');
      if (!RegExp(r'^\d+$').hasMatch(digits)) {
        return _BarcodeNormalizeResult(message: 'EAN-13 harus angka saja.');
      }
      if (digits.length == 12) {
        final full = _ean13WithChecksum(digits);
        return _BarcodeNormalizeResult(
          dataForWidget: full,
          message: 'EAN-13: 12 digit diterima, checksum otomatis.',
        );
      }
      if (digits.length == 13) {
        return _BarcodeNormalizeResult(dataForWidget: digits);
      }
      return _BarcodeNormalizeResult(message: 'EAN-13 harus 12 atau 13 digit.');
    }

    return _BarcodeNormalizeResult(dataForWidget: v);
  }

  _BarcodeSaveNormalize _normalizeBarcodeForSave(String raw, BarcodeKind kind) {
    final v = sanitizeScan(raw);
    if (v.isEmpty) return _BarcodeSaveNormalize(error: 'Barcode wajib diisi');

    if (kind == BarcodeKind.ean13) {
      final digits = v.replaceAll(RegExp(r'\s+'), '');
      if (!RegExp(r'^\d+$').hasMatch(digits)) return _BarcodeSaveNormalize(error: 'EAN-13 harus angka saja');
      if (digits.length == 12) return _BarcodeSaveNormalize(value: _ean13WithChecksum(digits));
      if (digits.length == 13) return _BarcodeSaveNormalize(value: digits);
      return _BarcodeSaveNormalize(error: 'EAN-13 harus 12 atau 13 digit');
    }

    return _BarcodeSaveNormalize(value: v);
  }

  String _ean13WithChecksum(String twelveDigits) {
    final cd = _ean13CheckDigit(twelveDigits);
    return '$twelveDigits$cd';
  }

  int _ean13CheckDigit(String twelveDigits) {
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final d = int.parse(twelveDigits[i]);
      sum += (i % 2 == 0) ? d : (d * 3);
    }
    final mod = sum % 10;
    return mod == 0 ? 0 : (10 - mod);
  }

  String _uniqueBarcodeCandidate() {
    final existing = ProductService.instance.notifier.value.map((e) => e.barcode.trim()).toSet();
    for (int i = 0; i < 20; i++) {
      final candidate = (_barcodeKind == BarcodeKind.ean13)
          ? _generateEan12Candidate(existing)
          : generateSkuLikeCode(prefix: 'BC', digits: 10);

      if (!existing.contains(candidate)) return candidate;
    }
    return generateSkuLikeCode(prefix: 'BC', digits: 12);
  }

  String _generateEan12Candidate(Set<String> existing) {
    final r = DateTime.now().millisecondsSinceEpoch.toString();
    final tail = r.length >= 12 ? r.substring(r.length - 12) : r.padLeft(12, '0');
    if (!existing.contains(tail)) return tail;
    final t = tail.substring(0, 11) + ((int.parse(tail[11]) + 1) % 10).toString();
    return t;
  }

  int _parseInt(String s) => int.tryParse(s.trim()) ?? 0;
  double _parseDouble(String s) => double.tryParse(s.trim()) ?? 0;

  String _fmtInt(int value) {
    final s = value.abs().toString();
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
    return value < 0 ? '-$reversed' : reversed;
  }
}

class _BarcodeNormalizeResult {
  final String? dataForWidget;
  final String? message;
  _BarcodeNormalizeResult({this.dataForWidget, this.message});
}

class _BarcodeSaveNormalize {
  final String? value;
  final String? error;
  _BarcodeSaveNormalize({this.value, this.error});
}
