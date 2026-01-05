class User {
  final int? id;
  final String name;
  final String email;
  final String? username;
  final String role;
  final int? storeId;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    this.id,
    required this.name,
    required this.email,
    this.username,
    required this.role,
    this.storeId,
    this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  // Factory constructor untuk parsing JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'],
      role: json['role'] ?? 'cashier',
      storeId: json['store_id'] != null ? int.tryParse(json['store_id'].toString()) : null,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      if (username != null) 'username': username,
      'role': role,
      if (storeId != null) 'store_id': storeId,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Copy with method untuk update data
  User copyWith({
    int? id,
    String? name,
    String? email,
    String? username,
    String? role,
    int? storeId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods
  bool get isOwner => role.toLowerCase() == 'owner';
  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isCashier => role.toLowerCase() == 'cashier';

  String get roleDisplayName {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Pemilik';
      case 'admin':
        return 'Admin';
      case 'cashier':
        return 'Kasir';
      default:
        return 'Pengguna';
    }
  }

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, role: $role, storeId: $storeId)';
  }
}