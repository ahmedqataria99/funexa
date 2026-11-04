enum ReturnStatus { draft, pending, approved, rejected, completed, cancelled }

enum ReturnQualityStatus { pending, approved, rejected, quarantined }

enum QualityInspectionStatus {
  pending,
  inProgress,
  completed,
  rejected,
  quarantined,
}

enum QualityInspectionResult { passed, failed, quarantined, rejected }

extension ReturnStatusValue on ReturnStatus {
  String get value => switch (this) {
    ReturnStatus.draft => 'DRAFT',
    ReturnStatus.pending => 'PENDING',
    ReturnStatus.approved => 'APPROVED',
    ReturnStatus.rejected => 'REJECTED',
    ReturnStatus.completed => 'COMPLETED',
    ReturnStatus.cancelled => 'CANCELLED',
  };
}

extension ReturnQualityStatusValue on ReturnQualityStatus {
  String get value => switch (this) {
    ReturnQualityStatus.pending => 'PENDING',
    ReturnQualityStatus.approved => 'APPROVED',
    ReturnQualityStatus.rejected => 'REJECTED',
    ReturnQualityStatus.quarantined => 'QUARANTINED',
  };
}

extension QualityInspectionStatusValue on QualityInspectionStatus {
  String get value => switch (this) {
    QualityInspectionStatus.pending => 'PENDING',
    QualityInspectionStatus.inProgress => 'IN_PROGRESS',
    QualityInspectionStatus.completed => 'COMPLETED',
    QualityInspectionStatus.rejected => 'REJECTED',
    QualityInspectionStatus.quarantined => 'QUARANTINED',
  };
}

extension QualityInspectionResultValue on QualityInspectionResult {
  String get value => switch (this) {
    QualityInspectionResult.passed => 'PASSED',
    QualityInspectionResult.failed => 'FAILED',
    QualityInspectionResult.quarantined => 'QUARANTINED',
    QualityInspectionResult.rejected => 'REJECTED',
  };
}

typedef SalesReturnStatus = ReturnStatus;
typedef PurchaseReturnStatus = ReturnStatus;

typedef SalesReturnQualityStatus = ReturnQualityStatus;
typedef PurchaseReturnQualityStatus = ReturnQualityStatus;

class SalesReturnItem {
  const SalesReturnItem({
    required this.id,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.unitId,
    this.variantId,
    this.baseUnitId,
    this.unitConversionFactor = 1,
    this.baseQuantity,
    this.inventoryIdentityKind = 'BASE',
    this.identitySnapshotStatus = 'UNVERIFIED',
    this.unitPrice = 0,
    this.reason,
    this.notes,
    this.qualityStatus = ReturnQualityStatus.pending,
    this.sourceDeliveryId,
    this.sourceDeliveryItemId,
  });

  final String id;
  final String itemId;
  final String itemType;
  final double quantity;
  final String unitId;
  final String? variantId, baseUnitId;
  final double unitConversionFactor;
  final double? baseQuantity;
  final String inventoryIdentityKind;
  final String identitySnapshotStatus;
  final double unitPrice;
  final String? reason;
  final String? notes;
  final ReturnQualityStatus qualityStatus;
  final String? sourceDeliveryId;
  final String? sourceDeliveryItemId;

  Map<String, Object?> toMap(
    String salesReturnId, {
    String? identitySnapshotStatus,
  }) => {
    'id': id,
    'salesReturnId': salesReturnId,
    'itemId': itemId,
    'productId': itemId,
    'itemType': itemType,
    'quantity': quantity,
    'unitId': unitId,
    'variantId': variantId,
    'baseUnitId': baseUnitId,
    'unitConversionFactor': unitConversionFactor,
    'baseQuantity': baseQuantity ?? quantity * unitConversionFactor,
    'inventoryIdentityKind': inventoryIdentityKind,
    'identitySnapshotStatus':
        identitySnapshotStatus ?? this.identitySnapshotStatus,
    'unitPrice': unitPrice,
    'reason': reason,
    'qualityStatus': qualityStatus.value,
    'sourceDeliveryItemId': sourceDeliveryItemId,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };

