import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:bluetooth_classic/models/device.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/transaction_model.dart';
import '../services/store_settings_service.dart';

class ReceiptBtPrinterService {
  ReceiptBtPrinterService._();
  static final instance = ReceiptBtPrinterService._();

  final BluetoothClassic _bt = BluetoothClassic();

  // SPP UUID (umum untuk thermal printer Bluetooth Classic)
  static const String _sppUuid = "00001101-0000-1000-8000-00805F9B34FB";

  // Fungsi untuk mendapatkan jumlah karakter per baris berdasarkan lebar kertas
  int _getLineChars(int paperWidth) {
    if (paperWidth <= 58) return 32;
    if (paperWidth <= 72) return 42;
    return 48; // 80mm atau lebih
  }

  Future<void> ensurePermissions() async {
    try {
      await _bt.initPermissions();
    } catch (_) {
      // fallback (beberapa device butuh permission_handler)
    }

    if (!Platform.isAndroid) return;

    // Android 12+ runtime permissions
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      // Untuk Android <= 11 (scan sering butuh lokasi)
      Permission.locationWhenInUse,
    ].request();
  }

  Future<List<Device>> getBondedDevices() async {
    try {
      final list = await _bt.getPairedDevices();
      return list;
    } catch (e) {
      print('Error getting bonded devices: $e');
      return [];
    }
  }

  Future<void> printReceipt({
    required Device device,
    required TransactionData tx,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    String? footerNote,
    // Parameter fixed dari settings
    double taxPercentage = 10.0, // Persentase pajak default 10%
    int paperWidth = 58,
  }) async {
    try {
      final connected = await _bt.connect(device.address, _sppUuid);

      if (connected != true) {
        throw Exception("Gagal connect ke printer: ${device.name ?? device.address}");
      }

      final bytes = _buildEscPosReceipt(
        tx: tx,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        footerNote: footerNote,
        taxPercentage: taxPercentage,
        paperWidth: paperWidth,
      );

      await _bt.writeBytes(Uint8List.fromList(bytes));

      // Sebagian printer butuh jeda sebelum disconnect agar tidak "kepotong"
      await Future.delayed(const Duration(milliseconds: 300));
      await _bt.disconnect();
    } catch (e) {
      rethrow;
    }
  }

  // =========================
  // ESC/POS builder yang sederhana
  // =========================
  List<int> _buildEscPosReceipt({
    required TransactionData tx,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    String? footerNote,
    required double taxPercentage,
    required int paperWidth,
  }) {
    final out = <int>[];
    void add(List<int> b) => out.addAll(b);

    // ================= ESC/POS =================
    List<int> init() => [0x1B, 0x40];
    List<int> alignLeft() => [0x1B, 0x61, 0x00];
    List<int> alignCenter() => [0x1B, 0x61, 0x01];
    List<int> boldOn() => [0x1B, 0x45, 0x01];
    List<int> boldOff() => [0x1B, 0x45, 0x00];
    List<int> sizeNormal() => [0x1D, 0x21, 0x00];
    List<int> sizeLarge() => [0x1D, 0x21, 0x11];
    List<int> doubleHeightOn() => [0x1B, 0x21, 0x10];
    List<int> doubleHeightOff() => [0x1B, 0x21, 0x00];
    List<int> feed(int n) => [0x1B, 0x64, n];
    List<int> cut() => [0x1D, 0x56, 0x01];
    List<int> text(String s) => utf8.encode("$s\n");

    final lineChars = paperWidth <= 58 ? 32 : 48;

    // ================= FORMAT =================
    String rp(int v) {
      final raw = v.abs().toString();
      final buf = StringBuffer();
      for (int i = 0; i < raw.length; i++) {
        if ((raw.length - i) % 3 == 0 && i != 0) buf.write('.');
        buf.write(raw[i]);
      }
      return "${v < 0 ? '-' : ''}Rp ${buf}";
    }

    String lr(String l, String r) {
      final space = lineChars - l.length - r.length;
      return "$l${' ' * (space > 0 ? space : 1)}$r";
    }

    String lineDash() => '-' * lineChars;

    // ================= HITUNG =================
    int subtotal = 0;
    int diskon = 0;

    for (final i in tx.items) {
      subtotal += i.lineTotal;
      diskon += i.discountAmount;
    }

    final afterDisc = subtotal - diskon;
    final tax = (afterDisc * taxPercentage / 100).round();
    final total = afterDisc + tax;

    // ================= CETAK =================
    add(init());

    // HEADER
    add(alignCenter());
    add(doubleHeightOn());
    add(boldOn());
    add(text(storeName));
    add(doubleHeightOff());
    add(boldOff());
    add(text(storeAddress));
    add(text(storePhone));
    add(text(lineDash()));

    // INFO
    add(boldOn());
    add(text("STRUK PEMBAYARAN"));
    add(boldOff());
    add(alignLeft());

    // Format tanggal
    String dateLabel(DateTime dt) {
      const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = months[dt.month - 1];
      final yyyy = dt.year.toString();
      final hh = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final ss = dt.second.toString().padLeft(2, '0');
      return "$dd $mm $yyyy $hh:$min:$ss";
    }

    add(text("No     : ${tx.idFull}"));
    add(text("Tgl    : ${dateLabel(tx.createdAt)}"));
    add(text("Kasir  : Admin"));
    add(text("Metode : ${tx.method}"));
    add(text(lineDash()));

    // ITEM
    add(boldOn());
    add(text("ITEM PEMBELIAN"));
    add(boldOff());

    for (final it in tx.items) {
      // Potong nama jika terlalu panjang
      String nama = it.name;
      if (nama.length > lineChars - 8) {
        nama = nama.substring(0, lineChars - 8) + "...";
      }
      add(text(nama));
      add(text(lr(
        "${it.qty} x ${rp(it.price)}",
        rp(it.lineTotal),
      )));

      if (it.discountAmount > 0) {
        add(text(lr("  Diskon", rp(-it.discountAmount))));
      }

      add(text("")); // Jarak antar produk
    }

    add(text(lineDash()));

    // RINGKASAN
    add(text(lr("Subtotal", rp(subtotal))));
    if (diskon > 0) {
      add(text(lr("Total Diskon", rp(-diskon))));
      add(text(lr("Subtotal Diskon", rp(afterDisc))));
    }

    add(text(lr("PPN (${taxPercentage.toStringAsFixed(1)}%)", rp(tax))));

    add(boldOn());
    add(sizeLarge());
    add(text(lr("TOTAL", rp(total))));
    add(sizeNormal());
    add(boldOff());

    add(text(""));
    add(text(lr("Tunai", rp(tx.received))));
    add(text(lr("Kembalian", rp(tx.change))));
    add(text(lineDash()));

    // FOOTER
    if (footerNote != null && footerNote.isNotEmpty) {
      add(alignCenter());
      add(text("CATATAN:"));
      add(text(footerNote));
    }

    add(alignCenter());
    add(boldOn());
    add(doubleHeightOn());
    add(text("TERIMA KASIH"));
    add(doubleHeightOff());
    add(text("Atas kunjungan Anda"));
    add(boldOff());

    add(feed(3));
    add(cut());

    return out;
  }

  // Fungsi tambahan: Test printer
  Future<void> testPrint({
    required Device device,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    double taxPercentage = 10.0,
    int paperWidth = 58,
  }) async {
    try {
      final connected = await _bt.connect(device.address, _sppUuid);

      if (connected != true) {
        throw Exception("Gagal connect ke printer: ${device.name ?? device.address}");
      }

      final out = <int>[];
      void add(List<int> b) => out.addAll(b);

      List<int> init() => [0x1B, 0x40];
      List<int> alignCenter() => [0x1B, 0x61, 0x01];
      List<int> alignLeft() => [0x1B, 0x61, 0x00];
      List<int> boldOn() => [0x1B, 0x45, 0x01];
      List<int> boldOff() => [0x1B, 0x45, 0x00];
      List<int> feed(int n) => [0x1B, 0x64, n];
      List<int> cut() => [0x1D, 0x56, 0x01];
      List<int> text(String s) => utf8.encode("$s\n");
      List<int> sizeLarge() => [0x1D, 0x21, 0x11];
      List<int> sizeNormal() => [0x1D, 0x21, 0x00];
      List<int> doubleHeightOn() => [0x1B, 0x21, 0x10];
      List<int> doubleHeightOff() => [0x1B, 0x21, 0x00];

      add(init());
      add(alignCenter());
      add(boldOn());
      add(sizeLarge());
      add(text("TEST PRINTER"));
      add(sizeNormal());
      add(boldOff());
      add(text("================"));
      add(alignLeft());
      add(text("Nama Toko : $storeName"));
      add(text("Alamat    : $storeAddress"));
      add(text("Telepon   : $storePhone"));
      add(text("PPN       : ${taxPercentage.toStringAsFixed(1)}%"));
      add(text("Kertas    : ${paperWidth}mm"));
      add(text("================"));
      add(alignCenter());
      add(boldOn());
      add(doubleHeightOn());
      add(text("BERHASIL TERHUBUNG"));
      add(doubleHeightOff());
      add(text("Printer siap digunakan"));
      add(boldOff());
      add(feed(3));
      add(cut());

      await _bt.writeBytes(Uint8List.fromList(out));
      await Future.delayed(const Duration(milliseconds: 300));
      await _bt.disconnect();
    } catch (e) {
      rethrow;
    }
  }

  // Fungsi untuk test print dengan transaksi dummy
  Future<void> testPrintWithDummyTransaction({
    required Device device,
    required String storeName,
    required String storeAddress,
    required String storePhone,
    double taxPercentage = 10.0,
    int paperWidth = 58,
  }) async {
    try {
      // Buat transaksi dummy untuk testing
      final dummyTx = TransactionData(
        idFull: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        idShort: 'TEST${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        createdAt: DateTime.now(),
        method: 'Tunai',
        total: 150000,
        received: 200000,
        change: 50000,
        items: [
          TxItem(
            idShort: 'TEST001',
            productId: 'PROD001',
            name: 'Produk Test 1',
            price: 50000,
            qty: 2,
            lineTotal: 100000,
            sku: 'TEST001',
            discountAmount: 0,
          ),
          TxItem(
            idShort: 'TEST002',
            productId: 'PROD002',
            name: 'Produk Test 2 dengan nama yang panjang untuk testing',
            price: 25000,
            qty: 1,
            lineTotal: 25000,
            sku: 'TEST002',
            discountAmount: 0,
          ),
          TxItem(
            idShort: 'TEST003',
            productId: 'PROD003',
            name: 'Produk Test 3 (Diskon)',
            price: 30000,
            qty: 1,
            lineTotal: 25000, // Total setelah diskon
            sku: 'TEST003',
            discountAmount: 5000, // Diskon Rp 5.000
          ),
        ],
      );

      final connected = await _bt.connect(device.address, _sppUuid);

      if (connected != true) {
        throw Exception("Gagal connect ke printer: ${device.name ?? device.address}");
      }

      final bytes = _buildEscPosReceipt(
        tx: dummyTx,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        footerNote: 'Ini adalah test print untuk memastikan printer berfungsi dengan baik.',
        taxPercentage: taxPercentage,
        paperWidth: paperWidth,
      );

      await _bt.writeBytes(Uint8List.fromList(bytes));

      // Sebagian printer butuh jeda sebelum disconnect agar tidak "kepotong"
      await Future.delayed(const Duration(milliseconds: 300));
      await _bt.disconnect();
    } catch (e) {
      rethrow;
    }
  }
}