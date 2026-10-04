class Warehouse {
  Warehouse({
    required this.id,
    required this.factoryId,
    required this.name,
    required this.code,
    this.type,
    this.state = 'active',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    }) {
    if (name.trim().isEmpty) throw ArgumentError('اسم المخزن مطلوب');
    if (code.trim().isEmpty) throw ArgumentError('كود المخزن مطلوب');
    if (!const {'active', 'inactive'}.contains(state)) {
      throw ArgumentError('حالة المخزن غير صالحة');
    }
  }

  final String id;
  final String factoryId;
  final String name;
  final String code;
  final String? type;
  final String state;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Warehouse copyWith({
    String? id,
    String? factoryId,
    String? name,
    String? code,
    String? type,
    String? state,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Warehouse(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      state: state ?? this.state,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'factoryId': factoryId,
      'name': name.trim(),
      'code': code.trim(),
      'type': type?.trim(),
      'state': state,
      'notes': notes?.trim(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Warehouse.fromMap(Map<String, Object?> map) {
    return Warehouse(
      id: map['id'] as String,
      factoryId: map['factoryId'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      type: map['type'] as String?,
      state: map['state'] as String? ?? 'active',
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}
