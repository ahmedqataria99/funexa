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
  confirmed,
  partiallyReceived,
  fullyReceived,
  cancelled,
}

enum PurchasingItemType { rawMaterial, product }

extension PurchasingItemTypeValue on PurchasingItemType {
  String get value =>
      this == PurchasingItemType.rawMaterial ? 'RAW_MATERIAL' : 'PRODUCT';
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
    this.notes,
    this.unitPrice = 0,
    this.discount = 0,
    this.tax = 0,
    this.receivedQuantity = 0,
    this.lineTotal = 0,
  });
  final String id, itemId, unitId;
  final PurchasingItemType itemType;
  final double quantity, unitPrice, discount, tax, receivedQuantity, lineTotal;
  final String? notes;
  double get remainingQuantity => quantity - receivedQuantity;
}

class PurchaseRequest {
  PurchaseRequest({
    required this.id,
    required this.requestNumber,
    required this.requestDate,
    required this.requestedBy,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });
  final String id, requestNumber, requestedBy;
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
}

class PurchaseReceipt {
  const PurchaseReceipt({
    required this.id,
    required this.receiptNumber,
    required this.purchaseOrderId,
    required this.warehouseId,
    required this.receiptDate,
    this.notes,
  });
  final String id, receiptNumber, purchaseOrderId, warehouseId;
  final DateTime receiptDate;
  final String? notes;
}

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int);
