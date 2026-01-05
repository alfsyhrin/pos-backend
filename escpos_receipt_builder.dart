import 'dart:convert';

/// Public model agar bisa dipakai lintas file (bukan _Item).
class ReceiptItem {
  final String name;
  final String sku;
  final int price;
  final int qty;
  final int lineTotal;

  const ReceiptItem({
    required this.name,
    required this.sku,
    required this.price,
    required this.qty,
    required this.lineTotal,
  });
}

class EscPosReceiptBuilder58 {
  /// Umumnya 58mm = 32 karakter per baris (Font A).
  final int lineChars;

  EscPosReceiptBuilder58({this.lineChars = 32});

  final List<int> _bytes = [];

  List<int> build({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String txId,
    required String dateLabel,
    required String method,
    required List<ReceiptItem> items,
    required int subtotal,
    required int total,
    required int received,
    required int change,
    String? footerNote,
  }) {
    _bytes.clear();

    _init();
    _center();
    _boldOn();
    _doubleSizeOn();
    _textLine(storeName);
    _doubleSizeOff();
    _boldOff();

    _textWrap(storeAddress);
    _textLine(storePhone);
    _feed(1);

    _hr();
    _boldOn();
    _textLine('STRUK PEMBAYARAN');
    _boldOff();

    _left();
    _textLine('No : $txId');
    _textLine('Tgl: $dateLabel');
    _textLine('By : $method');
    _hr();

    _boldOn();
    _textLine('ITEM');
    _boldOff();

    for (final it in items) {
      _textWrap(it.name);

      final left = '${_fmtRp(it.price)} x ${it.qty}';
      final right = _fmtRp(it.lineTotal);
      _rowLR(left, right);

      if (it.sku.trim().isNotEmpty) {
        _textLine('SKU: ${it.sku}');
      }
      _feed(1);
    }

    _hr();
    _rowLR('Subtotal', _fmtRp(subtotal));
    _boldOn();
    _rowLR('TOTAL', _fmtRp(total));
    _boldOff();

    _feed(1);
    _rowLR('Tunai', _fmtRp(received));
    _rowLR('Kembalian', _fmtRp(change));
    _hr();

    if (footerNote != null && footerNote.trim().isNotEmpty) {
      _center();
      _textWrap(footerNote.trim());
      _feed(1);
      _left();
    }

    _center();
    _boldOn();
    _textLine('Terima kasih');
    _boldOff();
    _feed(3);

    // Banyak printer murah kadang tidak dukung cut, tapi aman dipanggil.
    _cutPartial();

    return List<int>.from(_bytes);
  }

  // =======================
  // ESC/POS primitives
  // =======================

  void _init() => _bytes.addAll([0x1B, 0x40]); // ESC @
  void _lf() => _bytes.add(0x0A);

  void _textLine(String s) {
    _bytes.addAll(utf8.encode(s));
    _lf();
  }

  void _textWrap(String s) {
    final lines = _wrap(s, lineChars);
    for (final ln in lines) {
      _textLine(ln);
    }
  }

  void _hr() => _textLine('-' * lineChars);

  void _feed(int n) => _bytes.addAll([0x1B, 0x64, n]); // ESC d n

  void _left() => _bytes.addAll([0x1B, 0x61, 0x00]); // ESC a 0
  void _center() => _bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1

  void _boldOn() => _bytes.addAll([0x1B, 0x45, 0x01]); // ESC E 1
  void _boldOff() => _bytes.addAll([0x1B, 0x45, 0x00]); // ESC E 0

  void _doubleSizeOn() => _bytes.addAll([0x1D, 0x21, 0x11]); // GS ! 0x11
  void _doubleSizeOff() => _bytes.addAll([0x1D, 0x21, 0x00]); // GS ! 0x00

  void _cutPartial() => _bytes.addAll([0x1D, 0x56, 0x41, 0x10]); // GS V A n

  void _rowLR(String left, String right) {
    final r = right.length > lineChars ? right.substring(0, lineChars) : right;
    final space = lineChars - r.length;

    final l = left.length > space ? left.substring(0, space) : left;
    final pad = ' ' * (space - l.length);

    _textLine('$l$pad$r');
  }

  List<String> _wrap(String text, int width) {
    final words = text.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    for (final w in words) {
      if (current.isEmpty) {
        current = w;
      } else if ((current.length + 1 + w.length) <= width) {
        current = '$current $w';
      } else {
        lines.add(current);
        current = w;
      }
    }
    if (current.isNotEmpty) lines.add(current);

    // Pecah paksa bila ada kata super panjang
    final normalized = <String>[];
    for (final ln in lines) {
      if (ln.length <= width) {
        normalized.add(ln);
      } else {
        for (int i = 0; i < ln.length; i += width) {
          normalized.add(ln.substring(i, (i + width).clamp(0, ln.length)));
        }
      }
    }
    return normalized;
  }

  String _fmtRp(int value) {
    final s = value.abs().toString();
    final buf = StringBuffer();
    int c = 0;

    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        buf.write('.');
        c = 0;
      }
    }
    final reversed = buf.toString().split('').reversed.join();
    return '${value < 0 ? '-' : ''}Rp $reversed';
  }
}
