import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/presentation/pages/purchasing_page.dart';
import 'test_helpers/database_test_helper.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

void main() {
  late PurchasingLocalDataSource dataSource;
  late String suffix;
  late DateTime now;
  late String warehouseId;
  late String unitId;
  late String materialId;
  late String supplierId;

  Future<void> seed() async {
    final db = await FurnexaDatabase.instance.database;
    warehouseId = 'purchase-warehouse-$suffix';
    unitId = 'purchase-unit-$suffix';
    materialId = 'purchase-material-$suffix';
    supplierId = 'purchase-supplier-$suffix';
    final factoryId = 'purchase-factory-$suffix';
    final categoryId = 'purchase-category-$suffix';
    final timestamp = now.millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': factoryId,
      'name': 'مصنع مشتريات $suffix',
      'code': 'PF-$suffix',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'مخزن مشتريات $suffix',
      'code': 'PW-$suffix',
      'state': 'active',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'تصنيف مشتريات $suffix',
      'code': 'PC-$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'وحدة مشتريات $suffix',
      'abbreviation': 'PU$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('raw_materials', {
      'id': materialId,
      'name': 'خامة مشتريات $suffix',
      'code': 'PM-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('suppliers', {
      'id': supplierId,
      'name': 'مورد مشتريات $suffix',
      'code': 'PS-$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
  }

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login('admin', 'Furnexa-Test-Admin-2026!');
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime(2026, 9, 17);
    dataSource = PurchasingLocalDataSource();
    await seed();
  });

  testWidgets(
    'Windows purchasing list scrollbars use their ListView controllers',
    (tester) async {
      await dataSource.saveRequest(
        PurchaseRequest(
          id: 'scroll-request-$suffix',
          requestNumber: 'PR-SCROLL-$suffix',
          requestDate: now,
          requestedBy: 'test',
          status: PurchaseRequestStatus.draft,
          createdAt: now,
          updatedAt: now,
          items: const [],
        ),
      );
      await dataSource.saveOrder(
        PurchaseOrder(
          id: 'scroll-order-$suffix',
          orderNumber: 'PO-SCROLL-$suffix',
          supplierId: supplierId,
          orderDate: now,
          status: PurchaseOrderStatus.draft,
          subtotal: 100,
          discount: 0,
          tax: 0,
          grandTotal: 100,
          createdAt: now,
          updatedAt: now,
          items: [
            PurchasingItem(
              id: 'scroll-order-item-$suffix',
              itemId: materialId,
              itemType: PurchasingItemType.rawMaterial,
              quantity: 100,
              unitId: unitId,
              unitPrice: 1,
              lineTotal: 100,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: const PurchasingPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tab in ['طلبات الشراء', 'أوامر الشراء', 'الموردين']) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  tearDown(() async {
    SecurityLocalDataSource().logout();
    await DatabaseTestHelper.reset();
  });

  PurchaseOrder order({
    required String id,
    PurchaseOrderStatus status = PurchaseOrderStatus.confirmed,
    double received = 0,
  }) => PurchaseOrder(
    id: id,
    orderNumber: 'PO-$id',
    supplierId: supplierId,
    orderDate: now,
    status: status,
    subtotal: 100,
    discount: 0,
    tax: 0,
    grandTotal: 100,
    createdAt: now,
    updatedAt: now,
    items: [
      PurchasingItem(
        id: '$id-item',
        itemId: materialId,
        itemType: PurchasingItemType.rawMaterial,
        quantity: 100,
        unitId: unitId,
        unitPrice: 1,
        receivedQuantity: received,
        lineTotal: 100,
      ),
    ],
  );

  test(
    'supplier create, update, uniqueness, and inactive validation',
    () async {
      final supplier = Supplier(
        id: supplierId,
        name: 'مورد محدث',
        code: 'PS-$suffix',
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.saveSupplier(supplier);
      expect((await dataSource.suppliers(suffix)).single.name, 'مورد محدث');
      await dataSource.setSupplierActive(supplierId, false);
      expect(
        () => dataSource.saveOrder(order(id: 'inactive-order-$suffix')),
        throwsException,
      );
    },
  );

  test(
    'direct purchase order and partial receiving update stock atomically',
    () async {
      final purchaseOrder = order(id: 'partial-order-$suffix');
      await dataSource.saveOrder(purchaseOrder);
      await dataSource.postReceipt(
        order: purchaseOrder,
        warehouseId: warehouseId,
        receiptDate: now,
        items: [
          PurchasingItem(
            id: '${purchaseOrder.id}-item',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 60,
            unitId: unitId,
          ),
        ],
      );
      final saved = (await dataSource.orders()).firstWhere(
        (value) => value.id == purchaseOrder.id,
      );
      expect(saved.status, PurchaseOrderStatus.partiallyReceived);
      expect(saved.items.single.receivedQuantity, 60);
      await dataSource.postReceipt(
        order: saved,
        warehouseId: warehouseId,
        receiptDate: now,
        items: [
          PurchasingItem(
            id: '${purchaseOrder.id}-item',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 40,
            unitId: unitId,
          ),
        ],
      );
      final complete = (await dataSource.orders()).firstWhere(
        (value) => value.id == purchaseOrder.id,
      );
      expect(complete.status, PurchaseOrderStatus.fullyReceived);
      final stock = await (await FurnexaDatabase.instance.database).query(
        'stock_balances',
        where: 'warehouseId = ?',
        whereArgs: [warehouseId],
      );
      final transactions = await (await FurnexaDatabase.instance.database)
          .query(
            'stock_transactions',
            where: 'warehouseId = ?',
            whereArgs: [warehouseId],
          );
      expect((stock.single['quantity'] as num).toDouble(), 100);
      expect(transactions, hasLength(2));
    },
  );

  test(
    'receiving beyond remaining quantity rolls back receipt, stock, and order quantities',
    () async {
      final purchaseOrder = order(id: 'rollback-order-$suffix');
      await dataSource.saveOrder(purchaseOrder);
      expect(
        () => dataSource.postReceipt(
          order: purchaseOrder,
          warehouseId: warehouseId,
          receiptDate: now,
          items: [
            PurchasingItem(
              id: '${purchaseOrder.id}-item',
              itemId: materialId,
              itemType: PurchasingItemType.rawMaterial,
              quantity: 101,
              unitId: unitId,
            ),
          ],
        ),
        throwsException,
      );
      expect((await dataSource.receipts(purchaseOrder.id)), isEmpty);
      expect(
        (await dataSource.orders())
            .firstWhere((value) => value.id == purchaseOrder.id)
            .items
            .single
            .receivedQuantity,
        0,
      );
      final stock = await (await FurnexaDatabase.instance.database).query(
        'stock_balances',
        where: 'warehouseId = ?',
        whereArgs: [warehouseId],
      );
      expect(stock, isEmpty);
    },
  );

  test(
    'approved request conversion preserves request and links order',
    () async {
      final request = PurchaseRequest(
        id: 'request-$suffix',
        requestNumber: 'PR-$suffix',
        requestDate: now,
        requestedBy: 'المخزن',
        status: PurchaseRequestStatus.approved,
        createdAt: now,
        updatedAt: now,
        items: [
          PurchasingItem(
            id: 'request-item-$suffix',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 10,
            unitId: unitId,
          ),
        ],
      );
      await dataSource.saveRequest(request);
      final base = order(id: 'converted-order-$suffix');
      final converted = PurchaseOrder(
        id: base.id,
        orderNumber: base.orderNumber,
        supplierId: base.supplierId,
        purchaseRequestId: request.id,
        orderDate: base.orderDate,
        status: base.status,
        subtotal: base.subtotal,
        discount: base.discount,
        tax: base.tax,
        grandTotal: base.grandTotal,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
        items: base.items,
      );
      await dataSource.convertRequestToOrder(request, converted);
      expect(
        (await dataSource.requests())
            .firstWhere((value) => value.id == request.id)
            .status,
        PurchaseRequestStatus.converted,
      );
      expect(
        (await dataSource.orders())
            .firstWhere((value) => value.id == converted.id)
            .purchaseRequestId,
        converted.purchaseRequestId,
      );
      final db = await FurnexaDatabase.instance.database;
      expect(
        (await db.query(
          'purchase_requests',
          where: 'id = ?',
          whereArgs: [request.id],
        )).single['status'],
        'CONVERTED',
      );
    },
  );

  test('stale cancelled order cannot post receiving', () async {
    final purchaseOrder = order(id: 'stale-order-$suffix');
    await dataSource.saveOrder(purchaseOrder);
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'purchase_orders',
      {'status': 'CANCELLED'},
      where: 'id = ?',
      whereArgs: [purchaseOrder.id],
    );
    expect(
      () => dataSource.postReceipt(
        order: purchaseOrder,
        warehouseId: warehouseId,
        receiptDate: now,
        items: [
          PurchasingItem(
            id: '${purchaseOrder.id}-item',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 1,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );
    expect(await dataSource.receipts(purchaseOrder.id), isEmpty);
    expect(
      await db.query(
        'stock_transactions',
        where: 'warehouseId = ?',
        whereArgs: [warehouseId],
      ),
      isEmpty,
    );
  });

  test(
    'request conversion is idempotent and direct status saves are guarded',
    () async {
      final request = PurchaseRequest(
        id: 'guarded-request-$suffix',
        requestNumber: 'PR-GUARDED-$suffix',
        requestDate: now,
        requestedBy: 'test',
        status: PurchaseRequestStatus.draft,
        createdAt: now,
        updatedAt: now,
        items: [
          PurchasingItem(
            id: 'guarded-request-item-$suffix',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 10,
            unitId: unitId,
          ),
        ],
      );
      await dataSource.saveRequest(request);
      final invalid = PurchaseRequest(
        id: request.id,
        requestNumber: request.requestNumber,
        requestDate: request.requestDate,
        requestedBy: request.requestedBy,
        status: PurchaseRequestStatus.converted,
        createdAt: request.createdAt,
        updatedAt: now,
        items: request.items,
      );
      expect(() => dataSource.saveRequest(invalid), throwsException);
      await dataSource.changeRequestStatus(
        request.id,
        PurchaseRequestStatus.pending,
      );
      await dataSource.changeRequestStatus(
        request.id,
        PurchaseRequestStatus.approved,
      );
      final first = order(id: 'converted-once-$suffix');
      final linkedFirst = PurchaseOrder(
        id: first.id,
        orderNumber: first.orderNumber,
        supplierId: first.supplierId,
        purchaseRequestId: request.id,
        orderDate: first.orderDate,
        status: first.status,
        subtotal: first.subtotal,
        discount: first.discount,
        tax: first.tax,
        grandTotal: first.grandTotal,
        createdAt: first.createdAt,
        updatedAt: first.updatedAt,
        items: first.items,
      );
      await dataSource.convertRequestToOrder(request, linkedFirst);
      expect(
        () => dataSource.convertRequestToOrder(
          request,
          linkedFirst.copyWithForTest(id: 'converted-twice-$suffix'),
        ),
        throwsException,
      );
    },
  );

  test('received order edits and unit mismatches are rejected', () async {
    final purchaseOrder = order(id: 'immutable-order-$suffix');
    await dataSource.saveOrder(purchaseOrder);
    await dataSource.postReceipt(
      order: purchaseOrder,
      warehouseId: warehouseId,
      receiptDate: now,
      items: [
        PurchasingItem(
          id: '${purchaseOrder.id}-item',
          itemId: materialId,
          itemType: PurchasingItemType.rawMaterial,
          quantity: 60,
          unitId: unitId,
        ),
      ],
    );
    final received = (await dataSource.orders()).singleWhere(
      (value) => value.id == purchaseOrder.id,
    );
    expect(
      () => dataSource.saveOrder(
        PurchaseOrder(
          id: received.id,
          orderNumber: received.orderNumber,
          supplierId: received.supplierId,
          orderDate: received.orderDate,
          status: received.status,
          subtotal: received.subtotal,
          discount: received.discount,
          tax: received.tax,
          grandTotal: received.grandTotal,
          createdAt: received.createdAt,
          updatedAt: now,
          items: [
            PurchasingItem(
              id: received.items.single.id,
              itemId: materialId,
              itemType: PurchasingItemType.rawMaterial,
              quantity: 50,
              unitId: unitId,
              receivedQuantity: 60,
              unitPrice: 1,
              lineTotal: 100,
            ),
          ],
        ),
      ),
      throwsException,
    );
    final db = await FurnexaDatabase.instance.database;
    await db.insert('units', {
      'id': 'wrong-unit-$suffix',
      'name': 'وحدة خاطئة $suffix',
      'abbreviation': 'WU$suffix',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    expect(
      () => dataSource.saveOrder(
        order(
          id: 'wrong-unit-order-$suffix',
        ).copyWithForTest(itemUnitId: 'wrong-unit-$suffix'),
      ),
      throwsException,
    );
  });

  test(
    'direct purchasing calls require permission and create audit events',
    () async {
      final security = SecurityLocalDataSource();
      final role = await security.createRole(
        name: 'No Purchasing ${DateTime.now().microsecondsSinceEpoch}',
      );
      final user = await security.createUser(
        username: 'no-purchasing-${DateTime.now().microsecondsSinceEpoch}',
        displayName: 'No Purchasing',
        password: 'secret',
        roleId: role.id,
      );
      security.logout();
      await security.login(user.username, 'secret');
      expect(
        () => dataSource.saveSupplier(
          Supplier(
            id: 'blocked-supplier-$suffix',
            name: 'Blocked',
            code: 'BLOCKED-$suffix',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsException,
      );
      security.logout();
      await security.login('admin', 'Furnexa-Test-Admin-2026!');
      await dataSource.saveSupplier(
        Supplier(
          id: 'audited-supplier-$suffix',
          name: 'Audited',
          code: 'AUDITED-$suffix',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final logs = await security.auditLogs(module: 'Purchasing');
      expect(
        logs.any(
          (log) => log.entityType == 'Supplier' && log.action == 'CREATE',
        ),
        isTrue,
      );
    },
  );
}

extension on PurchaseOrder {
  PurchaseOrder copyWithForTest({String? id, String? itemUnitId}) =>
      PurchaseOrder(
        id: id ?? this.id,
        orderNumber: id == null ? orderNumber : 'PO-$id',
        supplierId: supplierId,
        purchaseRequestId: purchaseRequestId,
        orderDate: orderDate,
        expectedDeliveryDate: expectedDeliveryDate,
        status: status,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        grandTotal: grandTotal,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        items: items
            .map(
              (item) => PurchasingItem(
                id: item.id,
                itemId: item.itemId,
                itemType: item.itemType,
                quantity: item.quantity,
                unitId: itemUnitId ?? item.unitId,
                unitPrice: item.unitPrice,
                discount: item.discount,
                tax: item.tax,
                lineTotal: item.lineTotal,
                receivedQuantity: item.receivedQuantity,
                notes: item.notes,
              ),
            )
            .toList(),
      );
}
