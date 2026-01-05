import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../shared/app_colors.dart' as colors;
import '../widgets/app_bar.dart';

// Screens
import 'cashier_screen.dart';
import 'product_screen.dart';
import 'transaction_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart' hide kMaroon, kDarkSurface, kDarkBg;
import 'login_screen.dart';
import 'employee_screen.dart'; // ✅ tambahkan ini

class DashboardScreen extends StatefulWidget {
  final User? user;
  const DashboardScreen({super.key, this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum _NavKey {
  dashboard,
  cashier,
  product,
  transaction,
  employee,
  report,
  settings,
  activityLog,
}

class _DashboardScreenState extends State<DashboardScreen> {
  _NavKey _selected = _NavKey.dashboard;

  void _go(_NavKey key) => setState(() => _selected = key);

  String _subtitleFor(_NavKey key) {
    switch (key) {
      case _NavKey.dashboard:
        return 'Dashboard';
      case _NavKey.cashier:
        return 'Kasir';
      case _NavKey.product:
        return 'Produk';
      case _NavKey.transaction:
        return 'Transaksi';
      case _NavKey.employee:
        return 'Karyawan';
      case _NavKey.report:
        return 'Laporan';
      case _NavKey.settings:
        return 'Pengaturan';
      case _NavKey.activityLog:
        return 'Log Aktivitas';
    }
  }

  // ===== USER DISPLAY HELPERS (aman walau field berbeda) =====
  String _displayName() {
    final u = widget.user;
    if (u == null) return 'Pengguna';

    try {
      final dynamic du = u;
      final name = (du.name ?? '').toString().trim();
      if (name.isNotEmpty) return name;

      final fullName = (du.fullName ?? '').toString().trim();
      if (fullName.isNotEmpty) return fullName;

      final username = (du.username ?? '').toString().trim();
      if (username.isNotEmpty) return username;
    } catch (_) {}

    return 'Pengguna';
  }

  String _displayEmailOrIdentifier() {
    final u = widget.user;
    if (u == null) return '—';

    try {
      final dynamic du = u;

      final email = (du.email ?? '').toString().trim();
      if (email.isNotEmpty) return email;

      final username = (du.username ?? '').toString().trim();
      if (username.isNotEmpty) return username;

      final identifier = (du.identifier ?? '').toString().trim();
      if (identifier.isNotEmpty) return identifier;
    } catch (_) {}

    return '—';
  }

  String _firstLetterUpper(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'U';
    final r = t.runes.toList();
    if (r.isEmpty) return 'U';
    return String.fromCharCode(r.first).toUpperCase();
  }

  String _initials() {
    final name = _displayName().trim();
    if (name.isEmpty) return 'U';

    final parts =
    name.split(RegExp(r'\s+')).where((e) => e.trim().isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return _firstLetterUpper(parts[0]);

    final a = _firstLetterUpper(parts[0]);
    final b = _firstLetterUpper(parts[1]);
    return '$a$b';
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.kDarkSurface,
        title: const Text(
          'Keluar akun?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Anda akan logout dan kembali ke halaman login.',
          style: TextStyle(color: colors.kParagraph.withOpacity(0.95)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: TextStyle(color: colors.kParagraph.withOpacity(0.95))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.kMaroon),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    // TODO: hapus token/session (SharedPreferences) di sini jika ada.

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final isDesktop = width >= 1100;

        final pages = <_NavKey, Widget>{
          _NavKey.dashboard: _DashboardHome(
            onOpenCashier: () => _go(_NavKey.cashier),
            onOpenProduct: () => _go(_NavKey.product),
            onOpenTransaction: () => _go(_NavKey.transaction),
            onOpenReport: () => _go(_NavKey.report),
            onOpenSettings: () => _go(_NavKey.settings),
          ),
          _NavKey.cashier: const CashierScreen(embedded: true),
          _NavKey.product: const ProductScreen(),
          _NavKey.transaction: const TransactionScreen(),


          _NavKey.employee: const EmployeeScreen(embedded: true),

          _NavKey.report: const ReportScreen(embedded: true),
          _NavKey.settings: const SettingsScreen(embedded: true),
          _NavKey.activityLog: const ActivityLogScreen(embedded: true),
        };

        final content = Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0505),
                Color(0xFF000000),
              ],
            ),
          ),
          child: IndexedStack(
            index: _NavKey.values.indexOf(_selected),
            children: _NavKey.values
                .map((k) => pages[k] ?? const SizedBox.shrink())
                .toList(),
          ),
        );

        // ===== DESKTOP (sidebar kiri + konten kanan) =====
        if (isDesktop) {
          return Scaffold(
            backgroundColor: colors.kDarkBg,
            body: Row(
              children: [
                _SideNav(
                  selected: _selected,
                  onSelect: _go,
                  userName: _displayName(),
                  userEmail: _displayEmailOrIdentifier(),
                  initials: _initials(),
                  onLogout: _logout,
                ),
                Expanded(child: content),
              ],
            ),
          );
        }

        // ===== MOBILE/TABLET =====
        return Scaffold(
          backgroundColor: colors.kDarkBg,
          appBar: KimposAppBar(
            title: 'PIPos',
            subtitle: _subtitleFor(_selected),
            showBack: false,
            actions: [
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                tooltip: 'Logout',
              ),
            ],
          ),
          body: SafeArea(child: content),
          bottomNavigationBar: _MobileBottomNav(
            selected: _selected,
            onSelect: _go,
          ),
        );
      },
    );
  }
}

