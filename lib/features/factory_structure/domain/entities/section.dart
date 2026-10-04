class Section {
  Section({
    required this.id,
    required this.factoryId,
    required this.name,
    required this.code,
    this.description,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    }) {
    if (name.trim().isEmpty) throw ArgumentError('اسم القسم مطلوب');
    if (code.trim().isEmpty) throw ArgumentError('كود القسم مطلوب');
  }

  final String id;
  final String factoryId;
  final String name;
  final String code;
  final String? description;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Section copyWith({
    String? id,
    String? factoryId,
    String? name,
    String? code,
    String? description,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Section(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
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
      'name': name.trim(),
      'code': code.trim(),
      'description': description?.trim(),
      'active': active ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Section.fromMap(Map<String, Object?> map) {
    return Section(
      id: map['id'] as String,
      factoryId: map['factoryId'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      description: map['description'] as String?,
      active: (map['active'] as int? ?? 1) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }
}
