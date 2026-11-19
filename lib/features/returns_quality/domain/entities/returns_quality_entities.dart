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

class SalesReturnReceiptItem {
  const SalesReturnReceiptItem({
    required this.salesReturnItemId,
    required this.quantity,
    this.baseQuantity,
  });

  final String salesReturnItemId;
  final double quantity;
  final double? baseQuantity;
}

class SalesReturnSourceDelivery {
  const SalesReturnSourceDelivery({
    required this.id,
    required this.deliveryNumber,
    required this.salesOrderId,
    required this.salesOrderNumber,
    required this.customerId,
    required this.customerName,
    required this.warehouseId,
    required this.deliveryDate,
  });

  final String id;
  final String deliveryNumber;
  final String salesOrderId;
  final String salesOrderNumber;
  final String customerId;
  final String customerName;
  final String warehouseId;
  final DateTime deliveryDate;
}

class SalesReturnSourceLine {
  const SalesReturnSourceLine({
    required this.deliveryItemId,
    required this.itemId,
    required this.itemType,
    required this.itemName,
    required this.deliveredQuantity,
    required this.deliveredBaseQuantity,
    required this.previouslyReturnedBaseQuantity,
    required this.unitId,
    required this.unitName,
    required this.baseUnitId,
    required this.baseUnitName,
    required this.unitConversionFactor,
    required this.inventoryIdentityKind,
    required this.identitySnapshotStatus,
    this.variantId,
    this.variantName,
  });

  final String deliveryItemId;
  final String itemId;
  final String itemType;
  final String itemName;
  final double deliveredQuantity;
  final double deliveredBaseQuantity;
  final double previouslyReturnedBaseQuantity;
  final String unitId;
  final String unitName;
  final String baseUnitId;
  final String baseUnitName;
  final double unitConversionFactor;
  final String inventoryIdentityKind;
  final String identitySnapshotStatus;
  final String? variantId;
  final String? variantName;

  double get returnableBaseQuantity =>
      deliveredBaseQuantity - previouslyReturnedBaseQuantity;
  double get returnableQuantity =>
      returnableBaseQuantity / unitConversionFactor;
}

class SalesReturnWorkflowLine {
  const SalesReturnWorkflowLine({
    required this.item,
    required this.itemName,
    required this.unitName,
    required this.deliveredQuantity,
    required this.receivedQuantity,
    required this.receivedBaseQuantity,
    required this.acceptedQuantity,
    required this.acceptedBaseQuantity,
    required this.rejectedQuantity,
    required this.rejectedBaseQuantity,
  });

  final SalesReturnItem item;
  final String itemName;
  final String unitName;
  final double deliveredQuantity;
  final double receivedQuantity;
  final double receivedBaseQuantity;
  final double acceptedQuantity;
  final double acceptedBaseQuantity;
  final double rejectedQuantity;
  final double rejectedBaseQuantity;
}

class SalesReturnReceiptRecord {
  const SalesReturnReceiptRecord({
    required this.id,
    required this.receiptNumber,
    required this.warehouseId,
    required this.warehouseName,
    required this.receiptDate,
    required this.items,
  });

  final String id;
  final String receiptNumber;
  final String warehouseId;
  final String warehouseName;
  final DateTime receiptDate;
  final List<SalesReturnReceiptItem> items;
}

class SalesReturnWorkflowDetails {
  const SalesReturnWorkflowDetails({
    required this.salesReturn,
    required this.customerName,
    required this.salesOrderNumber,
    required this.deliveryNumber,
    required this.destinationWarehouseName,
    required this.lines,
    required this.receipts,
    required this.acceptedTransferCount,
    this.inspection,
    this.journalNumber,
  });

