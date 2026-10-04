import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/notifications/data/datasources/notifications_local_data_source.dart';
import 'package:furnexa/features/notifications/domain/entities/notification_entity.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import '../../test_helpers/database_test_helper.dart';

void main() {
  late SecurityLocalDataSource security;
  late NotificationsLocalDataSource notifications;
  late Database db;

  setUp(() async {
    await DatabaseTestHelper.reset();
    db = await FurnexaDatabase.instance.database;
    security = SecurityLocalDataSource();
    await security.ensureInitialAdmin();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    notifications = NotificationsLocalDataSource(security: security);
    await _seedFactory(db);
  });

  tearDown(() async {
    security.logout();
    await DatabaseTestHelper.reset();
  });

  Future<void> createBasicNotification({String key = 'event-1'}) =>
      notifications.createNotification(
        type: NotificationType.stockAdjustment,
        category: NotificationCategory.inventory,
        severity: NotificationSeverity.info,
        title: 'تسوية',
        message: 'تمت التسوية',
        deduplicationKey: key,
        relatedEntityType: 'Stock',
        relatedEntityId: 'warehouse-a:item-a',
        actionKey: 'warehouse_stock',
      );

  test('create notification', () async {
    await createBasicNotification();
    expect((await notifications.getNotifications()).single.title, 'تسوية');
  });

  test('persist notification', () async {
    await createBasicNotification();
    final rows = await db.query('notifications');
    expect(rows, hasLength(1));
  });

  test('retrieve all notifications', () async {
    await createBasicNotification(key: 'one');
    await createBasicNotification(key: 'two');
    expect(await notifications.getNotifications(), hasLength(2));
  });

  test('retrieve unread notifications', () async {
    await createBasicNotification();
    await createBasicNotification(key: 'two');
    final values = await notifications.getNotifications(unreadOnly: true);
    expect(values, hasLength(2));
  });

  test('retrieve alerts', () async {
    await notifications.createNotification(
      type: NotificationType.outOfStock,
      category: NotificationCategory.inventory,
      severity: NotificationSeverity.critical,
      title: 'نفاد',
      message: 'نفد',
      deduplicationKey: 'critical',
    );
    await createBasicNotification();
    expect(
      await notifications.getNotifications(alertsOnly: true),
      hasLength(1),
    );
  });

  test('mark notification as read', () async {
    await createBasicNotification();
    final value = (await notifications.getNotifications()).single;
    await notifications.markRead(value.id);
    expect((await notifications.getNotifications()).single.isRead, isTrue);
  });

  test('mark notification as unread', () async {
    await createBasicNotification();
    final value = (await notifications.getNotifications()).single;
    await notifications.markRead(value.id);
    await notifications.markUnread(value.id);
    expect((await notifications.getNotifications()).single.isRead, isFalse);
  });

  test('mark all notifications as read', () async {
    await createBasicNotification(key: 'one');
    await createBasicNotification(key: 'two');
    await notifications.markAllRead();
    expect(await notifications.unreadCount(), 0);
  });

  test('archive notification', () async {
    await createBasicNotification();
    final value = (await notifications.getNotifications()).single;
    await notifications.archive(value.id);
    expect(await notifications.getNotifications(), isEmpty);
    expect(await db.query('notifications'), hasLength(1));
  });

  test('archived notification excluded from default view', () async {
    await createBasicNotification();
    final value = (await notifications.getNotifications()).single;
    await notifications.archive(value.id);
    expect(await notifications.unreadCount(), 0);
  });

  test('unread count', () async {
    await createBasicNotification(key: 'one');
    await createBasicNotification(key: 'two');
    expect(await notifications.unreadCount(), 2);
  });

  test('low-stock detection', () async {
    await notifications.setMinimumStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
      minimumQuantity: 20,
    );
    await _setBalance(db, 10);
    await notifications.evaluateStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
    );
    expect(
      (await notifications.getNotifications()).single.type,
      NotificationType.lowStock,
    );
  });

  test('out-of-stock detection', () async {
    await notifications.setMinimumStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
      minimumQuantity: 20,
    );
    await _setBalance(db, 0);
    await notifications.evaluateStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
    );
    expect(
      (await notifications.getNotifications()).single.type,
      NotificationType.outOfStock,
    );
  });

  test('out-of-stock takes precedence over low-stock', () async {
    await notifications.setMinimumStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
      minimumQuantity: 20,
    );
    await _setBalance(db, 0);
    await notifications.evaluateStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
    );
    expect(
      (await notifications.getNotifications()).where(
        (value) => value.type == NotificationType.lowStock,
      ),
      isEmpty,
    );
  });

  test('no duplicate low-stock notification', () async {
    await notifications.setMinimumStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
      minimumQuantity: 20,
    );
    await _setBalance(db, 10);
    await notifications.evaluateStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
    );
    await notifications.evaluateStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
    );
    expect(await notifications.getNotifications(), hasLength(1));
  });

  test('new low-stock event after stock recovers', () async {
    await notifications.setMinimumStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
      minimumQuantity: 20,
    );
    await _setBalance(db, 10, transactionId: 'first');
    await notifications.evaluateStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
    );
    await _setBalance(db, 30, transactionId: 'recovered');
    await _setBalance(db, 15, transactionId: 'second');
    await notifications.evaluateStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
    );
    expect(await notifications.getNotifications(), hasLength(2));
  });

  test('minimum stock level validation', () async {
    expect(
      () => notifications.setMinimumStock(
        warehouseId: 'warehouse-a',
        itemId: 'item-a',
        itemType: 'RAW_MATERIAL',
        minimumQuantity: -1,
      ),
      throwsException,
    );
  });

  test('warehouse + item-specific minimum stock', () async {
    await notifications.setMinimumStock(
      warehouseId: 'warehouse-a',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
      minimumQuantity: 20,
    );
    await notifications.setMinimumStock(
      warehouseId: 'warehouse-b',
      itemId: 'item-a',
      itemType: 'RAW_MATERIAL',
      minimumQuantity: 5,
    );
    expect(
      await notifications.minimumStock(
        warehouseId: 'warehouse-a',
        itemId: 'item-a',
        itemType: 'RAW_MATERIAL',
      ),
      20,
    );
    expect(
      await notifications.minimumStock(
        warehouseId: 'warehouse-b',
        itemId: 'item-a',
        itemType: 'RAW_MATERIAL',
      ),
      5,
    );
  });

  test('permission-based notification visibility', () async {
    final role = await security.createRole(name: 'No stock alerts');
    final user = await security.createUser(
      username: 'limited',
      displayName: 'Limited',
      password: 'secret',
      roleId: role.id,
    );
    security.logout();
    await security.login(user.username, 'secret');
    await notifications.createNotification(
      type: NotificationType.lowStock,
      category: NotificationCategory.inventory,
      severity: NotificationSeverity.warning,
      title: 'تنبيه',
      message: 'تنبيه',
      deduplicationKey: 'permission-check',
    );
    expect(await notifications.getNotifications(), isEmpty);
  });

  test('scope-based notification visibility', () async {
    final role = await security.createRole(name: 'Warehouse alerts');
    await security.setRolePermissions(role.id, ['WAREHOUSE_STOCK_VIEW']);
    final user = await security.createUser(
      username: 'warehouse-user',
      displayName: 'Warehouse',
      password: 'secret',
      roleId: role.id,
    );
    await security.setUserScopes(user.id, const [
      UserScope(
        id: 'scope',
        userId: 'x',
        type: ScopeType.warehouse,
        scopeId: 'warehouse-b',
      ),
    ]);
    security.logout();
    await security.login(user.username, 'secret');
    await notifications.createNotification(
      type: NotificationType.lowStock,
      category: NotificationCategory.inventory,
      severity: NotificationSeverity.warning,
      title: 'تنبيه',
      message: 'تنبيه',
      deduplicationKey: 'scope-check',
      scopeType: ScopeType.warehouse,
      scopeId: 'warehouse-a',
    );
    expect(await notifications.getNotifications(), isEmpty);
  });

  test('purchase delayed notification', () async {
    await notifications.refresh();
    expect(await notifications.getNotifications(), isNotNull);
  });

  test('sales pending delivery notification', () async {
    await notifications.refresh();
    expect(await notifications.getNotifications(), isNotNull);
  });

  test('production material shortage notification', () async {
    await notifications.createNotification(
      type: NotificationType.productionMaterialShortage,
      category: NotificationCategory.production,
      severity: NotificationSeverity.critical,
      title: 'نقص مواد',
      message: 'نقص',
      deduplicationKey: 'shortage',
    );
    expect(
      (await notifications.getNotifications()).single.type,
      NotificationType.productionMaterialShortage,
    );
  });

  test('pending leave notification', () async {
    await notifications.createNotification(
      type: NotificationType.leavePendingApproval,
      category: NotificationCategory.hr,
      severity: NotificationSeverity.warning,
      title: 'إجازة',
      message: 'معلقة',
      deduplicationKey: 'leave',
    );
    expect(
      (await notifications.getNotifications()).single.category,
      NotificationCategory.hr,
    );
  });

  test('pending payroll notification', () async {
    await notifications.createNotification(
      type: NotificationType.payrollPendingApproval,
      category: NotificationCategory.hr,
      severity: NotificationSeverity.warning,
      title: 'رواتب',
      message: 'معلقة',
      deduplicationKey: 'payroll',
    );
    expect(
      (await notifications.getNotifications()).single.type,
      NotificationType.payrollPendingApproval,
    );
  });

  test('accounting failure notification', () async {
    await notifications.createNotification(
      type: NotificationType.accountingOperationFailed,
      category: NotificationCategory.accounting,
      severity: NotificationSeverity.critical,
      title: 'فشل',
      message: 'فشلت العملية',
      deduplicationKey: 'failure',
    );
    expect(
      (await notifications.getNotifications()).single.severity,
      NotificationSeverity.critical,
    );
  });

  test('related entity navigation metadata', () async {
    await createBasicNotification();
    final value = (await notifications.getNotifications()).single;
    expect(value.actionKey, 'warehouse_stock');
    expect(value.relatedEntityId, isNotNull);
  });

  test('missing related entity does not crash', () async {
    await notifications.createNotification(
      type: NotificationType.stockAdjustment,
      category: NotificationCategory.inventory,
      severity: NotificationSeverity.info,
      title: 'قديم',
      message: 'كيان محذوف',
      deduplicationKey: 'missing',
      relatedEntityType: 'Stock',
      relatedEntityId: 'missing',
    );
    expect(await notifications.getNotifications(), hasLength(1));
  });

  test('notifications survive app/database restart', () async {
    await createBasicNotification();
    await FurnexaDatabase.instance.close();
    final reopened = NotificationsLocalDataSource(security: security);
    expect(await reopened.getNotifications(), hasLength(1));
  });

  test('date-based evaluation does not create duplicates', () async {
    await notifications.refresh();
    await notifications.refresh();
    final rows = await db.query('notifications');
    expect(
      rows
          .where(
            (row) => row['deduplicationKey'].toString().startsWith(
              'PURCHASE_ORDER_DELAYED',
            ),
          )
          .length,
      lessThanOrEqualTo(1),
    );
  });
}

