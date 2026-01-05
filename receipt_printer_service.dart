import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction_model.dart';

class RollPdfResult {
  final Uint8List bytes;
  final PdfPageFormat format;
  RollPdfResult({required this.bytes, required this.format});
}

class ReceiptPdfService {
  /// Buat PDF roll 58mm (tinggi dinamis berdasarkan jumlah item).
  static Future<RollPdfResult> generateRollBytes(
      TransactionData tx, {
        required String storeName,
        required String storeAddress,
        required String storePhone,
        String? footerNote,
      }) async {
    // 58mm paper roll
    const paperW = 58.0 * PdfPageFormat.mm;

    // Tinggi dinamis (perkiraan aman). Anda bisa adjust agar tidak kepotong.
    final baseH = 140.0 * PdfPageFormat.mm;
    final perItem = 10.0 * PdfPageFormat.mm;
    final h = baseH + (tx.items.length * perItem);

    final format = PdfPageFormat(paperW, h, marginAll: 4.0 * PdfPageFormat.mm);

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

    final subtotal = tx.items.fold<int>(0, (sum, it) => sum + it.lineTotal);

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(storeName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ),
              pw.Center(child: pw.Text(storeAddress, style: const pw.TextStyle(fontSize: 9))),
              pw.Center(child: pw.Text(storePhone, style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 6),
              pw.Divider(),

              pw.Center(
                child: pw.Text('STRUK PEMBAYARAN',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('No : ${tx.idFull}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Tgl: ${dateLabel(tx.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Metode: ${tx.method}', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),

              pw.Text('ITEM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 6),

              ...tx.items.map((it) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(it.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text('${fmtRp(it.price as int)} x ${it.qty}', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Text(fmtRp(it.lineTotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ],
                    ),
                    pw.Text('SKU: ${it.sku}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 6),
                  ],
                );
              }),

              pw.Divider(),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Subtotal', style: const pw.TextStyle(fontSize: 9))),
                  pw.Text(fmtRp(subtotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Text(fmtRp(tx.total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Tunai', style: const pw.TextStyle(fontSize: 9))),
                  pw.Text(fmtRp(tx.received), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Kembalian', style: const pw.TextStyle(fontSize: 9))),
                  pw.Text(fmtRp(tx.change), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),

              pw.Divider(),

              if (footerNote != null && footerNote.trim().isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Center(child: pw.Text(footerNote, style: const pw.TextStyle(fontSize: 8))),
                pw.SizedBox(height: 6),
              ],

              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text('Terima kasih',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    return RollPdfResult(bytes: bytes, format: format);
  }
}
