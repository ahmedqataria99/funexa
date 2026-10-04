class ProductionStage {
  ProductionStage({
    required this.id,
    required this.factoryId,
    required this.name,
    required this.code,
    this.description,
    required this.sequence,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    }) {
    if (name.trim().isEmpty) throw ArgumentError('اسم المرحلة مطلوب');
    if (code.trim().isEmpty) throw ArgumentError('كود المرحلة مطلوب');
    if (sequence <= 0) throw ArgumentError('ترتيب المرحلة يجب أن يكون موجباً');
  }

  final String id;
  final String factoryId;
  final String name;
  final String code;
  final String? description;
  final int sequence;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductionStage copyWith({
    String? id,
    String? factoryId,
    String? name,
    String? code,
    String? description,
    int? sequence,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductionStage(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      sequence: sequence ?? this.sequence,
      active: active ?? this.active,
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
      'description': description?.trim(),
      'sequence': sequence,
      'active': active ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ProductionStage.fromMap(Map<String, Object?> map) {
    return ProductionStage(
      id: map['id'] as String,
      factoryId: map['factoryId'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      description: map['description'] as String?,
      sequence: map['sequence'] as int,
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}
