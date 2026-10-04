enum DiscountType { percentage, amount }

enum PricingSource {
  listPrice,
  customerOverride,
  quantityTier,
  discount,
  noSuggestedPrice,
}

class PriceList {
  PriceList({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.validFrom,
    this.validTo,
    this.active = true,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (code.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('كود وقيمة قائمة السعر مطلوبان');
    }
  }

  final String id, code, name;
  final String? description;
  final DateTime? validFrom, validTo;
  final bool active;
  final bool isDefault;
  final DateTime createdAt, updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'code': code.trim(),
    'name': name.trim(),
    'description': description?.trim(),
    'validFrom': validFrom?.millisecondsSinceEpoch,
    'validTo': validTo?.millisecondsSinceEpoch,
    'active': active ? 1 : 0,
    'isDefault': isDefault ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory PriceList.fromMap(Map<String, Object?> row) => PriceList(
    id: row['id'] as String,
    code: row['code'] as String,
    name: row['name'] as String,
    description: row['description'] as String?,
    validFrom: row['validFrom'] == null ? null : _date(row['validFrom']),
    validTo: row['validTo'] == null ? null : _date(row['validTo']),
    active: row['active'] == 1,
    isDefault: row['isDefault'] == 1,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class ProductPrice {
  ProductPrice({
    required this.id,
    required this.priceListId,
    required this.productId,
    this.variantId,
    required this.unitPrice,
    this.currency = 'SAR',
    this.validFrom,
    this.validTo,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (unitPrice < 0) throw ArgumentError('سعر الوحدة لا يمكن أن يكون سالبًا');
  }

  final String id, priceListId, productId;
  final String? variantId, currency;
  final double unitPrice;
  final DateTime? validFrom, validTo;
  final bool active;
  final DateTime createdAt, updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'priceListId': priceListId,
    'productId': productId,
    'variantId': variantId,
    'unitPrice': unitPrice,
    'currency': currency,
    'validFrom': validFrom?.millisecondsSinceEpoch,
    'validTo': validTo?.millisecondsSinceEpoch,
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory ProductPrice.fromMap(Map<String, Object?> row) => ProductPrice(
    id: row['id'] as String,
    priceListId: row['priceListId'] as String,
    productId: row['productId'] as String,
    variantId: row['variantId'] as String?,
    unitPrice: (row['unitPrice'] as num).toDouble(),
    currency: (row['currency'] as String?) ?? 'SAR',
    validFrom: row['validFrom'] == null ? null : _date(row['validFrom']),
    validTo: row['validTo'] == null ? null : _date(row['validTo']),
    active: row['active'] == 1,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class CustomerPriceOverride {
  CustomerPriceOverride({
    required this.id,
    required this.customerId,
    required this.productId,
    this.variantId,
    required this.unitPrice,
    this.currency = 'SAR',
    this.validFrom,
    this.validTo,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (unitPrice < 0) throw ArgumentError('سعر العميل لا يمكن أن يكون سالبًا');
  }

  final String id, customerId, productId;
  final String? variantId, currency;
  final double unitPrice;
  final DateTime? validFrom, validTo;
  final bool active;
  final DateTime createdAt, updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'customerId': customerId,
    'productId': productId,
    'variantId': variantId,
    'unitPrice': unitPrice,
    'currency': currency,
    'validFrom': validFrom?.millisecondsSinceEpoch,
    'validTo': validTo?.millisecondsSinceEpoch,
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory CustomerPriceOverride.fromMap(Map<String, Object?> row) =>
      CustomerPriceOverride(
        id: row['id'] as String,
        customerId: row['customerId'] as String,
        productId: row['productId'] as String,
        variantId: row['variantId'] as String?,
        unitPrice: (row['unitPrice'] as num).toDouble(),
        currency: (row['currency'] as String?) ?? 'SAR',
        validFrom: row['validFrom'] == null ? null : _date(row['validFrom']),
        validTo: row['validTo'] == null ? null : _date(row['validTo']),
        active: row['active'] == 1,
        createdAt: _date(row['createdAt']),
        updatedAt: _date(row['updatedAt']),
      );
}

class PriceTier {
  PriceTier({
    required this.id,
    required this.priceListId,
    required this.productId,
    this.variantId,
    required this.minimumQuantity,
    required this.unitPrice,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (minimumQuantity < 0)
      throw ArgumentError('الحد الأدنى لا يمكن أن يكون سالبًا');
    if (unitPrice < 0) throw ArgumentError('سعر النطاق لا يمكن أن يكون سالبًا');
  }

  final String id, priceListId, productId;
  final String? variantId;
  final double minimumQuantity, unitPrice;
  final bool active;
  final DateTime createdAt, updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'priceListId': priceListId,
    'productId': productId,
    'variantId': variantId,
    'minimumQuantity': minimumQuantity,
    'unitPrice': unitPrice,
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory PriceTier.fromMap(Map<String, Object?> row) => PriceTier(
    id: row['id'] as String,
    priceListId: row['priceListId'] as String,
    productId: row['productId'] as String,
    variantId: row['variantId'] as String?,
    minimumQuantity: (row['minimumQuantity'] as num).toDouble(),
    unitPrice: (row['unitPrice'] as num).toDouble(),
    active: row['active'] == 1,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class DiscountRule {
  DiscountRule({
    required this.id,
    this.customerId,
    this.productId,
    this.variantId,
    required this.type,
    required this.value,
    this.minimumQuantity = 0,
    this.validFrom,
    this.validTo,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (value < 0) throw ArgumentError('قيمة الخصم لا يمكن أن تكون سلبية');
  }

  final String id;
  final String? customerId, productId, variantId;
  final DiscountType type;
  final double value;
  final double minimumQuantity;
  final DateTime? validFrom, validTo;
  final bool active;
  final DateTime createdAt, updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'customerId': customerId,
    'productId': productId,
    'variantId': variantId,
    'type': type.name,
    'value': value,
    'minimumQuantity': minimumQuantity,
    'validFrom': validFrom?.millisecondsSinceEpoch,
    'validTo': validTo?.millisecondsSinceEpoch,
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory DiscountRule.fromMap(Map<String, Object?> row) => DiscountRule(
    id: row['id'] as String,
    customerId: row['customerId'] as String?,
    productId: row['productId'] as String?,
    variantId: row['variantId'] as String?,
    type: DiscountType.values.firstWhere(
      (value) => value.name == row['type'],
      orElse: () => DiscountType.percentage,
    ),
    value: (row['value'] as num).toDouble(),
    minimumQuantity: (row['minimumQuantity'] as num?)?.toDouble() ?? 0,
    validFrom: row['validFrom'] == null ? null : _date(row['validFrom']),
    validTo: row['validTo'] == null ? null : _date(row['validTo']),
    active: row['active'] == 1,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class PriceHistory {
  PriceHistory({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.productId,
    this.variantId,
    required this.unitPrice,
    required this.discountAmount,
    required this.finalPrice,
    required this.effectiveAt,
    required this.createdAt,
  });

  final String id, entityType, entityId, productId;
  final String? variantId;
  final double unitPrice, discountAmount, finalPrice;
  final DateTime effectiveAt, createdAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'productId': productId,
    'variantId': variantId,
    'unitPrice': unitPrice,
    'discountAmount': discountAmount,
    'finalPrice': finalPrice,
    'effectiveAt': effectiveAt.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory PriceHistory.fromMap(Map<String, Object?> row) => PriceHistory(
    id: row['id'] as String,
    entityType: row['entityType'] as String,
    entityId: row['entityId'] as String,
    productId: row['productId'] as String,
    variantId: row['variantId'] as String?,
    unitPrice: (row['unitPrice'] as num).toDouble(),
    discountAmount: (row['discountAmount'] as num).toDouble(),
    finalPrice: (row['finalPrice'] as num).toDouble(),
    effectiveAt: _date(row['effectiveAt']),
    createdAt: _date(row['createdAt']),
  );
}

class CustomerPrice extends CustomerPriceOverride {
  CustomerPrice({
    required super.id,
    required super.customerId,
    required super.productId,
    super.variantId,
    required super.unitPrice,
    super.currency,
    super.validFrom,
    super.validTo,
    super.active,
    required super.createdAt,
    required super.updatedAt,
  });
}

class CommercialDiscountRule extends DiscountRule {
  CommercialDiscountRule({
    required super.id,
    super.customerId,
    super.productId,
    super.variantId,
    required super.type,
    required super.value,
    super.minimumQuantity,
    super.validFrom,
    super.validTo,
    super.active,
    required super.createdAt,
    required super.updatedAt,
  });
}

class ManualPriceAdjustment extends PriceHistory {
  ManualPriceAdjustment({
    required super.id,
    required super.entityType,
    required super.entityId,
    required super.productId,
    super.variantId,
    required super.unitPrice,
    required super.discountAmount,
    required super.finalPrice,
    required super.effectiveAt,
    required super.createdAt,
  });
}

class PricingResolution {
  const PricingResolution({
    required this.productId,
    required this.variantId,
    required this.customerId,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.finalPrice,
    required this.source,
  });

  final String productId;
  final String? variantId;
  final String? customerId;
  final double quantity;
  final double unitPrice;
  final double discountAmount;
  final double finalPrice;
  final PricingSource source;
}

extension PricingSourceValue on PricingSource {
  String get value => switch (this) {
    PricingSource.listPrice => 'LIST_PRICE',
    PricingSource.customerOverride => 'CUSTOMER_OVERRIDE',
    PricingSource.quantityTier => 'QUANTITY_TIER',
    PricingSource.discount => 'DISCOUNT',
    PricingSource.noSuggestedPrice => 'NO_SUGGESTED_PRICE',
  };
}

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int);
