import 'package:flutter/foundation.dart';

@immutable
class TxItem {
  final int productId;
  final String name;
  final String sku;
  final double price;
  final int qty;

  const TxItem({
    required this.productId,
    required this.name,
    required this.sku,
    required this.price,
    required this.qty,
  });

  int get lineTotal => price.round() * qty;
}

@immutable
class TransactionData {
  final String idShort;
  final String idFull;
  final DateTime createdAt;
  final String method;
  final int total;
  final int received;
  final int change;
  final List<TxItem> items;

  const TransactionData({
    required this.idShort,
    required this.idFull,
    required this.createdAt,
    required this.method,
    required this.total,
    required this.received,
    required this.change,
    required this.items,
  });
}
