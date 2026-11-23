import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/returns_quality/data/datasources/returns_quality_local_data_source.dart';
import 'package:furnexa/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late SecurityLocalDataSource security;
  late SalesLocalDataSource sales;
  late ReturnsQualityLocalDataSource returns;
  late String suffix;
  late String orderId;
  late String deliveryAId;
  late String deliveryBId;
  late String returnAId;
  late String returnBId;
  late String itemAId;
  late String itemBId;
  late String warehouseAId;
  late String warehouseBId;
  late String scopedUserId;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.login('admin', DatabaseTestHelper.adminPassword);
    sales = SalesLocalDataSource(null, null, security);
    returns = ReturnsQualityLocalDataSource(null, security);
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    orderId = 'scope-order-$suffix';
    deliveryAId = 'scope-delivery-a-$suffix';
    deliveryBId = 'scope-delivery-b-$suffix';
    returnAId = 'scope-return-a-$suffix';
    returnBId = 'scope-return-b-$suffix';
    itemAId = 'scope-return-item-a-$suffix';
    itemBId = 'scope-return-item-b-$suffix';
    warehouseAId = 'scope-warehouse-a-$suffix';
    warehouseBId = 'scope-warehouse-b-$suffix';
    final factoryAId = 'scope-factory-a-$suffix';
    final factoryBId = 'scope-factory-b-$suffix';
    final customerId = 'scope-customer-$suffix';
    final unitId = 'scope-unit-$suffix';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final db = await FurnexaDatabase.instance.database;

    for (final factory in [
      (factoryAId, 'SFA-$suffix'),
      (factoryBId, 'SFB-$suffix'),
    ]) {
      await db.insert('factories', {
        'id': factory.$1,
        'name': factory.$2,
        'code': factory.$2,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    }
    for (final warehouse in [
      (warehouseAId, factoryAId, 'SWA-$suffix'),
      (warehouseBId, factoryBId, 'SWB-$suffix'),
    ]) {
      await db.insert('warehouses', {
        'id': warehouse.$1,
        'factoryId': warehouse.$2,
        'name': warehouse.$3,
        'code': warehouse.$3,
        'state': 'active',
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    }
    await db.insert('customers', {
      'id': customerId,
      'name': 'Scope Customer $suffix',
      'code': 'SC-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'Scope Unit $suffix',
      'abbreviation': 'SU$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('sales_orders', {
      'id': orderId,
      'orderNumber': 'SO-$suffix',
      'customerId': customerId,
      'orderDate': stamp,
      'status': 'CONFIRMED',
      'subtotal': 20,
      'discount': 0,
      'tax': 0,
      'grandTotal': 20,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    for (final factory in ['a', 'b']) {
      await db.insert('sales_order_items', {
        'id': 'scope-order-item-$factory-$suffix',
        'salesOrderId': orderId,
        'itemId': 'scope-product-$factory-$suffix',
        'productId': 'scope-product-$factory-$suffix',
        'itemType': 'PRODUCT',
        'quantity': 1,
        'unitId': unitId,
        'baseUnitId': unitId,
        'unitConversionFactor': 1,
        'baseQuantity': 1,
        'unitPrice': 10,
        'discount': 0,
        'tax': 0,
        'lineTotal': 10,
      });
    }
    await _insertDelivery(
      db,
      id: deliveryAId,
      itemId: 'scope-delivery-item-a-$suffix',
      orderId: orderId,
      warehouseId: warehouseAId,
      orderItemId: 'scope-order-item-a-$suffix',
      productId: 'scope-product-a-$suffix',
      unitId: unitId,
      stamp: stamp,
    );
    await _insertDelivery(
      db,
      id: deliveryBId,
      itemId: 'scope-delivery-item-b-$suffix',
      orderId: orderId,
      warehouseId: warehouseBId,
      orderItemId: 'scope-order-item-b-$suffix',
      productId: 'scope-product-b-$suffix',
      unitId: unitId,
      stamp: stamp,
    );
    await _insertReturn(
      db,
      id: returnAId,
      itemId: itemAId,
      orderId: orderId,
      deliveryId: deliveryAId,
      customerId: customerId,
      warehouseId: warehouseAId,
      sourceDeliveryItemId: 'scope-delivery-item-a-$suffix',
      productId: 'scope-product-a-$suffix',
      unitId: unitId,
      stamp: stamp,
    );
    await _insertReturn(
      db,
      id: returnBId,
      itemId: itemBId,
      orderId: orderId,
      deliveryId: deliveryBId,
      customerId: customerId,
      warehouseId: warehouseBId,
      sourceDeliveryItemId: 'scope-delivery-item-b-$suffix',
      productId: 'scope-product-b-$suffix',
      unitId: unitId,
      stamp: stamp,
    );
    await db.insert('sales_return_items', {
      'id': 'scope-cross-item-$suffix',
      'salesReturnId': returnAId,
      'itemId': 'scope-product-b-$suffix',
      'productId': 'scope-product-b-$suffix',
      'itemType': 'PRODUCT',
      'quantity': 1,
      'unitId': unitId,
      'unitPrice': 10,
      'qualityStatus': 'PENDING',
      'sourceDeliveryItemId': 'scope-delivery-item-b-$suffix',
      'createdAt': stamp,
    });
    await db.insert('sales_returns', {
      'id': 'scope-return-missing-delivery-$suffix',
      'returnNumber': 'SR-MISSING-$suffix',
      'salesOrderId': orderId,
      'salesDeliveryId': 'missing-delivery-$suffix',
      'customerId': customerId,
      'warehouseId': warehouseAId,
      'returnDate': stamp,
      'status': 'PENDING',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('sales_return_receipts', {
      'id': 'scope-receipt-a-$suffix',
      'receiptNumber': 'SRR-A-$suffix',
      'salesReturnId': returnAId,
      'warehouseId': warehouseAId,
      'receiptDate': stamp,
      'createdAt': stamp,
    });
    await db.insert('sales_return_receipt_items', {
      'receiptId': 'scope-receipt-a-$suffix',
      'salesReturnItemId': itemAId,
      'quantity': 1,
      'baseQuantity': 1,
    });
    await db.insert('sales_return_receipts', {
      'id': 'scope-receipt-b-$suffix',
      'receiptNumber': 'SRR-B-$suffix',
      'salesReturnId': returnAId,
      'warehouseId': warehouseBId,
      'receiptDate': stamp,
      'createdAt': stamp,
    });
    await db.insert('sales_return_receipt_items', {
      'receiptId': 'scope-receipt-b-$suffix',
      'salesReturnItemId': itemAId,
      'quantity': 1,
      'baseQuantity': 1,
    });

    final role = await security.createRole(name: 'Read Scope $suffix');
    await security.setRolePermissions(role.id, [
      'SALES_VIEW',
      'RETURNS_VIEW',
      'QUALITY_VIEW',
    ]);
    final scopedUser = await security.createUser(
      username: 'scope-user-$suffix',
      displayName: 'Scoped Reader',
      password: 'scope-secret',
      roleId: role.id,
    );
    scopedUserId = scopedUser.id;
    await security.createUser(
      username: 'unscoped-user-$suffix',
      displayName: 'Unscoped Reader',
      password: 'scope-secret',
      roleId: role.id,
    );
    await security.setUserScopes(scopedUserId, [
      UserScope(
        id: 'ignored-scope-$suffix',
        userId: scopedUserId,
        type: ScopeType.warehouse,
        scopeId: warehouseAId,
      ),
    ]);
    security.logout();
    await security.login('scope-user-$suffix', 'scope-secret');
  });

  tearDown(() async {
    security.logout();
    await DatabaseTestHelper.reset();
  });

  test(
    'delivery reads are limited to authorized warehouses and factories',
    () async {
      final rows = await sales.deliveries(orderId);
      expect(rows.map((row) => row.id), [deliveryAId]);
      expect(
        (await sales.activeWarehouses()).map((warehouse) => warehouse.id),
        [warehouseAId],
      );
    },
  );

  test('order-based delivery lookup cannot bypass warehouse scope', () async {
    final rows = await sales.deliveries(orderId);
    expect(rows, hasLength(1));
    expect(rows.single.warehouseId, warehouseAId);
  });

  test(
    'a user with no warehouse scope receives no delivery or return rows',
    () async {
      security.logout();
      await security.login('unscoped-user-$suffix', 'scope-secret');

      expect(await sales.deliveries(orderId), isEmpty);
      expect(await sales.activeWarehouses(), isEmpty);
      expect(await returns.salesReturns(), isEmpty);
      expect(await returns.salesReturnSourceDeliveries(), isEmpty);
    },
  );

  test('return listing is limited to authorized warehouses', () async {
    final rows = await returns.salesReturns();
    expect(rows.map((row) => row.id), [returnAId]);
  });

  test(
    'return source delivery and line pickers enforce warehouse scope',
    () async {
      final deliveries = await returns.salesReturnSourceDeliveries();
      expect(deliveries.map((delivery) => delivery.id), [deliveryAId]);

      final lines = await returns.salesReturnSourceLines(deliveryAId);
      expect(lines.map((line) => line.deliveryItemId), [
        'scope-delivery-item-a-$suffix',
      ]);
    },
  );

  test(
    'return details scope items, source lines, and receipt children',
    () async {
      final details = await returns.salesReturnDetails(returnAId);

      expect(details.salesReturn.items.map((item) => item.id), [itemAId]);
      expect(details.lines.map((line) => line.item.id), [itemAId]);
      expect(details.lines.single.itemName, isNot(contains('scope-product-b')));
      expect(details.receipts.map((receipt) => receipt.id), [
        'scope-receipt-a-$suffix',
      ]);
      expect(
        details.receipts.single.items.map((item) => item.salesReturnItemId),
        [itemAId],
      );
    },
  );

  test(
    'quality inspection reads enforce return and warehouse relationships',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final inspectionId = 'scope-inspection-a-$suffix';
      final inaccessibleInspectionId = 'scope-inspection-b-$suffix';
      for (final inspection in [
        (inspectionId, warehouseAId),
        (inaccessibleInspectionId, warehouseBId),
      ]) {
        await db.insert('quality_inspections', {
          'id': inspection.$1,
          'inspectionNumber': 'QI-${inspection.$1}',
          'sourceType': 'SALES_RETURN',
          'sourceId': returnAId,
          'warehouseId': inspection.$2,
          'itemId': 'scope-product-a-$suffix',
          'itemType': 'PRODUCT',
          'inspectionDate': stamp,
          'status': 'COMPLETED',
          'result': 'QUARANTINED',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
      }
      for (final item in [
        ('scope-qc-item-a-$suffix', inspectionId, itemAId),
        ('scope-qc-item-cross-$suffix', inspectionId, itemBId),
        ('scope-qc-item-b-$suffix', inaccessibleInspectionId, itemAId),
      ]) {
        await db.insert('quality_inspection_items', {
          'id': item.$1,
          'inspectionId': item.$2,
          'itemId': 'scope-product-a-$suffix',
          'productId': 'scope-product-a-$suffix',
          'sourceReturnItemId': item.$3,
          'itemType': 'PRODUCT',
          'requestedQuantity': 1,
          'inspectedQuantity': 1,
          'acceptedQuantity': 1,
          'rejectedQuantity': 0,
          'result': 'PASSED',
          'createdAt': stamp,
        });
      }

      final inspections = await returns.qualityInspections(
        sourceType: 'SALES_RETURN',
      );
      expect(inspections.map((inspection) => inspection.id), [inspectionId]);
      expect(inspections.single.items.map((item) => item.id), [
        'scope-qc-item-a-$suffix',
      ]);
      final details = await returns.salesReturnDetails(returnAId);
      expect(details.inspection?.id, inspectionId);
      expect(details.inspection?.items.map((item) => item.id), [
        'scope-qc-item-a-$suffix',
      ]);
    },
  );

  test('invalid or missing delivery relationships fail closed', () async {
    expect(
      (await returns.salesReturns()).any(
        (value) => value.id == 'scope-return-missing-delivery-$suffix',
      ),
      isFalse,
    );
    await expectLater(
      returns.salesReturnDetails('scope-return-missing-delivery-$suffix'),
      throwsException,
    );
  });

  test('system administrator retains existing cross-factory reads', () async {
    security.logout();
    await security.login('admin', DatabaseTestHelper.adminPassword);

    expect(await sales.deliveries(orderId), hasLength(2));
    expect(await returns.salesReturns(), hasLength(2));
    expect(
      (await returns.salesReturnDetails(returnAId)).receipts,
      hasLength(2),
    );
  });
}

Future<void> _insertDelivery(
  DatabaseExecutor db, {
  required String id,
  required String itemId,
  required String orderId,
  required String warehouseId,
  required String orderItemId,
  required String productId,
  required String unitId,
  required int stamp,
}) async {
  await db.insert('sales_deliveries', {
    'id': id,
    'deliveryNumber': 'DL-$id',
    'salesOrderId': orderId,
    'warehouseId': warehouseId,
    'deliveryDate': stamp,
    'status': 'DELIVERED',
    'createdAt': stamp,
  });
  await db.insert('sales_delivery_items', {
    'id': itemId,
    'salesDeliveryId': id,
    'salesOrderItemId': orderItemId,
    'deliveredQuantity': 1,
    'unitId': unitId,
    'productId': productId,
    'baseUnitId': unitId,
    'unitConversionFactor': 1,
    'baseQuantity': 1,
    'inventoryIdentityKind': 'BASE',
    'identitySnapshotStatus': 'VERIFIED',
    'unitRevenue': 10,
    'unitCogs': 1,
  });
}

Future<void> _insertReturn(
  DatabaseExecutor db, {
  required String id,
  required String itemId,
  required String orderId,
  required String deliveryId,
  required String customerId,
  required String warehouseId,
  required String sourceDeliveryItemId,
  required String productId,
  required String unitId,
  required int stamp,
}) async {
  await db.insert('sales_returns', {
    'id': id,
    'returnNumber': 'SR-$id',
    'salesOrderId': orderId,
    'salesDeliveryId': deliveryId,
    'customerId': customerId,
    'warehouseId': warehouseId,
    'returnDate': stamp,
    'status': 'PENDING',
    'createdAt': stamp,
    'updatedAt': stamp,
  });
  await db.insert('sales_return_items', {
    'id': itemId,
    'salesReturnId': id,
    'itemId': productId,
    'productId': productId,
    'itemType': 'PRODUCT',
    'quantity': 1,
    'unitId': unitId,
    'unitPrice': 10,
    'qualityStatus': 'PENDING',
    'sourceDeliveryItemId': sourceDeliveryItemId,
    'createdAt': stamp,
  });
}
