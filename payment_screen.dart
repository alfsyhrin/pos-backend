import 'package:flutter/material.dart';
import 'package:kimpos/screens/settings_screen.dart' hide kDarkBg, kDarkSurface, kMaroon, kDarkBorder;

import '../shared/app_colors.dart';
import '../utils/formatters.dart';
import '../widgets/app_bar.dart';

enum PaymentStatus { paid, cancelled }

class PaymentResult {
  final PaymentStatus status;
  final int paidAmount;
  final int change;

  const PaymentResult({
    required this.status,
    required this.paidAmount,
    required this.change,
  });
}

class PaymentScreen extends StatefulWidget {
  final int total;
  const PaymentScreen({super.key, required this.total});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _received = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  int _parseReceived() {
    final raw = _received.text.trim().replaceAll('.', '').replaceAll(' ', '');
    return int.tryParse(raw) ?? 0;
  }

  int get _receivedValue => _parseReceived();
  int get _changeValue => (_receivedValue >= widget.total) ? (_receivedValue - widget.total) : 0;

  void _submit() {
    final val = _receivedValue;

    if (val <= 0) {
      setState(() => _error = 'Masukkan angka yang valid');
      return;
    }
    if (val < widget.total) {
      setState(() => _error = 'Uang diterima kurang dari total');
      return;
    }

    Navigator.pop(
      context,
      PaymentResult(
        status: PaymentStatus.paid,
        paidAmount: val,
        change: val - widget.total,
      ),
    );
  }

  void _cancel() {
    Navigator.pop(
      context,
      const PaymentResult(status: PaymentStatus.cancelled, paidAmount: 0, change: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: kDarkBg,
      resizeToAvoidBottomInset: true,
      appBar: const KimposAppBar(
        title: 'Pembayaran',
        subtitle: 'Konfirmasi pembayaran',
        showBack: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 900;
            final pad = isWide ? 24.0 : 18.0;

            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  pad,
                  pad,
                  pad,
                  pad + mq.viewInsets.bottom, // KUNCI: naik saat keyboard muncul
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 820,
                      minHeight: c.maxHeight, // KUNCI: menjaga tombol tetap “di bawah” saat keyboard tidak muncul
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(height: 2, color: kMaroon.withOpacity(0.9)),
                          const SizedBox(height: 14),

                          _totalCard(),

                          const SizedBox(height: 14),

                          _receivedCard(),

                          const SizedBox(height: 14),

                          _changeCard(),

                          const Spacer(),

                          _actionRow(),
                        ],
                      ),
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

  Widget _totalCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          const Text(
            'TOTAL',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatRupiah(widget.total),
              style: TextStyle(color: kMaroon, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receivedCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tunai diterima',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _received,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
              setState(() {}); // refresh kembalian
            },
            decoration: InputDecoration(
              hintText: 'Contoh: 150000',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
              filled: true,
              fillColor: kDarkBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: kMaroon, width: 1.2),
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _error,
              errorStyle: const TextStyle(color: Colors.orangeAccent),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tips: Anda bisa input angka tanpa titik. Sistem akan menghitung otomatis.',
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _changeCard() {
    final ok = _receivedValue >= widget.total && _receivedValue > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kDarkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkBorder),
      ),
      child: Row(
        children: [
          Text(
            'Kembalian',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatRupiah(_changeValue),
              style: TextStyle(
                color: ok ? const Color(0xFF22C55E) : Colors.white.withOpacity(0.55),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _cancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.08),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: kMaroon,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Bayar', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}
