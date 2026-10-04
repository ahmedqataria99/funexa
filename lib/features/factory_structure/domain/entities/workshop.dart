class Workshop {
  Workshop({
    required this.id,
    required this.factoryId,
    required this.sectionId,
    required this.name,
    required this.code,
    this.description,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    }) {
    if (name.trim().isEmpty) throw ArgumentError('اسم الورشة مطلوب');
    if (code.trim().isEmpty) throw ArgumentError('كود الورشة مطلوب');
  }

  final String id;
  final String factoryId;
  final String sectionId;
  final String name;
  final String code;
  final String? description;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Workshop copyWith({
    String? id,
    String? factoryId,
    String? sectionId,
    String? name,
    String? code,
    String? description,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workshop(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
      sectionId: sectionId ?? this.sectionId,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'factoryId': factoryId,
      'sectionId': sectionId,
      'name': name.trim(),
      'code': code.trim(),
      'description': description?.trim(),
      'active': active ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Workshop.fromMap(Map<String, Object?> map) {
    return Workshop(
      id: map['id'] as String,
      factoryId: map['factoryId'] as String,
      sectionId: map['sectionId'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      description: map['description'] as String?,
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}
