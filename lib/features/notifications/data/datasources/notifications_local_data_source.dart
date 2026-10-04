import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/notifications/data/models/notification_model.dart';
import 'package:furnexa/features/notifications/domain/entities/notification_entity.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class NotificationsLocalDataSource {
  NotificationsLocalDataSource({SecurityLocalDataSource? security})
    : security = security ?? SecurityLocalDataSource();

  final SecurityLocalDataSource security;
  static int _sequence = 0;
  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<List<NotificationEntity>> getNotifications({
    bool unreadOnly = false,
    bool alertsOnly = false,
  }) async {
    final userId = _requireUser();
    final where = <String>['userId = ?', 'isArchived = 0'];
    final args = <Object?>[userId];
    if (unreadOnly) {
      where.add('isRead = 0');
    }
    if (alertsOnly) {
      where.add("severity IN ('WARNING', 'CRITICAL')");
    }
    final rows = await (await _db).query(
      'notifications',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'isRead ASC, createdAt DESC',
    );
    return rows.map(NotificationModel.fromMap).toList();
  }

  Future<int> unreadCount() async {
    final rows = await (await _db).rawQuery(
      'SELECT COUNT(*) value FROM notifications WHERE userId = ? AND isRead = 0 AND isArchived = 0',
      [_requireUser()],
    );
    return (rows.first['value'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    await _updateOwned(id, {
      'isRead': 1,
      'readAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> markUnread(String id) async {
    await _updateOwned(id, {'isRead': 0, 'readAt': null});
  }

  Future<void> markAllRead() async {
    await (await _db).update(
      'notifications',
      {'isRead': 1, 'readAt': DateTime.now().millisecondsSinceEpoch},
      where: 'userId = ? AND isArchived = 0 AND isRead = 0',
      whereArgs: [_requireUser()],
    );
  }

  Future<void> archive(String id) async {
    await _updateOwned(id, {
      'isArchived': 1,
      'archivedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setMinimumStock({
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double minimumQuantity,
  }) async {
    security.require('WAREHOUSE_STOCK_EDIT');
    if (minimumQuantity < 0)
      throw Exception('الحد الأدنى لا يمكن أن يكون سالباً');
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('stock_minimum_levels', {
      'id': 'minimum-${warehouseId}-${itemType}-${itemId}',
      'warehouseId': warehouseId,
      'itemId': itemId,
      'itemType': itemType,
      'minimumQuantity': minimumQuantity,
      'createdAt': now,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<double?> minimumStock({
    required String warehouseId,
    required String itemId,
    required String itemType,
  }) async {
    final rows = await (await _db).query(
      'stock_minimum_levels',
      columns: ['minimumQuantity'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : (rows.first['minimumQuantity'] as num).toDouble();
  }

  Future<void> createNotification({
    required NotificationType type,
    required NotificationCategory category,
    required NotificationSeverity severity,
    required String title,
    required String message,
    required String deduplicationKey,
    String? relatedEntityType,
    String? relatedEntityId,
    String? actionKey,
    String? permission,
    ScopeType? scopeType,
    String? scopeId,
  }) async {
    final users = await _eligibleUsers(
      permission ?? _permissionFor(category, type),
      scopeType: scopeType,
      scopeId: scopeId,
    );
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final userId in users) {
      await db.insert('notifications', {
        'id': 'notification-${now}-${_sequence++}',
        'userId': userId,
        'type': type.value,
        'category': category.value,
        'severity': severity.value,
        'title': title,
        'message': message,
        'isRead': 0,
        'isArchived': 0,
        'createdAt': now,
        'relatedEntityType': relatedEntityType,
        'relatedEntityId': relatedEntityId,
        'actionKey': actionKey,
        'deduplicationKey': deduplicationKey,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> evaluateStock({
    required String warehouseId,
    required String itemId,
    required String itemType,
    bool adjustment = false,
  }) async {
    final db = await _db;
    final balanceRows = await db.query(
      'stock_balances',
      columns: ['quantity'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType],
      limit: 1,
    );
    final quantity = balanceRows.isEmpty
        ? 0
        : (balanceRows.first['quantity'] as num).toDouble();
    final latest = await db.query(
      'stock_transactions',
      columns: ['id'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType],
      orderBy: 'createdAt DESC, id DESC',
      limit: 1,
    );
    final eventId = latest.isEmpty ? 'initial' : latest.first['id'] as String;
    final itemName = await _itemName(db, itemId, itemType);
    if (adjustment) {
      await createNotification(
        type: NotificationType.stockAdjustment,
        category: NotificationCategory.inventory,
        severity: NotificationSeverity.info,
        title: 'تسوية مخزون',
        message: 'تم تسجيل تسوية للصنف $itemName في المخزن $warehouseId',
        deduplicationKey: 'STOCK_ADJUSTMENT:$warehouseId:$itemId:$eventId',
        relatedEntityType: 'Stock',
        relatedEntityId: '$warehouseId:$itemId:$itemType',
        actionKey: 'warehouse_stock',
        scopeType: ScopeType.warehouse,
        scopeId: warehouseId,
      );
    }
    final minimum = await minimumStock(
      warehouseId: warehouseId,
      itemId: itemId,
      itemType: itemType,
    );
    if (quantity <= 0) {
      await createNotification(
        type: NotificationType.outOfStock,
        category: NotificationCategory.inventory,
        severity: NotificationSeverity.critical,
        title: 'نفاد المخزون',
        message: 'نفد الصنف $itemName من المخزن $warehouseId',
        deduplicationKey: 'OUT_OF_STOCK:$warehouseId:$itemId:$eventId',
        relatedEntityType: 'Stock',
        relatedEntityId: '$warehouseId:$itemId:$itemType',
        actionKey: 'warehouse_stock',
        scopeType: ScopeType.warehouse,
        scopeId: warehouseId,
      );
    } else if (minimum != null && minimum > 0 && quantity <= minimum) {
      await createNotification(
        type: NotificationType.lowStock,
        category: NotificationCategory.inventory,
        severity: NotificationSeverity.warning,
        title: 'مخزون منخفض',
        message: 'انخفض الصنف $itemName إلى $quantity في المخزن $warehouseId',
        deduplicationKey: 'LOW_STOCK:$warehouseId:$itemId:$eventId',
        relatedEntityType: 'Stock',
        relatedEntityId: '$warehouseId:$itemId:$itemType',
        actionKey: 'warehouse_stock',
        scopeType: ScopeType.warehouse,
        scopeId: warehouseId,
      );
    }
  }

  Future<void> refresh() async {
    final db = await _db;
    final minimums = await db.query('stock_minimum_levels');
    for (final row in minimums) {
      await evaluateStock(
        warehouseId: row['warehouseId'] as String,
        itemId: row['itemId'] as String,
        itemType: row['itemType'] as String,
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final delayedPurchases = await db.query(
      'purchase_orders',
      where:
          'expectedDeliveryDate IS NOT NULL AND expectedDeliveryDate < ? AND status NOT IN (?, ?)',
      whereArgs: [now, 'FULLY_RECEIVED', 'CANCELLED'],
    );
    for (final row in delayedPurchases) {
      await createNotification(
        type: NotificationType.purchaseOrderDelayed,
        category: NotificationCategory.purchasing,
        severity: NotificationSeverity.warning,
        title: 'أمر شراء متأخر',
        message: 'تجاوز أمر الشراء ${row['orderNumber']} موعد التوريد',
        deduplicationKey:
            'PURCHASE_ORDER_DELAYED:${row['id']}:${row['expectedDeliveryDate']}',
        relatedEntityType: 'PurchaseOrder',
        relatedEntityId: row['id'] as String,
        actionKey: 'purchasing',
      );
    }
    await _evaluatePending(
      table: 'purchase_requests',
      where: "status = 'PENDING'",
      type: NotificationType.purchaseRequestPendingApproval,
      category: NotificationCategory.purchasing,
      permission: 'PURCHASING_VIEW',
      entityType: 'PurchaseRequest',
      numberColumn: 'requestNumber',
      actionKey: 'purchasing',
    );
    await _evaluatePending(
      table: 'purchase_orders',
      where: "status IN ('CONFIRMED', 'PARTIALLY_RECEIVED')",
      type: NotificationType.purchaseReceiptPending,
      category: NotificationCategory.purchasing,
      permission: 'PURCHASING_VIEW',
      entityType: 'PurchaseOrder',
      numberColumn: 'orderNumber',
      actionKey: 'purchasing',
    );
    await _evaluateDelayed(
      table: 'sales_orders',
      dateColumn: 'expectedDeliveryDate',
      where: "status IN ('CONFIRMED', 'PARTIALLY_DELIVERED')",
      type: NotificationType.salesDeliveryDelayed,
      category: NotificationCategory.sales,
      permission: 'SALES_VIEW',
      entityType: 'SalesOrder',
      numberColumn: 'orderNumber',
      actionKey: 'sales',
    );
    await _evaluateDelayed(
      table: 'production_orders',
      dateColumn: 'startDate',
      where: "status IN ('PLANNED', 'IN_PROGRESS')",
      type: NotificationType.productionOrderDelayed,
      category: NotificationCategory.production,
      permission: 'PRODUCTION_VIEW',
      entityType: 'ProductionOrder',
      numberColumn: 'orderNumber',
      actionKey: 'production',
    );
    await _evaluatePending(
      table: 'sales_orders',
      where: "status IN ('CONFIRMED', 'PARTIALLY_DELIVERED')",
      type: NotificationType.salesOrderPendingDelivery,
      category: NotificationCategory.sales,
      permission: 'SALES_VIEW',
      entityType: 'SalesOrder',
      numberColumn: 'orderNumber',
      actionKey: 'sales',
    );
    await _evaluatePending(
      table: 'leave_records',
      where: "status = 'PENDING'",
      type: NotificationType.leavePendingApproval,
      category: NotificationCategory.hr,
      permission: 'HR_EDIT',
      entityType: 'Leave',
      numberColumn: 'id',
      actionKey: 'hr',
    );
    await _evaluatePending(
      table: 'payroll_periods',
      where: "status IN ('DRAFT', 'CALCULATED')",
      type: NotificationType.payrollPendingApproval,
      category: NotificationCategory.hr,
      permission: 'HR_PAYROLL_APPROVE',
      entityType: 'PayrollPeriod',
      numberColumn: 'name',
      actionKey: 'hr',
    );
    final today = DateTime.now();
    final attendance = await db.rawQuery(
      '''
      SELECT ar.id, ar.workerId, ar.status, ar.lateMinutes
      FROM attendance_records ar WHERE ar.workDate >= ? AND ar.workDate < ?
        AND (ar.status = 'ABSENT' OR ar.lateMinutes > 0)
    ''',
      [
        DateTime(today.year, today.month, today.day).millisecondsSinceEpoch,
        DateTime(today.year, today.month, today.day + 1).millisecondsSinceEpoch,
      ],
    );
    for (final row in attendance) {
      final absent = row['status'] == 'ABSENT';
      await createNotification(
        type: absent
            ? NotificationType.attendanceAbsence
            : NotificationType.attendanceLate,
        category: NotificationCategory.hr,
        severity: NotificationSeverity.warning,
        title: absent ? 'غياب عامل' : 'تأخر عامل',
        message: absent ? 'يوجد عامل غائب اليوم' : 'تم تسجيل تأخر في الحضور',
        deduplicationKey:
            '${absent ? 'ATTENDANCE_ABSENCE' : 'ATTENDANCE_LATE'}:${row['id']}',
        relatedEntityType: 'Attendance',
        relatedEntityId: row['id'] as String,
        actionKey: 'hr',
        permission: 'HR_VIEW',
      );
    }
  }

  Future<void> _evaluateDelayed({
    required String table,
    required String dateColumn,
    required String where,
    required NotificationType type,
    required NotificationCategory category,
    required String permission,
    required String entityType,
    required String numberColumn,
    required String actionKey,
  }) async {
    final rows = await (await _db).query(
      table,
      where: '$dateColumn IS NOT NULL AND $dateColumn < ? AND $where',
      whereArgs: [DateTime.now().millisecondsSinceEpoch],
    );
    for (final row in rows) {
      final id = row['id'] as String;
      await createNotification(
        type: type,
        category: category,
        severity: NotificationSeverity.warning,
        title: 'عملية متأخرة',
        message: '$numberColumn: ${row[numberColumn]}',
        deduplicationKey: '${type.value}:$id:${row[dateColumn]}',
        relatedEntityType: entityType,
        relatedEntityId: id,
        actionKey: actionKey,
        permission: permission,
      );
    }
  }

  Future<void> _evaluatePending({
    required String table,
    required String where,
    required NotificationType type,
    required NotificationCategory category,
    required String permission,
    required String entityType,
    required String numberColumn,
    required String actionKey,
  }) async {
    final rows = await (await _db).query(table, where: where);
    for (final row in rows) {
      final id = row['id'] as String;
      await createNotification(
        type: type,
        category: category,
        severity: NotificationSeverity.warning,
        title: 'يتطلب إجراء',
        message: '$numberColumn: ${row[numberColumn]}',
        deduplicationKey: '${type.value}:$id',
        relatedEntityType: entityType,
        relatedEntityId: id,
        actionKey: actionKey,
        permission: permission,
      );
    }
  }

  Future<List<String>> _eligibleUsers(
    String permission, {
    ScopeType? scopeType,
    String? scopeId,
  }) async {
    final rows = await (await _db).rawQuery(
      '''
      SELECT DISTINCT u.id, r.isSystemRole
      FROM users u JOIN roles r ON r.id = u.roleId
      LEFT JOIN role_permissions rp ON rp.roleId = r.id
      LEFT JOIN permissions p ON p.id = rp.permissionId AND p.code = ?
      WHERE u.active = 1 AND r.active = 1 AND (r.isSystemRole = 1 OR p.code IS NOT NULL)
    ''',
      [permission],
    );
    if (scopeType == null || scopeId == null)
      return rows.map((row) => row['id'] as String).toList();
    final result = <String>[];
    for (final row in rows) {
      if (row['isSystemRole'] == 1) {
        result.add(row['id'] as String);
        continue;
      }
      final scopes = await (await _db).query(
        'user_scopes',
        where: 'userId = ? AND scopeType = ? AND scopeId = ?',
        whereArgs: [row['id'], _scopeValue(scopeType), scopeId],
        limit: 1,
      );
      if (scopes.isNotEmpty) result.add(row['id'] as String);
    }
    return result;
  }

  String _permissionFor(NotificationCategory category, NotificationType type) {
    if (type == NotificationType.payrollPendingApproval)
      return 'HR_PAYROLL_APPROVE';
    return switch (category) {
      NotificationCategory.inventory => 'WAREHOUSE_STOCK_VIEW',
      NotificationCategory.purchasing => 'PURCHASING_VIEW',
      NotificationCategory.sales => 'SALES_VIEW',
      NotificationCategory.production => 'PRODUCTION_VIEW',
      NotificationCategory.hr => 'HR_VIEW',
      NotificationCategory.accounting => 'ACCOUNTING_VIEW',
    };
  }

  String _scopeValue(ScopeType value) => value == ScopeType.productionStage
      ? 'PRODUCTION_STAGE'
      : value.name.toUpperCase();

  Future<String> _itemName(Database db, String itemId, String itemType) async {
    final table = itemType == 'RAW_MATERIAL' ? 'raw_materials' : 'products';
    final rows = await db.query(
      table,
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    return rows.isEmpty ? itemId : rows.first['name'] as String;
  }

  String _requireUser() {
    final id = security.session?.user.id;
    if (id == null) throw Exception('يجب تسجيل الدخول');
    return id;
  }

  Future<void> _updateOwned(String id, Map<String, Object?> values) async {
    await (await _db).update(
      'notifications',
      values,
      where: 'id = ? AND userId = ?',
      whereArgs: [id, _requireUser()],
    );
  }
}