  factory SalesReturnItem.fromMap(Map<String, Object?> row) => SalesReturnItem(
    id: row['id'] as String,
    itemId: row['itemId'] as String,
    itemType: row['itemType'] as String,
    quantity: (row['quantity'] as num).toDouble(),
    unitId: row['unitId'] as String,
    variantId: row['variantId'] as String?,
    baseUnitId: row['baseUnitId'] as String?,
    unitConversionFactor:
        (row['unitConversionFactor'] as num?)?.toDouble() ?? 1,
    baseQuantity: (row['baseQuantity'] as num?)?.toDouble(),
    inventoryIdentityKind: row['inventoryIdentityKind'] as String? ?? 'BASE',
    identitySnapshotStatus:
        row['identitySnapshotStatus'] as String? ?? 'UNVERIFIED',
    unitPrice: (row['unitPrice'] as num?)?.toDouble() ?? 0,
    reason: row['reason'] as String?,
    notes: row['notes'] as String?,
    qualityStatus: _returnQualityStatus(row['qualityStatus'] as String?),
    sourceDeliveryId: row['sourceDeliveryId'] as String?,
    sourceDeliveryItemId: row['sourceDeliveryItemId'] as String?,
  );
}

class SalesReturn {
  const SalesReturn({
    required this.id,
    required this.returnNumber,
    required this.salesOrderId,
    required this.customerId,
    required this.warehouseId,
    required this.returnDate,
    this.salesDeliveryId,
    this.reason,
    this.status = ReturnStatus.pending,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String id;
  final String returnNumber;
  final String salesOrderId;
  final String customerId;
  final String warehouseId;
  final DateTime returnDate;
  final String? salesDeliveryId;
  final String? reason;
  final ReturnStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SalesReturnItem> items;

  Map<String, Object?> toMap() => {
    'id': id,
    'returnNumber': returnNumber,
    'salesOrderId': salesOrderId,
    'salesDeliveryId': salesDeliveryId,
    'customerId': customerId,
    'warehouseId': warehouseId,
    'returnDate': returnDate.millisecondsSinceEpoch,
    'reason': reason,
    'status': status.value,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory SalesReturn.fromMap(Map<String, Object?> row) => SalesReturn(
    id: row['id'] as String,
    returnNumber: row['returnNumber'] as String,
    salesOrderId: row['salesOrderId'] as String,
    customerId: row['customerId'] as String,
    warehouseId: row['warehouseId'] as String,
    returnDate: _date(row['returnDate']),
    salesDeliveryId: row['salesDeliveryId'] as String?,
    reason: row['reason'] as String?,
    status: _returnStatus(row['status'] as String?),
    notes: row['notes'] as String?,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class PurchaseReturnItem {
  const PurchaseReturnItem({
    required this.id,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.unitId,
    this.variantId,
    this.baseUnitId,
    this.unitConversionFactor = 1,
    this.baseQuantity,
    this.inventoryIdentityKind = 'BASE',
    this.identitySnapshotStatus = 'UNVERIFIED',
    this.unitPrice = 0,
    this.reason,
    this.notes,
    this.qualityStatus = ReturnQualityStatus.pending,
    this.sourceReceiptId,
    this.purchaseOrderItemId,
  });

  final String id;
  final String itemId;
  final String itemType;
  final double quantity;
  final String unitId;
  final String? variantId, baseUnitId;
  final double unitConversionFactor;
  final double? baseQuantity;
  final String inventoryIdentityKind;
  final String identitySnapshotStatus;
  final double unitPrice;
  final String? reason;
  final String? notes;
  final ReturnQualityStatus qualityStatus;
  final String? sourceReceiptId;
  final String? purchaseOrderItemId;

  Map<String, Object?> toMap(
    String purchaseReturnId, {
    String? purchaseOrderItemId,
    String? identitySnapshotStatus,
    String? sourceReceiptId,
  }) => {
    'id': id,
    'purchaseReturnId': purchaseReturnId,
    'itemId': itemId,
    'productId': itemId,
    'purchaseOrderItemId': purchaseOrderItemId ?? this.purchaseOrderItemId,
    'sourceReceiptId': sourceReceiptId ?? this.sourceReceiptId,
    'itemType': itemType,
    'quantity': quantity,
    'unitId': unitId,
    'variantId': variantId,
    'baseUnitId': baseUnitId,
    'unitConversionFactor': unitConversionFactor,
    'baseQuantity': baseQuantity ?? quantity * unitConversionFactor,
    'inventoryIdentityKind': inventoryIdentityKind,
    'identitySnapshotStatus':
        identitySnapshotStatus ?? this.identitySnapshotStatus,
    'unitPrice': unitPrice,
    'reason': reason,
    'qualityStatus': qualityStatus.value,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };

  factory PurchaseReturnItem.fromMap(Map<String, Object?> row) =>
      PurchaseReturnItem(
        id: row['id'] as String,
        itemId: row['itemId'] as String,
        itemType: row['itemType'] as String,
        quantity: (row['quantity'] as num).toDouble(),
        unitId: row['unitId'] as String,
        variantId: row['variantId'] as String?,
        baseUnitId: row['baseUnitId'] as String?,
        unitConversionFactor:
            (row['unitConversionFactor'] as num?)?.toDouble() ?? 1,
        baseQuantity: (row['baseQuantity'] as num?)?.toDouble(),
        inventoryIdentityKind:
            row['inventoryIdentityKind'] as String? ?? 'BASE',
        identitySnapshotStatus:
            row['identitySnapshotStatus'] as String? ?? 'UNVERIFIED',
        unitPrice: (row['unitPrice'] as num?)?.toDouble() ?? 0,
        reason: row['reason'] as String?,
        notes: row['notes'] as String?,
        qualityStatus: _returnQualityStatus(row['qualityStatus'] as String?),
        sourceReceiptId: row['sourceReceiptId'] as String?,
        purchaseOrderItemId: row['purchaseOrderItemId'] as String?,
      );
}

class PurchaseReturn {
  const PurchaseReturn({
    required this.id,
    required this.returnNumber,
    required this.purchaseOrderId,
    required this.supplierId,
    required this.warehouseId,
    required this.returnDate,
    this.purchaseReceiptId,
    this.reason,
    this.status = ReturnStatus.pending,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String id;
  final String returnNumber;
  final String purchaseOrderId;
  final String supplierId;
  final String warehouseId;
  final DateTime returnDate;
  final String? purchaseReceiptId;
  final String? reason;
  final ReturnStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PurchaseReturnItem> items;

  Map<String, Object?> toMap() => {
    'id': id,
    'returnNumber': returnNumber,
    'purchaseOrderId': purchaseOrderId,
    'purchaseReceiptId': purchaseReceiptId,
    'supplierId': supplierId,
    'warehouseId': warehouseId,
    'returnDate': returnDate.millisecondsSinceEpoch,
    'reason': reason,
    'status': status.value,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory PurchaseReturn.fromMap(Map<String, Object?> row) => PurchaseReturn(
    id: row['id'] as String,
    returnNumber: row['returnNumber'] as String,
    purchaseOrderId: row['purchaseOrderId'] as String,
    supplierId: row['supplierId'] as String,
    warehouseId: row['warehouseId'] as String,
    returnDate: _date(row['returnDate']),
    purchaseReceiptId: row['purchaseReceiptId'] as String?,
    reason: row['reason'] as String?,
    status: _returnStatus(row['status'] as String?),
    notes: row['notes'] as String?,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class QualityInspectionItem {
  const QualityInspectionItem({
    required this.id,
    required this.itemId,
    required this.itemType,
    required this.requestedQuantity,
    required this.inspectedQuantity,
    required this.acceptedQuantity,
    required this.rejectedQuantity,
    this.sourceReturnItemId,
    this.productId,
    this.variantId,
    this.inventoryIdentityKind,
    this.identitySnapshotStatus,
    this.unitId,
    this.baseUnitId,
    this.unitConversionFactor,
    this.requestedBaseQuantity,
    this.inspectedBaseQuantity,
    this.acceptedBaseQuantity,
    this.rejectedBaseQuantity,
    this.result = QualityInspectionResult.passed,
    this.notes,
  });

  final String id;
  final String itemId;
  final String itemType;
  final double requestedQuantity;
  final double inspectedQuantity;
  final double acceptedQuantity;
  final double rejectedQuantity;
  final String? sourceReturnItemId;
  final String? productId, variantId;
  final String? inventoryIdentityKind, identitySnapshotStatus;
  final String? unitId, baseUnitId;
  final double? unitConversionFactor;
  final double? requestedBaseQuantity,
      inspectedBaseQuantity,
      acceptedBaseQuantity,
      rejectedBaseQuantity;
  final QualityInspectionResult result;
  final String? notes;

  Map<String, Object?> toMap(String inspectionId) {
    final factor = unitConversionFactor ?? 1;
    return {
      'id': id,
      'inspectionId': inspectionId,
      'itemId': itemId,
      'sourceReturnItemId': sourceReturnItemId,
      'productId': productId ?? itemId,
      'variantId': variantId,
      'inventoryIdentityKind': inventoryIdentityKind ?? 'BASE',
      'identitySnapshotStatus': identitySnapshotStatus ?? 'UNVERIFIED',
      'unitId': unitId,
      'baseUnitId': baseUnitId,
      'unitConversionFactor': factor,
      'itemType': itemType,
      'requestedQuantity': requestedQuantity,
      'inspectedQuantity': inspectedQuantity,
      'acceptedQuantity': acceptedQuantity,
      'rejectedQuantity': rejectedQuantity,
      'requestedBaseQuantity':
          requestedBaseQuantity ?? requestedQuantity * factor,
      'inspectedBaseQuantity':
          inspectedBaseQuantity ?? inspectedQuantity * factor,
      'acceptedBaseQuantity': acceptedBaseQuantity ?? acceptedQuantity * factor,
      'rejectedBaseQuantity': rejectedBaseQuantity ?? rejectedQuantity * factor,
      'result': result.value,
      'notes': notes,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory QualityInspectionItem.fromMap(
    Map<String, Object?> row,
  ) => QualityInspectionItem(
    id: row['id'] as String,
    itemId: row['itemId'] as String,
    itemType: row['itemType'] as String,
    sourceReturnItemId: row['sourceReturnItemId'] as String?,
    productId: row['productId'] as String?,
    variantId: row['variantId'] as String?,
    inventoryIdentityKind: row['inventoryIdentityKind'] as String?,
    identitySnapshotStatus: row['identitySnapshotStatus'] as String?,
    unitId: row['unitId'] as String?,
    baseUnitId: row['baseUnitId'] as String?,
    unitConversionFactor: (row['unitConversionFactor'] as num?)?.toDouble(),
    requestedQuantity: (row['requestedQuantity'] as num).toDouble(),
    inspectedQuantity: (row['inspectedQuantity'] as num).toDouble(),
    acceptedQuantity: (row['acceptedQuantity'] as num).toDouble(),
    rejectedQuantity: (row['rejectedQuantity'] as num).toDouble(),
    requestedBaseQuantity: (row['requestedBaseQuantity'] as num?)?.toDouble(),
    inspectedBaseQuantity: (row['inspectedBaseQuantity'] as num?)?.toDouble(),
    acceptedBaseQuantity: (row['acceptedBaseQuantity'] as num?)?.toDouble(),
    rejectedBaseQuantity: (row['rejectedBaseQuantity'] as num?)?.toDouble(),
    result: _inspectionResult(row['result'] as String?),
    notes: row['notes'] as String?,
  );
}

class QualityInspection {
  const QualityInspection({
    required this.id,
    required this.inspectionNumber,
    required this.sourceType,
    required this.sourceId,
    this.warehouseId,
    required this.itemId,
    required this.itemType,
    this.inspectedBy,
    required this.inspectionDate,
    this.status = QualityInspectionStatus.pending,
    this.result = QualityInspectionResult.passed,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
  });

  final String id;
  final String inspectionNumber;
  final String sourceType;
  final String sourceId;
  final String? warehouseId;
  final String itemId;
  final String itemType;
  final String? inspectedBy;
  final DateTime inspectionDate;
  final QualityInspectionStatus status;
  final QualityInspectionResult result;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QualityInspectionItem> items;

  Map<String, Object?> toMap() => {
    'id': id,
    'inspectionNumber': inspectionNumber,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'warehouseId': warehouseId,
    'itemId': itemId,
    'itemType': itemType,
    'inspectedBy': inspectedBy,
    'inspectionDate': inspectionDate.millisecondsSinceEpoch,
    'status': status.value,
    'result': result.value,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory QualityInspection.fromMap(
    Map<String, Object?> row, {
    List<QualityInspectionItem> items = const [],
  }) => QualityInspection(
    id: row['id'] as String,
    inspectionNumber: row['inspectionNumber'] as String,
    sourceType: row['sourceType'] as String,
    sourceId: row['sourceId'] as String,
    warehouseId: row['warehouseId'] as String?,
    itemId: row['itemId'] as String,
    itemType: row['itemType'] as String,
    inspectedBy: row['inspectedBy'] as String?,
    inspectionDate: _date(row['inspectionDate']),
    status: _inspectionStatus(row['status'] as String?),
    result: _inspectionResult(row['result'] as String?),
    notes: row['notes'] as String?,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
    items: items,
  );
}

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int);

ReturnStatus _returnStatus(String? value) => ReturnStatus.values.firstWhere(
  (status) => status.value == value,
  orElse: () => ReturnStatus.pending,
);

ReturnQualityStatus _returnQualityStatus(String? value) =>
    ReturnQualityStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ReturnQualityStatus.pending,
    );

QualityInspectionStatus _inspectionStatus(String? value) =>
    QualityInspectionStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => QualityInspectionStatus.pending,
    );

QualityInspectionResult _inspectionResult(String? value) =>
    QualityInspectionResult.values.firstWhere(
      (result) => result.value == value,
      orElse: () => QualityInspectionResult.passed,
    );
