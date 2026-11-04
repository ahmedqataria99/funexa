enum PurchaseRequestStatus {
  draft,
  pending,
  approved,
  rejected,
  converted,
  cancelled,
}

enum PurchaseOrderStatus {
  draft,
  approved,
  partiallyReceived,
  fullyReceived,
  cancelled,
}

enum PurchasingItemType { rawMaterial, product }

extension PurchasingItemTypeValue on PurchasingItemType {
  String get value =>
      this == PurchasingItemType.rawMaterial ? 'RAW_MATERIAL' : 'PRODUCT';
}

String purchasingDocumentItemId(String documentId, int lineIndex) {
  if (documentId.trim().isEmpty || lineIndex < 0) {
    throw ArgumentError('هوية المستند أو ترتيب السطر غير صالح');
  }
  return '$documentId-item-${lineIndex + 1}';
}

class Supplier {
  Supplier({
    required this.id,
    required this.name,
    required this.code,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.notes,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (name.trim().isEmpty || code.trim().isEmpty) {
      throw ArgumentError('اسم وكود المورد مطلوبان');
    }
  }
  final String id, name, code;
  final String? phone, email, address, taxNumber, notes;
  final bool active;
  final DateTime createdAt, updatedAt;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name.trim(),
    'code': code.trim(),
    'phone': phone?.trim(),
    'email': email?.trim(),
    'address': address?.trim(),
    'taxNumber': taxNumber?.trim(),
    'notes': notes?.trim(),
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };
  factory Supplier.fromMap(Map<String, Object?> m) => Supplier(
    id: m['id'] as String,
    name: m['name'] as String,
    code: m['code'] as String,
    phone: m['phone'] as String?,
    email: m['email'] as String?,
    address: m['address'] as String?,
    taxNumber: m['taxNumber'] as String?,
    notes: m['notes'] as String?,
    active: m['active'] == 1,
    createdAt: _date(m['createdAt']),
    updatedAt: _date(m['updatedAt']),
  );
}

class PurchasingItem {
  const PurchasingItem({
    required this.id,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.unitId,
    this.variantId,
    this.baseUnitId,
    this.unitConversionFactor = 1,
    this.baseQuantity,
    this.receivedBaseQuantity = 0,
    this.inventoryIdentityKind = 'BASE',
    this.identitySnapshotStatus = 'VERIFIED',
    this.notes,
    this.unitPrice = 0,
    this.discount = 0,
    this.tax = 0,
    this.receivedQuantity = 0,
    this.lineTotal = 0,
  });
  final String id, itemId, unitId;
  final String? variantId, baseUnitId;
  final String inventoryIdentityKind, identitySnapshotStatus;
  final PurchasingItemType itemType;
  final double quantity, unitPrice, discount, tax, receivedQuantity, lineTotal;
  final double unitConversionFactor;
  final double? baseQuantity;
  final double receivedBaseQuantity;
  final String? notes;
  double get remainingQuantity => quantity - receivedQuantity;
  double get normalizedBaseQuantity =>
      baseQuantity ?? quantity * unitConversionFactor;

  PurchasingItem copyWith({
    String? id,
    String? itemId,
    PurchasingItemType? itemType,
    double? quantity,
    String? unitId,
    String? variantId,
    String? baseUnitId,
    double? unitConversionFactor,
    double? baseQuantity,
    double? receivedBaseQuantity,
    String? inventoryIdentityKind,
    String? identitySnapshotStatus,
    String? notes,
    double? unitPrice,
    double? discount,
    double? tax,
    double? receivedQuantity,
    double? lineTotal,
  }) => PurchasingItem(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    itemType: itemType ?? this.itemType,
    quantity: quantity ?? this.quantity,
    unitId: unitId ?? this.unitId,
    variantId: variantId ?? this.variantId,
    baseUnitId: baseUnitId ?? this.baseUnitId,
    unitConversionFactor: unitConversionFactor ?? this.unitConversionFactor,
    baseQuantity: baseQuantity ?? this.baseQuantity,
    receivedBaseQuantity: receivedBaseQuantity ?? this.receivedBaseQuantity,
    inventoryIdentityKind: inventoryIdentityKind ?? this.inventoryIdentityKind,
    identitySnapshotStatus:
        identitySnapshotStatus ?? this.identitySnapshotStatus,
    notes: notes ?? this.notes,
    unitPrice: unitPrice ?? this.unitPrice,
    discount: discount ?? this.discount,
    tax: tax ?? this.tax,
    receivedQuantity: receivedQuantity ?? this.receivedQuantity,
    lineTotal: lineTotal ?? this.lineTotal,
  );
}

class PurchaseRequest {
  PurchaseRequest({
    required this.id,
    required this.requestNumber,
    required this.requestDate,
    required this.supplierId,
    required this.requestedBy,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });
  final String id, requestNumber, supplierId, requestedBy;
  final DateTime requestDate, createdAt, updatedAt;
  final String? notes;
  final PurchaseRequestStatus status;
  final List<PurchasingItem> items;
}

class PurchaseOrder {
  PurchaseOrder({
    required this.id,
    required this.orderNumber,
    required this.supplierId,
    this.purchaseRequestId,
    required this.orderDate,
    this.expectedDeliveryDate,
    required this.status,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.grandTotal,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });
  final String id, orderNumber, supplierId;
  final String? purchaseRequestId, notes;
  final DateTime orderDate, createdAt, updatedAt;
  final DateTime? expectedDeliveryDate;
  final PurchaseOrderStatus status;
  final double subtotal, discount, tax, grandTotal;
  final List<PurchasingItem> items;

  PurchaseOrder copyWith({
    String? id,
    String? orderNumber,
    String? supplierId,
    String? purchaseRequestId,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    PurchaseOrderStatus? status,
    double? subtotal,
    double? discount,
    double? tax,
    double? grandTotal,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PurchasingItem>? items,
  }) => PurchaseOrder(
    id: id ?? this.id,
    orderNumber: orderNumber ?? this.orderNumber,
    supplierId: supplierId ?? this.supplierId,
    purchaseRequestId: purchaseRequestId ?? this.purchaseRequestId,
    orderDate: orderDate ?? this.orderDate,
    expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
    status: status ?? this.status,
    subtotal: subtotal ?? this.subtotal,
    discount: discount ?? this.discount,
    tax: tax ?? this.tax,
    grandTotal: grandTotal ?? this.grandTotal,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    items: items ?? this.items,
  );
}

class PurchaseReceipt {
  const PurchaseReceipt({
    required this.id,
    required this.receiptNumber,
    required this.purchaseOrderId,
    required this.warehouseId,
    required this.receiptDate,
    this.notes,
    this.receivedBy,
    this.items = const [],
    this.orderStatusAfterReceipt,
  });
  final String id, receiptNumber, purchaseOrderId, warehouseId;
  final DateTime receiptDate;
  final String? notes, receivedBy;
  final List<PurchaseReceiptLine> items;
  final PurchaseOrderStatus? orderStatusAfterReceipt;
}

class PurchaseReceiptLine {
  const PurchaseReceiptLine({
    required this.id,
    required this.purchaseOrderItemId,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.unitId,
    required this.previouslyReceived,
    required this.remainingAfterReceipt,
    this.notes,
  });

  final String id, purchaseOrderItemId, itemId, unitId;
  final PurchasingItemType itemType;
  final double quantity, previouslyReceived, remainingAfterReceipt;
  final String? notes;
}

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int);