  final SalesReturn salesReturn;
  final String customerName;
  final String salesOrderNumber;
  final String deliveryNumber;
  final String destinationWarehouseName;
  final List<SalesReturnWorkflowLine> lines;
  final List<SalesReturnReceiptRecord> receipts;
  final QualityInspection? inspection;
  final int acceptedTransferCount;
  final String? journalNumber;
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
    items: row['items'] is List<SalesReturnItem>
        ? row['items'] as List<SalesReturnItem>
        : const [],
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
    this.approvedBy,
    this.approvedAt,
    this.approvalNotes,
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
  final String? approvedBy, approvalNotes;
  final DateTime? approvedAt;
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
    'approvedBy': approvedBy,
    'approvedAt': approvedAt?.millisecondsSinceEpoch,
    'approvalNotes': approvalNotes,
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
    approvedBy: row['approvedBy'] as String?,
    approvedAt: row['approvedAt'] == null ? null : _date(row['approvedAt']),
    approvalNotes: row['approvalNotes'] as String?,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class PurchaseReturnSourceOrder {
  const PurchaseReturnSourceOrder({
    required this.id,
    required this.orderNumber,
    required this.supplierId,
    required this.supplierName,
    required this.orderDate,
  });

  final String id, orderNumber, supplierId, supplierName;
  final DateTime orderDate;
}

class PurchaseReturnSourceLine {
  const PurchaseReturnSourceLine({
    required this.purchaseOrderItemId,
    required this.receiptId,
    required this.receiptNumber,
    required this.sourceWarehouseId,
    required this.itemId,
    required this.itemType,
    required this.itemName,
    required this.quantity,
    required this.receivedQuantity,
    required this.receivedBaseQuantity,
    required this.purchaseOrderReceivedBaseQuantity,
    required this.returnedBaseQuantity,
    required this.receiptReturnedBaseQuantity,
    required this.unitPrice,
    required this.unitId,
    required this.unitName,
    required this.baseUnitId,
    required this.unitConversionFactor,
    required this.inventoryIdentityKind,
    required this.identitySnapshotStatus,
    this.variantId,
    this.variantName,
  });

  final String purchaseOrderItemId, receiptId, receiptNumber;
  final String sourceWarehouseId;
  final String itemId, itemType, itemName, unitId, unitName, baseUnitId;
  final String inventoryIdentityKind, identitySnapshotStatus;
  final String? variantId, variantName;
  final double quantity, receivedQuantity, receivedBaseQuantity;
  final double purchaseOrderReceivedBaseQuantity;
  final double returnedBaseQuantity, receiptReturnedBaseQuantity, unitPrice;
  final double unitConversionFactor;
  double get returnableBaseQuantity =>
      (receivedBaseQuantity - receiptReturnedBaseQuantity)
          .clamp(0, double.infinity)
          .clamp(
            0,
            (purchaseOrderReceivedBaseQuantity - returnedBaseQuantity).clamp(
              0,
              double.infinity,
            ),
          )
          .toDouble();
  double get returnableQuantity =>
      returnableBaseQuantity / unitConversionFactor;
}

class PurchaseReturnReceiptItem {
  const PurchaseReturnReceiptItem({
    this.id,
    required this.purchaseReturnItemId,
    required this.quantity,
    this.baseQuantity,
    this.movementReference,
    this.inspectionStatus,
    this.inspectedQuantity = 0,
    this.acceptedQuantity = 0,
    this.rejectedQuantity = 0,
    this.quarantinedQuantity = 0,
    this.handedOverQuantity = 0,
  });

  final String? id;
  final String purchaseReturnItemId;
  final double quantity;
  final double? baseQuantity;
  final String? movementReference;
  final String? inspectionStatus;
  final double inspectedQuantity, acceptedQuantity, rejectedQuantity;
  final double quarantinedQuantity, handedOverQuantity;
}

class PurchaseReturnReceiptRecord {
  const PurchaseReturnReceiptRecord({
    required this.id,
    required this.receiptNumber,
    required this.warehouseId,
    required this.warehouseName,
    required this.receiptDate,
    required this.items,
    this.receivedBy,
    this.notes,
  });

  final String id, receiptNumber, warehouseId, warehouseName;
  final DateTime receiptDate;
  final String? receivedBy, notes;
  final List<PurchaseReturnReceiptItem> items;
}

class PurchaseReturnHandoverItem {
  const PurchaseReturnHandoverItem({
    required this.purchaseReturnItemId,
    required this.purchaseReturnReceiptItemId,
    required this.quantity,
    this.baseQuantity,
    this.movementReference,
  });