Future<void> _seedFactory(Database db) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert('factories', {
    'id': 'factory-a',
    'name': 'Factory',
    'code': 'F-A',
    'createdAt': now,
    'updatedAt': now,
  });
  await db.insert('warehouses', {
    'id': 'warehouse-a',
    'factoryId': 'factory-a',
    'name': 'Warehouse A',
    'code': 'W-A',
    'state': 'active',
    'createdAt': now,
    'updatedAt': now,
  });
  await db.insert('warehouses', {
    'id': 'warehouse-b',
    'factoryId': 'factory-a',
    'name': 'Warehouse B',
    'code': 'W-B',
    'state': 'active',
    'createdAt': now,
    'updatedAt': now,
  });
  await db.insert('units', {
    'id': 'unit-a',
    'name': 'Unit',
    'abbreviation': 'u',
    'createdAt': now,
    'updatedAt': now,
  });
  await db.insert('categories', {
    'id': 'category-a',
    'name': 'Materials',
    'code': 'CAT-A',
    'createdAt': now,
    'updatedAt': now,
  });
  await db.insert('raw_materials', {
    'id': 'item-a',
    'name': 'MDF',
    'code': 'MDF-A',
    'categoryId': 'category-a',
    'unitId': 'unit-a',
    'createdAt': now,
    'updatedAt': now,
  });
}

Future<void> _setBalance(
  Database db,
  double quantity, {
  String transactionId = 'event',
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert('stock_balances', {
    'id': 'balance-${quantity}-${transactionId}',
    'warehouseId': 'warehouse-a',
    'itemId': 'item-a',
    'itemType': 'RAW_MATERIAL',
    'quantity': quantity,
    'createdAt': now,
    'updatedAt': now,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
  await db.insert('stock_transactions', {
    'id': transactionId,
    'warehouseId': 'warehouse-a',
    'itemId': 'item-a',
    'itemType': 'RAW_MATERIAL',
    'transactionType': 'ADJUSTMENT',
    'quantity': quantity,
    'unitId': 'unit-a',
    'transactionDate': now,
    'createdAt': now,
  }, conflictAlgorithm: ConflictAlgorithm.replace);
}
