// models/subscription_model.dart
class Subscription {
  final String plan;
  final String status;
  final DateTime endDate;
  final DateTime startDate;

  Subscription({
    required this.plan,
    required this.status,
    required this.endDate,
    required this.startDate,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      plan: json['plan'] ?? 'FREE',
      status: json['status'] ?? 'inactive',
      endDate: DateTime.parse(json['end_date']),
      startDate: DateTime.parse(json['start_date']),
    );
  }

  // Hitung sisa hari
  int get daysRemaining {
    final now = DateTime.now();
    final diff = endDate.difference(now);
    return diff.inDays.clamp(0, 365);
  }

  // Format tanggal Indonesia
  String formattedEndDate() {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${endDate.day} ${months[endDate.month - 1]} ${endDate.year}';
  }

  // Status aktif/inactive
  bool get isActive => status.toLowerCase() == 'active';
}