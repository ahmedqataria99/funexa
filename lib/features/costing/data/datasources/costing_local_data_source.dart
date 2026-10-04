import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

enum OverheadBase { materialCost, laborCost, materialPlusLabor }

extension OverheadBaseValue on OverheadBase {
  String get value {
    switch (this) {
      case OverheadBase.materialCost:
        return 'MATERIAL_COST';
      case OverheadBase.laborCost:
        return 'LABOR_COST';
      case OverheadBase.materialPlusLabor:
        return 'MATERIAL_PLUS_LABOR';
    }
  }

  static OverheadBase fromValue(String? value) {
    switch (value) {
      case 'LABOR_COST':
        return OverheadBase.laborCost;
      case 'MATERIAL_PLUS_LABOR':
        return OverheadBase.materialPlusLabor;
      case 'MATERIAL_COST':
      default:
        return OverheadBase.materialCost;
    }
  }
}

enum CostStatus { draft, calculated, finalized }

extension CostStatusValue on CostStatus {
  String get value {
    switch (this) {
      case CostStatus.draft:
        return 'DRAFT';
      case CostStatus.calculated:
        return 'CALCULATED';
      case CostStatus.finalized:
        return 'FINALIZED';
    }
  }

  static CostStatus fromValue(String? value) {
    switch (value) {
      case 'FINALIZED':
        return CostStatus.finalized;
      case 'CALCULATED':
        return CostStatus.calculated;
      case 'DRAFT':
      default:
        return CostStatus.draft;
    }
  }
}

