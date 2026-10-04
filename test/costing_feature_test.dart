import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/costing/data/datasources/costing_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late CostingLocalDataSource costing;
  late SecurityLocalDataSource security;
  late String suffix;
  late DateTime now;
  late String factoryId;
  late String warehouseId;
  late String secondWarehouseId;
  late String categoryId;
  late String unitId;
  late String materialId;
  late String productId;
  late String routeId;
  late String productionStageId;
  late String workerId;
  late String orderId;
  late String shiftId;
  late Database db;

  setUp(() async {
    await DatabaseTestHelper.reset();
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime(2026, 9, 17);
    costing = CostingLocalDataSource();
    security = SecurityLocalDataSource();
    db = await FurnexaDatabase.instance.database;

    await db.delete('production_batch_costs');
    await db.delete('production_other_costs');
    await db.delete('production_cost_adjustments');
    await db.delete('costing_overhead_rules');
    await db.delete('production_outputs');
    await db.delete('production_waste');
    await db.delete('production_material_consumptions');
    await db.delete('production_order_stages');
    await db.delete('production_orders');
    await db.delete('production_routes');
    await db.delete('production_route_stages');
    await db.delete('inventory_valuations');
    await db.delete('stock_transactions');
    await db.delete('stock_balances');
    await db.delete('product_bom_items');
    await db.delete('products');
    await db.delete('raw_materials');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('warehouses');
    await db.delete('factories');
    await db.delete('production_stages');
    await db.delete('workers');
    await db.delete('attendance_records');
    await db.delete('shifts');

    factoryId = 'costing-factory-$suffix';
    warehouseId = 'costing-warehouse-$suffix';
    secondWarehouseId = 'costing-warehouse-2-$suffix';
    categoryId = 'costing-category-$suffix';
    unitId = 'costing-unit-$suffix';
    materialId = 'costing-material-$suffix';
    productId = 'costing-product-$suffix';
    routeId = 'costing-route-$suffix';
    productionStageId = 'costing-stage-$suffix';
    workerId = 'costing-worker-$suffix';
    orderId = 'costing-order-$suffix';
    shiftId = 'shift-$suffix';

    await db.insert('factories', {
      'id': factoryId,
      'name': 'مصنع التكلفة $suffix',
      'code': 'COST-$suffix',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('production_stages', {
      'id': productionStageId,
      'factoryId': factoryId,
      'name': 'Costing Stage $suffix',
      'code': 'CSTG-$suffix',
      'sequence': 1,
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'مخزن التكلفة $suffix',
      'code': 'WCOST-$suffix',
      'state': 'active',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('warehouses', {
      'id': secondWarehouseId,
      'factoryId': factoryId,
      'name': 'مخزن التكلفة 2 $suffix',
      'code': 'WCOST2-$suffix',
      'state': 'active',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'تصنيف التكلفة $suffix',
      'code': 'CATCOST-$suffix',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'وحدة التكلفة $suffix',
      'abbreviation': 'UCOST$suffix',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('raw_materials', {
      'id': materialId,
      'name': 'خامة التكلفة $suffix',
      'code': 'RM-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'منتج التكلفة $suffix',
      'code': 'PROD-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('product_bom_items', {
      'id': 'bom-$suffix',
      'productId': productId,
      'rawMaterialId': materialId,
      'quantity': 2,
    });
    await db.insert('inventory_valuations', {
      'id': 'iv-$suffix',
      'warehouseId': warehouseId,
      'itemId': materialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 20,
      'averageCost': 100,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('workers', {
      'id': workerId,
      'employeeCode': 'EMP-$suffix',
      'name': 'عامل التكلفة $suffix',
      'hireDate': now.millisecondsSinceEpoch,
      'active': 1,
      'basicSalary': 4000,
      'salaryType': 'MONTHLY',
      'overtimeEnabled': 1,
      'overtimeRateOverride': 50,
      'productionStageId': productionStageId,
      'annualLeaveAllowance': 0,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('shifts', {
      'id': shiftId,
      'name': 'Shift $suffix',
      'startTime': '08:00',
      'endTime': '17:00',
      'graceMinutes': 0,
      'overtimeEnabled': 1,
      'overtimeStartAfterMinutes': 60,
      'overtimeRate': 50,
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('production_routes', {
      'id': routeId,
      'productId': productId,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('production_orders', {
      'id': orderId,
      'orderNumber': 'PO-$suffix',
      'productId': productId,
      'routeId': routeId,
      'plannedQuantity': 10,
      'producedQuantity': 0,
      'status': 'COMPLETED',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('production_order_stages', {
      'id': 'order-stage-$suffix',
      'productionOrderId': orderId,
      'productionStageId': productionStageId,
      'sequence': 1,
      'status': 'COMPLETED',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('production_material_consumptions', {
      'id': 'cons-$suffix',
      'productionOrderId': orderId,
      'rawMaterialId': materialId,
      'warehouseId': warehouseId,
      'quantity': 10,
      'unitId': unitId,
      'consumptionDate': now.millisecondsSinceEpoch,
      'createdAt': now.millisecondsSinceEpoch,
    });
    await db.insert('attendance_records', {
      'id': 'att-$suffix',
      'workerId': workerId,
      'shiftId': shiftId,
      'workDate': now.millisecondsSinceEpoch,
      'regularHours': 8,
      'overtimeHours': 2,
      'overtimeRate': 50,
      'overtimeAmount': 100,
      'status': 'PRESENT',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    await security.ensureInitialAdmin();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  test(
    '1. estimated material cost uses BOM quantity and current material cost',
    () async {
      final estimate = await costing.estimateProductCost(
        productId,
        quantity: 10,
      );
      expect(estimate.materialEstimatedCost, 2000);
      expect(estimate.totalEstimatedCost, 2000);
    },
  );

  test('2. actual material cost from production consumption', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 0,
      overheadRate: 0,
      goodFinishedQuantity: 9,
    );

    expect(batch.materialCost, 1000);
    expect(batch.totalCost, 1000);
    expect(batch.actualUnitCost, closeTo(111.11, 0.01));
  });

  test('3. weighted-average material cost reuse', () async {
    await db.delete('inventory_valuations');
    await db.insert('inventory_valuations', {
      'id': 'iv-1-$suffix',
      'warehouseId': warehouseId,
      'itemId': materialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 5,
      'averageCost': 80,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('inventory_valuations', {
      'id': 'iv-2-$suffix',
      'warehouseId': secondWarehouseId,
      'itemId': materialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 15,
      'averageCost': 120,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    final estimate = await costing.estimateProductCost(productId, quantity: 1);
    expect(estimate.materialEstimatedCost, 220);
    expect(estimate.totalEstimatedCost, 220);
  });

  test('4. direct labor cost is included', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 250,
      overheadRate: 0,
      goodFinishedQuantity: 10,
    );

    expect(batch.laborCost, 250);
    expect(batch.totalCost, 1250);
  });

  test('5. overtime cost is included from attendance', () async {
    await db.insert('workers', {
      'id': 'unrelated-worker-$suffix',
      'employeeCode': 'UNRELATED-$suffix',
      'name': 'Unrelated Worker',
      'hireDate': now.millisecondsSinceEpoch,
      'active': 1,
      'basicSalary': 9999,
      'salaryType': 'MONTHLY',
      'overtimeEnabled': 1,
      'overtimeRateOverride': 999,
      'annualLeaveAllowance': 0,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('attendance_records', {
      'id': 'unrelated-attendance-$suffix',
      'workerId': 'unrelated-worker-$suffix',
      'shiftId': shiftId,
      'workDate': now.millisecondsSinceEpoch,
      'regularHours': 8,
      'overtimeHours': 2,
      'overtimeRate': 999,
      'overtimeAmount': 1998,
      'status': 'PRESENT',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      overheadRate: 0,
      goodFinishedQuantity: 10,
    );

    expect(batch.laborCost, 300);
  });

  test(
    'same-worker attendance labor is isolated to its explicitly allocated order',
    () async {
      final secondOrderId = 'costing-order-2-$suffix';
      await db.insert('production_orders', {
        'id': secondOrderId,
        'orderNumber': 'PO-2-$suffix',
        'productId': productId,
        'routeId': routeId,
        'plannedQuantity': 10,
        'producedQuantity': 0,
        'status': 'COMPLETED',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.insert('production_order_stages', {
        'id': 'order-stage-2-$suffix',
        'productionOrderId': secondOrderId,
        'productionStageId': productionStageId,
        'sequence': 1,
        'status': 'COMPLETED',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      final ambiguousOrderA = await costing.calculateBatchCost(
        productionOrderId: orderId,
        overheadRate: 0,
        goodFinishedQuantity: 10,
      );
      final ambiguousOrderB = await costing.calculateBatchCost(
        productionOrderId: secondOrderId,
        overheadRate: 0,
        goodFinishedQuantity: 10,
      );
      expect(ambiguousOrderA.laborCost, 0);
      expect(ambiguousOrderB.laborCost, 0);

      await costing.allocateAttendanceToProductionOrder(
        productionOrderId: orderId,
        attendanceId: 'att-$suffix',
        regularHours: 8,
        overtimeHours: 2,
      );

      final allocatedOrderA = await costing.calculateBatchCost(
        productionOrderId: orderId,
        overheadRate: 0,
        goodFinishedQuantity: 10,
      );
      final allocatedOrderB = await costing.calculateBatchCost(
        productionOrderId: secondOrderId,
        overheadRate: 0,
        goodFinishedQuantity: 10,
      );
      expect(allocatedOrderA.laborCost, 300);
      expect(allocatedOrderB.laborCost, 0);

      await expectLater(
        costing.allocateAttendanceToProductionOrder(
          productionOrderId: secondOrderId,
          attendanceId: 'att-$suffix',
          regularHours: 1,
          overtimeHours: 0,
        ),
        throwsException,
      );
      await expectLater(
        costing.allocateAttendanceToProductionOrder(
          productionOrderId: secondOrderId,
          attendanceId: 'att-$suffix',
          regularHours: 8,
          overtimeHours: 2,
        ),
        throwsException,
      );

      final recalculatedOrderA = await costing.calculateBatchCost(
        productionOrderId: orderId,
        overheadRate: 0,
        goodFinishedQuantity: 10,
      );
      final recalculatedOrderB = await costing.calculateBatchCost(
        productionOrderId: secondOrderId,
        overheadRate: 0,
        goodFinishedQuantity: 10,
      );
      expect(recalculatedOrderA.laborCost, 300);
      expect(recalculatedOrderB.laborCost, 0);
    },
  );

  test('costing mutation requires its existing permission', () async {
    security.logout();
    expect(
      () => costing.saveOverheadRule(
        OverheadRule(
          id: 'unauthorized-rule-$suffix',
          name: 'Unauthorized',
          calculationType: 'PERCENTAGE',
          rate: 1,
          base: OverheadBase.materialCost,
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsException,
    );
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
  });

  test('6. percentage overhead is applied', () async {
    await db.insert('costing_overhead_rules', {
      'id': 'overhead-$suffix',
      'name': 'Factory overhead',
      'calculationType': 'PERCENTAGE',
      'rate': 10,
      'base': 'MATERIAL_COST',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    final estimate = await costing.estimateProductCost(productId, quantity: 10);
    expect(estimate.overheadEstimatedCost, 200);
    expect(estimate.totalEstimatedCost, 2200);
  });

  test('7. overhead base changes the calculation basis', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      materialCost: 1000,
      laborCost: 200,
      overheadRate: 10,
      overheadBase: OverheadBase.materialPlusLabor,
      goodFinishedQuantity: 8,
    );

    expect(batch.overheadCost, 120);
    expect(batch.totalCost, 1320);
  });

  test('8. other production costs are added', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 0,
      overheadRate: 0,
      otherCosts: [
        ProductionOtherCostInput(
          id: 'other-$suffix',
          productionOrderId: orderId,
          description: 'Machine usage',
          amount: 150,
          date: now,
          createdBy: 'admin',
        ),
      ],
      goodFinishedQuantity: 10,
    );

    expect(batch.otherCost, 150);
    expect(batch.totalCost, 1150);
  });

  test('9. scrap recovery reduces total cost', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 400,
      overheadRate: 10,
      otherCosts: [
        ProductionOtherCostInput(
          id: 'scrap-$suffix',
          productionOrderId: orderId,
          description: 'Scrap handling',
          amount: 50,
          date: now,
          createdBy: 'admin',
        ),
      ],
      scrapRecovery: 100,
      goodFinishedQuantity: 9,
    );

    expect(batch.scrapRecovery, 100);
    expect(batch.totalCost, 1450);
  });

  test('10. good finished quantity determines actual unit cost', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 400,
      overheadRate: 10,
      otherCosts: [
        ProductionOtherCostInput(
          id: 'unit-$suffix',
          productionOrderId: orderId,
          description: 'Utilities',
          amount: 50,
          date: now,
          createdBy: 'admin',
        ),
      ],
      goodFinishedQuantity: 8,
    );

    expect(batch.goodFinishedQuantity, 8);
    expect(batch.actualUnitCost, closeTo(193.75, 0.01));
  });

  test('11. zero good quantity cannot finalize', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 100,
      overheadRate: 0,
      goodFinishedQuantity: 0,
    );

    expect(
      () => costing.finalizeBatchCost(batch.productionOrderId, 'admin'),
      throwsException,
    );
  });

  test('12. estimated and actual cost remain separate', () async {
    final estimate = await costing.estimateProductCost(productId, quantity: 10);
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 400,
      overheadRate: 10,
      goodFinishedQuantity: 9,
    );

    expect(estimate.totalEstimatedCost, 2000);
    expect(batch.totalCost, 1500);
    expect(batch.totalCost != estimate.totalEstimatedCost, isTrue);
  });

  test('13. batch cost calculation stores the expected total', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 300,
      overheadRate: 10,
      otherCosts: [
        ProductionOtherCostInput(
          id: 'batch-$suffix',
          productionOrderId: orderId,
          description: 'Packaging',
          amount: 100,
          date: now,
          createdBy: 'admin',
        ),
      ],
      goodFinishedQuantity: 8,
    );

    expect(batch.materialCost, 1000);
    expect(batch.laborCost, 300);
    expect(batch.overheadCost, 100);
    expect(batch.otherCost, 100);
    expect(batch.totalCost, 1500);
  });

  test('14. finalized cost immutability is enforced', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 500,
      overheadRate: 20,
      goodFinishedQuantity: 8,
    );
    final finalized = await costing.finalizeBatchCost(
      batch.productionOrderId,
      'admin',
    );

    expect(finalized.status, CostStatus.finalized);
    expect(
      () => costing.finalizeBatchCost(batch.productionOrderId, 'admin'),
      throwsException,
    );
  });

  test(
    '15. historical finalized cost remains unchanged after source price changes',
    () async {
      final batch = await costing.calculateBatchCost(
        productionOrderId: orderId,
        laborCost: 400,
        overheadRate: 10,
        goodFinishedQuantity: 9,
      );
      final finalized = await costing.finalizeBatchCost(
        batch.productionOrderId,
        'admin',
      );

      await db.update(
        'inventory_valuations',
        {'averageCost': 200},
        where: 'itemId = ?',
        whereArgs: [materialId],
      );

      final recalculated = await costing.calculateBatchCost(
        productionOrderId: orderId,
        laborCost: 400,
        overheadRate: 10,
        goodFinishedQuantity: 9,
      );

      expect(finalized.totalCost, 1500);
      expect(recalculated.totalCost, finalized.totalCost);
    },
  );

  test('16. last actual cost is exposed', () async {
    final first = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 200,
      overheadRate: 0,
      goodFinishedQuantity: 10,
    );
    await costing.finalizeBatchCost(first.productionOrderId, 'admin');

    final latest = await costing.productLastActualCost(productId);
    expect(latest, first.totalCost);
  });

  test('17. average actual cost is exposed', () async {
    final first = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 200,
      overheadRate: 0,
      goodFinishedQuantity: 10,
    );
    await costing.finalizeBatchCost(first.productionOrderId, 'admin');

    final average = await costing.productAverageActualCost(productId);
    expect(average, first.totalCost / first.goodFinishedQuantity);
  });

  test('18. cost variance is calculated', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 400,
      overheadRate: 10,
      goodFinishedQuantity: 8,
    );

    final variance = await costing.costVariance(orderId);
    expect(variance, batch.totalCost - 2000);
  });

  test('19. margin calculation uses actual cost', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 400,
      overheadRate: 10,
      goodFinishedQuantity: 8,
    );
    await costing.finalizeBatchCost(batch.productionOrderId, 'admin');

    final margin = await costing.grossMargin(productId, sellingPrice: 3000);
    expect(margin, 3000 - batch.totalCost);
  });

  test('20. feature 14 pricing remains unchanged', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 100,
      overheadRate: 0,
      goodFinishedQuantity: 10,
    );
    await costing.finalizeBatchCost(batch.productionOrderId, 'admin');

    expect(batch.totalCost, 1100);
    expect((await costing.productLastActualCost(productId)), batch.totalCost);
  });

  test('21. feature 8 inventory valuation is not duplicated', () async {
    final estimate = await costing.estimateProductCost(productId, quantity: 1);
    final valuationRows = await db.query(
      'inventory_valuations',
      where: 'itemId = ?',
      whereArgs: [materialId],
    );

    expect(valuationRows.length, 1);
    expect(estimate.materialEstimatedCost, 200);
  });

  test('22. permission enforcement is respected', () async {
    expect(await security.can('COSTING_VIEW'), isTrue);
    expect(await security.can('COSTING_MANAGE'), isTrue);
    expect(await security.can('COSTING_FINALIZE'), isTrue);
  });

  test('23. audit creation is recorded', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 100,
      overheadRate: 0,
      goodFinishedQuantity: 9,
    );
    await costing.finalizeBatchCost(batch.productionOrderId, 'admin');

    final logs = await security.auditLogs(module: 'Costing');
    expect(logs.any((log) => log.action == 'BATCH_COST_FINALIZED'), isTrue);
  });

  test('24. batch cost persists after restart', () async {
    final batch = await costing.calculateBatchCost(
      productionOrderId: orderId,
      laborCost: 400,
      overheadRate: 10,
      goodFinishedQuantity: 9,
    );
    await costing.finalizeBatchCost(batch.productionOrderId, 'admin');

    await FurnexaDatabase.instance.close();
    final reopenedDb = await FurnexaDatabase.instance.database;
    final rows = await reopenedDb.query(
      'production_batch_costs',
      where: 'productionOrderId = ?',
      whereArgs: [orderId],
    );

    expect(rows.length, 1);
    expect((rows.first['totalCost'] as num).toDouble(), 1500);
  });
}