/// =======================
/// DESKTOP SIDEBAR (mirip screenshot)
/// =======================
class _SideNav extends StatelessWidget {
  final _NavKey selected;
  final ValueChanged<_NavKey> onSelect;

  final String userName;
  final String userEmail;
  final String initials;
  final VoidCallback onLogout;

  const _SideNav({
    required this.selected,
    required this.onSelect,
    required this.userName,
    required this.userEmail,
    required this.initials,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    const sideWidth = 300.0;

    return Container(
      width: sideWidth,
      decoration: BoxDecoration(
        color: colors.kSecondary, // #1D1616
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),

          // Brand row (logo + PIPos + PRO)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: colors.kMaroon.withOpacity(0.95), width: 1.3),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo-pipos.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'PIPos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.kMaroon,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              children: [
                _navItem(Icons.home_rounded, 'Beranda', _NavKey.dashboard),
                const SizedBox(height: 4),
                _navItem(Icons.point_of_sale_rounded, 'Kasir', _NavKey.cashier),
                const SizedBox(height: 4),
                _navItem(Icons.inventory_2_rounded, 'Produk', _NavKey.product),
                const SizedBox(height: 4),
                _navItem(Icons.receipt_long_rounded, 'Transaksi',
                    _NavKey.transaction),
                const SizedBox(height: 4),
                _navItem(Icons.groups_rounded, 'Karyawan', _NavKey.employee),
                const SizedBox(height: 4),
                _navItem(Icons.bar_chart_rounded, 'Laporan', _NavKey.report),
                const SizedBox(height: 4),
                _navItem(Icons.settings_rounded, 'Pengaturan', _NavKey.settings),
                const SizedBox(height: 4),
                _navItem(Icons.history_rounded, 'Log Aktivitas',
                    _NavKey.activityLog),

                const SizedBox(height: 10),
                Divider(color: Colors.white.withOpacity(0.06)),
                const SizedBox(height: 6),

                _navItem(
                  Icons.logout_rounded,
                  'Logout',
                  _NavKey.activityLog,
                  onTapOverride: onLogout,
                  forceInactiveStyle: true,
                ),
              ],
            ),
          ),

