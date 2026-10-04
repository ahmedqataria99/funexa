class FactoryProfile {
  FactoryProfile({
    required this.id,
    required this.name,
    required this.code,
    this.phone,
    this.email,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _validate();
  }

  final String id;
  final String name;
  final String code;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  void _validate() {
    if (name.trim().isEmpty) {
      throw ArgumentError('Factory name is required');
    }
    if (code.trim().isEmpty) {
      throw ArgumentError('Factory code is required');
    }
  }

  FactoryProfile copyWith({
    String? id,
    String? name,
    String? code,
    String? phone,
    String? email,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FactoryProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name.trim(),
      'code': code.trim(),
      'phone': phone?.trim(),
      'email': email?.trim(),
      'address': address?.trim(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory FactoryProfile.fromMap(Map<String, Object?> map) {
    return FactoryProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}
