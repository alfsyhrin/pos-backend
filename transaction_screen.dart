import 'package:flutter/material.dart';

import '../shared/app_colors.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import 'transaction_detail_screen.dart';

class TransactionScreen extends StatefulWidget {
  final bool embedded;
  const TransactionScreen({super.key, this.embedded = false});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
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

  Future<void> _confirmDelete(TransactionData tx) async {
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

    if (ok == true) {
      TransactionService.instance.deleteByIdFull(tx.idFull);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: kDarkBg,
      child: ValueListenableBuilder<List<TransactionData>>(
        valueListenable: TransactionService.instance.transactions,
        builder: (context, list, _) {
          return LayoutBuilder(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Riwayat Transaksi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${list.length} transaksi',
                                style: TextStyle(
                                  color: kTextMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: list.isEmpty
                        ? Center(
                      child: Text(
                        'Belum ada transaksi.\nSilakan lakukan pembayaran dari Kasir.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                        : ListView.separated(
                      padding: EdgeInsets.fromLTRB(padH, 18, padH, 24),
                      itemBuilder: (ctx, i) {
                        final tx = list[i];
                        return _TransactionCard(
                          tx: tx,
                          dateLabel: _dateTimeLabel(tx.createdAt),
                          totalLabel: fmtRpNum(tx.total),
                          onOpen: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransactionDetailScreen(transaction: tx),
                              ),
                            );
                          },
                          onDelete: () => _confirmDelete(tx),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: list.length,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: kDarkBg,
      body: SafeArea(child: content),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionData tx;
  final String dateLabel;
  final String totalLabel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _TransactionCard({
    required this.tx,
    required this.dateLabel,
    required this.totalLabel,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kDarkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kMaroon.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: kMaroon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${tx.idShort}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.payments_outlined, size: 14, color: Colors.white.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Text(
                        tx.method,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  totalLabel,
                  style: const TextStyle(color: kMaroon, fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  '${tx.items.length} item',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: kMaroon),
              tooltip: 'Hapus',
            ),
          ],
        ),
      ),
    );
  }
}
