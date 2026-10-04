enum SalesItemType { product, rawMaterial }

enum QuotationStatus {
  draft,
  sent,
  accepted,
  rejected,
  expired,
  converted,
  cancelled,
}

enum SalesOrderStatus {
  draft,
  confirmed,
  partiallyDelivered,
  fullyDelivered,
  cancelled,
}

enum DeliveryDispatchStatus {
  pending,
  dispatched,
  inTransit,
  delivered,
  cancelled,
}

extension SalesItemTypeValue on SalesItemType {
  String get value =>
      this == SalesItemType.product ? 'PRODUCT' : 'RAW_MATERIAL';
}

class Customer {
  Customer({
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
      throw ArgumentError('اسم وكود العميل مطلوبان');
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
  factory Customer.fromMap(Map<String, Object?> m) => Customer(
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

class SalesItem {
  const SalesItem({
    required this.id,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.unitId,
    this.unitPrice = 0,
    this.discount = 0,
    this.tax = 0,
    this.lineTotal = 0,
    this.deliveredQuantity = 0,
    this.notes,
  });
  final String id, itemId, unitId;
  final SalesItemType itemType;
  final double quantity, unitPrice, discount, tax, lineTotal, deliveredQuantity;
  final String? notes;
  double get remainingQuantity => quantity - deliveredQuantity;
}

class Quotation {
  const Quotation({
    required this.id,
    required this.quotationNumber,
    required this.customerId,
    required this.quotationDate,
    this.validUntil,
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
  final String id, quotationNumber, customerId;
  final DateTime quotationDate, createdAt, updatedAt;
  final DateTime? validUntil;
  final QuotationStatus status;
  final double subtotal, discount, tax, grandTotal;
  final String? notes;
  final List<SalesItem> items;
}

class SalesOrder {
  const SalesOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    this.quotationId,
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
  final String id, orderNumber, customerId;
  final String? quotationId, notes;
  final DateTime orderDate, createdAt, updatedAt;
  final DateTime? expectedDeliveryDate;
  final SalesOrderStatus status;
  final double subtotal, discount, tax, grandTotal;
  final List<SalesItem> items;
}

class SalesDelivery {
  const SalesDelivery({
    required this.id,
    required this.deliveryNumber,
    required this.salesOrderId,
    required this.warehouseId,
    required this.deliveryDate,
    this.status = DeliveryDispatchStatus.pending,
    this.dispatchDate,
    this.driverName,
    this.vehicleNumber,
    this.destination,
    this.notes,
  });
  final String id, deliveryNumber, salesOrderId, warehouseId;
  final DateTime deliveryDate;
  final DeliveryDispatchStatus status;
  final DateTime? dispatchDate;
  final String? driverName, vehicleNumber, destination, notes;

  factory SalesDelivery.fromMap(Map<String, Object?> row) {
    final rawStatus = row['status'] as String? ?? 'PENDING';
    return SalesDelivery(
      id: row['id'] as String,
      deliveryNumber: row['deliveryNumber'] as String,
      salesOrderId: row['salesOrderId'] as String,
      warehouseId: row['warehouseId'] as String,
      deliveryDate: _date(row['deliveryDate']),
      status: _deliveryDispatchStatus(rawStatus),
      dispatchDate: row['dispatchDate'] == null
          ? null
          : _date(row['dispatchDate']),
      driverName: row['driverName'] as String?,
      vehicleNumber: row['vehicleNumber'] as String?,
      destination: row['destination'] as String?,
      notes: row['notes'] as String?,
    );
  }
}

extension DeliveryDispatchStatusValue on DeliveryDispatchStatus {
  String get value => switch (this) {
    DeliveryDispatchStatus.pending => 'PENDING',
    DeliveryDispatchStatus.dispatched => 'DISPATCHED',
    DeliveryDispatchStatus.inTransit => 'IN_TRANSIT',
    DeliveryDispatchStatus.delivered => 'DELIVERED',
    DeliveryDispatchStatus.cancelled => 'CANCELLED',
  };
}

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int);

DeliveryDispatchStatus _deliveryDispatchStatus(String value) =>
    DeliveryDispatchStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DeliveryDispatchStatus.pending,
    );
