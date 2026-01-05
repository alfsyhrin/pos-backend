import 'package:bluetooth_classic/models/device.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../shared/app_colors.dart';
import '../models/transaction_model.dart';
import '../services/receipt_pdf_service.dart';
import '../services/receipt_bt_printer_service.dart';
import '../services/transaction_service.dart';

enum ReceiptAutoPrintMode {
  directThermal58,
  pdfRoll58,
}

class TransactionDetailScreen extends StatefulWidget {
  final TransactionData transaction;

  final bool autoPrintOnOpen;
  final ReceiptAutoPrintMode autoPrintMode;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.autoPrintOnOpen = false,
    this.autoPrintMode = ReceiptAutoPrintMode.directThermal58,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool _printingPdf = false;
  bool _printingDirect = false;
  bool _autoPrintTriggered = false;

  final String _storeName = 'Toko Sukses Jaya';
  final String _storeAddress = 'Jl. Contoh No. 123, Jakarta';
  final String _storePhone = '+62 812-3456-7890';
  final String _footerNote = 'Barang yang sudah dibeli tidak dapat dikembalikan.';

  int get _subtotal =>
      widget.transaction.items.fold<int>(0, (sum, it) => sum + it.lineTotal);

  String _dateTimeLabel(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = months[dt.month - 1];
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd $mm $yyyy, $hh:$min';
  }

  String fmtRpNum(num value) {
    final intValue = value.round();
    final s = intValue.abs().toString();
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
    final prefix = intValue < 0 ? '-Rp ' : 'Rp ';
    return '$prefix$reversed';
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!widget.autoPrintOnOpen) return;
      if (_autoPrintTriggered) return;

      _autoPrintTriggered = true;

