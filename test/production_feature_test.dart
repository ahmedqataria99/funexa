import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/production/data/datasources/production_local_data_source.dart';
import 'package:furnexa/features/production/data/repositories/production_repository_impl.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/production/domain/repositories/production_repository.dart';
import 'package:furnexa/features/production/presentation/pages/production_page.dart';
import 'package:furnexa/features/raw_materials_products/data/datasources/raw_materials_products_local_data_source.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late ProductionLocalDataSource dataSource;
  late String suffix;
  late String factoryId;
  late String categoryId;
  late String unitId;
  late String rawMaterialId;
  late String productId;
  late String warehouseId;
  late String firstStageId;
  late String secondStageId;
  late DateTime now;

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login('admin', 'Furnexa-Test-Admin-2026!');
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime(2026, 9, 17);
    dataSource = ProductionLocalDataSource();
    final db = await FurnexaDatabase.instance.database;
    await db.delete('production_outputs');
    await db.delete('production_waste');
    await db.delete('production_material_consumptions');
    await db.delete('production_order_stages');
    await db.delete('production_orders');
    await db.delete('production_route_stages');
    await db.delete('production_routes');
    await db.delete('stock_transactions');
    await db.delete('stock_balances');
    await db.delete('product_bom_items');
    await db.delete('product_variants');
    await db.delete('products');
    await db.delete('raw_materials');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('warehouses');
    await db.delete('production_stages');
    await db.delete('factories');

    final stamp = now.millisecondsSinceEpoch;
    factoryId = 'production-factory-$suffix';
    categoryId = 'production-category-$suffix';
    unitId = 'production-unit-$suffix';
    rawMaterialId = 'production-raw-$suffix';
    productId = 'production-product-$suffix';
    warehouseId = 'production-warehouse-$suffix';
    firstStageId = 'production-stage-one-$suffix';
    secondStageId = 'production-stage-two-$suffix';

    await db.insert('factories', {
      'id': factoryId,
      'name': 'مصنع إنتاج $suffix',
      'code': 'PF-$suffix',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'تصنيف إنتاج $suffix',
      'code': 'PC-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'وحدة إنتاج $suffix',
      'abbreviation': 'PU$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'مخزن إنتاج $suffix',
      'code': 'PW-$suffix',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('production_stages', {
      'id': firstStageId,
      'factoryId': factoryId,
      'name': 'قص $suffix',
      'code': 'CUT-$suffix',
      'sequence': 1,
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('production_stages', {
      'id': secondStageId,
      'factoryId': factoryId,
      'name': 'تجميع $suffix',
      'code': 'ASM-$suffix',
      'sequence': 2,
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('raw_materials', {
      'id': rawMaterialId,
      'name': 'خشب إنتاج $suffix',
      'code': 'PR-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'كرسي إنتاج $suffix',
      'code': 'PP-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'unfinished',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('product_bom_items', {
      'id': 'bom-$suffix',
      'productId': productId,
      'rawMaterialId': rawMaterialId,
      'quantity': 5,
      'notes': 'قص حسب المقاس',
    });
    await db.insert('stock_balances', {
      'id': 'raw-balance-$suffix',
      'warehouseId': warehouseId,
      'itemId': rawMaterialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 10,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('inventory_valuations', {
      'id': 'raw-valuation-$suffix',
      'warehouseId': warehouseId,
      'itemId': rawMaterialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 10,
      'averageCost': 10,
      'updatedAt': stamp,
    });
  });

  tearDown(() async {
    SecurityLocalDataSource().logout();
    await DatabaseTestHelper.reset();
  });

  Future<ProductionOrder> plannedOrder(List<String> stageIds) async {
    await dataSource.saveRoute(productId, stageIds);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2,
    );
    await dataSource.planOrder(order.id);
    return dataSource.getOrder(order.id);
  }

  Future<void> startOrder(ProductionOrder order) async {
    await dataSource.startOrder(order.id);
  }

  Future<String> addVariant(String owningProductId, String code) async {
    final variantId = '$code-$suffix';
    await (await FurnexaDatabase.instance.database).insert('product_variants', {
      'id': variantId,
      'productId': owningProductId,
      'name': code,
      'code': code,
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    return variantId;
  }

  Future<ProductionOrder> inProgressOrder({String? variantId}) async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      variantId: variantId,
      plannedQuantity: 2,
    );
    await dataSource.planOrder(order.id);
    await dataSource.startOrder(order.id);
    final started = await dataSource.getOrder(order.id);
    await dataSource.startStage(started.stages.single.id);
    await dataSource.completeStage(started.stages.single.id);
    return dataSource.getOrder(order.id);
  }

  test(
    'production consumption and waste reject restricted warehouses atomically',
    () async {
      final order = await inProgressOrder();
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'warehouses',
        {'purpose': 'REWORK'},
        where: 'id = ?',
        whereArgs: [warehouseId],
      );

      Future<Map<String, Object?>> snapshot() async => {
        'balances': await db.query('stock_balances', orderBy: 'id ASC'),
        'valuations': await db.query('inventory_valuations', orderBy: 'id ASC'),
        'transactions': await db.query('stock_transactions', orderBy: 'id ASC'),
        'consumptions': await db.query(
          'production_material_consumptions',
          orderBy: 'id ASC',
        ),
        'waste': await db.query('production_waste', orderBy: 'id ASC'),
        'journalEntries': await db.query('journal_entries', orderBy: 'id ASC'),
        'journalLines': await db.query('journal_lines', orderBy: 'id ASC'),
        'journalParties': await db.query(
          'journal_parties',
          orderBy: 'journalEntryId ASC',
        ),
      };

      final before = await snapshot();
      await expectLater(
        dataSource.consumeMaterial(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: 'restricted-consumption-$suffix',
        ),
        throwsA(predicate((error) => error.toString().contains('REWORK'))),
      );
      expect(await snapshot(), before);

      await expectLater(
        dataSource.recordWaste(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          reason: 'restricted warehouse test',
          date: now,
        ),
        throwsA(predicate((error) => error.toString().contains('REWORK'))),
      );
      expect(await snapshot(), before);
    },
  );

  test(
    'route creation validates duplicates and order snapshots stages',
    () async {
      await dataSource.saveRoute(productId, [firstStageId, secondStageId]);
      expect(
        () => dataSource.saveRoute(productId, [firstStageId, firstStageId]),
        throwsException,
      );
      final order = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 2,
      );
      await dataSource.saveRoute(productId, [secondStageId]);
      final stored = await dataSource.getOrder(order.id);
      expect(stored.stages, hasLength(2));
      expect(stored.stages.first.productionStageId, firstStageId);
      expect(stored.routeId, order.routeId);
    },
  );

  test(
    'production mutation requires authorization and creates an audit event',
    () async {
      final security = SecurityLocalDataSource();
      security.logout();
      expect(
        () => dataSource.saveRoute(productId, [firstStageId]),
        throwsException,
      );
      await security.login('admin', 'Furnexa-Test-Admin-2026!');
      await dataSource.saveRoute(productId, [firstStageId]);
      final logs = await security.auditLogs(module: 'Production');
      expect(logs.any((log) => log.entityType == 'ProductionRoute'), isTrue);
    },
  );

  test(
    'production orders keep their BOM snapshot after product BOM changes',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final first = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 2,
      );
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'product_bom_items',
        {'quantity': 9},
        where: 'productId = ? AND rawMaterialId = ?',
        whereArgs: [productId, rawMaterialId],
      );
      final firstRequirements = await dataSource.requirements(first.id);
      expect(firstRequirements.single.requiredQuantity, 10);
      final snapshot = await db.query(
        'production_order_bom_items',
        where: 'productionOrderId = ?',
        whereArgs: [first.id],
      );
      expect(snapshot.single['rawMaterialId'], rawMaterialId);
      expect(snapshot.single['unitId'], unitId);
      expect((snapshot.single['quantity'] as num).toDouble(), 5);
      expect(snapshot.single['notes'], 'قص حسب المقاس');
      final second = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 2,
      );
      expect(
        (await dataSource.requirements(second.id)).single.requiredQuantity,
        18,
      );
    },
  );

  test(
    'variant identity is required and validated when creating an order',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final variantId = await addVariant(productId, 'red');
      final otherProductId = 'production-other-product-$suffix';
      await db.insert('products', {
        'id': otherProductId,
        'name': 'منتج آخر $suffix',
        'code': 'OTHER-$suffix',
        'categoryId': categoryId,
        'unitId': unitId,
        'productState': 'unfinished',
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      final foreignVariantId = await addVariant(otherProductId, 'foreign');
      await dataSource.saveRoute(productId, [firstStageId]);

      await expectLater(
        dataSource.createOrder(productId: productId, plannedQuantity: 2),
        throwsException,
      );
      expect(await db.query('production_orders'), isEmpty);

      final order = await dataSource.createOrder(
        productId: productId,
        variantId: variantId,
        plannedQuantity: 2,
      );

      expect((await dataSource.getOrder(order.id)).variantId, variantId);
      await expectLater(
        dataSource.createOrder(
          productId: productId,
          variantId: foreignVariantId,
          plannedQuantity: 1,
        ),
        throwsException,
      );
      expect(await db.query('production_orders'), hasLength(1));
    },
  );

  test('order creation rejects a stale product unit from the form', () async {
    final db = await FurnexaDatabase.instance.database;
    await dataSource.saveRoute(productId, [firstStageId]);
    final staleUnitId = unitId;
    final changedUnitId = 'production-unit-changed-$suffix';
    await db.insert('units', {
      'id': changedUnitId,
      'name': 'وحدة إنتاج محدثة $suffix',
      'abbreviation': 'PUC$suffix',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.update(
      'products',
      {'unitId': changedUnitId},
      where: 'id = ?',
      whereArgs: [productId],
    );

    await expectLater(
      dataSource.createOrder(
        productId: productId,
        expectedUnitId: staleUnitId,
        plannedQuantity: 1,
      ),
      throwsException,
    );
    expect(await db.query('production_orders'), isEmpty);
  });

  test(
    'overlapping unit change and order creation remain consistent',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final changedUnitId = 'production-unit-race-$suffix';
      await (await FurnexaDatabase.instance.database).insert('units', {
        'id': changedUnitId,
        'name': 'وحدة سباق $suffix',
        'abbreviation': 'PUR$suffix',
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      final products = RawMaterialsProductsLocalDataSource();
      final orderAttempt = dataSource
          .createOrder(
            productId: productId,
            expectedUnitId: unitId,
            plannedQuantity: 1,
          )
          .then<Object?>((order) => order, onError: (Object error) => error);
      final unitAttempt = products
          .saveProduct(
            Product(
              id: productId,
              name: 'كرسي إنتاج $suffix',
              code: 'PP-$suffix',
              categoryId: categoryId,
              unitId: changedUnitId,
              state: ProductState.unfinished,
              active: true,
              createdAt: now,
              updatedAt: now,
            ),
          )
          .then<Object?>(
            (_) => 'UNIT_CHANGED',
            onError: (Object error) => error,
          );
      final results = await Future.wait<Object?>([orderAttempt, unitAttempt]);
      final db = await FurnexaDatabase.instance.database;
      final persistedUnitId = (await db.query(
        'products',
        columns: ['unitId'],
        where: 'id = ?',
        whereArgs: [productId],
      )).single['unitId'];
      final persistedOrders = await db.query(
        'production_orders',
        where: 'productId = ?',
        whereArgs: [productId],
      );

      if (results[1] == 'UNIT_CHANGED') {
        expect(results[0], isA<Exception>());
        expect(persistedUnitId, changedUnitId);
        expect(persistedOrders, isEmpty);
      } else {
        expect(results[1], isA<Exception>());
        expect(results[0], isA<ProductionOrder>());
        expect(persistedUnitId, unitId);
        expect(persistedOrders, hasLength(1));
      }
    },
  );

  test('variant output posts only to its exact inventory identity', () async {
    final variantId = await addVariant(productId, 'red');
    final siblingVariantId = await addVariant(productId, 'blue');
    final siblingItemId = inventoryItemKey(
      productId: productId,
      type: StockItemType.product,
      variantId: siblingVariantId,
      identityKind: InventoryIdentityKind.variant,
    );
    final db = await FurnexaDatabase.instance.database;
    await db.insert('stock_balances', {
      'id': 'sibling-balance-$suffix',
      'warehouseId': warehouseId,
      'itemId': siblingItemId,
      'itemType': 'PRODUCT',
      'productId': productId,
      'variantId': siblingVariantId,
      'inventoryIdentityKind': 'VARIANT',
      'unitId': unitId,
      'quantity': 3,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('inventory_valuations', {
      'id': 'sibling-valuation-$suffix',
      'warehouseId': warehouseId,
      'itemId': siblingItemId,
      'itemType': 'PRODUCT',
      'productId': productId,
      'variantId': siblingVariantId,
      'inventoryIdentityKind': 'VARIANT',
      'unitId': unitId,
      'quantity': 3,
      'averageCost': 12,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    final order = await inProgressOrder(variantId: variantId);
    await dataSource.consumeMaterial(
      orderId: order.id,
      rawMaterialId: rawMaterialId,
      warehouseId: warehouseId,
      quantity: 10,
      date: now,
      operationId: 'variant-consumption-$suffix',
    );
    await dataSource.recordOutput(
      orderId: order.id,
      warehouseId: warehouseId,
      quantity: 2,
      date: now,
      operationId: 'variant-output-$suffix',
    );

    final selectedItemId = inventoryItemKey(
      productId: productId,
      type: StockItemType.product,
      variantId: variantId,
      identityKind: InventoryIdentityKind.variant,
    );
    final selectedBalance = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, selectedItemId, 'PRODUCT'],
    );
    expect(selectedBalance.single['quantity'], 2);
    final siblingBalance = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, siblingItemId, 'PRODUCT'],
    );
    expect(siblingBalance.single['quantity'], 3);
    final siblingValuation = await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, siblingItemId, 'PRODUCT'],
    );
    expect(siblingValuation.single['quantity'], 3);
    expect(siblingValuation.single['averageCost'], 12);
    final outputTransaction = await db.query(
      'stock_transactions',
      where: 'reference = ?',
      whereArgs: ['PRODUCTION_OUTPUT:variant-output-$suffix'],
    );
    expect(outputTransaction.single['itemId'], selectedItemId);
    expect(outputTransaction.single['variantId'], variantId);
    expect(outputTransaction.single['inventoryIdentityKind'], 'VARIANT');
    expect(
      await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      ),
      isEmpty,
    );
    final completed = await dataSource.getOrder(order.id);
    expect(completed.status, ProductionOrderStatus.completed);
    expect(completed.producedQuantity, 2);
  });

  test(
    'missing persisted variant identity blocks material consumption',
    () async {
      final variantId = await addVariant(productId, 'red');
      final order = await inProgressOrder(variantId: variantId);
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'production_orders',
        {'variantId': null},
        where: 'id = ?',
        whereArgs: [order.id],
      );

      await expectLater(
        dataSource.consumeMaterial(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: 'invalid-variant-consumption-$suffix',
        ),
        throwsException,
      );
      await expectLater(
        dataSource.recordWaste(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          reason: 'invalid identity',
          date: now,
        ),
        throwsException,
      );

      expect(
        (await db.query(
          'stock_balances',
          columns: ['quantity'],
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, rawMaterialId],
        )).single['quantity'],
        10,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          columns: ['quantity', 'averageCost'],
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, rawMaterialId, 'RAW_MATERIAL'],
        )).single,
        {'quantity': 10, 'averageCost': 10},
      );
      expect(await dataSource.consumptions(order.id), isEmpty);
      expect(await dataSource.waste(order.id), isEmpty);
      expect(
        (await dataSource.getOrder(order.id)).status,
        ProductionOrderStatus.inProgress,
      );
    },
  );

  test('missing persisted variant identity blocks finished output', () async {
    final variantId = await addVariant(productId, 'red');
    final order = await inProgressOrder(variantId: variantId);
    final db = await FurnexaDatabase.instance.database;
    await dataSource.consumeMaterial(
      orderId: order.id,
      rawMaterialId: rawMaterialId,
      warehouseId: warehouseId,
      quantity: 10,
      date: now,
      operationId: 'valid-consumption-before-corruption-$suffix',
    );
    await db.update(
      'production_orders',
      {'variantId': null},
      where: 'id = ?',
      whereArgs: [order.id],
    );
    final transactionCount = (await db.query('stock_transactions')).length;

    await expectLater(
      dataSource.recordOutput(
        orderId: order.id,
        warehouseId: warehouseId,
        quantity: 2,
        date: now,
        operationId: 'invalid-variant-output-$suffix',
      ),
      throwsException,
    );

    expect(await dataSource.outputs(order.id), isEmpty);
    expect(
      await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemType = ?',
        whereArgs: [warehouseId, 'PRODUCT'],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemType = ?',
        whereArgs: [warehouseId, 'PRODUCT'],
      ),
      isEmpty,
    );
    expect((await db.query('stock_transactions')).length, transactionCount);
    final unchangedOrder = await dataSource.getOrder(order.id);
    expect(unchangedOrder.status, ProductionOrderStatus.inProgress);
    expect(unchangedOrder.producedQuantity, 0);
  });

  test('empty BOM draft is saved but cannot start production', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.delete(
      'product_bom_items',
      where: 'productId = ?',
      whereArgs: [productId],
    );
    await dataSource.saveRoute(productId, [firstStageId]);

    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2,
    );
    expect(order.status, ProductionOrderStatus.draft);
    expect(await dataSource.orderBomIsValid(order.id), isFalse);
    await dataSource.planOrder(order.id);
    await expectLater(dataSource.startOrder(order.id), throwsException);
    expect(
      (await dataSource.getOrder(order.id)).status,
      ProductionOrderStatus.planned,
    );
  });

  test('inactive snapshot material blocks production start', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2,
    );
    await dataSource.planOrder(order.id);
    await (await FurnexaDatabase.instance.database).update(
      'raw_materials',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [rawMaterialId],
    );

    await expectLater(dataSource.startOrder(order.id), throwsException);
    expect(await dataSource.orderBomIsValid(order.id), isFalse);
  });

  test('inactive snapshot unit blocks production start', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2,
    );
    await dataSource.planOrder(order.id);
    await (await FurnexaDatabase.instance.database).update(
      'units',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [unitId],
    );

    await expectLater(dataSource.startOrder(order.id), throwsException);
    expect(await dataSource.orderBomIsValid(order.id), isFalse);
  });

  test('planned quantity must be finite and greater than zero', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        dataSource.createOrder(productId: productId, plannedQuantity: invalid),
        throwsException,
      );
    }
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2.5,
    );
    expect(order.plannedQuantity, 2.5);
    expect(order.remainingQuantity, 2.5);
  });

  test('new base order persists a complete verified unit snapshot', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2.5,
    );
    final row = (await (await FurnexaDatabase.instance.database).query(
      'production_orders',
      where: 'id = ?',
      whereArgs: [order.id],
    )).single;

    expect(order.unitId, unitId);
    expect(order.baseUnitId, unitId);
    expect(order.unitConversionFactor, 1);
    expect(order.plannedBaseQuantity, 2.5);
    expect(order.unitSnapshotStatus, ProductionUnitSnapshotStatus.verified);
    expect(row['unitId'], unitId);
    expect(row['baseUnitId'], unitId);
    expect(row['unitConversionFactor'], 1);
    expect(row['plannedBaseQuantity'], 2.5);
    expect(row['unitSnapshotStatus'], 'VERIFIED');
  });

  test('variant order stores product-level unit snapshot unchanged', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final variantId = await addVariant(productId, 'snapshot-variant');
    final order = await dataSource.createOrder(
      productId: productId,
      variantId: variantId,
      plannedQuantity: 1.25,
    );

    expect(order.productId, productId);
    expect(order.variantId, variantId);
    expect(order.unitId, unitId);
    expect(order.baseUnitId, unitId);
    expect(order.unitConversionFactor, 1);
    expect(order.plannedBaseQuantity, 1.25);
    expect(order.unitSnapshotStatus, ProductionUnitSnapshotStatus.verified);
  });

  test(
    'inactive base unit prevents order creation without a partial row',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'units',
        {'active': 0},
        where: 'id = ?',
        whereArgs: [unitId],
      );

      await expectLater(
        dataSource.createOrder(productId: productId, plannedQuantity: 1),
        throwsA(isA<ProductionUnitSnapshotException>()),
      );
      expect(
        await db.query(
          'production_orders',
          where: 'productId = ?',
          whereArgs: [productId],
        ),
        isEmpty,
      );
    },
  );

  test(
    'unverified and inconsistent snapshots block all stock operations',
    () async {
      final order = await inProgressOrder();
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'production_orders',
        {'unitSnapshotStatus': 'UNVERIFIED'},
        where: 'id = ?',
        whereArgs: [order.id],
      );
      expect((await dataSource.getOrder(order.id)).remainingQuantity, isNull);
      final stockBefore = await db.query('stock_balances');
      final valuationsBefore = await db.query('inventory_valuations');
      final transactionsBefore = await db.query('stock_transactions');
      final orderBefore = await db.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [order.id],
      );

      await expectLater(
        dataSource.consumeMaterial(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: 'unverified-consumption-$suffix',
        ),
        throwsA(isA<ProductionUnitSnapshotException>()),
      );
      await expectLater(
        dataSource.recordWaste(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          reason: 'snapshot unavailable',
          date: now,
        ),
        throwsA(isA<ProductionUnitSnapshotException>()),
      );
      await expectLater(
        dataSource.recordOutput(
          orderId: order.id,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: 'unverified-output-$suffix',
        ),
        throwsA(isA<ProductionUnitSnapshotException>()),
      );

      expect(await db.query('stock_balances'), stockBefore);
      expect(await db.query('inventory_valuations'), valuationsBefore);
      expect(await db.query('stock_transactions'), transactionsBefore);
      expect(await db.query('production_material_consumptions'), isEmpty);
      expect(await db.query('production_waste'), isEmpty);
      expect(await dataSource.outputs(order.id), isEmpty);
      expect(
        await db.query(
          'production_orders',
          where: 'id = ?',
          whereArgs: [order.id],
        ),
        orderBefore,
      );

      await db.update(
        'production_orders',
        {'unitSnapshotStatus': 'VERIFIED', 'plannedBaseQuantity': 99},
        where: 'id = ?',
        whereArgs: [order.id],
      );
      await expectLater(
        dataSource.recordOutput(
          orderId: order.id,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: 'inconsistent-output-$suffix',
        ),
        throwsA(isA<ProductionUnitSnapshotException>()),
      );
      expect(await db.query('stock_balances'), stockBefore);
      expect(await db.query('inventory_valuations'), valuationsBefore);
      expect(await db.query('stock_transactions'), transactionsBefore);
      expect(await dataSource.outputs(order.id), isEmpty);
    },
  );

  test(
    'invalid snapshots reject matching consumption and output replays',
    () async {
      final order = await inProgressOrder();
      const consumptionOperationId = 'snapshot-invalid-consumption-replay';
      const outputOperationId = 'snapshot-invalid-output-replay';
      await dataSource.consumeMaterial(
        orderId: order.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 10,
        date: now,
        operationId: consumptionOperationId,
      );
      await dataSource.recordOutput(
        orderId: order.id,
        warehouseId: warehouseId,
        quantity: 1,
        date: now,
        operationId: outputOperationId,
      );

      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'production_orders',
        {'unitSnapshotStatus': 'UNVERIFIED'},
        where: 'id = ?',
        whereArgs: [order.id],
      );
      final stockBefore = await db.query('stock_balances');
      final valuationBefore = await db.query('inventory_valuations');
      final transactionsBefore = await db.query('stock_transactions');
      final consumptionsBefore = await db.query(
        'production_material_consumptions',
      );
      final outputsBefore = await db.query('production_outputs');
      final orderBefore = await db.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [order.id],
      );

      await expectLater(
        dataSource.consumeMaterial(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 10,
          date: now,
          operationId: consumptionOperationId,
        ),
        throwsA(isA<ProductionUnitSnapshotException>()),
      );
      await expectLater(
        dataSource.recordOutput(
          orderId: order.id,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: outputOperationId,
        ),
        throwsA(isA<ProductionUnitSnapshotException>()),
      );

      expect(await db.query('stock_balances'), stockBefore);
      expect(await db.query('inventory_valuations'), valuationBefore);
      expect(await db.query('stock_transactions'), transactionsBefore);
      expect(
        await db.query('production_material_consumptions'),
        consumptionsBefore,
      );
      expect(await db.query('production_outputs'), outputsBefore);
      expect(
        await db.query(
          'production_orders',
          where: 'id = ?',
          whereArgs: [order.id],
        ),
        orderBefore,
      );
    },
  );

  test(
    'finalized costing blocks new output but preserves accepted replay',
    () async {
      final order = await inProgressOrder();
      final operationId = 'output-before-cost-finalization-$suffix';
      await dataSource.consumeMaterial(
        orderId: order.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 10,
        date: now,
        operationId: 'output-finalization-consumption-$suffix',
      );
      await dataSource.recordOutput(
        orderId: order.id,
        warehouseId: warehouseId,
        quantity: 1,
        date: now,
        operationId: operationId,
      );

      final db = await FurnexaDatabase.instance.database;
      await db.insert('production_batch_costs', {
        'id': 'finalized-cost-$suffix',
        'productionOrderId': order.id,
        'productId': productId,
        'plannedQuantity': 2,
        'goodFinishedQuantity': 1,
        'materialCost': 1,
        'laborCost': 0,
        'overheadCost': 0,
        'otherCost': 0,
        'scrapRecovery': 0,
        'totalCost': 1,
        'actualUnitCost': 1,
        'estimatedCost': 1,
        'estimatedUnitCost': 1,
        'status': 'FINALIZED',
        'calculatedAt': now.millisecondsSinceEpoch,
        'finalizedAt': now.millisecondsSinceEpoch,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      final stockBefore = await db.query('stock_balances');
      final valuationsBefore = await db.query('inventory_valuations');
      final transactionsBefore = await db.query('stock_transactions');
      final outputsBefore = await db.query('production_outputs');
      final orderBefore = await db.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [order.id],
      );

      await dataSource.recordOutput(
        orderId: order.id,
        warehouseId: warehouseId,
        quantity: 1,
        date: now,
        operationId: operationId,
      );
      await expectLater(
        dataSource.recordOutput(
          orderId: order.id,
          warehouseId: warehouseId,
          quantity: 0.5,
          date: now,
          operationId: 'new-output-after-finalization-$suffix',
        ),
        throwsException,
      );

      expect(await db.query('stock_balances'), stockBefore);
      expect(await db.query('inventory_valuations'), valuationsBefore);
      expect(await db.query('stock_transactions'), transactionsBefore);
      expect(await db.query('production_outputs'), outputsBefore);
      expect(
        await db.query(
          'production_orders',
          where: 'id = ?',
          whereArgs: [order.id],
        ),
        orderBefore,
      );
    },
  );

  test(
    'later product unit changes do not reinterpret the saved snapshot',
    () async {
      final order = await inProgressOrder();
      final db = await FurnexaDatabase.instance.database;
      final changedUnitId = 'production-changed-unit-$suffix';
      await db.insert('units', {
        'id': changedUnitId,
        'name': 'Changed production unit $suffix',
        'abbreviation': 'CPU$suffix',
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await dataSource.consumeMaterial(
        orderId: order.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 10,
        date: now,
        operationId: 'snapshot-drift-consumption-$suffix',
      );
      await db.update(
        'products',
        {'unitId': changedUnitId},
        where: 'id = ?',
        whereArgs: [productId],
      );
      final stockBeforeOutput = await db.query('stock_balances');
      final valuationsBeforeOutput = await db.query('inventory_valuations');
      final transactionsBeforeOutput = await db.query('stock_transactions');

      await expectLater(
        dataSource.recordOutput(
          orderId: order.id,
          warehouseId: warehouseId,
          quantity: 2,
          date: now,
          operationId: 'snapshot-drift-output-$suffix',
        ),
        throwsException,
      );

      final reloaded = await dataSource.getOrder(order.id);
      expect(reloaded.unitId, unitId);
      expect(reloaded.baseUnitId, unitId);
      expect(reloaded.unitConversionFactor, 1);
      expect(reloaded.plannedBaseQuantity, 2);
      expect(
        reloaded.unitSnapshotStatus,
        ProductionUnitSnapshotStatus.verified,
      );
      expect(await db.query('stock_balances'), stockBeforeOutput);
      expect(await db.query('inventory_valuations'), valuationsBeforeOutput);
      expect(await db.query('stock_transactions'), transactionsBeforeOutput);
      expect(await dataSource.outputs(order.id), isEmpty);
    },
  );

  test(
    'partial output uses the verified planned base quantity limit',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final order = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 2.5,
      );
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'stock_balances',
        {'quantity': 12.5},
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, rawMaterialId, 'RAW_MATERIAL'],
      );
      await db.update(
        'inventory_valuations',
        {'quantity': 12.5},
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, rawMaterialId, 'RAW_MATERIAL'],
      );
      await dataSource.planOrder(order.id);
      await dataSource.startOrder(order.id);
      final started = await dataSource.getOrder(order.id);
      await dataSource.startStage(started.stages.single.id);
      await dataSource.completeStage(started.stages.single.id);
      await dataSource.consumeMaterial(
        orderId: order.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 12.5,
        date: now,
        operationId: 'planned-base-consumption-$suffix',
      );
      await dataSource.recordOutput(
        orderId: order.id,
        warehouseId: warehouseId,
        quantity: 2,
        date: now,
        operationId: 'planned-base-output-first-$suffix',
      );

      await expectLater(
        dataSource.recordOutput(
          orderId: order.id,
          warehouseId: warehouseId,
          quantity: 0.50001,
          date: now,
          operationId: 'planned-base-output-overrun-$suffix',
        ),
        throwsException,
      );
      await dataSource.recordOutput(
        orderId: order.id,
        warehouseId: warehouseId,
        quantity: 0.5,
        date: now,
        operationId: 'planned-base-output-final-$suffix',
      );

      final outputs = await db.query(
        'production_outputs',
        where: 'productionOrderId = ?',
        whereArgs: [order.id],
      );
      expect(outputs.map((row) => row['baseQuantity']), [2, 0.5]);
      expect(outputs.every((row) => row['unitId'] == unitId), isTrue);
      expect(outputs.every((row) => row['baseUnitId'] == unitId), isTrue);
      expect(outputs.every((row) => row['unitConversionFactor'] == 1), isTrue);
      final completed = await dataSource.getOrder(order.id);
      expect(completed.producedQuantity, 2.5);
      expect(completed.remainingBaseQuantity, 0);
      expect(completed.status, ProductionOrderStatus.completed);
    },
  );

  test('rapid order creation generates distinct references', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final orders = await Future.wait([
      dataSource.createOrder(productId: productId, plannedQuantity: 1),
      dataSource.createOrder(productId: productId, plannedQuantity: 1),
      dataSource.createOrder(productId: productId, plannedQuantity: 1),
    ]);
    expect(orders.map((order) => order.orderNumber).toSet(), hasLength(3));
  });

  test(
    'order creation requires authorization and records one audit event',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final security = SecurityLocalDataSource();
      security.logout();
      await expectLater(
        dataSource.createOrder(productId: productId, plannedQuantity: 1),
        throwsException,
      );
      expect(
        await (await FurnexaDatabase.instance.database).query(
          'production_orders',
        ),
        isEmpty,
      );

      await security.login('admin', 'Furnexa-Test-Admin-2026!');
      final order = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 1,
      );
      final logs = await security.auditLogs(module: 'Production');
      expect(
        logs.where(
          (log) =>
              log.entityType == 'ProductionOrder' &&
              log.entityId == order.id &&
              log.action == 'CREATE',
        ),
        hasLength(1),
      );
    },
  );

  test('production status and stage sequence are enforced', () async {
    await dataSource.saveRoute(productId, [firstStageId, secondStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 1,
    );
    await dataSource.planOrder(order.id);
    await dataSource.startOrder(order.id);
    final started = await dataSource.getOrder(order.id);
    expect(() => dataSource.startStage(started.stages[1].id), throwsException);
    await dataSource.startStage(started.stages.first.id);
    expect(
      () => dataSource.recordOutput(
        orderId: order.id,
        warehouseId: warehouseId,
        quantity: 1,
        date: now,
        operationId: 'production-output-status-$suffix',
      ),
      throwsException,
    );
    await dataSource.completeStage(started.stages.first.id);
    await dataSource.startStage(started.stages[1].id);
    await expectLater(dataSource.cancelOrder(order.id), throwsException);
  });

  test(
    'cancellation preserves its eligible statuses and does not reverse movements',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final draft = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 1,
      );
      await dataSource.cancelOrder(draft.id);
      expect(
        (await dataSource.getOrder(draft.id)).status,
        ProductionOrderStatus.cancelled,
      );

      final planned = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 1,
      );
      await dataSource.planOrder(planned.id);
      await dataSource.cancelOrder(planned.id);
      expect(
        (await dataSource.getOrder(planned.id)).status,
        ProductionOrderStatus.cancelled,
      );

      final inProgress = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 1,
      );
      await dataSource.planOrder(inProgress.id);
      await dataSource.startOrder(inProgress.id);
      await expectLater(dataSource.cancelOrder(inProgress.id), throwsException);
      expect(
        (await dataSource.getOrder(inProgress.id)).status,
        ProductionOrderStatus.inProgress,
      );

      final completed = await inProgressOrder();
      await dataSource.consumeMaterial(
        orderId: completed.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 10,
        date: now,
        operationId: 'cancel-check-consumption-$suffix',
      );
      await dataSource.recordOutput(
        orderId: completed.id,
        warehouseId: warehouseId,
        quantity: 2,
        date: now,
        operationId: 'cancel-check-output-$suffix',
      );
      final db = await FurnexaDatabase.instance.database;
      final stockBefore = await db.query('stock_transactions');
      final valuationsBefore = await db.query('inventory_valuations');
      final consumptionBefore = await db.query(
        'production_material_consumptions',
        where: 'productionOrderId = ?',
        whereArgs: [completed.id],
      );
      final wasteBefore = await db.query(
        'production_waste',
        where: 'productionOrderId = ?',
        whereArgs: [completed.id],
      );
      final outputsBefore = await db.query(
        'production_outputs',
        where: 'productionOrderId = ?',
        whereArgs: [completed.id],
      );

      await expectLater(dataSource.cancelOrder(completed.id), throwsException);

      expect(
        (await dataSource.getOrder(completed.id)).status,
        ProductionOrderStatus.completed,
      );
      expect(await db.query('stock_transactions'), stockBefore);
      expect(await db.query('inventory_valuations'), valuationsBefore);
      expect(
        await db.query(
          'production_material_consumptions',
          where: 'productionOrderId = ?',
          whereArgs: [completed.id],
        ),
        consumptionBefore,
      );
      expect(
        await db.query(
          'production_waste',
          where: 'productionOrderId = ?',
          whereArgs: [completed.id],
        ),
        wasteBefore,
      );
      expect(
        await db.query(
          'production_outputs',
          where: 'productionOrderId = ?',
          whereArgs: [completed.id],
        ),
        outputsBefore,
      );
    },
  );

  test(
    'overlapping start and cancel requests cannot overwrite the winner',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final order = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 1,
      );
      await dataSource.planOrder(order.id);

      final startAttempt = dataSource
          .startOrder(order.id)
          .then<Object?>((_) => 'STARTED', onError: (Object error) => error);
      final cancelAttempt = dataSource
          .cancelOrder(order.id)
          .then<Object?>((_) => 'CANCELLED', onError: (Object error) => error);
      final results = await Future.wait<Object?>([startAttempt, cancelAttempt]);
      final successfulTransitions = results.whereType<String>().toList();
      final persisted = await dataSource.getOrder(order.id);
      final db = await FurnexaDatabase.instance.database;

      expect(successfulTransitions, hasLength(1));
      if (successfulTransitions.single == 'STARTED') {
        expect(persisted.status, ProductionOrderStatus.inProgress);
        expect(results[1], isA<Exception>());
      } else {
        expect(persisted.status, ProductionOrderStatus.cancelled);
        expect(results[0], isA<Exception>());
      }
      expect(await db.query('stock_transactions'), isEmpty);
      expect(await db.query('inventory_valuations'), hasLength(1));
      expect(await dataSource.consumptions(order.id), isEmpty);
      expect(await dataSource.waste(order.id), isEmpty);
      expect(await dataSource.outputs(order.id), isEmpty);
    },
  );

  test(
    'stage progression persists and final stage does not complete the order',
    () async {
      final order = await plannedOrder([firstStageId, secondStageId]);
      await startOrder(order);
      final initial = await dataSource.getOrder(order.id);
      final first = initial.stages.first;
      final second = initial.stages.last;
      final db = await FurnexaDatabase.instance.database;
      final initialTransactionCount = (await db.query(
        'stock_transactions',
      )).length;

      await expectLater(
        dataSource.startStage('not-in-order-snapshot'),
        throwsException,
      );
      await expectLater(dataSource.completeStage(first.id), throwsException);
      await expectLater(dataSource.startStage(second.id), throwsException);
      expect(
        (await dataSource.getOrder(
          order.id,
        )).stages.map((stage) => stage.status),
        initial.stages.map((stage) => stage.status),
      );
      final logsBeforeStart = await SecurityLocalDataSource().auditLogs(
        module: 'Production',
        action: 'STAGE_START',
      );
      expect(logsBeforeStart, isEmpty);

      await dataSource.startStage(first.id);
      await expectLater(dataSource.startStage(first.id), throwsException);
      expect(
        (await SecurityLocalDataSource().auditLogs(
          module: 'Production',
          action: 'STAGE_START',
        )).where((entry) => entry.entityId == first.id),
        hasLength(1),
      );
      await dataSource.completeStage(first.id);
      await expectLater(dataSource.completeStage(first.id), throwsException);

      final afterFirst = await dataSource.getOrder(order.id);
      expect(afterFirst.stages.first.status, ProductionStageStatus.completed);
      expect(afterFirst.stages.last.status, ProductionStageStatus.pending);
      expect(afterFirst.status, ProductionOrderStatus.inProgress);
      await expectLater(dataSource.startStage(first.id), throwsException);
      expect(
        (await SecurityLocalDataSource().auditLogs(
          module: 'Production',
          action: 'STAGE_COMPLETE',
        )).where((entry) => entry.entityId == first.id),
        hasLength(1),
      );

      await dataSource.startStage(second.id);
      await dataSource.completeStage(second.id);
      final afterFinal = await dataSource.getOrder(order.id);
      expect(afterFinal.stages.last.status, ProductionStageStatus.completed);
      expect(afterFinal.status, ProductionOrderStatus.inProgress);
      expect(
        await db.query('stock_transactions'),
        hasLength(initialTransactionCount),
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'itemType = ?',
          whereArgs: ['PRODUCT'],
        )),
        isEmpty,
      );
      expect(
        (await SecurityLocalDataSource().auditLogs(
          module: 'Production',
          action: 'STAGE_START',
        )).where((entry) => entry.entityId == second.id),
        hasLength(1),
      );
    },
  );

  test(
    'skip requires a reason, respects sequence, and persists for reload',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final thirdStageId = 'production-stage-three-$suffix';
      await db.insert('production_stages', {
        'id': thirdStageId,
        'factoryId': factoryId,
        'name': 'دهان $suffix',
        'code': 'PAINT-$suffix',
        'sequence': 3,
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await dataSource.saveRoute(productId, [
        firstStageId,
        secondStageId,
        thirdStageId,
      ]);
      final threeStageOrder = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 2,
      );
      await dataSource.planOrder(threeStageOrder.id);
      await dataSource.startOrder(threeStageOrder.id);
      final stages = (await dataSource.getOrder(threeStageOrder.id)).stages;
      await expectLater(
        dataSource.skipStage(stages[2].id, 'تخطي مبكر'),
        throwsException,
      );
      await expectLater(
        dataSource.skipStage(stages.first.id, '  '),
        throwsException,
      );
      expect(
        await SecurityLocalDataSource().auditLogs(
          module: 'Production',
          action: 'STAGE_SKIP',
        ),
        isEmpty,
      );

      await dataSource.skipStage(stages.first.id, 'تعطل معدة القص');
      final afterSkip = await dataSource.getOrder(threeStageOrder.id);
      expect(afterSkip.stages.first.status, ProductionStageStatus.skipped);
      expect(afterSkip.stages.first.notes, 'تعطل معدة القص');
      expect(
        (await dataSource.getOrder(threeStageOrder.id)).stages[1].status,
        ProductionStageStatus.pending,
      );
      await dataSource.startStage(stages[1].id);
      await dataSource.skipStage(stages[1].id, 'إعادة جدولة');
      await dataSource.startStage(stages[2].id);
      await expectLater(dataSource.startStage(stages[1].id), throwsException);
      expect(
        (await SecurityLocalDataSource().auditLogs(
          module: 'Production',
          action: 'STAGE_SKIP',
        )),
        hasLength(2),
      );
    },
  );

  test(
    'stage start enforces authorization and production-stage scope',
    () async {
      final order = await plannedOrder([firstStageId]);
      await startOrder(order);
      final stage = (await dataSource.getOrder(order.id)).stages.single;
      final security = SecurityLocalDataSource();
      final role = await security.createRole(name: 'Stage Scope $suffix');
      await security.setRolePermissions(role.id, ['PRODUCTION_EDIT']);
      final user = await security.createUser(
        username: 'stage-scope-$suffix',
        displayName: 'Stage Scope',
        password: 'secret',
        roleId: role.id,
      );
      await security.setUserScopes(user.id, const []);
      security.logout();
      await security.login(user.username, 'secret');

      await expectLater(dataSource.startStage(stage.id), throwsException);
      expect(
        (await dataSource.getOrder(order.id)).stages.single.status,
        ProductionStageStatus.pending,
      );
      expect(
        await (await FurnexaDatabase.instance.database).query(
          'audit_logs',
          where: 'module = ? AND action = ?',
          whereArgs: ['Production', 'STAGE_START'],
        ),
        isEmpty,
      );
    },
  );

  test('stage transition requires Production edit permission', () async {
    final order = await plannedOrder([firstStageId]);
    await startOrder(order);
    final stage = (await dataSource.getOrder(order.id)).stages.single;
    final security = SecurityLocalDataSource();
    final role = await security.createRole(name: 'No Production Edit $suffix');
    await security.setRolePermissions(role.id, []);
    final user = await security.createUser(
      username: 'no-production-edit-$suffix',
      displayName: 'No Production Edit',
      password: 'secret',
      roleId: role.id,
    );
    security.logout();
    await security.login(user.username, 'secret');

    await expectLater(dataSource.startStage(stage.id), throwsException);
    expect(
      (await dataSource.getOrder(order.id)).stages.single.status,
      ProductionStageStatus.pending,
    );
    expect(
      await (await FurnexaDatabase.instance.database).query(
        'audit_logs',
        where: 'module = ? AND action = ?',
        whereArgs: ['Production', 'STAGE_START'],
      ),
      isEmpty,
    );
  });

  test('consumption and output integrate with stock atomically', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2,
    );
    await dataSource.planOrder(order.id);
    await dataSource.startOrder(order.id);
    await dataSource.startStage(order.stages.first.id);
    await dataSource.completeStage(order.stages.first.id);
    await dataSource.consumeMaterial(
      orderId: order.id,
      rawMaterialId: rawMaterialId,
      warehouseId: warehouseId,
      quantity: 5,
      date: now,
      operationId: 'consume-first-$suffix',
    );
    expect(
      () => dataSource.consumeMaterial(
        orderId: order.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 6,
        date: now,
        operationId: 'consume-over-limit-$suffix',
      ),
      throwsException,
    );
    await dataSource.consumeMaterial(
      orderId: order.id,
      rawMaterialId: rawMaterialId,
      warehouseId: warehouseId,
      quantity: 5,
      date: now,
      operationId: 'consume-second-$suffix',
    );
    await dataSource.recordOutput(
      orderId: order.id,
      warehouseId: warehouseId,
      quantity: 1,
      date: now,
      operationId: 'production-output-$suffix',
    );
    await dataSource.recordOutput(
      orderId: order.id,
      warehouseId: warehouseId,
      quantity: 1,
      date: now,
      operationId: 'production-output-$suffix',
    );
    final stored = await dataSource.getOrder(order.id);
    expect(stored.producedQuantity, 1);
    expect(stored.status, ProductionOrderStatus.inProgress);
    final db = await FurnexaDatabase.instance.database;
    final raw = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ?',
      whereArgs: [warehouseId, rawMaterialId],
    );
    final product = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ?',
      whereArgs: [warehouseId, productId],
    );
    expect(raw.single['quantity'], 0);
    expect(product.single['quantity'], 1);
    final valuation = await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, rawMaterialId, 'RAW_MATERIAL'],
      limit: 1,
    );
    expect((valuation.single['quantity'] as num).toDouble(), 0);
    expect((valuation.single['averageCost'] as num).toDouble(), 10);
    expect(
      await db.query(
        'stock_transactions',
        where: 'warehouseId = ?',
        whereArgs: [warehouseId],
      ),
      hasLength(3),
    );
  });

  test(
    'consumption operation replay is idempotent and auditable once',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final order = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 2,
      );
      await (await FurnexaDatabase.instance.database).update(
        'product_bom_items',
        {'quantity': 1},
        where: 'productId = ? AND rawMaterialId = ?',
        whereArgs: [productId, rawMaterialId],
      );
      await dataSource.planOrder(order.id);
      await dataSource.startOrder(order.id);
      await dataSource.startStage(order.stages.single.id);
      await dataSource.completeStage(order.stages.single.id);

      Future<void> consume(String operationId, double quantity) =>
          dataSource.consumeMaterial(
            orderId: order.id,
            rawMaterialId: rawMaterialId,
            warehouseId: warehouseId,
            quantity: quantity,
            date: now,
            operationId: operationId,
          );

      const firstOperation = 'production-consume-retry-a';
      await consume(firstOperation, 2);
      final db = await FurnexaDatabase.instance.database;
      expect(
        (await db.rawQuery(
          'PRAGMA table_info(production_material_consumptions)',
        )).any((column) => column['name'] == 'operationId'),
        isTrue,
      );
      expect(
        (await db.rawQuery(
          'PRAGMA index_list(production_material_consumptions)',
        )).any(
          (index) =>
              index['name'] == 'idx_production_consumption_operation' &&
              index['unique'] == 1,
        ),
        isTrue,
      );
      final firstBalance = await db.query(
        'stock_balances',
        columns: ['quantity'],
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, rawMaterialId],
        limit: 1,
      );
      expect((firstBalance.single['quantity'] as num).toDouble(), 8);

      await consume(firstOperation, 2);
      expect(
        (await db.query(
          'stock_balances',
          columns: ['quantity'],
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, rawMaterialId],
          limit: 1,
        )).single['quantity'],
        8,
      );
      var records = await dataSource.consumptions(order.id);
      expect(records, hasLength(1));
      expect(records.single.operationId, firstOperation);
      expect(records.single.unitCost, 10);
      expect(records.single.rawMaterialCode, 'PR-$suffix');
      expect(records.single.warehouseName, 'مخزن إنتاج $suffix');
      expect(
        (await dataSource.requirements(order.id)).single.requiredQuantity,
        10,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'reference = ?',
          whereArgs: ['OPERATION:PRODUCTION_CONSUMPTION:$firstOperation'],
        ),
        hasLength(1),
      );
      expect(
        (await SecurityLocalDataSource().auditLogs(
          module: 'Production',
        )).where((entry) => entry.action == 'MATERIAL_CONSUMPTION'),
        hasLength(1),
      );

      await consume('production-consume-retry-b', 3);
      records = await dataSource.consumptions(order.id);
      expect(records, hasLength(2));
      expect(
        (await dataSource.requirements(order.id)).single.remainingQuantity,
        5,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemType = ?',
          whereArgs: [warehouseId, 'RAW_MATERIAL'],
        ),
        hasLength(2),
      );
      expect(
        (await SecurityLocalDataSource().auditLogs(
          module: 'Production',
        )).where((entry) => entry.action == 'MATERIAL_CONSUMPTION'),
        hasLength(2),
      );

      await expectLater(consume(firstOperation, 1), throwsException);
    },
  );

  test(
    'insufficient stock rolls back balance valuation transaction and record',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final order = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 5,
      );
      await dataSource.planOrder(order.id);
      await dataSource.startOrder(order.id);
      await dataSource.startStage(order.stages.single.id);
      await dataSource.completeStage(order.stages.single.id);
      final db = await FurnexaDatabase.instance.database;

      await expectLater(
        dataSource.consumeMaterial(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 11,
          date: now,
          operationId: 'production-consume-insufficient',
        ),
        throwsException,
      );

      expect(
        (await db.query(
          'stock_balances',
          columns: ['quantity'],
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, rawMaterialId],
        )).single['quantity'],
        10,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          columns: ['quantity'],
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, rawMaterialId],
        )).single['quantity'],
        10,
      );
      expect(await dataSource.consumptions(order.id), isEmpty);
      expect(
        await db.query(
          'stock_transactions',
          where: 'reference = ?',
          whereArgs: [
            'OPERATION:PRODUCTION_CONSUMPTION:production-consume-insufficient',
          ],
        ),
        isEmpty,
      );
      expect(
        (await SecurityLocalDataSource().auditLogs(
          module: 'Production',
        )).where((entry) => entry.action == 'MATERIAL_CONSUMPTION'),
        isEmpty,
      );
    },
  );

  test('consumption is rejected before the order enters production', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2,
    );
    await dataSource.planOrder(order.id);
    await expectLater(
      dataSource.consumeMaterial(
        orderId: order.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 1,
        date: now,
        operationId: 'production-consume-before-start',
      ),
      throwsException,
    );
    expect(await dataSource.consumptions(order.id), isEmpty);
  });

  test(
    'consumption rejects invalid quantities and changed material units',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final order = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 2,
      );
      await dataSource.planOrder(order.id);
      await dataSource.startOrder(order.id);
      await dataSource.startStage(order.stages.single.id);
      await dataSource.completeStage(order.stages.single.id);

      for (final quantity in [0.0, -1.0, double.nan, double.infinity]) {
        await expectLater(
          dataSource.consumeMaterial(
            orderId: order.id,
            rawMaterialId: rawMaterialId,
            warehouseId: warehouseId,
            quantity: quantity,
            date: now,
            operationId: 'invalid-$quantity',
          ),
          throwsException,
        );
      }

      final secondUnitId = 'production-second-unit-$suffix';
      final db = await FurnexaDatabase.instance.database;
      await db.insert('units', {
        'id': secondUnitId,
        'name': 'وحدة بديلة $suffix',
        'abbreviation': 'PU2$suffix',
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.update(
        'raw_materials',
        {'unitId': secondUnitId},
        where: 'id = ?',
        whereArgs: [rawMaterialId],
      );

      await expectLater(
        dataSource.consumeMaterial(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: 'production-consume-wrong-unit',
        ),
        throwsException,
      );
      expect(await dataSource.consumptions(order.id), isEmpty);
    },
  );

  test('consumption rejects an inactive snapshotted unit', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 2,
    );
    await dataSource.planOrder(order.id);
    await dataSource.startOrder(order.id);
    await dataSource.startStage(order.stages.single.id);
    await dataSource.completeStage(order.stages.single.id);
    await (await FurnexaDatabase.instance.database).update(
      'units',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [unitId],
    );

    await expectLater(
      dataSource.consumeMaterial(
        orderId: order.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 1,
        date: now,
        operationId: 'production-consume-inactive-unit',
      ),
      throwsException,
    );
    expect(await dataSource.consumptions(order.id), isEmpty);
  });

  test(
    'consumption enforces Production authorization and warehouse scope',
    () async {
      await dataSource.saveRoute(productId, [firstStageId]);
      final order = await dataSource.createOrder(
        productId: productId,
        plannedQuantity: 2,
      );
      await dataSource.planOrder(order.id);
      await dataSource.startOrder(order.id);
      await dataSource.startStage(order.stages.single.id);
      await dataSource.completeStage(order.stages.single.id);
      final security = SecurityLocalDataSource();
      security.logout();
      await expectLater(
        dataSource.consumeMaterial(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: 'production-consume-no-session',
        ),
        throwsException,
      );

      await security.login('admin', 'Furnexa-Test-Admin-2026!');
      final role = await security.createRole(name: 'Production Scope $suffix');
      await security.setRolePermissions(role.id, ['PRODUCTION_EDIT']);
      final user = await security.createUser(
        username: 'prod-scope-$suffix',
        displayName: 'Production Scope',
        password: 'secret',
        roleId: role.id,
      );
      await security.setUserScopes(user.id, const []);
      security.logout();
      await security.login(user.username, 'secret');
      await expectLater(
        dataSource.consumeMaterial(
          orderId: order.id,
          rawMaterialId: rawMaterialId,
          warehouseId: warehouseId,
          quantity: 1,
          date: now,
          operationId: 'production-consume-out-of-scope',
        ),
        throwsException,
      );
      expect(await dataSource.consumptions(order.id), isEmpty);
    },
  );

  test('production order requires a route', () async {
    expect(
      () => dataSource.createOrder(productId: productId, plannedQuantity: 1),
      throwsException,
    );
  });

  test('existing route is updated without creating duplicates', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final db = await FurnexaDatabase.instance.database;
    final before = await db.query('production_routes');
    expect(before, hasLength(1));

    await dataSource.saveRoute(productId, [firstStageId, secondStageId]);

    final after = await db.query('production_routes');
    expect(after, hasLength(1));
    expect(
      (await db.query(
        'production_route_stages',
        where: 'routeId = ?',
        whereArgs: [after.single['id']],
      )),
      hasLength(2),
    );
  });

  test('waste must reference a material in the order BOM', () async {
    await dataSource.saveRoute(productId, [firstStageId]);
    final order = await dataSource.createOrder(
      productId: productId,
      plannedQuantity: 1,
    );
    await dataSource.planOrder(order.id);
    await dataSource.startOrder(order.id);
    final db = await FurnexaDatabase.instance.database;
    final otherMaterialId = 'other-material-$suffix';
    await db.insert('raw_materials', {
      'id': otherMaterialId,
      'name': 'خامة أخرى $suffix',
      'code': 'OTHER-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    expect(
      () => dataSource.recordWaste(
        orderId: order.id,
        rawMaterialId: otherMaterialId,
        warehouseId: warehouseId,
        quantity: 1,
        reason: 'invalid',
        date: now,
      ),
      throwsException,
    );
  });

  testWidgets('new route form starts without a selected product', (
    tester,
  ) async {
    final product = Product(
      id: 'widget-product',
      name: 'منتج اختبار',
      code: 'WIDGET-PRODUCT',
      categoryId: 'widget-category',
      unitId: 'widget-unit',
      createdAt: now,
      updatedAt: now,
    );
    final stage = ProductionStage(
      id: 'widget-stage',
      factoryId: 'widget-factory',
      name: 'مرحلة اختبار',
      code: 'WIDGET-STAGE',
      sequence: 1,
      active: true,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteForm(
            products: [product],
            product: null,
            stages: [stage],
            selected: const [],
          ),
        ),
      ),
    );

    expect(find.text('مسار إنتاج جديد'), findsOneWidget);
    expect(find.text('اختر المنتج'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'حفظ المسار'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('production order form exposes variants and BOM readiness', (
    tester,
  ) async {
    final formContext = (await tester.runAsync(() async {
      final db = await FurnexaDatabase.instance.database;
      final variantId = 'production-form-variant-$suffix';
      await db.insert('product_variants', {
        'id': variantId,
        'productId': productId,
        'name': 'كرسي أزرق $suffix',
        'code': 'PFV-$suffix',
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await dataSource.saveRoute(productId, [firstStageId]);
      return (
        products: await dataSource.activeProducts(),
        variants: await dataSource.activeVariants(productId),
        route: await dataSource.routeForProduct(productId),
        bomValid: await dataSource.productBomIsValid(productId),
      );
    }))!;

    await tester.pumpWidget(
      MaterialApp(
        home: ProductionOrderForm(
          products: formContext.products,
          repository: _ProductionOrderFormRepository(
            variants: formContext.variants,
            route: formContext.route,
            bomValid: formContext.bomValid,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('البديل (مطلوب)'), findsOneWidget);
    expect(find.text('قائمة الخامات صالحة للتنفيذ.'), findsOneWidget);
    expect(find.text('المسار المعتمد لهذا المنتج'), findsOneWidget);

    await tester.tap(find.text('حفظ كمسودة'));
    await tester.pumpAndSettle();
    expect(find.text('يجب اختيار بديل المنتج'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<ProductVariant>));
    await tester.pumpAndSettle();
    expect(find.text('كرسي أزرق $suffix • PFV-$suffix'), findsOneWidget);
  });

  testWidgets('empty BOM remains a draft with a visible execution warning', (
    tester,
  ) async {
    final db = await FurnexaDatabase.instance.database;
    await db.delete(
      'product_bom_items',
      where: 'productId = ?',
      whereArgs: [productId],
    );
    await dataSource.saveRoute(productId, [firstStageId]);

    await tester.pumpWidget(
      MaterialApp(
        home: ProductionOrderForm(
          products: await dataSource.activeProducts(),
          repository: ProductionRepositoryImpl(dataSource),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('لا يمكن بدء الإنتاج قبل استكمال قائمة الخامات'),
      findsOneWidget,
    );
    expect(find.text('حفظ كمسودة'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'not-a-number');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ كمسودة'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل كمية صالحة أكبر من صفر'), findsOneWidget);
  });
}

class _ProductionOrderFormRepository implements ProductionRepository {
  const _ProductionOrderFormRepository({
    required this.variants,
    required this.route,
    required this.bomValid,
  });

  final List<ProductVariant> variants;
  final ProductionRoute? route;
  final bool bomValid;

  @override
  Future<List<ProductVariant>> activeVariants(String productId) async =>
      variants;

  @override
  Future<ProductionRoute?> routeForProduct(String productId) async => route;

  @override
  Future<bool> productBomIsValid(String productId) async => bomValid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
