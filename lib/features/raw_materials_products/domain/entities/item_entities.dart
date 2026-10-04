class Category {
  Category({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _required(name, 'اسم التصنيف');
    _required(code, 'كود التصنيف');
  }
  final String id, name, code;
  final String? description;
  final bool active;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'code': code.trim(),
    'description': description?.trim(),
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
  factory Category.fromMap(Map<String, Object?> m) => Category(
    id: m['id'] as String,
    name: m['name'] as String,
    code: m['code'] as String,
    description: m['description'] as String?,
    active: m['active'] == 1,
    createdAt: _date(m['createdAt']),
    updatedAt: _date(m['updatedAt']),
  );
}

class UnitEntity {
  UnitEntity({
    required this.id,
    required this.name,
    required this.abbreviation,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _required(name, 'اسم الوحدة');
    _required(abbreviation, 'اختصار الوحدة');
  }
  final String id, name, abbreviation;
  final bool active;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'abbreviation': abbreviation.trim(),
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
  factory UnitEntity.fromMap(Map<String, Object?> m) => UnitEntity(
    id: m['id'] as String,
    name: m['name'] as String,
    abbreviation: m['abbreviation'] as String,
    active: m['active'] == 1,
    createdAt: _date(m['createdAt']),
    updatedAt: _date(m['updatedAt']),
  );
}

class ItemColor {
  ItemColor({
    required this.id,
    required this.name,
    required this.code,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _required(name, 'اسم اللون');
    _required(code, 'كود اللون');
  }
  final String id, name, code;
  final bool active;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'code': code.trim(),
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
  factory ItemColor.fromMap(Map<String, Object?> m) => ItemColor(
    id: m['id'] as String,
    name: m['name'] as String,
    code: m['code'] as String,
    active: m['active'] == 1,
    createdAt: _date(m['createdAt']),
    updatedAt: _date(m['updatedAt']),
  );
}

class RawMaterial {
  RawMaterial({
    required this.id,
    required this.name,
    required this.code,
    required this.categoryId,
    required this.unitId,
    this.description,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _required(name, 'اسم الخامة');
    _required(code, 'كود الخامة');
    _required(categoryId, 'التصنيف');
    _required(unitId, 'الوحدة');
  }
  final String id, name, code, categoryId, unitId;
  final String? description;
  final bool active;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'code': code.trim(),
    'categoryId': categoryId,
    'unitId': unitId,
    'description': description?.trim(),
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
  factory RawMaterial.fromMap(Map<String, Object?> m) => RawMaterial(
    id: m['id'] as String,
    name: m['name'] as String,
    code: m['code'] as String,
    categoryId: m['categoryId'] as String,
    unitId: m['unitId'] as String,
    description: m['description'] as String?,
    active: m['active'] == 1,
    createdAt: _date(m['createdAt']),
    updatedAt: _date(m['updatedAt']),
  );
}

enum ProductState { unfinished, finished }

class Product {
  Product({
    required this.id,
    required this.name,
    required this.code,
    required this.categoryId,
    required this.unitId,
    this.description,
    this.state = ProductState.unfinished,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _required(name, 'اسم المنتج');
    _required(code, 'كود المنتج');
    _required(categoryId, 'التصنيف');
    _required(unitId, 'الوحدة');
  }
  final String id, name, code, categoryId, unitId;
  final String? description;
  final ProductState state;
  final bool active;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'code': code.trim(),
    'categoryId': categoryId,
    'unitId': unitId,
    'description': description?.trim(),
    'productState': state.name,
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
  factory Product.fromMap(Map<String, Object?> m) => Product(
    id: m['id'] as String,
    name: m['name'] as String,
    code: m['code'] as String,
    categoryId: m['categoryId'] as String,
    unitId: m['unitId'] as String,
    description: m['description'] as String?,
    state: ProductState.values.firstWhere(
      (v) => v.name == m['productState'],
      orElse: () => throw ArgumentError('حالة المنتج غير صالحة'),
    ),
    active: m['active'] == 1,
    createdAt: _date(m['createdAt']),
    updatedAt: _date(m['updatedAt']),
  );
}

class ProductVariant {
  ProductVariant({
    required this.id,
    required this.productId,
    required this.name,
    required this.code,
    this.colorId,
    this.description,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    _required(name, 'اسم البديل');
    _required(code, 'كود البديل');
  }
  final String id, productId, name, code;
  final String? colorId, description;
  final bool active;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'productId': productId,
    'name': name.trim(),
    'code': code.trim(),
    'colorId': colorId,
    'description': description?.trim(),
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
  factory ProductVariant.fromMap(Map<String, Object?> m) => ProductVariant(
    id: m['id'] as String,
    productId: m['productId'] as String,
    name: m['name'] as String,
    code: m['code'] as String,
    colorId: m['colorId'] as String?,
    description: m['description'] as String?,
    active: m['active'] == 1,
    createdAt: _date(m['createdAt']),
    updatedAt: _date(m['updatedAt']),
  );
}

class ProductAlternativeCandidate {
  const ProductAlternativeCandidate({
    required this.product,
    required this.categoryName,
    this.colorNames,
  });

  final Product product;
  final String categoryName;
  final String? colorNames;
}

class ProductAlternative {
  const ProductAlternative({
    required this.id,
    required this.sourceProductId,
    required this.target,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String sourceProductId;
  final ProductAlternativeCandidate target;
  final int priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get targetProductId => target.product.id;

  Map<String, Object?> toMap() => {
    'id': id,
    'sourceProductId': sourceProductId,
    'targetProductId': targetProductId,
    'priority': priority,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
}

class ProductDimension {
  ProductDimension({
    required this.id,
    required this.productId,
    this.variantId,
    this.length,
    this.width,
    this.height,
    this.unit,
  }) {
    for (final value in [length, width, height]) {
      if (value != null && value <= 0) {
        throw ArgumentError('الأبعاد يجب أن تكون موجبة');
      }
    }
  }
  final String id, productId;
  final String? variantId, unit;
  final double? length, width, height;
  Map<String, Object?> toMap() => {
    'id': id,
    'productId': productId,
    'variantId': variantId,
    'length': length,
    'width': width,
    'height': height,
    'unit': unit,
  };
  factory ProductDimension.fromMap(Map<String, Object?> m) => ProductDimension(
    id: m['id'] as String,
    productId: m['productId'] as String,
    variantId: m['variantId'] as String?,
    length: (m['length'] as num?)?.toDouble(),
    width: (m['width'] as num?)?.toDouble(),
    height: (m['height'] as num?)?.toDouble(),
    unit: m['unit'] as String?,
  );
}

class BomItem {
  BomItem({
    required this.id,
    required this.productId,
    required this.rawMaterialId,
    required this.quantity,
    this.notes,
  }) {
    if (quantity <= 0) throw ArgumentError('الكمية يجب أن تكون أكبر من صفر');
  }
  final String id, productId, rawMaterialId;
  final double quantity;
  final String? notes;
  Map<String, Object?> toMap() => {
    'id': id,
    'productId': productId,
    'rawMaterialId': rawMaterialId,
    'quantity': quantity,
    'notes': notes?.trim(),
  };
  factory BomItem.fromMap(Map<String, Object?> m) => BomItem(
    id: m['id'] as String,
    productId: m['productId'] as String,
    rawMaterialId: m['rawMaterialId'] as String,
    quantity: (m['quantity'] as num).toDouble(),
    notes: m['notes'] as String?,
  );
}

void _required(String value, String label) {
  if (value.trim().isEmpty) throw ArgumentError('$label مطلوب');
}

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int);