      if (widget.autoPrintMode == ReceiptAutoPrintMode.directThermal58) {
        await _printDirectThermal58();
      } else {
        await _printPdfRoll();
      }
    });
  }

  Future<void> _printPdfRoll() async {
    if (_printingPdf) return;
    setState(() => _printingPdf = true);

    try {
      final res = await ReceiptPdfService.generateRollBytes(
        widget.transaction,
        storeName: _storeName,
        storeAddress: _storeAddress,
        storePhone: _storePhone,
        footerNote: _footerNote,
      );

      await Printing.layoutPdf(
        format: res.format,
        onLayout: (_) async => res.bytes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dialog print dibuka (PDF roll 58mm).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal print PDF roll: $e')),
      );
    } finally {
      if (mounted) setState(() => _printingPdf = false);
    }
  }

  Future<void> _printDirectThermal58() async {
    if (_printingDirect) return;
    setState(() => _printingDirect = true);

    try {
      await ReceiptBtPrinterService.instance.ensurePermissions();

      final device = await showModalBottomSheet<Device>(
        context: context,
        backgroundColor: kDarkSurface,
        isScrollControlled: true,
        builder: (_) => const _BondedPrinterPickerSheet(
          title: 'Pilih Printer Thermal 58mm',
          hint: 'Pairing dulu di Bluetooth Android. Jika muncul "RP02N", pilih itu.',
        ),
      );

      if (device == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cetak dibatalkan. Anda bisa cetak lagi dari tombol di bawah.')),
        );
        return;
      }

      await ReceiptBtPrinterService.instance.printReceipt(
        device: device,
        tx: widget.transaction,
        storeName: _storeName,
        storeAddress: _storeAddress,
        storePhone: _storePhone,
        footerNote: _footerNote,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil print ke: ${device.name ?? device.address}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal print langsung: $e')),
      );
    } finally {
      if (mounted) setState(() => _printingDirect = false);
    }
  }

  Future<void> _deleteTx() async {
    final tx = widget.transaction;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kDarkSurface,
        title: const Text('Hapus transaksi?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Transaksi ${tx.idFull} akan dihapus.',
          style: TextStyle(color: Colors.white.withOpacity(0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: kTextMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      TransactionService.instance.deleteByIdFull(tx.idFull);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;

    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 900;
            final padH = isWide ? 24.0 : 16.0;

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(padH, 18, padH, 14),
                  decoration: BoxDecoration(
                    color: kDarkSurface,
                    border: Border(
                      bottom: BorderSide(color: kMaroon.withOpacity(0.45), width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detail Transaksi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tx.idFull,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(padH, 16, padH, 16),
                    children: [
                      _fieldCard('No. Transaksi', tx.idFull),
                      const SizedBox(height: 10),
                      _fieldCard('Tanggal & Waktu', _dateTimeLabel(tx.createdAt)),
                      const SizedBox(height: 10),
                      _fieldCard('Metode Pembayaran', tx.method),
                      const SizedBox(height: 14),
                      _itemsCard(tx),
                      const SizedBox(height: 14),
                      _summaryCard(tx),
                    ],
                  ),
                ),

                Container(
                  padding: EdgeInsets.fromLTRB(padH, 12, padH, 14),
                  decoration: BoxDecoration(
                    color: kDarkSurface,
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: isWide ? 360 : double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _printingDirect ? null : _printDirectThermal58,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _printingDirect
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.print_rounded, color: Colors.white),
                          label: Text(
                            _printingDirect ? 'Mencetak...' : 'Print Langsung (Thermal 58mm)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: isWide ? 360 : double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _printingPdf ? null : _printPdfRoll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kMaroon,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: _printingPdf
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                          label: Text(
                            _printingPdf ? 'Menyiapkan...' : 'Print PDF Roll (58mm)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),

                      SizedBox(
                        width: isWide ? 180 : double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _deleteTx,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.delete_outline, color: Colors.white),
                          label: const Text(
                            'Hapus',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _fieldCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _itemsCard(TransactionData tx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Item Pembelian',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          ...tx.items.map((it) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          '${fmtRpNum(it.price)} × ${it.qty}',
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SKU: ${it.sku}',
                          style: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fmtRpNum(it.lineTotal),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _summaryCard(TransactionData tx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Column(
        children: [
          _row('Subtotal', fmtRpNum(_subtotal), mutedLeft: true),
          const SizedBox(height: 10),
          Container(height: 1, color: kMaroon.withOpacity(0.35)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('TOTAL', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(
                fmtRpNum(tx.total),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row('Tunai Diterima', fmtRpNum(tx.received)),
          const SizedBox(height: 8),
          _row('Kembalian', fmtRpNum(tx.change)),
        ],
      ),
    );
  }

  Widget _row(String left, String right, {bool mutedLeft = false}) {
    return Row(
      children: [
        Text(
          left,
          style: TextStyle(
            color: mutedLeft ? Colors.white.withOpacity(0.55) : Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _BondedPrinterPickerSheet extends StatefulWidget {
  final String title;
  final String hint;
  const _BondedPrinterPickerSheet({required this.title, required this.hint});

  @override
  State<_BondedPrinterPickerSheet> createState() => _BondedPrinterPickerSheetState();
}

class _BondedPrinterPickerSheetState extends State<_BondedPrinterPickerSheet> {
  bool _loading = true;
  List<Device> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ReceiptBtPrinterService.instance.getBondedDevices();
      if (!mounted) return;
      setState(() {
        _devices = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.hint,
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            if (_loading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Text('Memuat daftar perangkat...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],

            if (!_loading && _devices.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Tidak ada perangkat paired.\nPairing printer dulu di Settings Bluetooth Android.',
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _devices.length,
                separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.08)),
                itemBuilder: (_, i) {
                  final d = _devices[i];
                  return ListTile(
                    onTap: () => Navigator.pop(context, d),
                    title: Text(d.name ?? 'Printer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    subtitle: Text(d.address, style: TextStyle(color: Colors.white.withOpacity(0.65))),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
