enum StockItemType { rawMaterial, product }

enum StockTransactionType {
  stockIn,
  stockOut,
  transferIn,
  transferOut,
  adjustment,
}

extension StockItemTypeValue on StockItemType {
  String get value =>
      this == StockItemType.rawMaterial ? 'RAW_MATERIAL' : 'PRODUCT';
  String get arabic => this == StockItemType.rawMaterial ? 'خامة' : 'منتج';
}

extension StockTransactionTypeValue on StockTransactionType {
  String get value => switch (this) {
    StockTransactionType.stockIn => 'STOCK_IN',
    StockTransactionType.stockOut => 'STOCK_OUT',
    StockTransactionType.transferIn => 'TRANSFER_IN',
    StockTransactionType.transferOut => 'TRANSFER_OUT',
    StockTransactionType.adjustment => 'ADJUSTMENT',
  };
  String get arabic => switch (this) {
    StockTransactionType.stockIn => 'إضافة مخزون',
    StockTransactionType.stockOut => 'صرف مخزون',
    StockTransactionType.transferIn => 'تحويل وارد',
    StockTransactionType.transferOut => 'تحويل صادر',
    StockTransactionType.adjustment => 'تسوية',
  };
}

class StockBalance {
  StockBalance({
    required this.id,
    required this.warehouseId,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, warehouseId, itemId;
  final StockItemType itemType;
  final double quantity;
  final DateTime createdAt, updatedAt;
  factory StockBalance.fromMap(Map<String, Object?> map) => StockBalance(
    id: map['id'] as String,
    warehouseId: map['warehouseId'] as String,
    itemId: map['itemId'] as String,
    itemType: map['itemType'] == 'PRODUCT'
        ? StockItemType.product
        : StockItemType.rawMaterial,
    quantity: (map['quantity'] as num).toDouble(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}

class StockTransaction {
  StockTransaction({
    required this.id,
    required this.warehouseId,
    required this.itemId,
    required this.itemType,
    required this.transactionType,
    required this.quantity,
    required this.unitId,
    this.reference,
    this.notes,
    required this.transactionDate,
    required this.createdAt,
    this.negativeAdjustment = false,
  });
  final String id, warehouseId, itemId, unitId;
  final StockItemType itemType;
  final StockTransactionType transactionType;
  final double quantity;
  final String? reference, notes;
  final DateTime transactionDate, createdAt;
  final bool negativeAdjustment;
  factory StockTransaction.fromMap(Map<String, Object?> map) =>
      StockTransaction(
        id: map['id'] as String,
        warehouseId: map['warehouseId'] as String,
        itemId: map['itemId'] as String,
        itemType: map['itemType'] == 'PRODUCT'
            ? StockItemType.product
            : StockItemType.rawMaterial,
        transactionType: StockTransactionType.values.firstWhere(
          (v) => v.value == map['transactionType'],
        ),
        quantity: (map['quantity'] as num).toDouble(),
        unitId: map['unitId'] as String,
        reference: _displayReference(map['reference'] as String?),
        notes: map['notes'] as String?,
        transactionDate: DateTime.fromMillisecondsSinceEpoch(
          map['transactionDate'] as int,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        negativeAdjustment:
            map['transactionType'] == 'ADJUSTMENT' &&
            (map['reference'] as String?)?.startsWith('ADJUSTMENT_OUT:') ==
                true,
      );
  double get signedQuantity => switch (transactionType) {
    StockTransactionType.stockOut ||
    StockTransactionType.transferOut => -quantity.abs(),
    StockTransactionType.adjustment =>
      negativeAdjustment ? -quantity : quantity,
    _ => quantity.abs(),
  };
}

String? _displayReference(String? reference) {
  if (reference == null) return null;
  if (reference.startsWith('ADJUSTMENT_OUT:')) {
    return reference.substring('ADJUSTMENT_OUT:'.length);
  }
  if (reference.startsWith('OPERATION:')) {
    return reference.substring('OPERATION:'.length);
  }
  return reference;
}

class StockItemOption {
  const StockItemOption({
    required this.id,
    required this.name,
    required this.code,
    required this.unitId,
    required this.type,
    required this.active,
  });
  final String id, name, code, unitId;
  final StockItemType type;
  final bool active;
}

class StockLine {
  const StockLine({
    required this.balance,
    required this.item,
    required this.unitName,
  });
  final StockBalance balance;
  final StockItemOption item;
  final String unitName;
}

class StockLedgerLine {
  const StockLedgerLine({
    required this.transaction,
    required this.balanceAfter,
  });
  final StockTransaction transaction;
  final double balanceAfter;
}
