import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/product_service.dart';
import '../shared/app_colors.dart'; // dipakai untuk kMaxContentWidth jika ada
import '../widgets/app_bar.dart';
import '../widgets/barcode_tools.dart';
import 'add_product_screen.dart';

class ProductScreen extends StatefulWidget {
  final bool embedded;
  const ProductScreen({super.key, this.embedded = true});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _search = TextEditingController();
  bool _scannerEnabled = false;

  @override
  void initState() {
    super.initState();
    ProductService.instance.bootstrapIfEmpty();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        _ProductBody(
          searchController: _search,
          scannerEnabled: _scannerEnabled,
          onToggleScanner: () {
            setState(() => _scannerEnabled = !_scannerEnabled);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_scannerEnabled ? 'Mode scan aktif.' : 'Mode scan dimatikan.'),
              ),
            );
          },
          onAdd: () => _goAdd(context),
          onEdit: (p) => _goEdit(context, p),
          onDelete: (p) => _deleteConfirm(context, p),
          onScanCamera: () async {
            final v = await openCameraScanner(context);
            if (!mounted) return;
            if (v == null || v.trim().isEmpty) return;
            _search.text = sanitizeScan(v);
          },
          onShowBarcode: (p, kind) async {
            await showBarcodePreviewDialog(
              context: context,
              value: p.barcode.isNotEmpty ? p.barcode : p.sku,
              kind: kind,
              title: 'Barcode Produk',
            );
          },
        ),
        ScannerSink(
          enabled: _scannerEnabled,
          onScan: (value) {
            _search.text = sanitizeScan(value);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Scan diterima: ${sanitizeScan(value)}')),
            );
          },
        ),
      ],
    );

    if (widget.embedded) {
      return Container(
        color: _Palette.bg, // hitam solid
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      backgroundColor: _Palette.bg, // hitam solid
      appBar: const KimposAppBar(
        title: 'PIPos',
        subtitle: 'Produk',
        showBack: true,
      ),
      body: SafeArea(child: body),
    );
  }

  Future<void> _goAdd(BuildContext context) async {
    final created = await Navigator.push<Product?>(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );

    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk ditambahkan: ${created.name}')),
      );
    }
  }

  Future<void> _goEdit(BuildContext context, Product p) async {
    final updated = await Navigator.push<Product?>(
      context,
      MaterialPageRoute(builder: (_) => AddProductScreen(initial: p)),
    );

    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk diupdate: ${updated.name}')),
      );
    }
  }

  Future<void> _deleteConfirm(BuildContext context, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _Palette.surface,
        title: const Text(
          'Hapus produk?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Anda akan menghapus "${p.name}". Tindakan ini tidak bisa dibatalkan.',
          style: TextStyle(color: _Palette.paragraph, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _Palette.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ProductService.instance.remove(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk dihapus: ${p.name}')),
      );
    }
  }
}

class _ProductBody extends StatefulWidget {
  final TextEditingController searchController;
  final VoidCallback onAdd;
  final void Function(Product p) onEdit;
  final void Function(Product p) onDelete;

  final bool scannerEnabled;
  final VoidCallback onToggleScanner;
  final Future<void> Function() onScanCamera;
  final Future<void> Function(Product p, BarcodeKind kind) onShowBarcode;

  const _ProductBody({
    required this.searchController,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.scannerEnabled,
    required this.onToggleScanner,
    required this.onScanCamera,
    required this.onShowBarcode,
  });

  @override
  State<_ProductBody> createState() => _ProductBodyState();
}

class _ProductBodyState extends State<_ProductBody> {
  BarcodeKind _barcodeKind = BarcodeKind.code128;
  int? _selectedId;

  bool _isTabletLandscape() {
    final mq = MediaQuery.of(context);
    return mq.orientation == Orientation.landscape && mq.size.shortestSide >= 600;
  }

  bool _useThreePanel(double w) => w >= 1100 || (_isTabletLandscape() && w >= 980);
  bool _useTwoPanel(double w) => !_useThreePanel(w) && (w >= 980 || _isTabletLandscape());

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final threePanel = _useThreePanel(w);
        final twoPanel = _useTwoPanel(w);

        // “sisi-sisi” lebih lega agar tidak mepet edge pada tablet landscape
        final padH = (twoPanel || threePanel) ? 28.0 : 16.0;

