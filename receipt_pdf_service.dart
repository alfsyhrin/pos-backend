import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction_model.dart';
import '../services/store_settings_service.dart';

class ReceiptPdfService {
  /// Generate PDF bytes dengan semua parameter dari pengaturan
  static Future<({Uint8List bytes, PdfPageFormat format})> generateRollBytes(
      TransactionData tx, {
        String storeName = 'TOKO',
        String storeAddress = '-',
        String storePhone = '-',
        String? footerNote,
        // Parameter baru dari settings
        String receiptTemplate = 'DEFAULT_TEMPLATE_V1',
        bool showStoreLogo = true,
        bool showItemDetails = true,
        bool showTaxInfo = true,
        bool showFooterNote = true,
        int paperWidth = 58,
      }) async {
    // ====== Tentukan format halaman berdasarkan lebar kertas ======
    final widthMm = paperWidth.toDouble();

    // Hitung tinggi dinamis berdasarkan konten
    final baseHeightMm = _calculateBaseHeight(
      template: receiptTemplate,
      showItemDetails: showItemDetails,
      showTaxInfo: showTaxInfo,
      showFooterNote: showFooterNote && footerNote != null,
      itemCount: tx.items.length,
    );

    final format = PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      baseHeightMm * PdfPageFormat.mm,
      marginAll: _getMarginByTemplate(receiptTemplate) * PdfPageFormat.mm,
    );

    final doc = pw.Document();

    // Helper functions
    String fmtRp(int value) {
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
      return '${value < 0 ? '-' : ''}Rp $reversed';
    }

    String dateLabel(DateTime dt) {
      const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = months[dt.month - 1];
      final yyyy = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dd $mm $yyyy $hh:$min';
    }