          // User footer (mirip screenshot)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: colors.kMaroon.withOpacity(0.95), width: 1.2),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.kParagraph.withOpacity(0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
      IconData icon,
      String label,
      _NavKey key, {
        VoidCallback? onTapOverride,
        bool forceInactiveStyle = false,
      }) {
    final active = !forceInactiveStyle && selected == key;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapOverride ?? () => onSelect(key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: active ? colors.kMaroon : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: active ? Colors.white : colors.kParagraph.withOpacity(0.95),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : colors.kParagraph.withOpacity(0.95),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// MOBILE BOTTOM NAV
/// =======================
class _MobileBottomNav extends StatelessWidget {
  final _NavKey selected;
  final ValueChanged<_NavKey> onSelect;

  const _MobileBottomNav({
    required this.selected,
    required this.onSelect,
  });

  int _indexOf(_NavKey k) {
    switch (k) {
      case _NavKey.dashboard:
        return 0;
      case _NavKey.cashier:
        return 1;
      case _NavKey.product:
        return 2;
      case _NavKey.report:
        return 3;
      case _NavKey.settings:
        return 4;
      default:
        return 0;
    }
  }

  _NavKey _keyOf(int i) {
    switch (i) {
      case 0:
        return _NavKey.dashboard;
      case 1:
        return _NavKey.cashier;
      case 2:
        return _NavKey.product;
      case 3:
        return _NavKey.report;
      case 4:
        return _NavKey.settings;
      default:
        return _NavKey.dashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexOf(selected);

    return Container(
      decoration: BoxDecoration(
        color: colors.kDarkSurface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) => onSelect(_keyOf(i)),
          backgroundColor: colors.kDarkSurface,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedItemColor: colors.kMaroon,
          unselectedItemColor: colors.kParagraph.withOpacity(0.90),
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'Kasir'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Produk'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Laporan'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Setting'),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// DASHBOARD HOME (KONTEN KANAN) - mengikuti screenshot
/// =======================
class _DashboardHome extends StatelessWidget {
  final VoidCallback onOpenCashier;
  final VoidCallback onOpenProduct;
  final VoidCallback onOpenTransaction;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenSettings;

  const _DashboardHome({
    required this.onOpenCashier,
    required this.onOpenProduct,
    required this.onOpenTransaction,
    required this.onOpenReport,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topHeader(),
            const SizedBox(height: 12),

            // garis merah memanjang
            Container(
              height: 2,
              width: double.infinity,
              color: colors.kMaroon.withOpacity(0.95),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _subscriptionCard(),
                    const SizedBox(height: 16),

                    _metricCard(
                      icon: Icons.payments_rounded,
                      title: 'Total Penjualan Hari Ini',
                      value: 'Rp 1.250.000',
                    ),
                    const SizedBox(height: 14),
                    _metricCard(
                      icon: Icons.receipt_long_rounded,
                      title: 'Transaksi Hari Ini',
                      value: '1',
                    ),
                    const SizedBox(height: 14),
                    _metricCard(
                      icon: Icons.inventory_2_rounded,
                      title: 'Stok Menipis',
                      value: '1',
                    ),
                    const SizedBox(height: 14),
                    _metricCard(
                      icon: Icons.category_rounded,
                      title: 'Total Produk',
                      value: '2',
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'APLIKASI PIPOS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dashboard',
          style: TextStyle(
            color: colors.kParagraph.withOpacity(0.95),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _subscriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.kSecondary, // #1D1616
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.035),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.kMaroon.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.kMaroon.withOpacity(0.55)),
                ),
                child: Icon(Icons.desktop_windows_rounded,
                    color: colors.kMaroon, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Langganan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.55)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded,
                        color: Color(0xFF10B981), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Aktif',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _subLine(left: 'Plan:', right: 'PRO'),
          const SizedBox(height: 8),
          _subLine(left: 'Berakhir:', right: '25 Desember 2025'),
          const SizedBox(height: 8),
          _subLine(
              left: 'Sisa Waktu:',
              right: '11 Hari Lagi',
              rightColor: const Color(0xFF10B981)),

          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _subLine({
    required String left,
    required String right,
    Color? rightColor,
  }) {
    return Row(
      children: [
        Text(
          left,
          style: TextStyle(
            color: colors.kParagraph.withOpacity(0.95),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            right,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: rightColor ?? Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  /// Card metrik (lebar + aksen merah kiri) seperti screenshot
  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.kSecondary, // #1D1616
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.028),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // aksen kiri merah
          Container(
            width: 6,
            height: 86,
            decoration: BoxDecoration(
              color: colors.kMaroon,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 14),

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.kMaroon.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.kMaroon.withOpacity(0.55)),
            ),
            child: Icon(icon, color: colors.kMaroon),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.kParagraph.withOpacity(0.95),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

/// =======================
/// ACTIVITY LOG SCREEN
/// =======================
class ActivityLogScreen extends StatelessWidget {
  final bool embedded;
  const ActivityLogScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final items = <_ActivityLogItem>[
      _ActivityLogItem(
        icon: Icons.login_rounded,
        title: 'Login berhasil',
        detail: 'Masuk ke aplikasi',
        time: 'Baru saja',
      ),
      _ActivityLogItem(
        icon: Icons.inventory_2_rounded,
        title: 'Produk ditambahkan',
        detail: 'Menambah produk “Kopi Susu”',
        time: '10 menit lalu',
      ),
      _ActivityLogItem(
        icon: Icons.receipt_long_rounded,
        title: 'Transaksi dibuat',
        detail: 'Invoice #INV-00012',
        time: '35 menit lalu',
      ),
      _ActivityLogItem(
        icon: Icons.settings_rounded,
        title: 'Pengaturan diubah',
        detail: 'Mengubah preferensi aplikasi',
        time: '1 jam lalu',
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0505),
            Color(0xFF000000),
          ],
        ),
      ),
      child: SafeArea(
        top: !embedded,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log Aktivitas',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Riwayat aktivitas pengguna dan sistem.',
                style: TextStyle(
                  color: colors.kParagraph.withOpacity(0.95),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _logCard(items[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logCard(_ActivityLogItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.kSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.kMaroon.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.kMaroon.withOpacity(0.55)),
            ),
            child: Icon(item.icon, color: colors.kMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  style: TextStyle(
                    color: colors.kParagraph.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            item.time,
            style: TextStyle(
              color: colors.kParagraph.withOpacity(0.90),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogItem {
  final IconData icon;
  final String title;
  final String detail;
  final String time;

  _ActivityLogItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
  });
}
