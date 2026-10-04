enum NotificationSeverity { info, success, warning, critical }

enum NotificationCategory {
  inventory,
  purchasing,
  sales,
  production,
  hr,
  accounting,
}

enum NotificationType {
  lowStock,
  outOfStock,
  stockAdjustment,
  purchaseRequestPendingApproval,
  purchaseOrderDelayed,
  purchaseReceiptPending,
  salesOrderPendingDelivery,
  salesDeliveryDelayed,
  productionOrderDelayed,
  productionStageDelayed,
  productionMaterialShortage,
  attendanceAbsence,
  attendanceLate,
  leavePendingApproval,
  payrollPendingApproval,
  customerOutstanding,
  supplierOutstanding,
  accountingPeriodClosing,
  accountingOperationFailed,
}

class NotificationEntity {
  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.category,
    required this.severity,
    required this.title,
    required this.message,
    required this.isRead,
    required this.isArchived,
    required this.createdAt,
    required this.readAt,
    required this.archivedAt,
    required this.relatedEntityType,
    required this.relatedEntityId,
    required this.actionKey,
    required this.deduplicationKey,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final NotificationCategory category;
  final NotificationSeverity severity;
  final String title;
  final String message;
  final bool isRead;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? actionKey;
  final String deduplicationKey;
}

extension NotificationTypeValues on NotificationType {
  String get value => switch (this) {
    NotificationType.lowStock => 'LOW_STOCK',
    NotificationType.outOfStock => 'OUT_OF_STOCK',
    NotificationType.stockAdjustment => 'STOCK_ADJUSTMENT',
    NotificationType.purchaseRequestPendingApproval =>
      'PURCHASE_REQUEST_PENDING_APPROVAL',
    NotificationType.purchaseOrderDelayed => 'PURCHASE_ORDER_DELAYED',
    NotificationType.purchaseReceiptPending => 'PURCHASE_RECEIPT_PENDING',
    NotificationType.salesOrderPendingDelivery =>
      'SALES_ORDER_PENDING_DELIVERY',
    NotificationType.salesDeliveryDelayed => 'SALES_DELIVERY_DELAYED',
    NotificationType.productionOrderDelayed => 'PRODUCTION_ORDER_DELAYED',
    NotificationType.productionStageDelayed => 'PRODUCTION_STAGE_DELAYED',
    NotificationType.productionMaterialShortage =>
      'PRODUCTION_MATERIAL_SHORTAGE',
    NotificationType.attendanceAbsence => 'ATTENDANCE_ABSENCE',
    NotificationType.attendanceLate => 'ATTENDANCE_LATE',
    NotificationType.leavePendingApproval => 'LEAVE_PENDING_APPROVAL',
    NotificationType.payrollPendingApproval => 'PAYROLL_PENDING_APPROVAL',
    NotificationType.customerOutstanding => 'CUSTOMER_OUTSTANDING',
    NotificationType.supplierOutstanding => 'SUPPLIER_OUTSTANDING',
    NotificationType.accountingPeriodClosing => 'ACCOUNTING_PERIOD_CLOSING',
    NotificationType.accountingOperationFailed => 'ACCOUNTING_OPERATION_FAILED',
  };
}

extension NotificationCategoryValues on NotificationCategory {
  String get value => name.toUpperCase();
}

extension NotificationSeverityValues on NotificationSeverity {
  String get value => name.toUpperCase();
}
