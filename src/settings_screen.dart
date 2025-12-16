import 'package:flutter/material.dart';

import '../shared/app_colors.dart' as colors;
import '../widgets/app_bar.dart';

class SettingsScreen extends StatelessWidget {
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = true});

  @override
  Widget build(BuildContext context) {
    final content = const _SettingsBody();

    // Background konsisten dengan DashboardScreen (gradient)
    final bg = Container(
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
        child: content,
      ),
    );

    if (embedded) return bg;

    return Scaffold(
      backgroundColor: colors.kDarkBg,
      appBar: KimposAppBar(
        title: 'BETA KASIR',
        subtitle: 'Pengaturan',
        showBack: true,
      ),
      body: bg,
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 900;

    // ===== DATA DUMMY (ganti dengan data asli dari DB/API Anda) =====
    const userEmail = 'rizalsoamole16@gmail.com';

    // ===== STORE/BUSINESS (sesuai field yang Anda kasih) =====
    const storeId = '1';
    const ownerId = '10';
    const storeName = 'Toko Sukses Jaya';
    const storeAddress = 'Jl. Contoh No. 123, Jakarta, Indonesia';
    const storePhone = '+62 812-3456-7890';
    const receiptTemplate = 'DEFAULT_TEMPLATE_V1';
    const createdAt = '2025-12-01 10:22:11';
    const updatedAt = '2025-12-15 19:05:45';

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isTablet ? 1100 : double.infinity),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 16,
              vertical: isTablet ? 18 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(isTablet),
                const SizedBox(height: 14),

                // =======================
                // AKUN
                // =======================
                _sectionTitle('Akun'),
                const SizedBox(height: 10),
                _accountCard(
                  email: userEmail,
                  isTablet: isTablet,
                ),
                const SizedBox(height: 16),

                // =======================
                // INFORMASI TOKO / BISNIS (sesuai schema Anda)
                // =======================
                _sectionTitle('Informasi Toko / Bisnis'),
                const SizedBox(height: 10),
                _businessCardV2(
                  isTablet: isTablet,
                  id: storeId,
                  ownerId: ownerId,
                  name: storeName,
                  address: storeAddress,
                  phone: storePhone,
                  receiptTemplate: receiptTemplate,
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                  onEdit: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit Informasi Toko (TODO)')),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // =======================
                // PLAN & BILLING
                // =======================
                _sectionTitle('Plan & Billing'),
                const SizedBox(height: 10),
                _planCard(
                  planName: 'PRO',
                  statusText: 'Aktif',
                  isTablet: isTablet,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Buka halaman Plan (TODO)')),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // =======================
                // INFORMASI APLIKASI
                // =======================
                _sectionTitle('Informasi Aplikasi'),
                const SizedBox(height: 10),
                _infoCard(
                  isTablet: isTablet,
                  items: const [
                    ('Versi Aplikasi', '1.1.8'),
                    ('Total Produk', '2'),
                    ('Total Transaksi', '4'),
                  ],
                ),
                const SizedBox(height: 14),

                _updateAvailableCard(
                  isTablet: isTablet,
                  onUpgrade: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Upgrade sekarang (TODO)')),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // =======================
                // WHATSAPP INTEGRATION
                // =======================
                _sectionTitle('WhatsApp Integration'),
                const SizedBox(height: 10),
                _tileCard(
                  title: 'WhatsApp Bot Integration',
                  subtitle: 'Laporan harian & alert otomatis via WhatsApp (GRATIS!)',
                  icon: Icons.chat_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  pillText: 'COMING SOON',
                  pillColor: const Color(0xFF8B5CF6),
                  onTap: () {},
                ),
                const SizedBox(height: 18),

                // =======================
                // DATA
                // =======================
                _sectionTitle('Data'),
                const SizedBox(height: 10),
                _tileCard(
                  title: 'Backup Data',
                  subtitle: 'Simpan data ke file',
                  icon: Icons.cloud_upload_rounded,
                  iconColor: const Color(0xFF10B981),
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _tileCard(
                  title: 'Copy Data',
                  subtitle: 'Restore data dari file backup',
                  icon: Icons.cloud_download_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _tileCard(
                  title: 'Hapus Semua Data',
                  subtitle: 'Reset aplikasi ke kondisi awal',
                  icon: Icons.delete_forever_rounded,
                  iconColor: const Color(0xFFEF4444),
                  onTap: () {},
                ),
                const SizedBox(height: 18),

                // =======================
                // TENTANG
                // =======================
                _sectionTitle('Tentang'),
                const SizedBox(height: 10),
                _tileCard(
                  title: 'Tentang BetaKasir',
                  subtitle: 'Aplikasi kasir untuk toko & minimarket',
                  icon: Icons.info_outline_rounded,
                  iconColor: colors.kMaroon,
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _tileCard(
                  title: 'Bantuan & Dukungan',
                  subtitle: 'Kami siap membantu Anda!',
                  icon: Icons.support_agent_rounded,
                  iconColor: colors.kMaroon,
                  onTap: () {},
                ),
                const SizedBox(height: 18),

                // =======================
                // AKUN & KEAMANAN
                // =======================
                _sectionTitle('Akun & Keamanan'),
                const SizedBox(height: 10),
                _logoutCard(
                  isTablet: isTablet,
                  onLogout: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Keluar dari akun (TODO)')),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // =======================
                // FAQ
                // =======================
                _sectionTitle('Pertanyaan Umum'),
                const SizedBox(height: 10),
                _faqTile(
                  title: 'Bagaimana cara upgrade?',
                  subtitle: 'Masuk ke Plan & Billing, lalu pilih paket.',
                  onTap: () {},
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =======================
  // UI BUILDING BLOCKS
  // =======================

  Widget _header(bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 18 : 14),
      decoration: BoxDecoration(
        color: colors.kSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.030),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.kMaroon.withOpacity(0.14),
              border: Border.all(color: colors.kMaroon.withOpacity(0.45)),
            ),
            child: Icon(Icons.settings_rounded, color: colors.kMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengaturan',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kelola akun, toko, data, dan preferensi aplikasi',
                  style: TextStyle(
                    color: colors.kParagraph.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: colors.kParagraph.withOpacity(0.92),
        fontWeight: FontWeight.w900,
        fontSize: 12,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _accountCard({required String email, required bool isTablet}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: colors.kSecondary,
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
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.kMaroon.withOpacity(0.14),
              border: Border.all(color: colors.kMaroon.withOpacity(0.55)),
            ),
            child: Icon(Icons.person_rounded, color: colors.kMaroon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Akun',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: colors.kParagraph.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ============================
  /// BUSINESS CARD (sesuai schema)
  /// ============================
  Widget _businessCardV2({
    required bool isTablet,
    required String id,
    required String ownerId,
    required String name,
    required String address,
    required String phone,
    required String receiptTemplate,
    required String createdAt,
    required String updatedAt,
    required VoidCallback onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: colors.kSecondary,
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.kMaroon.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.kMaroon.withOpacity(0.55)),
                ),
                child: Icon(Icons.store_rounded, color: colors.kMaroon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informasi Toko',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Data toko yang digunakan untuk identitas & nota.',
                      style: TextStyle(
                        color: colors.kParagraph.withOpacity(0.92),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.kMaroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _kvRow('ID', id),
          _thinDivider(),
          _kvRow('Owner ID', ownerId),
          _thinDivider(),
          _kvRow('Nama', name),
          _thinDivider(),
          _kvRow('Alamat', address, multiline: true),
          _thinDivider(),
          _kvRow('Telepon', phone),
          _thinDivider(),
          _kvRow('Receipt Template', receiptTemplate, multiline: true),
          _thinDivider(),
          _kvRow('Created At', createdAt),
          _thinDivider(),
          _kvRow('Updated At', updatedAt),
        ],
      ),
    );
  }

  Widget _planCard({
    required String planName,
    required String statusText,
    required bool isTablet,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 16 : 14),
          decoration: BoxDecoration(
            color: colors.kSecondary,
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.55)),
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(planName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.kParagraph.withOpacity(0.95)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required bool isTablet,
    required List<(String, String)> items,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: colors.kSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _kvRow(items[i].$1, items[i].$2),
            if (i != items.length - 1) _thinDivider(),
          ]
        ],
      ),
    );
  }

  Widget _kvRow(String left, String right, {bool multiline = false}) {
    return Row(
      crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            left,
            style: TextStyle(
              color: colors.kParagraph.withOpacity(0.95),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            right,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _thinDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Divider(height: 1, color: Colors.white.withOpacity(0.06)),
  );

  Widget _updateAvailableCard({required bool isTablet, required VoidCallback onUpgrade}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 10),
              Text(
                'Update Tersedia!',
                style: TextStyle(
                  color: Color(0xFF7C2D12),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Update baru tersedia! Dapatkan fitur terbaru sekarang.',
            style: TextStyle(color: Color(0xFF7C2D12), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const Text(
            'Versi Saat Ini: 1.2.2\nVersi Terbaru: 1.2.3',
            style: TextStyle(color: Color(0xFF7C2D12), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Upgrade Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tileCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    String? pillText,
    Color? pillColor,
  }) {
    final effectiveIconColor = iconColor ?? colors.kParagraph.withOpacity(0.95);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: colors.kSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [colors.kSoftShadow()],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.022),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: effectiveIconColor.withOpacity(0.35)),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.kParagraph.withOpacity(0.95), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (pillText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (pillColor ?? const Color(0xFF6B7280)).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: (pillColor ?? const Color(0xFF6B7280)).withOpacity(0.55)),
                  ),
                  child: Text(
                    pillText,
                    style: TextStyle(
                      color: pillColor ?? const Color(0xFF6B7280),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: colors.kParagraph.withOpacity(0.95)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoutCard({required bool isTablet, required VoidCallback onLogout}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: colors.kSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
      ),
      child: Center(
        child: ElevatedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'Keluar dari Akun',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.kMaroon,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _faqTile({required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: colors.kSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [colors.kSoftShadow()],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.kMaroon.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.kMaroon.withOpacity(0.55)),
                ),
                child: Icon(Icons.help_outline_rounded, color: colors.kMaroon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.kParagraph.withOpacity(0.95), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.kParagraph.withOpacity(0.95)),
            ],
          ),
        ),
      ),
    );
  }
}
