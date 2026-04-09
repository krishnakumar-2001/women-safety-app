class GuardianContact {
  final String id;
  final String userId;
  String name;
  String phone;

  GuardianContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    final map = {
      'userId': userId,
      'name': name,
      'phone': phone,
    };
    if (id.isNotEmpty) {
      map['_id'] = id;
    }
    return map;
  }

  factory GuardianContact.fromMap(Map<String, dynamic> map) {
    return GuardianContact(
      id: map['_id'] ?? '',
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
    );
  }
}
