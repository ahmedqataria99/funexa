enum ProductionOrderStatus { draft, planned, inProgress, completed, cancelled }

enum ProductionStageStatus { pending, inProgress, completed, skipped }

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
  final DateTime? startDate;
  final DateTime? completionDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductionOrderStage> stages;
  double get remainingQuantity => plannedQuantity - producedQuantity;
}

class ProductionMaterialRequirement {
  const ProductionMaterialRequirement({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.unitId,
    required this.requiredQuantity,
    required this.consumedQuantity,
  });
  final String rawMaterialId;
  final String rawMaterialName;
  final String unitId;
  final double requiredQuantity;
  final double consumedQuantity;
  double get remainingQuantity => requiredQuantity - consumedQuantity;
}

class ProductionMaterialRecord {
  const ProductionMaterialRecord({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.warehouseId,
    required this.quantity,
    required this.unitId,
    required this.date,
    this.notes,
  });
  final String id;
  final String rawMaterialId;
  final String rawMaterialName;
  final String warehouseId;
  final double quantity;
  final String unitId;
  final DateTime date;
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
    required this.warehouseId,
    required this.quantity,
    required this.unitId,
    required this.date,
    this.notes,
  });
  final String id;
  final String warehouseId;
  final double quantity;
  final String unitId;
  final DateTime date;
  final String? notes;
}
