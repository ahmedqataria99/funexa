enum ProductionOrderStatus { draft, planned, inProgress, completed, cancelled }

enum ProductionUnitSnapshotStatus { verified, unverified }

extension ProductionUnitSnapshotStatusValue on ProductionUnitSnapshotStatus {
  String get value => switch (this) {
    ProductionUnitSnapshotStatus.verified => 'VERIFIED',
    ProductionUnitSnapshotStatus.unverified => 'UNVERIFIED',
  };

  static ProductionUnitSnapshotStatus fromValue(Object? value) =>
      value == 'VERIFIED'
      ? ProductionUnitSnapshotStatus.verified
      : ProductionUnitSnapshotStatus.unverified;
}

class ProductionUnitSnapshotException implements Exception {
  const ProductionUnitSnapshotException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum ProductionStageStatus { pending, inProgress, completed, skipped }

enum ProductionRequirementStatus { notStarted, partial, complete }

class ProductionRouteStage {
  const ProductionRouteStage({
    required this.id,
    required this.productionStageId,
    required this.sequence,
    required this.stageName,
    this.notes,
  });
  final String id;
  final String productionStageId;
  final int sequence;
  final String stageName;
  final String? notes;
}

class ProductionRoute {
  const ProductionRoute({
    required this.id,
    required this.productId,
    required this.createdAt,
    required this.updatedAt,
    this.stages = const [],
  });
  final String id;
  final String productId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductionRouteStage> stages;
}

class ProductionOrderStage {
  const ProductionOrderStage({
    required this.id,
    required this.productionOrderId,
    required this.productionStageId,
    required this.sequence,
    required this.status,
    required this.stageName,
    this.startedAt,
    this.completedAt,
    this.notes,
  });
  final String id;
  final String productionOrderId;
  final String productionStageId;
  final int sequence;
  final ProductionStageStatus status;
  final String stageName;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
}

class ProductionOrder {
  const ProductionOrder({
    required this.id,
    required this.orderNumber,
    required this.productId,
    this.productName,
    this.variantId,
    this.routeId,
    required this.plannedQuantity,
    required this.producedQuantity,
    required this.status,
    this.unitId,
    this.baseUnitId,
    this.unitConversionFactor,
    this.plannedBaseQuantity,
    this.unitSnapshotStatus = ProductionUnitSnapshotStatus.unverified,
    this.startDate,
    this.completionDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.stages = const [],
  });
  final String id;
  final String orderNumber;
  final String productId;
  final String? productName;
  final String? variantId;
  final String? routeId;
  final double plannedQuantity;
  final double producedQuantity;
  final ProductionOrderStatus status;
  final String? unitId;
  final String? baseUnitId;
  final double? unitConversionFactor;
  final double? plannedBaseQuantity;
  final ProductionUnitSnapshotStatus unitSnapshotStatus;
  bool get hasVerifiedUnitSnapshot =>
      unitSnapshotStatus == ProductionUnitSnapshotStatus.verified;
  double? get remainingBaseQuantity =>
      hasVerifiedUnitSnapshot ? plannedBaseQuantity! - producedQuantity : null;
  final DateTime? startDate;
  final DateTime? completionDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductionOrderStage> stages;
  double? get remainingQuantity => remainingBaseQuantity;
}

class ProductionMaterialRequirement {
  const ProductionMaterialRequirement({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialCode,
    required this.unitId,
    required this.unitName,
    required this.requiredQuantity,
    required this.consumedQuantity,
  });
  final String rawMaterialId;
  final String rawMaterialName;
  final String rawMaterialCode;
  final String unitId;
  final String unitName;
  final double requiredQuantity;
  final double consumedQuantity;
  double get remainingQuantity => (requiredQuantity - consumedQuantity)
      .clamp(0, double.infinity)
      .toDouble();
  ProductionRequirementStatus get status => consumedQuantity <= 0
      ? ProductionRequirementStatus.notStarted
      : remainingQuantity <= 0
      ? ProductionRequirementStatus.complete
      : ProductionRequirementStatus.partial;
}

class ProductionMaterialRecord {
  const ProductionMaterialRecord({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialCode,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
    required this.unitId,
    required this.unitName,
    required this.date,
    required this.unitCost,
    this.operationId,
    this.notes,
  });
  final String id;
  final String rawMaterialId;
  final String rawMaterialName;
  final String rawMaterialCode;
  final String warehouseId;
  final String warehouseName;
  final double quantity;
  final String unitId;
  final String unitName;
  final DateTime date;
  final double unitCost;
  final String? operationId;
  final String? notes;
}

class ProductionWasteRecord {
  const ProductionWasteRecord({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.warehouseId,
    required this.quantity,
    required this.unitId,
    required this.reason,
    required this.date,
    this.notes,
  });
  final String id;
  final String rawMaterialId;
  final String rawMaterialName;
  final String warehouseId;
  final double quantity;
  final String unitId;
  final String reason;
  final DateTime date;
  final String? notes;
}

class ProductionOutputRecord {
  const ProductionOutputRecord({
    required this.id,
    required this.productionOrderId,
    required this.productId,
    required this.productName,
    required this.productCode,
    this.variantId,
    this.variantName,
    required this.warehouseId,
    required this.warehouseName,
    required this.quantity,
    required this.unitId,
    required this.unitName,
    required this.date,
    this.operationId,
    this.costingStatus,
    this.notes,
  });
  final String id;
  final String productionOrderId;
  final String productId;
  final String productName;
  final String productCode;
  final String? variantId;
  final String? variantName;
  final String warehouseId;
  final String warehouseName;
  final double quantity;
  final String unitId;
  final String unitName;
  final DateTime date;
  final String? operationId;
  final String? costingStatus;
  final String? notes;
}