class OverheadRule {
  const OverheadRule({
    required this.id,
    required this.name,
    required this.calculationType,
    required this.rate,
    required this.base,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String calculationType;
  final double rate;
  final OverheadBase base;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'calculationType': calculationType,
    'rate': rate,
    'base': base.value,
    'active': active ? 1 : 0,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory OverheadRule.fromMap(Map<String, Object?> map) => OverheadRule(
    id: map['id'] as String,
    name: map['name'] as String,
    calculationType: map['calculationType'] as String? ?? 'PERCENTAGE',
    rate: (map['rate'] as num?)?.toDouble() ?? 0,
    base: OverheadBaseValue.fromValue(map['base'] as String?),
    active: (map['active'] as int? ?? 0) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}

class ProductionOtherCostInput {
  const ProductionOtherCostInput({
    required this.id,
    required this.productionOrderId,
    required this.description,
    required this.amount,
    required this.date,
    required this.createdBy,
  });

  final String id;
  final String productionOrderId;
  final String description;
  final double amount;
  final DateTime date;
  final String createdBy;

  Map<String, Object?> toMap() => {
    'id': id,
    'productionOrderId': productionOrderId,
    'description': description,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
    'createdBy': createdBy,
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  };
}

class ProductCostEstimate {
  const ProductCostEstimate({
    required this.productId,
    required this.quantity,
    required this.materialEstimatedCost,
    required this.laborEstimatedCost,
    required this.overheadEstimatedCost,
    required this.otherEstimatedCost,
    required this.totalEstimatedCost,
    required this.estimatedUnitCost,
  });

  final String productId;
  final double quantity;
  final double materialEstimatedCost;
  final double laborEstimatedCost;
  final double overheadEstimatedCost;
  final double otherEstimatedCost;
  final double totalEstimatedCost;
  final double estimatedUnitCost;
}

class ProductionBatchCost {
  const ProductionBatchCost({
    required this.id,
    required this.productionOrderId,
    required this.productId,
    required this.plannedQuantity,
    required this.goodFinishedQuantity,
    required this.materialCost,
    required this.laborCost,
    required this.overheadCost,
    required this.otherCost,
    required this.scrapRecovery,
    required this.totalCost,
    required this.actualUnitCost,
    required this.estimatedCost,
    required this.estimatedUnitCost,
    required this.status,
    required this.calculatedAt,
    required this.finalizedAt,
  });

  final String id;
  final String productionOrderId;
  final String productId;
  final double plannedQuantity;
  final double goodFinishedQuantity;
  final double materialCost;
  final double laborCost;
  final double overheadCost;
  final double otherCost;
  final double scrapRecovery;
  final double totalCost;
  final double actualUnitCost;
  final double estimatedCost;
  final double estimatedUnitCost;
  final CostStatus status;
  final DateTime? calculatedAt;
  final DateTime? finalizedAt;

  static ProductionBatchCost fromMap(Map<String, Object?> map) =>
      ProductionBatchCost(
        id: map['id'] as String,
        productionOrderId: map['productionOrderId'] as String,
        productId: map['productId'] as String,
        plannedQuantity: (map['plannedQuantity'] as num).toDouble(),
        goodFinishedQuantity: (map['goodFinishedQuantity'] as num).toDouble(),
        materialCost: (map['materialCost'] as num).toDouble(),
        laborCost: (map['laborCost'] as num).toDouble(),
        overheadCost: (map['overheadCost'] as num).toDouble(),
        otherCost: (map['otherCost'] as num).toDouble(),
        scrapRecovery: (map['scrapRecovery'] as num).toDouble(),
        totalCost: (map['totalCost'] as num).toDouble(),
        actualUnitCost: (map['actualUnitCost'] as num).toDouble(),
        estimatedCost: (map['estimatedCost'] as num).toDouble(),
        estimatedUnitCost: (map['estimatedUnitCost'] as num).toDouble(),
        status: CostStatusValue.fromValue(map['status'] as String?),
        calculatedAt: map['calculatedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['calculatedAt'] as int),
        finalizedAt: map['finalizedAt'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['finalizedAt'] as int),
      );
}

class CostingLocalDataSource {
  final SecurityLocalDataSource _security = SecurityLocalDataSource();
  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<List<OverheadRule>> overheadRules({bool activeOnly = false}) async {
    final db = await _db;
    final rows = await db.query(
      'costing_overhead_rules',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'name ASC',
    );
    return rows.map(OverheadRule.fromMap).toList();
  }

  Future<OverheadRule> saveOverheadRule(OverheadRule rule) async {
    _security.require('COSTING_MANAGE');
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = {
      'id': rule.id,
      'name': rule.name,
      'calculationType': rule.calculationType,
      'rate': rule.rate,
      'base': rule.base.value,
      'active': rule.active ? 1 : 0,
      'createdAt': rule.createdAt.millisecondsSinceEpoch,
      'updatedAt': now,
    };
    final exists = await db.query(
      'costing_overhead_rules',
      where: 'id = ?',
      whereArgs: [rule.id],
      limit: 1,
    );
    if (exists.isNotEmpty) {
      await db.update(
        'costing_overhead_rules',
        row,
        where: 'id = ?',
        whereArgs: [rule.id],
      );
    } else {
      await db.insert('costing_overhead_rules', row);
    }
    final saved = await db.query(
      'costing_overhead_rules',
      where: 'id = ?',
      whereArgs: [rule.id],
      limit: 1,
    );
    await _audit(
      exists.isEmpty ? 'CREATE' : 'UPDATE',
      'Costing',
      'OverheadRule',
      rule.id,
      oldValue: null,
      newValue: '${rule.rate}:${rule.base.value}',
      description: 'Overhead rule saved',
    );
    return OverheadRule.fromMap(saved.first);
  }

  Future<ProductCostEstimate> estimateProductCost(
    String productId, {
    double quantity = 1,
  }) async {
    _security.require('COSTING_CALCULATE');
    if (quantity <= 0) throw Exception('كمية التقدير يجب أن تكون أكبر من صفر');
    final db = await _db;
    final productRows = await db.query(
      'products',
      columns: ['id'],
      where: 'id = ? AND active = 1',
      whereArgs: [productId],
      limit: 1,
    );
    if (productRows.isEmpty) throw Exception('المنتج غير موجود أو غير نشط');

    final bomRows = await db.query(
      'product_bom_items',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'id ASC',
    );
    double materialCost = 0;
    for (final bomRow in bomRows) {
      final rawMaterialId = bomRow['rawMaterialId'] as String;
      final bomQty = (bomRow['quantity'] as num).toDouble();
      final valuations = await db.query(
        'inventory_valuations',
        where: 'itemId = ? AND itemType = ?',
        whereArgs: [rawMaterialId, 'RAW_MATERIAL'],
      );
      if (valuations.isEmpty) continue;
      final totalQuantity = valuations.fold<double>(
        0,
        (sum, row) => sum + (row['quantity'] as num).toDouble(),
      );
      final totalValue = valuations.fold<double>(
        0,
        (sum, row) =>
            sum +
            (row['quantity'] as num).toDouble() *
                (row['averageCost'] as num).toDouble(),
      );
      final average = totalQuantity > 0 ? totalValue / totalQuantity : 0.0;
      materialCost += bomQty * average;
    }
    final materialEstimatedCost = materialCost * quantity;
    final laborEstimatedCost = 0.0;
    final overheadEstimatedCost = await _estimateOverhead(
      base: OverheadBase.materialCost,
      value: materialEstimatedCost,
      laborCost: laborEstimatedCost,
    );
    final otherEstimatedCost = 0.0;
    final total =
        materialEstimatedCost +
        laborEstimatedCost +
        overheadEstimatedCost +
        otherEstimatedCost;
    return ProductCostEstimate(
      productId: productId,
      quantity: quantity,
      materialEstimatedCost: materialEstimatedCost,
      laborEstimatedCost: laborEstimatedCost,
      overheadEstimatedCost: overheadEstimatedCost,
      otherEstimatedCost: otherEstimatedCost,
      totalEstimatedCost: total,
      estimatedUnitCost: quantity > 0 ? total / quantity : 0,
    );
  }

  Future<ProductionBatchCost> calculateBatchCost({
    required String productionOrderId,
    double? materialCost,
    double? laborCost,
    double? overheadRate,
    OverheadBase overheadBase = OverheadBase.materialCost,
    List<ProductionOtherCostInput> otherCosts = const [],
    double scrapRecovery = 0,
    double? goodFinishedQuantity,
  }) async {
    _security.require('COSTING_CALCULATE');
    final db = await _db;
    final existing = await db.query(
      'production_batch_costs',
      where: 'productionOrderId = ?',
      whereArgs: [productionOrderId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final existingBatch = ProductionBatchCost.fromMap(existing.first);
      if (existingBatch.status == CostStatus.finalized) {
        return existingBatch;
      }
    }

    final orderRows = await db.query(
      'production_orders',
      where: 'id = ?',
      whereArgs: [productionOrderId],
      limit: 1,
    );
    if (orderRows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    final order = orderRows.first;
    final productId = order['productId'] as String;
    final plannedQuantity = (order['plannedQuantity'] as num).toDouble();
    final resolvedMaterialCost =
        materialCost ?? await _materialCostForOrder(productionOrderId);
    final labor =
        laborCost ?? await _directLaborCostForOrder(productionOrderId);
    final overhead = _calculateOverheadAmount(
      base: overheadBase,
      materialCost: resolvedMaterialCost,
      laborCost: labor,
      rate: overheadRate ?? 0,
    );
    final otherCost = otherCosts.fold<double>(
      0,
      (sum, cost) => sum + cost.amount,
    );
    final quantity =
        goodFinishedQuantity ??
        (order['producedQuantity'] == null
            ? 0.0
            : (order['producedQuantity'] as num).toDouble());
    final projectedTotal =
        resolvedMaterialCost + labor + overhead + otherCost - scrapRecovery;
    final actualUnitCost = quantity > 0 ? projectedTotal / quantity : 0.0;
    final estimate = await estimateProductCost(
      productId,
      quantity: plannedQuantity,
    );
    final row = {
      'id': _id('batch-cost'),
      'productionOrderId': productionOrderId,
      'productId': productId,
      'plannedQuantity': plannedQuantity,
      'goodFinishedQuantity': quantity,
      'materialCost': resolvedMaterialCost,
      'laborCost': labor,
      'overheadCost': overhead,
      'otherCost': otherCost,
      'scrapRecovery': scrapRecovery,
      'totalCost': projectedTotal,
      'actualUnitCost': actualUnitCost,
      'estimatedCost': estimate.totalEstimatedCost,
      'estimatedUnitCost': estimate.estimatedUnitCost,
      'status': CostStatus.calculated.value,
      'calculatedAt': DateTime.now().millisecondsSinceEpoch,
      'finalizedAt': null,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    final batch = await db.transaction((txn) async {
      await _persistOtherCosts(txn, productionOrderId, otherCosts);
      if (existing.isNotEmpty) {
        await txn.update(
          'production_batch_costs',
          row,
          where: 'productionOrderId = ?',
          whereArgs: [productionOrderId],
        );
      } else {
        await txn.insert('production_batch_costs', row);
      }
      final saved = await txn.query(
        'production_batch_costs',
        where: 'productionOrderId = ?',
        whereArgs: [productionOrderId],
        limit: 1,
      );
      return ProductionBatchCost.fromMap(saved.first);
    });
    await _audit(
      'BATCH_COST_CALCULATED',
      'Costing',
      'ProductionBatchCost',
      productionOrderId,
      oldValue: null,
      newValue: '${batch.totalCost}',
      description: 'Batch cost calculated',
    );
    return batch;
  }

  Future<ProductionBatchCost> finalizeBatchCost(
    String productionOrderId,
    String user,
  ) async {
    _security.require('COSTING_FINALIZE');
    final db = await _db;
    late ProductionBatchCost current;
    final batch = await db.transaction((txn) async {
      final rows = await txn.query(
        'production_batch_costs',
        where: 'productionOrderId = ?',
        whereArgs: [productionOrderId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('تكلفة الإنتاج غير موجودة');
      current = ProductionBatchCost.fromMap(rows.first);
      if (current.status == CostStatus.finalized) {
        throw Exception('لا يمكن تعديل تكلفة نهائية');
      }
      if (current.goodFinishedQuantity <= 0) {
        throw Exception('لا يمكن إنهاء التكلفة بكمية جيدة صفر');
      }
      final outputRows = await txn.query(
        'production_outputs',
        columns: ['warehouseId', 'quantity'],
        where: 'productionOrderId = ?',
        whereArgs: [productionOrderId],
      );
      if (outputRows.isNotEmpty) {
        final outputQuantity = outputRows.fold<double>(
          0,
          (sum, row) => sum + (row['quantity'] as num).toDouble(),
        );
        if ((outputQuantity - current.goodFinishedQuantity).abs() > 0.000001) {
          throw Exception('الكمية النهائية لا تطابق مخرجات أمر الإنتاج');
        }
        final orderRows = await txn.query(
          'production_orders',
          columns: ['productId'],
          where: 'id = ?',
          whereArgs: [productionOrderId],
          limit: 1,
        );
        if (orderRows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
        final byWarehouse = <String, double>{};
        for (final row in outputRows) {
          final warehouseId = row['warehouseId'] as String;
          byWarehouse[warehouseId] =
              (byWarehouse[warehouseId] ?? 0) +
              (row['quantity'] as num).toDouble();
        }
        final unitCost = current.totalCost / current.goodFinishedQuantity;
        final accounting = AccountingLocalDataSource();
        for (final entry in byWarehouse.entries) {
          await accounting.receiveProductionCostWithinTransaction(
            executor: txn,
            result: ProductionCostResult(
              referenceId: '$productionOrderId:${entry.key}',
              warehouseId: entry.key,
              itemId: orderRows.single['productId'] as String,
              itemType: 'PRODUCT',
              quantity: entry.value,
              totalCost: entry.value * unitCost,
            ),
          );
        }
      }
      final now = DateTime.now();
      await txn.update(
        'production_batch_costs',
        {
          'status': CostStatus.finalized.value,
          'finalizedAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        },
        where: 'productionOrderId = ?',
        whereArgs: [productionOrderId],
      );
      final updated = await txn.query(
        'production_batch_costs',
        where: 'productionOrderId = ?',
        whereArgs: [productionOrderId],
        limit: 1,
      );
      return ProductionBatchCost.fromMap(updated.first);
    });
    await _audit(
      'BATCH_COST_FINALIZED',
      'Costing',
      'ProductionBatchCost',
      productionOrderId,
      oldValue: '${current.totalCost}',
      newValue: '${batch.totalCost}',
      description: 'Batch cost finalized by $user',
    );
    return batch;
  }

  Future<void> allocateAttendanceToProductionOrder({
    required String productionOrderId,
    required String attendanceId,
    required double regularHours,
    required double overtimeHours,
  }) async {
    _security.require('COSTING_CALCULATE');
    if (regularHours < 0 || overtimeHours < 0) {
      throw Exception('ساعات العمل لا يمكن أن تكون سالبة');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final attendanceRows = await txn.query(
        'attendance_records',
        where: 'id = ?',
        whereArgs: [attendanceId],
        limit: 1,
      );
      if (attendanceRows.isEmpty) throw Exception('سجل الحضور غير موجود');
      final attendance = attendanceRows.first;
      final orderRows = await txn.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [productionOrderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
      final order = orderRows.first;
      final workDate = (attendance['workDate'] as num).toInt();
      final start =
          (order['startDate'] as num?)?.toInt() ??
          (order['createdAt'] as num).toInt();
      final end =
          (order['completionDate'] as num?)?.toInt() ??
          (order['updatedAt'] as num).toInt();
      if (workDate < start || workDate > end) {
        throw Exception('تاريخ الحضور خارج فترة أمر الإنتاج');
      }
      final workerRows = await txn.query(
        'workers',
        columns: ['productionStageId'],
        where: 'id = ?',
        whereArgs: [attendance['workerId']],
        limit: 1,
      );
      final stage = workerRows.single['productionStageId'];
      final stageRows = await txn.query(
        'production_order_stages',
        columns: ['id'],
        where: 'productionOrderId = ? AND productionStageId = ?',
        whereArgs: [productionOrderId, stage],
        limit: 1,
      );
      if (stage == null || stageRows.isEmpty) {
        throw Exception('العامل غير مرتبط بمرحلة أمر الإنتاج');
      }
      final existing = await txn.query(
        'production_order_labor_allocations',
        where: 'attendanceId = ?',
        whereArgs: [attendanceId],
      );
      if (existing.any(
        (row) => row['productionOrderId'] != productionOrderId,
      )) {
        throw Exception('سجل الحضور مخصص لأمر إنتاج آخر');
      }
      final usedRegular = existing.fold<double>(
        0,
        (sum, row) => sum + (row['regularHours'] as num).toDouble(),
      );
      final usedOvertime = existing.fold<double>(
        0,
        (sum, row) => sum + (row['overtimeHours'] as num).toDouble(),
      );
      final attendanceRegular = (attendance['regularHours'] as num).toDouble();
      final attendanceOvertime = (attendance['overtimeHours'] as num)
          .toDouble();
      if (usedRegular + regularHours > attendanceRegular ||
          usedOvertime + overtimeHours > attendanceOvertime) {
        throw Exception('ساعات التوزيع تتجاوز ساعات الحضور');
      }
      await txn.insert('production_order_labor_allocations', {
        'id': _id('labor-allocation'),
        'productionOrderId': productionOrderId,
        'attendanceId': attendanceId,
        'regularHours': regularHours,
        'overtimeHours': overtimeHours,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<List<ProductionBatchCost>> finalizedBatchesForProduct(
    String productId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'production_batch_costs',
      where: 'productId = ? AND status = ?',
      whereArgs: [productId, CostStatus.finalized.value],
      orderBy: 'finalizedAt DESC',
    );
    return rows.map(ProductionBatchCost.fromMap).toList();
  }

  Future<double> productAverageActualCost(String productId) async {
    final batches = await finalizedBatchesForProduct(productId);
    if (batches.isEmpty) return 0;
    final totalCost = batches.fold<double>(
      0,
      (sum, item) => sum + item.totalCost,
    );
    final totalQuantity = batches.fold<double>(
      0,
      (sum, item) => sum + item.goodFinishedQuantity,
    );
    return totalQuantity == 0 ? 0 : totalCost / totalQuantity;
  }

  Future<double> productLastActualCost(String productId) async {
    final batches = await finalizedBatchesForProduct(productId);
    if (batches.isEmpty) return 0;
    return batches.first.totalCost;
  }

  Future<double> costVariance(String productionOrderId) async {
    final db = await _db;
    final row = await db.query(
      'production_batch_costs',
      where: 'productionOrderId = ?',
      whereArgs: [productionOrderId],
      limit: 1,
    );
    if (row.isEmpty) return 0;
    final batch = ProductionBatchCost.fromMap(row.first);
    final estimate = await estimateProductCost(
      batch.productId,
      quantity: batch.plannedQuantity,
    );
    return batch.totalCost - estimate.totalEstimatedCost;
  }

  Future<double> grossMargin(
    String productId, {
    required double sellingPrice,
  }) async {
    final actual = await productLastActualCost(productId);
    final grossProfit = sellingPrice - actual;
    return grossProfit;
  }

  Future<double> grossMarginPercent(
    String productId, {
    required double sellingPrice,
  }) async {
    final actual = await productLastActualCost(productId);
    if (sellingPrice <= 0) return 0;
    final grossProfit = sellingPrice - actual;
    return (grossProfit / sellingPrice) * 100;
  }

  Future<double> _estimateOverhead({
    required OverheadBase base,
    required double value,
    required double laborCost,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'costing_overhead_rules',
      where: 'active = 1',
      orderBy: 'createdAt ASC',
    );
    if (rows.isEmpty) return 0;
    double total = 0;
    for (final row in rows) {
      final rule = OverheadRule.fromMap(row);
      final baseValue = switch (rule.base) {
        OverheadBase.materialCost => value,
        OverheadBase.laborCost => laborCost,
        OverheadBase.materialPlusLabor => value + laborCost,
      };
      total += rule.rate / 100 * baseValue;
    }
    return total;
  }

  double _calculateOverheadAmount({
    required OverheadBase base,
    required double materialCost,
    required double laborCost,
    required double rate,
  }) {
    final baseValue = switch (base) {
      OverheadBase.materialCost => materialCost,
      OverheadBase.laborCost => laborCost,
      OverheadBase.materialPlusLabor => materialCost + laborCost,
    };
    return rate / 100 * baseValue;
  }

  Future<double> _materialCostForOrder(String productionOrderId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT c.id, c.rawMaterialId, c.quantity, c.unitCost
      FROM production_material_consumptions c
      WHERE c.productionOrderId = ?
      ''',
      [productionOrderId],
    );
    var total = 0.0;
    for (final row in rows) {
      final quantity = (row['quantity'] as num).toDouble();
      var cost = ((row['unitCost'] as num?) ?? 0).toDouble();
      if (cost == 0) {
        final valuations = await db.query(
          'inventory_valuations',
          where: 'itemId = ? AND itemType = ?',
          whereArgs: [row['rawMaterialId'], 'RAW_MATERIAL'],
          orderBy: 'updatedAt DESC',
          limit: 1,
        );
        cost = valuations.isEmpty
            ? 0
            : (valuations.single['averageCost'] as num).toDouble();
      }
      total += quantity * cost;
    }
    final wasteRows = await db.rawQuery(
      '''
      SELECT w.quantity, v.averageCost
      FROM production_waste w
      LEFT JOIN inventory_valuations v
        ON v.itemId = w.rawMaterialId AND v.itemType = 'RAW_MATERIAL'
      WHERE w.productionOrderId = ?
      ''',
      [productionOrderId],
    );
    for (final row in wasteRows) {
      total +=
          (row['quantity'] as num).toDouble() *
          ((row['averageCost'] as num?) ?? 0).toDouble();
    }
    return total;
  }

  Future<double> _directLaborCostForOrder(String productionOrderId) async {
    final db = await _db;
    final allocatedRows = await db.rawQuery(
      '''
      SELECT a.workerId, a.overtimeRate, l.regularHours, l.overtimeHours,
             w.basicSalary, w.salaryType, w.overtimeRateOverride
      FROM production_order_labor_allocations l
      JOIN attendance_records a ON a.id = l.attendanceId
      JOIN workers w ON w.id = a.workerId
      WHERE l.productionOrderId = ?
      ''',
      [productionOrderId],
    );
    final rows = await db.rawQuery(
      '''
      SELECT a.workerId, a.regularHours, a.overtimeHours, a.overtimeRate,
             w.basicSalary, w.salaryType, w.overtimeRateOverride
      FROM attendance_records a
      JOIN workers w ON w.id = a.workerId
      JOIN production_orders po ON po.id = ?
      WHERE a.workDate >=
          (COALESCE(po.startDate, po.createdAt) / 86400000) * 86400000
        AND a.workDate <=
          ((COALESCE(po.completionDate, po.updatedAt) / 86400000) + 1) * 86400000
        AND EXISTS (
          SELECT 1 FROM production_order_stages os
          WHERE os.productionOrderId = po.id
            AND os.productionStageId = w.productionStageId
        )
        AND NOT EXISTS (
          SELECT 1 FROM production_order_labor_allocations l
          WHERE l.productionOrderId = po.id AND l.attendanceId = a.id
        )
        AND NOT EXISTS (
          SELECT 1
          FROM production_orders other
          JOIN production_order_stages otherStage
            ON otherStage.productionOrderId = other.id
           AND otherStage.productionStageId = w.productionStageId
          WHERE other.id <> po.id
            AND a.workDate >=
                (COALESCE(other.startDate, other.createdAt) / 86400000) * 86400000
            AND a.workDate <=
                ((COALESCE(other.completionDate, other.updatedAt) / 86400000) + 1) * 86400000
        )
      ''',
      [productionOrderId],
    );
    var total = 0.0;
    for (final row in [...allocatedRows, ...rows]) {
      final regularHours = (row['regularHours'] as num?)?.toDouble() ?? 0;
      final overtimeHours = (row['overtimeHours'] as num?)?.toDouble() ?? 0;
      final basic = (row['basicSalary'] as num?)?.toDouble() ?? 0;
      final hourly = (row['salaryType'] as String? ?? 'MONTHLY') == 'MONTHLY'
          ? basic / 160
          : (row['salaryType'] as String? ?? 'HOURLY') == 'DAILY'
          ? basic / 8
          : basic;
      final overtimeRate =
          (row['overtimeRateOverride'] as num?)?.toDouble() ??
          (row['overtimeRate'] as num?)?.toDouble() ??
          0;
      total += regularHours * hourly + overtimeHours * overtimeRate;
    }
    return total;
  }

  Future<double> _persistOtherCosts(
    DatabaseExecutor db,
    String productionOrderId,
    List<ProductionOtherCostInput> otherCosts,
  ) async {
    if (otherCosts.isEmpty) return 0;
    var total = 0.0;
    for (final cost in otherCosts) {
      total += cost.amount;
      await db.insert('production_other_costs', {
        'id': cost.id,
        'productionOrderId': productionOrderId,
        'description': cost.description,
        'amount': cost.amount,
        'date': cost.date.millisecondsSinceEpoch,
        'createdBy': cost.createdBy,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return total;
  }

  Future<void> _audit(
    String action,
    String module,
    String entityType,
    String entityId, {
    required String? oldValue,
    required String? newValue,
    required String description,
  }) async {
    final security = SecurityLocalDataSource();
    if (security.session != null) {
      await security.audit(
        action: action,
        module: module,
        entityType: entityType,
        entityId: entityId,
        oldValue: oldValue,
        newValue: newValue,
        description: description,
      );
    }
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
