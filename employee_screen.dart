import 'dart:math';
import 'package:flutter/material.dart';
import '../shared/app_colors.dart' as colors;

/// ===============================
/// EMPLOYEE SCREEN (LIST + SEARCH + ADD BUTTON)
/// ===============================
class EmployeeScreen extends StatefulWidget {
  final bool embedded;
  const EmployeeScreen({super.key, this.embedded = false});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // PASTIKAN: hanya pakai List<EmployeeItem>, tidak ada List<_EmployeeItem>
  final List<EmployeeItem> _employees = <EmployeeItem>[
    EmployeeItem(
      id: 'ADM001',
      fullName: 'Fakih',
      phone: '081234567893',
      email: 'fakih@pipos.id',
      username: 'fakih',
      password: '******',
      role: EmployeeRole.admin,
    ),
    EmployeeItem(
      id: 'EMP001',
      fullName: 'Abyan',
      phone: '081234567893',
      email: 'abyan@pipos.id',
      username: 'abyan',
      password: '******',
      role: EmployeeRole.kasir,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<EmployeeItem> get _filtered {
    if (_query.isEmpty) return _employees;
    return _employees.where((e) {
      return e.fullName.toLowerCase().contains(_query) ||
          e.id.toLowerCase().contains(_query) ||
          e.username.toLowerCase().contains(_query) ||
          e.phone.toLowerCase().contains(_query) ||
          e.role.label.toLowerCase().contains(_query);
    }).toList();
  }

  String _generateId(EmployeeRole role) {
    final prefix = role == EmployeeRole.admin ? 'ADM' : 'EMP';
    int maxNum = 0;

    for (final e in _employees) {
      if (e.id.startsWith(prefix)) {
        final numPart = e.id.replaceAll(prefix, '');
        final n = int.tryParse(numPart) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }

    final next = (maxNum + 1).toString().padLeft(3, '0');
    return '$prefix$next';
  }

  Future<void> _openAdd() async {
    final created = await Navigator.of(context).push<EmployeeItem>(
      MaterialPageRoute(
        builder: (_) => EmployeeFormScreen(
          title: 'Tambah Karyawan',
          initial: null,
          generateId: () => _generateId(EmployeeRole.kasir),
        ),
      ),
    );

    if (created == null) return;

    final fixed = created.id.trim().isEmpty
        ? created.copyWith(id: _generateId(created.role))
        : created;

    setState(() => _employees.insert(0, fixed));
  }

  Future<void> _openEdit(EmployeeItem item) async {
    final updated = await Navigator.of(context).push<EmployeeItem>(
      MaterialPageRoute(
        builder: (_) => EmployeeFormScreen(
          title: 'Edit Karyawan',
          initial: item,
          generateId: () => item.id,
        ),
      ),
    );

    if (updated == null) return;

    setState(() {
      final idx = _employees.indexWhere((e) => e.id == item.id);
      if (idx >= 0) _employees[idx] = updated.copyWith(id: item.id);
    });
  }

  Future<void> _confirmDelete(EmployeeItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.kDarkSurface,
        title: const Text(
          'Hapus karyawan?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Data "${item.fullName}" akan dihapus.',
          style: TextStyle(color: colors.kParagraph.withOpacity(0.95)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(color: colors.kParagraph.withOpacity(0.95)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _employees.removeWhere((e) => e.id == item.id));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0505), Color(0xFF000000)],
        ),
      ),
      child: SafeArea(
        top: !widget.embedded,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 10),
              Container(
                height: 2,
                width: double.infinity,
                color: colors.kMaroon.withOpacity(0.95),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _searchBar()),
                  const SizedBox(width: 12),
                  _addButton(),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _filtered.isEmpty
                    ? _empty()
                    : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _employeeCard(_filtered[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
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
          'Karyawan',
          style: TextStyle(
            color: colors.kParagraph.withOpacity(0.95),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colors.kSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.03), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colors.kParagraph.withOpacity(0.90)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Cari karyawan...',
                hintStyle: TextStyle(
                  color: colors.kParagraph.withOpacity(0.70),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openAdd,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          width: 52,
          decoration: BoxDecoration(
            color: colors.kMaroon,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [colors.kSoftShadow()],
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _employeeCard(EmployeeItem item) {
    final roleColor = item.role == EmployeeRole.admin
        ? const Color(0xFF10B981)
        : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.kSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.03), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.14),
              shape: BoxShape.circle,
              border: Border.all(color: roleColor.withOpacity(0.55), width: 1.2),
            ),
            child: Icon(Icons.person_rounded, color: roleColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${item.id}',
                  style: TextStyle(
                    color: colors.kParagraph.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _pill(text: item.role.label, color: roleColor),
                    const SizedBox(width: 10),
                    Text(
                      item.phone,
                      style: TextStyle(
                        color: colors.kParagraph.withOpacity(0.95),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              _squareIconButton(
                icon: Icons.edit_rounded,
                bg: const Color(0xFFF59E0B).withOpacity(0.18),
                border: const Color(0xFFF59E0B).withOpacity(0.55),
                iconColor: const Color(0xFFF59E0B),
                onTap: () => _openEdit(item),
              ),
              const SizedBox(width: 10),
              _squareIconButton(
                icon: Icons.delete_rounded,
                bg: Colors.redAccent.withOpacity(0.18),
                border: Colors.redAccent.withOpacity(0.55),
                iconColor: Colors.redAccent,
                onTap: () => _confirmDelete(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.55)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _squareIconButton({
    required IconData icon,
    required Color bg,
    required Color border,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Text(
        'Belum ada data karyawan.',
        style: TextStyle(
          color: colors.kParagraph.withOpacity(0.95),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// ===============================
/// FORM SCREEN (Tambah / Edit) - SESUAI DESAIN
/// ===============================
class EmployeeFormScreen extends StatefulWidget {
  final String title;
  final EmployeeItem? initial;
  final String Function() generateId;

  const EmployeeFormScreen({
    super.key,
    required this.title,
    required this.initial,
    required this.generateId,
  });

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _username;
  late final TextEditingController _password;

  EmployeeRole _role = EmployeeRole.kasir;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _role = init?.role ?? EmployeeRole.kasir;

    _fullName = TextEditingController(text: init?.fullName ?? '');
    _phone = TextEditingController(text: init?.phone ?? '');
    _email = TextEditingController(text: init?.email ?? '');
    _username = TextEditingController(text: init?.username ?? '');
    _password = TextEditingController(text: init?.password ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789@#\$!';
    final r = Random();
    final pass = List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
    setState(() {
      _password.text = pass;
      _obscure = false;
    });
  }

  void _submit() {
    final fullName = _fullName.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final username = _username.text.trim();
    final password = _password.text.trim();

    if (fullName.isEmpty || phone.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama, username, dan password wajib diisi.')),
      );
      return;
    }

    final id = widget.initial?.id ?? widget.generateId();

    // PASTIKAN: Navigator.pop mengembalikan EmployeeItem (bukan _EmployeeItem)
    Navigator.pop(
      context,
      EmployeeItem(
        id: id,
        fullName: fullName,
        phone: phone,
        email: email,
        username: username,
        password: password,
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: colors.kMaroon.withOpacity(0.95)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
        child: ListView(
          children: [
            _input(label: 'Nama Lengkap *', controller: _fullName),
            const SizedBox(height: 14),
            _input(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 14),
            _input(label: 'Username *', controller: _username),
            const SizedBox(height: 14),
            _passwordField(),
            const SizedBox(height: 14),
            _generateBar(),
            const SizedBox(height: 18),
            Text(
              'Role *',
              style: TextStyle(
                color: colors.kParagraph.withOpacity(0.95),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _roleRow(),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(child: _ghostButton(label: 'Batal', onTap: () => Navigator.pop(context))),
                const SizedBox(width: 14),
                Expanded(child: _primaryButton(label: 'Simpan', onTap: _submit)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: colors.kSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.03), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: label,
            hintStyle: TextStyle(
              color: colors.kParagraph.withOpacity(0.70),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: colors.kSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [colors.kSoftShadow()],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.03), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Center(
        child: TextField(
          controller: _password,
          obscureText: _obscure,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Password *',
            hintStyle: TextStyle(
              color: colors.kParagraph.withOpacity(0.70),
              fontWeight: FontWeight.w700,
            ),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: colors.kParagraph.withOpacity(0.90),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _generateBar() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _generatePassword,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.kMaroon.withOpacity(0.95), width: 1.2),
          ),
          child: Center(
            child: Text(
              'Generate Password',
              style: TextStyle(
                color: colors.kMaroon.withOpacity(0.95),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleRow() {
    return Row(
      children: [
        Expanded(
          child: _roleButton(
            label: 'Kasir',
            active: _role == EmployeeRole.kasir,
            borderColor: const Color(0xFF22D3EE),
            onTap: () => setState(() => _role = EmployeeRole.kasir),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _roleButton(
            label: 'Admin',
            active: _role == EmployeeRole.admin,
            borderColor: const Color(0xFFF59E0B),
            onTap: () => setState(() => _role = EmployeeRole.admin),
          ),
        ),
      ],
    );
  }

  Widget _roleButton({
    required String label,
    required bool active,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: colors.kSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? borderColor : colors.kMaroon.withOpacity(0.30),
              width: 1.4,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? borderColor : colors.kParagraph.withOpacity(0.90),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ghostButton({required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: colors.kSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: colors.kMaroon,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [colors.kSoftShadow()],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// MODEL (PAKAI SATU JENIS SAJA)
/// ===============================
enum EmployeeRole { kasir, admin }

extension EmployeeRoleX on EmployeeRole {
  String get label => this == EmployeeRole.kasir ? 'Kasir' : 'Admin';
}

class EmployeeItem {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String username;
  final String password;
  final EmployeeRole role;

  const EmployeeItem({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.username,
    required this.password,
    required this.role,
  });

  EmployeeItem copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? username,
    String? password,
    EmployeeRole? role,
  }) {
    return EmployeeItem(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      username: username ?? this.username,
      password: password ?? this.password,
      role: role ?? this.role,
    );
  }
}
