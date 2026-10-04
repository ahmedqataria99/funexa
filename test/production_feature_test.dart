import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/production/data/datasources/production_local_data_source.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/production/presentation/pages/production_page.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
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
      ),
      throwsException,
    );
    await dataSource.completeStage(started.stages.first.id);
    await dataSource.startStage(started.stages[1].id);
    await expectLater(dataSource.cancelOrder(order.id), throwsException);
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
    );
    expect(
      () => dataSource.consumeMaterial(
        orderId: order.id,
        rawMaterialId: rawMaterialId,
        warehouseId: warehouseId,
        quantity: 6,
        date: now,
      ),
      throwsException,
    );
    await dataSource.recordOutput(
      orderId: order.id,
      warehouseId: warehouseId,
      quantity: 1,
      date: now,
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
    expect(raw.single['quantity'], 5);
    expect(product.single['quantity'], 1);
    final valuation = await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, rawMaterialId, 'RAW_MATERIAL'],
      limit: 1,
    );
    expect((valuation.single['quantity'] as num).toDouble(), 5);
    expect((valuation.single['averageCost'] as num).toDouble(), 10);
    expect(
      await db.query(
        'stock_transactions',
        where: 'warehouseId = ?',
        whereArgs: [warehouseId],
      ),
      hasLength(2),
    );
  });

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
}
