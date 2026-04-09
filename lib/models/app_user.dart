class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password;
  final String role; // 'user' or 'guardian'
  final bool isSafe;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    this.isSafe = true,
  });

  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role,
      'isSafe': isSafe,
    };
    if (id.isNotEmpty) {
      map['_id'] = id;
    }
    return map;
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['_id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      password: map['password'] ?? '',
      role: map['role'] ?? 'user',
      isSafe: map['isSafe'] ?? true,
    );
  }
}