    // Hitung subtotal dan pajak
    final subtotal = tx.items.fold<int>(0, (sum, it) => sum + it.lineTotal);
    final tax = showTaxInfo ? (subtotal * 0.1).round() : 0;

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (ctx) {
          // ====== Tentukan gaya berdasarkan template ======
          final styles = _getPdfStyles(receiptTemplate, paperWidth);

          // Widget helper
          pw.Widget line() {
            if (receiptTemplate == 'MINIMALIST') {
              return pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 4),
                height: 0.5,
                color: PdfColors.grey400,
              );
            }
            return pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 6),
              height: 0.7,
              color: PdfColors.grey700,
            );
          }

          pw.Widget kv(String left, String right, {bool bold = false, bool total = false}) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(left, style: bold ? styles.boldStyle : styles.normalStyle),
                pw.Text(right, style: total ? styles.totalStyle : (bold ? styles.boldStyle : styles.normalStyle)),
              ],
            );
          }

          // ====== BANGUN STRUK BERDASARKAN TEMPLATE ======
          switch (receiptTemplate) {
            case 'MINIMALIST':
              return _buildMinimalistReceipt(
                tx: tx,
                storeName: storeName,
                storeAddress: storeAddress,
                storePhone: storePhone,
                footerNote: footerNote,
                showItemDetails: showItemDetails,
                showTaxInfo: showTaxInfo,
                showFooterNote: showFooterNote,
                subtotal: subtotal,
                tax: tax,
                fmtRp: fmtRp,
                dateLabel: dateLabel,
                line: line,
                kv: kv,
                styles: styles,
              );

            case 'DEFAULT_TEMPLATE_V2':
              return _buildDefaultV2Receipt(
                tx: tx,
                storeName: storeName,
                storeAddress: storeAddress,
                storePhone: storePhone,
                footerNote: footerNote,
                showItemDetails: showItemDetails,
                showTaxInfo: showTaxInfo,
                showFooterNote: showFooterNote,
                subtotal: subtotal,
                tax: tax,
                fmtRp: fmtRp,
                dateLabel: dateLabel,
                line: line,
                kv: kv,
                styles: styles,
              );

            case 'MODERN':
              return _buildModernReceipt(
                tx: tx,
                storeName: storeName,
                storeAddress: storeAddress,
                storePhone: storePhone,
                footerNote: footerNote,
                showStoreLogo: showStoreLogo,
                showItemDetails: showItemDetails,
                showTaxInfo: showTaxInfo,
                showFooterNote: showFooterNote,
                subtotal: subtotal,
                tax: tax,
                fmtRp: fmtRp,
                dateLabel: dateLabel,
                line: line,
                kv: kv,
                styles: styles,
              );

            case 'DETAILED':
              return _buildDetailedReceipt(
                tx: tx,
                storeName: storeName,
                storeAddress: storeAddress,
                storePhone: storePhone,
                footerNote: footerNote,
                showItemDetails: showItemDetails,
                showTaxInfo: showTaxInfo,
                showFooterNote: showFooterNote,
                subtotal: subtotal,
                tax: tax,
                fmtRp: fmtRp,
                dateLabel: dateLabel,
                line: line,
                kv: kv,
                styles: styles,
              );

            default: // DEFAULT_TEMPLATE_V1
              return _buildDefaultV1Receipt(
                tx: tx,
                storeName: storeName,
                storeAddress: storeAddress,
                storePhone: storePhone,
                footerNote: footerNote,
                showItemDetails: showItemDetails,
                showTaxInfo: showTaxInfo,
                showFooterNote: showFooterNote,
                subtotal: subtotal,
                tax: tax,
                fmtRp: fmtRp,
                dateLabel: dateLabel,
                line: line,
                kv: kv,
                styles: styles,
              );
          }
        },
      ),
    );

    final bytes = await doc.save();
    return (bytes: bytes, format: format);
  }

  // ====== FUNGSI-FUNGSI PEMBANGUN STRUK ======

  static pw.Widget _buildMinimalistReceipt({
    required TransactionData tx,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String? footerNote,
    required bool showItemDetails,
    required bool showTaxInfo,
    required bool showFooterNote,
    required int subtotal,
    required int tax,
    required String Function(int) fmtRp,
    required String Function(DateTime) dateLabel,
    required pw.Widget Function() line,
    required pw.Widget Function(String, String, {bool bold, bool total}) kv,
    required PdfStyles styles,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header minimalis
        pw.Text(storeName, style: styles.titleStyle, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text(dateLabel(tx.createdAt), style: styles.smallStyle, textAlign: pw.TextAlign.center),
        line(),

        // Item pembelian
        ...tx.items.map((it) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(it.name, style: styles.normalStyle),
                    ),
                    pw.Text(fmtRp(it.lineTotal), style: styles.boldStyle),
                  ],
                ),
                if (showItemDetails) pw.Text('${fmtRp(it.price as int)} x ${it.qty}', style: styles.smallStyle),
              ],
            ),
          );
        }),

        line(),

        // Ringkasan
        if (showTaxInfo && tax > 0) kv('Subtotal', fmtRp(subtotal)),
        if (showTaxInfo && tax > 0) kv('Pajak 10%', fmtRp(tax)),
        kv('TOTAL', fmtRp(tx.total), total: true),
        pw.SizedBox(height: 4),
        kv('Tunai', fmtRp(tx.received)),
        kv('Kembalian', fmtRp(tx.change)),

        line(),

        // Footer
        if (showFooterNote && footerNote != null && footerNote.trim().isNotEmpty)
          pw.Text(footerNote, style: styles.smallStyle, textAlign: pw.TextAlign.center),

        pw.SizedBox(height: 6),
        pw.Text('Terima kasih', style: styles.boldStyle, textAlign: pw.TextAlign.center),
      ],
    );
  }

  static pw.Widget _buildDefaultV1Receipt({
    required TransactionData tx,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String? footerNote,
    required bool showItemDetails,
    required bool showTaxInfo,
    required bool showFooterNote,
    required int subtotal,
    required int tax,
    required String Function(int) fmtRp,
    required String Function(DateTime) dateLabel,
    required pw.Widget Function() line,
    required pw.Widget Function(String, String, {bool bold, bool total}) kv,
    required PdfStyles styles,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header
        pw.Text(storeName, style: styles.titleStyle, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text(storeAddress, style: styles.smallStyle, textAlign: pw.TextAlign.center),
        pw.Text(storePhone, style: styles.smallStyle, textAlign: pw.TextAlign.center),
        line(),

        // Judul struk
        pw.Text('STRUK PEMBAYARAN', style: styles.headerStyle, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 6),

        // Info transaksi
        kv('No Transaksi', tx.idFull),
        kv('Tanggal', dateLabel(tx.createdAt)),
        kv('Metode', tx.method),
        line(),

        // Item pembelian
        pw.Text('ITEM PEMBELIAN', style: styles.boldStyle),
        pw.SizedBox(height: 4),
        ...tx.items.map((it) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(it.name, style: styles.boldStyle),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${fmtRp(it.price as int)} x ${it.qty}', style: styles.normalStyle),
                    pw.Text(fmtRp(it.lineTotal), style: styles.boldStyle),
                  ],
                ),
                if (showItemDetails) pw.Text('SKU: ${it.sku}', style: styles.smallStyle),
              ],
            ),
          );
        }),

        line(),

        // Ringkasan
        kv('Subtotal', fmtRp(subtotal)),
        if (showTaxInfo && tax > 0) kv('Pajak 10%', fmtRp(tax)),
        kv('TOTAL', fmtRp(tx.total), total: true),
        pw.SizedBox(height: 6),
        kv('Tunai', fmtRp(tx.received)),
        kv('Kembalian', fmtRp(tx.change)),
        line(),

        // Footer
        if (showFooterNote && footerNote != null && footerNote.trim().isNotEmpty) ...[
          pw.Text(footerNote, style: styles.normalStyle, textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 6),
        ],

        pw.Text('Terima kasih atas kunjungan Anda', style: styles.boldStyle, textAlign: pw.TextAlign.center),
      ],
    );
  }

  static pw.Widget _buildDefaultV2Receipt({
    required TransactionData tx,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String? footerNote,
    required bool showItemDetails,
    required bool showTaxInfo,
    required bool showFooterNote,
    required int subtotal,
    required int tax,
    required String Function(int) fmtRp,
    required String Function(DateTime) dateLabel,
    required pw.Widget Function() line,
    required pw.Widget Function(String, String, {bool bold, bool total}) kv,
    required PdfStyles styles,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header minimal tanpa border
        pw.Text(storeName, style: styles.titleStyle, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 1),
        pw.Text(storeAddress, style: styles.verySmallStyle, textAlign: pw.TextAlign.center),
        pw.Text(storePhone, style: styles.verySmallStyle, textAlign: pw.TextAlign.center),
        line(),

        // Info transaksi kompak
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('No: ${tx.idFull.substring(0, 8)}', style: styles.smallStyle),
            pw.Text(dateLabel(tx.createdAt), style: styles.smallStyle),
          ],
        ),
        pw.Text('Metode: ${tx.method}', style: styles.smallStyle),
        line(),

        // Item pembelian kompak
        ...tx.items.map((it) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(it.name, style: styles.normalStyle),
                      if (showItemDetails) pw.Text('${it.qty} x ${fmtRp(it.price as int)}', style: styles.verySmallStyle),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(fmtRp(it.lineTotal), style: styles.normalStyle, textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          );
        }),

        line(),

        // Ringkasan
        kv('Subtotal', fmtRp(subtotal)),
        if (showTaxInfo && tax > 0) kv('Pajak', fmtRp(tax)),
        kv('TOTAL', fmtRp(tx.total), total: true),
        kv('Tunai', fmtRp(tx.received)),
        kv('Kembalian', fmtRp(tx.change)),
        line(),

        // Footer minimal
        if (showFooterNote && footerNote != null && footerNote.trim().isNotEmpty)
          pw.Text(footerNote, style: styles.verySmallStyle, textAlign: pw.TextAlign.center),

        pw.SizedBox(height: 4),
        pw.Text('Terima kasih', style: styles.smallStyle, textAlign: pw.TextAlign.center),
      ],
    );
  }

  static pw.Widget _buildModernReceipt({
    required TransactionData tx,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String? footerNote,
    required bool showStoreLogo,
    required bool showItemDetails,
    required bool showTaxInfo,
    required bool showFooterNote,
    required int subtotal,
    required int tax,
    required String Function(int) fmtRp,
    required String Function(DateTime) dateLabel,
    required pw.Widget Function() line,
    required pw.Widget Function(String, String, {bool bold, bool total}) kv,
    required PdfStyles styles,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header dengan border atas
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
          padding: const pw.EdgeInsets.all(4),
          child: pw.Column(
            children: [
              if (showStoreLogo) pw.Text('🛒', style: pw.TextStyle(fontSize: 20), textAlign: pw.TextAlign.center),
              pw.Text(storeName, style: styles.titleStyle.copyWith(fontSize: 14), textAlign: pw.TextAlign.center),
              pw.Text(storeAddress, style: styles.smallStyle, textAlign: pw.TextAlign.center),
              pw.Text(storePhone, style: styles.smallStyle, textAlign: pw.TextAlign.center),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // Info transaksi dalam box
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No Transaksi', style: styles.smallStyle),
                  pw.Text(tx.idFull, style: styles.boldStyle),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tanggal', style: styles.smallStyle),
                  pw.Text(dateLabel(tx.createdAt), style: styles.normalStyle),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Metode', style: styles.smallStyle),
                  pw.Text(tx.method, style: styles.normalStyle),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // Item pembelian dengan tabel
        pw.Text('DETAIL PEMBELIAN', style: styles.headerStyle, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),

        // Header tabel
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Text('Item', style: styles.boldStyle),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text('Qty', style: styles.boldStyle, textAlign: pw.TextAlign.center),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text('Harga', style: styles.boldStyle, textAlign: pw.TextAlign.right),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text('Subtotal', style: styles.boldStyle, textAlign: pw.TextAlign.right),
              ),
            ],
          ),
        ),

        // Baris item
        ...tx.items.map((it) {
          return pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.3)),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(it.name, style: styles.normalStyle),
                      if (showItemDetails) pw.Text('SKU: ${it.sku}', style: styles.verySmallStyle),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text('${it.qty}', style: styles.normalStyle, textAlign: pw.TextAlign.center),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(fmtRp(it.price as int), style: styles.normalStyle, textAlign: pw.TextAlign.right),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(fmtRp(it.lineTotal), style: styles.boldStyle, textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          );
        }),

        pw.SizedBox(height: 8),

        // Ringkasan dalam box
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: styles.normalStyle),
                  pw.Text(fmtRp(subtotal), style: styles.normalStyle),
                ],
              ),
              if (showTaxInfo && tax > 0) pw.SizedBox(height: 2),
              if (showTaxInfo && tax > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Pajak (10%):', style: styles.normalStyle),
                    pw.Text(fmtRp(tax), style: styles.normalStyle),
                  ],
                ),
              pw.SizedBox(height: 4),
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5)),
                ),
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL:', style: styles.totalStyle),
                    pw.Text(fmtRp(tx.total), style: styles.totalStyle),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tunai:', style: styles.smallStyle),
                  pw.Text(fmtRp(tx.received), style: styles.smallStyle),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kembalian:', style: styles.smallStyle),
                  pw.Text(fmtRp(tx.change), style: styles.smallStyle),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // QR Code area (placeholder)
        if (showFooterNote)
          pw.Container(
            child: pw.Column(
              children: [
                pw.Text('Scan untuk info lebih lanjut', style: styles.verySmallStyle, textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 4),
                // Placeholder untuk QR code
                pw.Container(
                  width: 50,
                  height: 50,
                  color: PdfColors.grey200,
                  child: pw.Center(
                    child: pw.Text('QR', style: styles.smallStyle),
                  ),
                ),
              ],
            ),
          ),

        if (showFooterNote && footerNote != null && footerNote.trim().isNotEmpty)
          pw.Text(footerNote, style: styles.verySmallStyle, textAlign: pw.TextAlign.center),

        pw.SizedBox(height: 8),
        pw.Text('Terima kasih telah berbelanja', style: styles.boldStyle, textAlign: pw.TextAlign.center),
        pw.Text('di toko kami', style: styles.smallStyle, textAlign: pw.TextAlign.center),
      ],
    );
  }

  static pw.Widget _buildDetailedReceipt({
    required TransactionData tx,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String? footerNote,
    required bool showItemDetails,
    required bool showTaxInfo,
    required bool showFooterNote,
    required int subtotal,
    required int tax,
    required String Function(int) fmtRp,
    required String Function(DateTime) dateLabel,
    required pw.Widget Function() line,
    required pw.Widget Function(String, String, {bool bold, bool total}) kv,
    required PdfStyles styles,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Header detail
        pw.Text(storeName.toUpperCase(), style: styles.titleStyle.copyWith(fontSize: 16), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 1),
        pw.Text(storeAddress, style: styles.smallStyle, textAlign: pw.TextAlign.center),
        pw.Text(storePhone, style: styles.smallStyle, textAlign: pw.TextAlign.center),
        pw.Text('================================', style: styles.smallStyle, textAlign: pw.TextAlign.center),

        // Info transaksi detail
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text('INVOICE / FAKTUR', style: styles.headerStyle.copyWith(fontSize: 12), textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Nomor:', style: styles.boldStyle),
                  pw.Text(tx.idFull, style: styles.normalStyle),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tanggal:', style: styles.boldStyle),
                  pw.Text(dateLabel(tx.createdAt), style: styles.normalStyle),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Metode:', style: styles.boldStyle),
                  pw.Text(tx.method, style: styles.normalStyle),
                ],
              ),
            ],
          ),
        ),

        pw.Text('--------------------------------', style: styles.smallStyle, textAlign: pw.TextAlign.center),

        // Detail item lengkap
        pw.Text('DETAIL BARANG', style: styles.boldStyle.copyWith(fontSize: 10), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),

        ...tx.items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final it = entry.value;

          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$index.', style: styles.boldStyle),
                    pw.SizedBox(width: 2),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Text(it.name, style: styles.boldStyle),
                          if (showItemDetails) pw.Text('Deskripsi: -', style: styles.verySmallStyle),
                          if (showItemDetails) pw.Text('SKU: ${it.sku}', style: styles.verySmallStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Harga Satuan:', style: styles.smallStyle),
                    pw.Text(fmtRp(it.price as int), style: styles.smallStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Kuantitas:', style: styles.smallStyle),
                    pw.Text('${it.qty}', style: styles.smallStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:', style: styles.boldStyle),
                    pw.Text(fmtRp(it.lineTotal), style: styles.boldStyle),
                  ],
                ),
                if (index < tx.items.length) pw.Text('---', style: styles.verySmallStyle, textAlign: pw.TextAlign.center),
              ],
            ),
          );
        }),

        pw.Text('================================', style: styles.smallStyle, textAlign: pw.TextAlign.center),

        // Ringkasan detail
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: styles.normalStyle),
                  pw.Text(fmtRp(subtotal), style: styles.normalStyle),
                ],
              ),
              if (showTaxInfo && tax > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Pajak Pertambahan Nilai (10%):', style: styles.normalStyle),
                    pw.Text(fmtRp(tax), style: styles.normalStyle),
                  ],
                ),
              pw.SizedBox(height: 4),
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 1)),
                ),
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL PEMBAYARAN:', style: styles.totalStyle),
                    pw.Text(fmtRp(tx.total), style: styles.totalStyle),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Uang Tunai Diterima:', style: styles.boldStyle),
                  pw.Text(fmtRp(tx.received), style: styles.boldStyle),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Kembalian:', style: styles.boldStyle),
                  pw.Text(fmtRp(tx.change), style: styles.boldStyle),
                ],
              ),
            ],
          ),
        ),

        pw.Text('================================', style: styles.smallStyle, textAlign: pw.TextAlign.center),

        // Footer detail
        if (showFooterNote && footerNote != null && footerNote.trim().isNotEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(footerNote, style: styles.verySmallStyle, textAlign: pw.TextAlign.center),
          ),

        pw.SizedBox(height: 8),
        pw.Text('BARANG YANG SUDAH DIBELI TIDAK DAPAT DIKEMBALIKAN', style: styles.verySmallStyle, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),
        pw.Text('Struk ini adalah bukti pembayaran yang sah', style: styles.verySmallStyle, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 6),
        pw.Text('TERIMA KASIH', style: styles.boldStyle.copyWith(fontSize: 12), textAlign: pw.TextAlign.center),
      ],
    );
  }

  // ====== HELPER FUNCTIONS ======

  static double _calculateBaseHeight({
    required String template,
    required bool showItemDetails,
    required bool showTaxInfo,
    required bool showFooterNote,
    required int itemCount,
  }) {
    double baseHeight = 110.0; // Header + footer dasar

    // Penyesuaian berdasarkan template
    switch (template) {
      case 'MINIMALIST':
        baseHeight = 80.0;
        break;
      case 'DEFAULT_TEMPLATE_V2':
        baseHeight = 100.0;
        break;
      case 'MODERN':
        baseHeight = 140.0;
        break;
      case 'DETAILED':
        baseHeight = 160.0;
        break;
      default: // DEFAULT_TEMPLATE_V1
        baseHeight = 110.0;
    }

    // Tambahan tinggi berdasarkan item
    final perItemHeight = showItemDetails ? 12.0 : 8.0;
    baseHeight += (itemCount * perItemHeight);

    // Tambahan untuk pajak
    if (showTaxInfo) baseHeight += 8.0;

    // Tambahan untuk footer note
    if (showFooterNote) baseHeight += 12.0;

    return baseHeight;
  }

  static double _getMarginByTemplate(String template) {
    switch (template) {
      case 'MINIMALIST':
        return 2.0;
      case 'DEFAULT_TEMPLATE_V2':
        return 2.5;
      case 'MODERN':
        return 3.0;
      case 'DETAILED':
        return 2.0;
      default: // DEFAULT_TEMPLATE_V1
        return 3.0;
    }
  }

  static PdfStyles _getPdfStyles(String template, int paperWidth) {
    // Base font sizes berdasarkan lebar kertas
    double baseSize = 8.0;
    if (paperWidth <= 58) baseSize = 7.0;
    if (paperWidth >= 80) baseSize = 9.0;

    // Penyesuaian berdasarkan template
    switch (template) {
      case 'MINIMALIST':
        return PdfStyles(
          verySmallStyle: pw.TextStyle(fontSize: baseSize - 2, font: pw.Font.courier()),
          smallStyle: pw.TextStyle(fontSize: baseSize - 1, font: pw.Font.courier()),
          normalStyle: pw.TextStyle(fontSize: baseSize, font: pw.Font.courier()),
          boldStyle: pw.TextStyle(fontSize: baseSize, fontWeight: pw.FontWeight.bold, font: pw.Font.courierBold()),
          titleStyle: pw.TextStyle(fontSize: baseSize + 2, fontWeight: pw.FontWeight.bold, font: pw.Font.courierBold()),
          headerStyle: pw.TextStyle(fontSize: baseSize + 1, fontWeight: pw.FontWeight.bold, font: pw.Font.courierBold()),
          totalStyle: pw.TextStyle(fontSize: baseSize + 1, fontWeight: pw.FontWeight.bold, font: pw.Font.courierBold()),
        );
      case 'DEFAULT_TEMPLATE_V2':
        return PdfStyles(
          verySmallStyle: pw.TextStyle(fontSize: baseSize - 1.5, font: pw.Font.helvetica()),
          smallStyle: pw.TextStyle(fontSize: baseSize - 0.5, font: pw.Font.helvetica()),
          normalStyle: pw.TextStyle(fontSize: baseSize, font: pw.Font.helvetica()),
          boldStyle: pw.TextStyle(fontSize: baseSize, fontWeight: pw.FontWeight.bold, font: pw.Font.helveticaBold()),
          titleStyle: pw.TextStyle(fontSize: baseSize + 3, fontWeight: pw.FontWeight.bold, font: pw.Font.helveticaBold()),
          headerStyle: pw.TextStyle(fontSize: baseSize + 1, fontWeight: pw.FontWeight.bold, font: pw.Font.helveticaBold()),
          totalStyle: pw.TextStyle(fontSize: baseSize + 1, fontWeight: pw.FontWeight.bold, font: pw.Font.helveticaBold()),
        );
      default:
        return PdfStyles(
          verySmallStyle: pw.TextStyle(fontSize: baseSize - 1, font: pw.Font.times()),
          smallStyle: pw.TextStyle(fontSize: baseSize, font: pw.Font.times()),
          normalStyle: pw.TextStyle(fontSize: baseSize + 1, font: pw.Font.times()),
          boldStyle: pw.TextStyle(fontSize: baseSize + 1, fontWeight: pw.FontWeight.bold, font: pw.Font.timesBold()),
          titleStyle: pw.TextStyle(fontSize: baseSize + 4, fontWeight: pw.FontWeight.bold, font: pw.Font.timesBold()),
          headerStyle: pw.TextStyle(fontSize: baseSize + 2, fontWeight: pw.FontWeight.bold, font: pw.Font.timesBold()),
          totalStyle: pw.TextStyle(fontSize: baseSize + 2, fontWeight: pw.FontWeight.bold, font: pw.Font.timesBold()),
        );
    }
  }

  /// Simpan PDF roll ke file
  static Future<File> generateAndSaveRollPdf(
      TransactionData tx, {
        String storeName = 'TOKO',
        String storeAddress = '-',
        String storePhone = '-',
        String? footerNote,
        // Parameter baru dari settings
        String receiptTemplate = 'DEFAULT_TEMPLATE_V1',
        bool showStoreLogo = true,
        bool showItemDetails = true,
        bool showTaxInfo = true,
        bool showFooterNote = true,
        int paperWidth = 58,
      }) async {
    final res = await generateRollBytes(
      tx,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      footerNote: footerNote,
      receiptTemplate: receiptTemplate,
      showStoreLogo: showStoreLogo,
      showItemDetails: showItemDetails,
      showTaxInfo: showTaxInfo,
      showFooterNote: showFooterNote,
      paperWidth: paperWidth,
    );

    final dir = Directory.systemTemp;
    final file = File('${dir.path}/receipt_${tx.idFull}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(res.bytes, flush: true);
    return file;
  }
}

// Helper class untuk menyimpan gaya PDF
class PdfStyles {
  final pw.TextStyle verySmallStyle;
  final pw.TextStyle smallStyle;
  final pw.TextStyle normalStyle;
  final pw.TextStyle boldStyle;
  final pw.TextStyle titleStyle;
  final pw.TextStyle headerStyle;
  final pw.TextStyle totalStyle;

  PdfStyles({
    required this.verySmallStyle,
    required this.smallStyle,
    required this.normalStyle,
    required this.boldStyle,
    required this.titleStyle,
    required this.headerStyle,
    required this.totalStyle,
  });
}