        final leftW = math.min(390.0, math.max(320.0, w * 0.34));
        final detailW = threePanel ? math.min(430.0, math.max(360.0, w * 0.34)) : 0.0;

        return ValueListenableBuilder<List<Product>>(
          valueListenable: ProductService.instance.products,
          builder: (context, allItems, _) {
            final filtered = _filter(allItems, widget.searchController.text);

            if (threePanel && _selectedId == null && filtered.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _selectedId = filtered.first.id);
              });
            }

            return Column(
              children: [
                _TopHeader(
                  padH: padH,
                  totalCount: allItems.length,
                  filteredCount: filtered.length,
                  hasQuery: widget.searchController.text.trim().isNotEmpty,
                  onAdd: widget.onAdd,
                  onToggleScanner: widget.onToggleScanner,
                  scannerEnabled: widget.scannerEnabled,
                  onScanCamera: widget.onScanCamera,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (twoPanel || threePanel) ? kMaxContentWidth : double.infinity,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(padH, 18, padH, 18),
                        child: SizedBox(
                          height: double.infinity,
                          child: threePanel
                              ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: leftW, child: _leftPanel(compact: false)),
                              const SizedBox(width: 14),
                              Expanded(child: _listPanel(filtered, showHeaderRow: true)),
                              const SizedBox(width: 14),
                              SizedBox(width: detailW, child: _detailPanel(allItems)),
                            ],
                          )
                              : (twoPanel
                              ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: leftW, child: _leftPanel(compact: false)),
                              const SizedBox(width: 14),
                              Expanded(child: _listPanel(filtered, showHeaderRow: true)),
                            ],
                          )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _leftPanel(compact: true),
                              const SizedBox(height: 14),
                              Expanded(child: _listPanel(filtered, showHeaderRow: false)),
                            ],
                          )),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // LEFT
  Widget _leftPanel({required bool compact}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _searchCard(),
          const SizedBox(height: 12),
          _toolsCard(),
          const SizedBox(height: 12),
          _statsCard(),
          if (!compact) const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _searchCard() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.searchController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Cari nama / SKU / Barcode...',
                hintStyle: TextStyle(color: _Palette.paragraph.withOpacity(0.85), fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (widget.searchController.text.trim().isNotEmpty)
            IconButton(
              onPressed: () => widget.searchController.clear(),
              icon: const Icon(Icons.clear_rounded, color: Colors.white70),
              tooltip: 'Clear',
            ),
        ],
      ),
    );
  }

  Widget _toolsCard() {
    return _card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tools', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(
                icon: widget.scannerEnabled ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                label: widget.scannerEnabled ? 'WP2DW Aktif' : 'WP2DW Off',
                onTap: widget.onToggleScanner,
              ),
              _pill(
                icon: Icons.photo_camera_rounded,
                label: 'Scan Kamera',
                onTap: () => widget.onScanCamera(),
              ),
              _barcodeKindDropdown(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barcodeKindDropdown() {
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _Palette.card2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BarcodeKind>(
          isExpanded: true,
          dropdownColor: _Palette.surface,
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

  Widget _statsCard() {
    return ValueListenableBuilder<List<Product>>(
      valueListenable: ProductService.instance.products,
      builder: (context, items, _) {
        final filtered = _filter(items, widget.searchController.text);
        final stats = ProductService.instance.computeStats(filtered);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _miniStat('Total', '${stats.total}', Icons.inventory_2_rounded, _Palette.primary),
            _miniStat('Menipis', '${stats.lowStock}', Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
            _miniStat('Kategori', '${stats.categories}', Icons.category_rounded, const Color(0xFF10B981)),
          ],
        );
      },
    );
  }

  Widget _miniStat(String title, String value, IconData icon, Color accent) {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(0.18)),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: _Palette.paragraph.withOpacity(0.95), fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // LIST
  Widget _listPanel(List<Product> filtered, {required bool showHeaderRow}) {
    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeaderRow) ...[
            Row(
              children: [
                const Text('Daftar Produk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text(
                  '${filtered.length} item',
                  style: TextStyle(color: _Palette.paragraph.withOpacity(0.95), fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: filtered.isEmpty
                ? Center(
              child: Text(
                'Produk tidak ditemukan',
                style: TextStyle(color: _Palette.paragraph.withOpacity(0.95), fontWeight: FontWeight.w800),
              ),
            )
                : ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = filtered[i];
                final selected = p.id == _selectedId;

                return _ProductCardCompact(
                  product: p,
                  selected: selected,
                  onTap: () => _openOrSelect(p),
                  onEdit: () => widget.onEdit(p),
                  onDelete: () => widget.onDelete(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openOrSelect(Product p) {
    final w = MediaQuery.of(context).size.width;
    final threePanel = _useThreePanel(w);

    if (threePanel) {
      setState(() => _selectedId = p.id);
      return;
    }
    _openDetailSheet(context, p);
  }

  // DETAIL
  Widget _detailPanel(List<Product> all) {
    final p = all.where((e) => e.id == _selectedId).cast<Product?>().firstOrNull;
    if (p == null) {
      return _card(
        padding: const EdgeInsets.all(14),
        child: Center(
          child: Text(
            'Pilih produk untuk melihat detail',
            style: TextStyle(color: _Palette.paragraph.withOpacity(0.95), fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _ProductDetailPanel(
      product: p,
      barcodeKind: _barcodeKind,
      onShowBarcode: () => widget.onShowBarcode(p, _barcodeKind),
      onEdit: () => widget.onEdit(p),
      onDelete: () => widget.onDelete(p),
    );
  }

  void _openDetailSheet(BuildContext context, Product p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return _ProductDetailSheet(
          product: p,
          barcodeKind: _barcodeKind,
          onShowBarcode: () => widget.onShowBarcode(p, _barcodeKind),
          onEdit: () {
            Navigator.pop(context);
            widget.onEdit(p);
          },
          onDelete: () {
            Navigator.pop(context);
            widget.onDelete(p);
          },
        );
      },
    );
  }

  // FILTER
  List<Product> _filter(List<Product> items, String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return items;

    return items.where((p) {
      final name = p.name.toLowerCase();
      final sku = p.sku.toLowerCase();
      final bc = p.barcode.toLowerCase();
      return name.contains(query) || sku.contains(query) || bc.contains(query);
    }).toList();
  }

  // UI helpers
  Widget _card({required EdgeInsets padding, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
        boxShadow: [_Palette.shadow],
      ),
      child: child,
    );
  }

  Widget _pill({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _Palette.primary.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _Palette.primary.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

// FULL WIDTH HEADER
class _TopHeader extends StatelessWidget {
  final double padH;
  final int totalCount;
  final int filteredCount;
  final bool hasQuery;

  final VoidCallback onAdd;
  final VoidCallback onToggleScanner;
  final bool scannerEnabled;
  final Future<void> Function() onScanCamera;

  const _TopHeader({
    required this.padH,
    required this.totalCount,
    required this.filteredCount,
    required this.hasQuery,
    required this.onAdd,
    required this.onToggleScanner,
    required this.scannerEnabled,
    required this.onScanCamera,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final compact = w < 520;

    final subtitle = hasQuery ? '$filteredCount item (dari $totalCount)' : '$totalCount item';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(padH, 18, padH, 14),
      decoration: BoxDecoration(
        color: _Palette.bg,
        border: Border(
          bottom: BorderSide(color: _Palette.primary.withOpacity(0.45), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Produk',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _Palette.paragraph,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            _HeaderBtn(
              label: 'Tambah',
              icon: Icons.add_rounded,
              onTap: onAdd,
              filled: true,
            ),
            const SizedBox(width: 10),
            _HeaderBtn(
              label: 'Kamera',
              icon: Icons.photo_camera_rounded,
              onTap: () => onScanCamera(),
              filled: false,
            ),
            const SizedBox(width: 10),
            _HeaderToggle(enabled: scannerEnabled, onTap: onToggleScanner),
          ] else ...[
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
              tooltip: 'Tambah',
            ),
            PopupMenuButton<_HeaderAction>(
              color: _Palette.surface,
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
              onSelected: (v) async {
                if (v == _HeaderAction.camera) {
                  await onScanCamera();
                } else if (v == _HeaderAction.toggleScan) {
                  onToggleScanner();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _HeaderAction.camera,
                  child: _HeaderMenuRow(icon: Icons.photo_camera_rounded, label: 'Scan Kamera'),
                ),
                PopupMenuItem(
                  value: _HeaderAction.toggleScan,
                  child: _HeaderMenuRow(
                    icon: scannerEnabled ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    label: scannerEnabled ? 'WP2DW: Aktif' : 'WP2DW: Off',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _HeaderAction { camera, toggleScan }

class _HeaderMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderMenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _HeaderBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? _Palette.primary : _Palette.surface,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: filled ? null : BorderSide(color: _Palette.border),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _HeaderToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _HeaderToggle({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? _Palette.secondary.withOpacity(0.20) : _Palette.card2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: enabled ? _Palette.secondary.withOpacity(0.55) : _Palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.qr_code_scanner_rounded : Icons.qr_code_scanner_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              enabled ? 'WP2DW Aktif' : 'WP2DW Off',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

// Compact list card
class _ProductCardCompact extends StatelessWidget {
  final Product product;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCardCompact({
    required this.product,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final promo = product.hasPromo;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _Palette.cardSelected : _Palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _Palette.primary.withOpacity(0.70) : _Palette.border,
              width: selected ? 1.2 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _Palette.primary.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (promo) ...[
                          const SizedBox(width: 10),
                          _chip(product.promoLabel()),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'SKU: ${product.sku}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _Palette.paragraph.withOpacity(0.95), fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _fmtRp(product.sellPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _badge('Stok: ${product.stock}'),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            product.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _Palette.paragraph.withOpacity(0.90), fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_MenuAction>(
                tooltip: 'Aksi',
                color: _Palette.surface,
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                onSelected: (v) {
                  switch (v) {
                    case _MenuAction.edit:
                      onEdit();
                      break;
                    case _MenuAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _MenuAction.edit,
                    child: _MenuRow(icon: Icons.edit_rounded, label: 'Edit'),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.delete,
                    child: _MenuRow(icon: Icons.delete_rounded, label: 'Hapus', danger: true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _Palette.primary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Palette.primary.withOpacity(0.55)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  static Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  static String _fmtRp(double value) {
    final n = value.round();
    final s = n.abs().toString();
    final chars = s.split('');
    final out = <String>[];
    int count = 0;
    for (int i = chars.length - 1; i >= 0; i--) {
      out.add(chars[i]);
      count++;
      if (count == 3 && i != 0) {
        out.add('.');
        count = 0;
      }
    }
    final core = out.reversed.join();
    return n < 0 ? '-Rp $core' : 'Rp $core';
  }
}

enum _MenuAction { edit, delete }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _MenuRow({required this.icon, required this.label, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = danger ? Colors.redAccent : Colors.white;
    return Row(
      children: [
        Icon(icon, color: c, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

// Detail Panel
class _ProductDetailPanel extends StatelessWidget {
  final Product product;
  final BarcodeKind barcodeKind;
  final VoidCallback onShowBarcode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductDetailPanel({
    required this.product,
    required this.barcodeKind,
    required this.onShowBarcode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
        boxShadow: [_Palette.shadow],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const Text('Detail', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                const Spacer(),
                IconButton(
                  onPressed: onShowBarcode,
                  tooltip: 'Lihat Barcode',
                  icon: Icon(Icons.qr_code_rounded, color: Colors.white.withOpacity(0.9)),
                ),
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Hapus',
                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.10), height: 1),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(14),
              child: _DetailContent(
                product: product,
                barcodeKind: barcodeKind,
                onShowBarcode: onShowBarcode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Detail Sheet (mobile)
class _ProductDetailSheet extends StatelessWidget {
  final Product product;
  final BarcodeKind barcodeKind;
  final VoidCallback onShowBarcode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductDetailSheet({
    required this.product,
    required this.barcodeKind,
    required this.onShowBarcode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
        decoration: BoxDecoration(
          color: _Palette.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
          ),
          border: Border.all(color: _Palette.border),
          boxShadow: [_Palette.shadow],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _Palette.primary.withOpacity(0.18),
                    ),
                    child: const Icon(Icons.shopping_bag_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.10), height: 1),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(14),
                child: _DetailContent(
                  product: product,
                  barcodeKind: barcodeKind,
                  onShowBarcode: onShowBarcode,
                ),
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.10), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_rounded),
                      label: const Text('Hapus'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.55)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Detail content
class _DetailContent extends StatelessWidget {
  final Product product;
  final BarcodeKind barcodeKind;
  final VoidCallback onShowBarcode;

  const _DetailContent({
    required this.product,
    required this.barcodeKind,
    required this.onShowBarcode,
  });

  @override
  Widget build(BuildContext context) {
    final margin = product.margin;
    final marginPct = product.marginPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Informasi'),
        const SizedBox(height: 10),
        _infoRow('SKU', product.sku),
        const SizedBox(height: 8),
        _infoRow('Barcode', product.barcode.isEmpty ? '-' : product.barcode, mono: true),
        const SizedBox(height: 8),
        _infoRow('Kategori', product.category),
        const SizedBox(height: 8),
        _infoRow('Stok', '${product.stock}'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _priceCard('Harga Modal', product.costPrice)),
            const SizedBox(width: 10),
            Expanded(child: _priceCard('Harga Jual', product.sellPrice, emphasize: true)),
          ],
        ),
        const SizedBox(height: 12),
        _cardHint(
          icon: Icons.insights_rounded,
          text: 'Margin: ${_fmtRp(margin)} (${marginPct.toStringAsFixed(1)}%)',
        ),
        const SizedBox(height: 14),
        if (product.hasPromo) ...[
          _sectionTitle('Promo'),
          const SizedBox(height: 10),
          _chip(product.promoLabel()),
          const SizedBox(height: 14),
        ],
        if (product.description.trim().isNotEmpty) ...[
          _sectionTitle('Deskripsi'),
          const SizedBox(height: 10),
          Text(
            product.description,
            style: TextStyle(color: _Palette.paragraph.withOpacity(0.98), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
        ],
        _sectionTitle('Barcode'),
        const SizedBox(height: 10),
        Text(
          'Format: ${barcodeKind.label}',
          style: TextStyle(color: _Palette.paragraph.withOpacity(0.95), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onShowBarcode,
            icon: const Icon(Icons.qr_code_rounded),
            label: const Text('Lihat Barcode'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Palette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900));
  }

  Widget _infoRow(String label, String value, {bool mono = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Palette.card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: _Palette.paragraph.withOpacity(0.98), fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white.withOpacity(0.96),
                fontWeight: FontWeight.w800,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceCard(String title, double value, {bool emphasize = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Palette.card2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: _Palette.paragraph.withOpacity(0.98), fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            _fmtRp(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasize ? Colors.white : Colors.white.withOpacity(0.92),
              fontWeight: FontWeight.w900,
              fontSize: emphasize ? 16 : 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _Palette.primary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _Palette.primary.withOpacity(0.55)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }

  Widget _cardHint({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Palette.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.primary.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  static String _fmtRp(double value) {
    final n = value.round();
    final s = n.abs().toString();
    final chars = s.split('');
    final out = <String>[];
    int count = 0;
    for (int i = chars.length - 1; i >= 0; i--) {
      out.add(chars[i]);
      count++;
      if (count == 3 && i != 0) {
        out.add('.');
        count = 0;
      }
    }
    final core = out.reversed.join();
    return n < 0 ? '-Rp $core' : 'Rp $core';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// PALETTE: background hitam solid + surface/card lebih kontras
class _Palette {
  // Background hitam (solid)
  static const Color bg = Color(0xFF000000);

  // Aksen mengikuti request Anda
  static const Color primary = Color(0xFFE43636);
  static const Color secondary = Color(0xFFD53333);
  static const Color paragraph = Color(0xFF818386);

  // panel umum (tetap)
  static const Color surface = Color(0xFF0E0E0E);
  static const Color card = Color(0xFF111111);
  static const Color cardSelected = Color(0xFF151515);
  static const Color card2 = Color(0xFF101010);
  static const Color border = Color(0xFF262626);

  // ====== KHUSUS KOLOM LIST PRODUK (warna "sebelumnya") ======
  // container besar "Daftar Produk"
  static const Color listSurface = Color(0xFF0A0505); // nuansa gelap seperti sebelumnya
  static const Color listBorder = Color(0xFF2A1414);

  // item produk di dalam list
  static const Color listItem = Color(0xFF111111);
  static const Color listItemSelected = Color(0xFF1A0C0C);
  // ==========================================================

  static final BoxShadow shadow = BoxShadow(
    color: Colors.black.withOpacity(0.30),
    blurRadius: 10,
    offset: const Offset(0, 6),
  );
}