  final String purchaseReturnItemId, purchaseReturnReceiptItemId;
  final double quantity;
  final double? baseQuantity;
  final String? movementReference;
}

class PurchaseReturnHandoverRecord {
  const PurchaseReturnHandoverRecord({
    required this.id,
    required this.handoverNumber,
    required this.warehouseId,
    required this.handoverDate,
    required this.items,
    this.performedBy,
    this.notes,
    this.journalEntryId,
    this.journalNumber,
  });

  final String id, handoverNumber, warehouseId;
  final DateTime handoverDate;
  final String? performedBy, notes, journalEntryId, journalNumber;
  final List<PurchaseReturnHandoverItem> items;
}

class PurchaseReturnWorkflowLine {
  const PurchaseReturnWorkflowLine({
    required this.item,
    required this.itemName,
    required this.unitName,
    required this.requestedQuantity,
    required this.receivedQuantity,
    required this.inspectedQuantity,
    required this.acceptedQuantity,
    required this.rejectedQuantity,
    required this.quarantinedQuantity,
    required this.handedOverQuantity,
  });

  final PurchaseReturnItem item;
  final String itemName, unitName;
  final double requestedQuantity;
  final double receivedQuantity, inspectedQuantity;
  final double acceptedQuantity, rejectedQuantity, quarantinedQuantity;
  final double handedOverQuantity;
  double get awaitingInspectionQuantity =>
      (receivedQuantity - inspectedQuantity).clamp(0, double.infinity);
  double get eligibleHandoverQuantity =>
      (acceptedQuantity - handedOverQuantity).clamp(0, double.infinity);
}

class PurchaseReturnWorkflowDetails {
  const PurchaseReturnWorkflowDetails({
    required this.purchaseReturn,
    required this.supplierName,
    required this.purchaseOrderNumber,
    required this.warehouseName,
    required this.lines,
    required this.receipts,
    required this.inspections,
    required this.handovers,
    required this.hasInspectionRecords,
    required this.receiptQcComplete,
  });

  final PurchaseReturn purchaseReturn;
  final String supplierName, purchaseOrderNumber, warehouseName;
  final List<PurchaseReturnWorkflowLine> lines;
  final List<PurchaseReturnReceiptRecord> receipts;
  final List<QualityInspection> inspections;
  final List<PurchaseReturnHandoverRecord> handovers;
  final bool hasInspectionRecords, receiptQcComplete;
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
    this.purchaseReturnReceiptItemId,
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
    this.quarantinedQuantity = 0,
    this.quarantinedBaseQuantity,
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
  final String? purchaseReturnReceiptItemId;
  final String? productId, variantId;
  final String? inventoryIdentityKind, identitySnapshotStatus;
  final String? unitId, baseUnitId;
  final double? unitConversionFactor;
  final double? requestedBaseQuantity,
      inspectedBaseQuantity,
      acceptedBaseQuantity,
      rejectedBaseQuantity,
      quarantinedBaseQuantity;
  final double quarantinedQuantity;
  final QualityInspectionResult result;
  final String? notes;

  Map<String, Object?> toMap(String inspectionId) {
    final factor = unitConversionFactor ?? 1;
    return {
      'id': id,
      'inspectionId': inspectionId,
      'itemId': itemId,
      'sourceReturnItemId': sourceReturnItemId,
      'purchaseReturnReceiptItemId': purchaseReturnReceiptItemId,
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
      'quarantinedQuantity': quarantinedQuantity,
      'quarantinedBaseQuantity':
          quarantinedBaseQuantity ?? quarantinedQuantity * factor,
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
    purchaseReturnReceiptItemId: row['purchaseReturnReceiptItemId'] as String?,
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
    quarantinedQuantity: (row['quarantinedQuantity'] as num?)?.toDouble() ?? 0,
    quarantinedBaseQuantity: (row['quarantinedBaseQuantity'] as num?)
        ?.toDouble(),
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
    this.purchaseReturnReceiptId,
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
  final String? purchaseReturnReceiptId;
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
    'purchaseReturnReceiptId': purchaseReturnReceiptId,
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
    purchaseReturnReceiptId: row['purchaseReturnReceiptId'] as String?,
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
