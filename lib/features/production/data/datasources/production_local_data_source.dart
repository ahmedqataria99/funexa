import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class ProductionLocalDataSource {
  static const double _quantityTolerance = 0.000001;

  ProductionLocalDataSource([
    WarehousesStockLocalDataSource? stock,
    AccountingLocalDataSource? accounting,
  ]) : _stock = stock ?? WarehousesStockLocalDataSource(),
       _accounting = accounting ?? AccountingLocalDataSource();

  final WarehousesStockLocalDataSource _stock;
  final AccountingLocalDataSource _accounting;
  final SecurityLocalDataSource _security = SecurityLocalDataSource();
  Future<Database> get _db async => FurnexaDatabase.instance.database;
  static int _sequence = 0;

  String _id(String prefix) {
    _sequence++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  String _number() {
    _sequence++;
    return 'PRD-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  Future<bool> productBomIsValid(String productId) async {
    final db = await _db;
    final rows = await db.query(
      'product_bom_items',
      where: 'productId = ?',
      whereArgs: [productId],
    );
    return _bomRowsAreValid(db, rows);
  }

  Future<bool> orderBomIsValid(String orderId) async {
    final db = await _db;
    final rows = await db.query(
      'production_order_bom_items',
      where: 'productionOrderId = ?',
      whereArgs: [orderId],
    );
    return _bomRowsAreValid(db, rows);
  }

  Future<bool> _bomRowsAreValid(
    DatabaseExecutor db,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return false;
    for (final row in rows) {
      final quantity = (row['quantity'] as num).toDouble();
      if (!quantity.isFinite || quantity <= 0) return false;
      final materialRows = await db.query(
        'raw_materials',
        columns: ['unitId'],
        where: 'id = ? AND active = 1',
        whereArgs: [row['rawMaterialId']],
        limit: 1,
      );
      if (materialRows.isEmpty) return false;
      final materialUnitId = materialRows.first['unitId'] as String;
      final snapshotUnitId = row['unitId'] as String?;
      if (snapshotUnitId != null && snapshotUnitId != materialUnitId)
        return false;
      final unitId = snapshotUnitId ?? materialUnitId;
      final units = await db.query(
        'units',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [unitId],
        limit: 1,
      );
      if (units.isEmpty) return false;
    }
    return true;
  }

  Future<List<Product>> activeProducts() async => (await (await _db).query(
    'products',
    where: 'active = 1',
    orderBy: 'name ASC',
  )).map(Product.fromMap).toList();

  Future<List<ProductVariant>> activeVariants(String productId) async =>
      (await (await _db).query(
        'product_variants',
        where: 'productId = ? AND active = 1',
        whereArgs: [productId],
        orderBy: 'name ASC',
      )).map(ProductVariant.fromMap).toList();

  Future<List<ProductionStage>> activeStages() async =>
      (await (await _db).query(
        'production_stages',
        where: 'active = 1',
        orderBy: 'sequence ASC, name ASC',
      )).map(ProductionStage.fromMap).toList();

  Future<List<Warehouse>> activeWarehouses() async => (await (await _db).query(
    'warehouses',
    where: 'state = ?',
    whereArgs: ['active'],
    orderBy: 'name ASC',
  )).map(Warehouse.fromMap).toList();

  Future<List<Warehouse>> accessibleProductionWarehouses() async {
    _security.require('PRODUCTION_EDIT');
    final session = _security.session;
    if (session == null) throw Exception('يجب تسجيل الدخول');
    final warehouses = await activeWarehouses();
    return warehouses
        .where(
          (warehouse) => session.canAccess(ScopeType.warehouse, warehouse.id),
        )
        .toList();
  }

  Future<List<Warehouse>> outputWarehouses(String orderId) async {
    _security.require('PRODUCTION_EDIT');
    final session = _security.session;
    if (session == null) throw Exception('يجب تسجيل الدخول');
    final db = await _db;
    final contextRows = await db.rawQuery(
      '''
      SELECT ps.factoryId
      FROM production_order_stages os
      JOIN production_stages ps ON ps.id = os.productionStageId
      WHERE os.productionOrderId = ?
      ORDER BY os.sequence DESC
      LIMIT 1
      ''',
      [orderId],
    );
    if (contextRows.isEmpty) return const [];
    final rows = await db.query(
      'warehouses',
      where: 'state = ? AND factoryId = ?',
      whereArgs: ['active', contextRows.single['factoryId']],
      orderBy: 'name ASC',
    );
    return rows
        .map(Warehouse.fromMap)
        .where(
          (warehouse) => session.canAccess(ScopeType.warehouse, warehouse.id),
        )
        .toList();
  }

  Future<List<StockItemOption>> activeRawMaterials() async {
    final rows = await (await _db).query(
      'raw_materials',
      where: 'active = 1',
      orderBy: 'name ASC',
    );
    return rows
        .map(
          (row) => StockItemOption(
            id: row['id'] as String,
            name: row['name'] as String,
            code: row['code'] as String,
            unitId: row['unitId'] as String,
            type: StockItemType.rawMaterial,
            active: true,
          ),
        )
        .toList();
  }

  Future<List<ProductionRoute>> routes() async {
    final rows = await (await _db).query(
      'production_routes',
      orderBy: 'productId ASC',
    );
    return Future.wait(rows.map(_route));
  }

  Future<ProductionRoute?> routeForProduct(String productId) async {
    final rows = await (await _db).query(
      'production_routes',
      where: 'productId = ?',
      whereArgs: [productId],
      limit: 1,
    );
    return rows.isEmpty ? null : _route(rows.first);
  }

  Future<void> saveRoute(String productId, List<String> stageIds) async {
    _security.require('PRODUCTION_EDIT');
    if (stageIds.isEmpty) throw Exception('أضف مرحلة واحدة على الأقل للمسار');
    if (stageIds.toSet().length != stageIds.length) {
      throw Exception('لا يمكن تكرار مرحلة في مسار الإنتاج');
    }
    final db = await _db;
    final existingRoute = await db.query(
      'production_routes',
      columns: ['id'],
      where: 'productId = ?',
      whereArgs: [productId],
      limit: 1,
    );
    await db.transaction((txn) async {
      final product = await txn.query(
        'products',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [productId],
        limit: 1,
      );
      if (product.isEmpty) throw Exception('المنتج غير موجود أو غير نشط');
      for (final stageId in stageIds) {
        final stage = await txn.query(
          'production_stages',
          columns: ['id'],
          where: 'id = ? AND active = 1',
          whereArgs: [stageId],
          limit: 1,
        );
        if (stage.isEmpty)
          throw Exception('مرحلة الإنتاج غير موجودة أو غير نشطة');
      }
      final existing = await txn.query(
        'production_routes',
        columns: ['id'],
        where: 'productId = ?',
        whereArgs: [productId],
        orderBy: 'createdAt ASC',
      );
      if (existing.length > 1) {
        throw Exception(
          'هذا المنتج يحتوي على ${existing.length} مسارات إنتاج مكررة، ولم يتم حفظ مسار جديد.',
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final routeId = existing.isEmpty
          ? _id('route')
          : existing.first['id'] as String;
      if (existing.isEmpty) {
        await txn.insert('production_routes', {
          'id': routeId,
          'productId': productId,
          'createdAt': now,
          'updatedAt': now,
        });
      } else {
        await txn.update(
          'production_routes',
          {'updatedAt': now},
          where: 'id = ?',
          whereArgs: [routeId],
        );
      }
      await txn.delete(
        'production_route_stages',
        where: 'routeId = ?',
        whereArgs: [routeId],
      );
      for (var index = 0; index < stageIds.length; index++) {
        await txn.insert('production_route_stages', {
          'id': _id('route-stage'),
          'routeId': routeId,
          'productionStageId': stageIds[index],
          'sequence': index + 1,
          'notes': null,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    });
    await _auditSafely(
      existingRoute.isEmpty ? 'CREATE' : 'UPDATE',
      'ProductionRoute',
      productId,
      'Production route saved',
    );
  }

  Future<ProductionOrder> createOrder({
    required String productId,
    String? variantId,
    String? expectedUnitId,
    required double plannedQuantity,
    String? notes,
  }) async {
    _security.require('PRODUCTION_EDIT');
    if (!plannedQuantity.isFinite || plannedQuantity <= 0) {
      throw Exception('كمية الإنتاج يجب أن تكون رقماً صالحاً أكبر من صفر');
    }
    final db = await _db;
    final order = await db.transaction((txn) async {
      final productRows = await txn.query(
        'products',
        where: 'id = ? AND active = 1',
        whereArgs: [productId],
        limit: 1,
      );
      if (productRows.isEmpty) throw Exception('المنتج غير موجود أو غير نشط');
      final unitId = productRows.single['unitId'] as String?;
      if (unitId == null ||
          unitId.trim().isEmpty ||
          (await txn.query(
            'units',
            columns: ['id'],
            where: 'id = ? AND active = 1',
            whereArgs: [unitId],
            limit: 1,
          )).isEmpty) {
        throw ProductionUnitSnapshotException(
          'لا يمكن إنشاء أمر الإنتاج لأن الوحدة الأساسية للمنتج غير متاحة.',
        );
      }
      if (expectedUnitId != null && unitId != expectedUnitId) {
        throw Exception(
          'تغيرت الوحدة الأساسية للمنتج. حدّث قائمة المنتجات ثم أعد إنشاء أمر الإنتاج.',
        );
      }
      const unitConversionFactor = 1.0;
      final plannedBaseQuantity = plannedQuantity * unitConversionFactor;
      if (!unitConversionFactor.isFinite ||
          unitConversionFactor <= 0 ||
          !plannedBaseQuantity.isFinite ||
          plannedBaseQuantity <= 0) {
        throw ProductionUnitSnapshotException(
          'تعذر إنشاء لقطة وحدة صالحة لأمر الإنتاج.',
        );
      }
      await _validateOrderVariantIdentity(txn, productId, variantId);
      final routeRows = await txn.query(
        'production_routes',
        where: 'productId = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (routeRows.isEmpty) throw Exception('لا يوجد مسار إنتاج لهذا المنتج');
      final routeId = routeRows.first['id'] as String;
      final routeStages = await txn.query(
        'production_route_stages',
        where: 'routeId = ?',
        whereArgs: [routeId],
        orderBy: 'sequence ASC',
      );
      if (routeStages.isEmpty) throw Exception('مسار الإنتاج غير صالح');
      for (var index = 0; index < routeStages.length; index++) {
        final stage = routeStages[index];
        if ((stage['sequence'] as num).toInt() != index + 1) {
          throw Exception('ترتيب مراحل مسار الإنتاج غير صالح');
        }
        final activeStage = await txn.query(
          'production_stages',
          columns: ['id'],
          where: 'id = ? AND active = 1',
          whereArgs: [stage['productionStageId']],
          limit: 1,
        );
        if (activeStage.isEmpty) throw Exception('مسار الإنتاج غير صالح');
      }
      final bomRows = await txn.query(
        'product_bom_items',
        where: 'productId = ?',
        whereArgs: [productId],
        orderBy: 'id ASC',
      );
      for (final bom in bomRows) {
        final material = await txn.query(
          'raw_materials',
          columns: ['id', 'unitId'],
          where: 'id = ?',
          whereArgs: [bom['rawMaterialId']],
          limit: 1,
        );
        if (material.isEmpty) {
          throw Exception('قائمة مواد المنتج غير صالحة');
        }
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final orderId = _id('production-order');
      await txn.insert('production_orders', {
        'id': orderId,
        'orderNumber': _number(),
        'productId': productId,
        'variantId': variantId,
        'routeId': routeId,
        'plannedQuantity': plannedQuantity,
        'producedQuantity': 0,
        'status': 'DRAFT',
        'unitId': unitId,
        'baseUnitId': unitId,
        'unitConversionFactor': unitConversionFactor,
        'plannedBaseQuantity': plannedBaseQuantity,
        'unitSnapshotStatus': ProductionUnitSnapshotStatus.verified.value,
        'startDate': null,
        'completionDate': null,
        'notes': notes,
        'createdAt': now,
        'updatedAt': now,
      });
      for (final stage in routeStages) {
        await txn.insert('production_order_stages', {
          'id': _id('order-stage'),
          'productionOrderId': orderId,
          'productionStageId': stage['productionStageId'],
          'sequence': stage['sequence'],
          'status': 'PENDING',
          'startedAt': null,
          'completedAt': null,
          'notes': null,
          'createdAt': now,
          'updatedAt': now,
        });
      }
      for (final bom in bomRows) {
        final material = await txn.query(
          'raw_materials',
          columns: ['unitId'],
          where: 'id = ?',
          whereArgs: [bom['rawMaterialId']],
          limit: 1,
        );
        await txn.insert('production_order_bom_items', {
          'id': _id('order-bom'),
          'productionOrderId': orderId,
          'rawMaterialId': bom['rawMaterialId'],
          'unitId': material.first['unitId'],
          'quantity': bom['quantity'],
          'notes': bom['notes'],
        });
      }
      return _order(txn, orderId);
    });
    await _auditSafely(
      'CREATE',
      'ProductionOrder',
      order.id,
      'Production order ${order.orderNumber} created for product $productId, quantity $plannedQuantity',
    );
    return order;
  }

  Future<List<ProductionOrder>> orders([String query = '']) async {
    final normalized = query.trim().toLowerCase();
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT po.*, p.name AS productName
      FROM production_orders po
      JOIN products p ON p.id = po.productId
      WHERE ? = '' OR LOWER(po.orderNumber) LIKE ? OR LOWER(p.name) LIKE ? OR LOWER(p.code) LIKE ?
      ORDER BY po.createdAt DESC
    ''',
      [normalized, '%$normalized%', '%$normalized%', '%$normalized%'],
    );
    return Future.wait(rows.map((row) => _order(db, row['id'] as String)));
  }

  Future<ProductionOrder> getOrder(String id) async => _order(await _db, id);

  Future<void> planOrder(String id) async {
    _security.require('PRODUCTION_EDIT');
    await _changeStatus(
      id,
      ProductionOrderStatus.draft,
      ProductionOrderStatus.planned,
    );
    await _auditSafely(
      'STATUS_CHANGE',
      'ProductionOrder',
      id,
      'Production order planned',
    );
  }

  Future<void> startOrder(String id) async {
    _security.require('PRODUCTION_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
      final order = rows.single;
      if (_status(order['status'] as String) != ProductionOrderStatus.planned) {
        throw Exception('يجب تخطيط أمر الإنتاج قبل البدء');
      }
      _requireVerifiedUnitSnapshot(order);
      if ((await txn.query(
        'products',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [order['productId']],
        limit: 1,
      )).isEmpty) {
        throw Exception('المنتج غير موجود أو غير نشط');
      }
      await _validateOrderVariantIdentity(
        txn,
        order['productId'] as String,
        order['variantId'] as String?,
      );
      final routeRows = await txn.query(
        'production_routes',
        columns: ['id'],
        where: 'id = ? AND productId = ?',
        whereArgs: [order['routeId'], order['productId']],
        limit: 1,
      );
      final stageRows = await txn.query(
        'production_order_stages',
        where: 'productionOrderId = ?',
        whereArgs: [id],
        orderBy: 'sequence ASC',
      );
      if (routeRows.isEmpty || stageRows.isEmpty) {
        throw Exception('لا يمكن بدء الإنتاج قبل توفر مسار إنتاج صالح');
      }
      for (var index = 0; index < stageRows.length; index++) {
        final stage = stageRows[index];
        if ((stage['sequence'] as num).toInt() != index + 1) {
          throw Exception('ترتيب مراحل أمر الإنتاج غير صالح');
        }
        final activeStage = await txn.query(
          'production_stages',
          columns: ['id'],
          where: 'id = ? AND active = 1',
          whereArgs: [stage['productionStageId']],
          limit: 1,
        );
        if (activeStage.isEmpty) {
          throw Exception('لا يمكن بدء الإنتاج قبل توفر مسار إنتاج صالح');
        }
      }
      final bomRows = await txn.query(
        'production_order_bom_items',
        where: 'productionOrderId = ?',
        whereArgs: [id],
      );
      if (!await _bomRowsAreValid(txn, bomRows)) {
        throw Exception('لا يمكن بدء الإنتاج قبل استكمال قائمة الخامات');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final changed = await txn.update(
        'production_orders',
        {'status': 'IN_PROGRESS', 'startDate': now, 'updatedAt': now},
        where: 'id = ? AND status = ?',
        whereArgs: [id, 'PLANNED'],
      );
      if (changed != 1) throw Exception('انتقال حالة أمر الإنتاج غير مسموح');
    });
    await _auditSafely(
      'STATUS_CHANGE',
      'ProductionOrder',
      id,
      'Production order started',
    );
  }

  Future<void> cancelOrder(String id) async {
    _security.require('PRODUCTION_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
      final status = rows.single['status'] as String;
      if (status != 'DRAFT' && status != 'PLANNED') {
        throw Exception('لا يمكن إلغاء أمر إنتاج بدأ أو اكتمل');
      }
      final changed = await txn.update(
        'production_orders',
        {
          'status': 'CANCELLED',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status IN (?, ?)',
        whereArgs: [id, 'DRAFT', 'PLANNED'],
      );
      if (changed != 1) {
        throw Exception(
          'تغيرت حالة أمر الإنتاج؛ حدّث القائمة قبل إعادة المحاولة',
        );
      }
    });
    await _auditSafely(
      'STATUS_CHANGE',
      'ProductionOrder',
      id,
      'Production order cancelled',
    );
  }

  Future<void> startStage(String id) async {
    _security.require('PRODUCTION_EDIT');
    final db = await _db;
    final started = await db.transaction((txn) async {
      final row = await _stageRow(txn, id);
      await _security.requireResourceScope(
        ScopeType.productionStage,
        row['productionStageId'] as String,
      );
      await _requireInProgress(txn, row['productionOrderId'] as String);
      if (row['status'] != 'PENDING') {
        throw Exception(_stageStartStateError(row['status'] as String));
      }
      await _requirePreviousStagesComplete(txn, row);
      final now = DateTime.now().millisecondsSinceEpoch;
      final changed = await txn.update(
        'production_order_stages',
        {'status': 'IN_PROGRESS', 'startedAt': now, 'updatedAt': now},
        where: 'id = ? AND status = ?',
        whereArgs: [id, 'PENDING'],
      );
      if (changed != 1) throw Exception('انتقال حالة المرحلة غير مسموح');
      final order = (await txn.query(
        'production_orders',
        columns: ['orderNumber'],
        where: 'id = ?',
        whereArgs: [row['productionOrderId']],
        limit: 1,
      )).first;
      return {
        'orderId': row['productionOrderId'] as String,
        'orderNumber': order['orderNumber'] as String,
        'stageId': row['productionStageId'] as String,
        'sequence': (row['sequence'] as num).toInt(),
      };
    });
    await _auditSafely(
      'STAGE_START',
      'ProductionStage',
      id,
      'Production order ${started['orderNumber']} (${started['orderId']}) stage ${started['sequence']} (${started['stageId']}) started',
    );
  }

  Future<void> completeStage(String id) async {
    _security.require('PRODUCTION_EDIT');
    final db = await _db;
    final completed = await db.transaction((txn) async {
      final row = await _stageRow(txn, id);
      await _security.requireResourceScope(
        ScopeType.productionStage,
        row['productionStageId'] as String,
      );
      await _requireInProgress(txn, row['productionOrderId'] as String);
      if (row['status'] != 'IN_PROGRESS') {
        throw Exception('لا يمكن إكمال مرحلة غير قيد التنفيذ');
      }
      await _requirePreviousStagesComplete(txn, row);
      final now = DateTime.now().millisecondsSinceEpoch;
      final changed = await txn.update(
        'production_order_stages',
        {'status': 'COMPLETED', 'completedAt': now, 'updatedAt': now},
        where: 'id = ? AND status = ?',
        whereArgs: [id, 'IN_PROGRESS'],
      );
      if (changed != 1) throw Exception('انتقال حالة المرحلة غير مسموح');
      return row;
    });
    await _auditSafely(
      'STAGE_COMPLETE',
      'ProductionStage',
      id,
      'Production order ${completed['productionOrderId']} stage ${completed['sequence']} (${completed['productionStageId']}) completed',
    );
  }

  Future<void> skipStage(String id, String reason) async {
    _security.require('PRODUCTION_EDIT');
    if (reason.trim().isEmpty) throw Exception('سبب تخطي المرحلة مطلوب');
    final db = await _db;
    final skipped = await db.transaction((txn) async {
      final row = await _stageRow(txn, id);
      await _security.requireResourceScope(
        ScopeType.productionStage,
        row['productionStageId'] as String,
      );
      await _requireInProgress(txn, row['productionOrderId'] as String);
      if (row['status'] != 'PENDING' && row['status'] != 'IN_PROGRESS') {
        throw Exception('لا يمكن تخطي المرحلة الحالية');
      }
      await _requirePreviousStagesComplete(txn, row);
      final now = DateTime.now().millisecondsSinceEpoch;
      final changed = await txn.update(
        'production_order_stages',
        {
          'status': 'SKIPPED',
          'completedAt': now,
          'notes': reason.trim(),
          'updatedAt': now,
        },
        where: 'id = ? AND status IN (?, ?)',
        whereArgs: [id, 'PENDING', 'IN_PROGRESS'],
      );
      if (changed != 1) throw Exception('انتقال حالة المرحلة غير مسموح');
      return row;
    });
    await _auditSafely(
      'STAGE_SKIP',
      'ProductionStage',
      id,
      'Production order ${skipped['productionOrderId']} stage ${skipped['sequence']} (${skipped['productionStageId']}) skipped: ${reason.trim()}',
    );
  }

  Future<void> _requirePreviousStagesComplete(
    DatabaseExecutor db,
    Map<String, Object?> stage,
  ) async {
    final previous = await db.query(
      'production_order_stages',
      columns: ['sequence', 'status'],
      where: 'productionOrderId = ? AND sequence < ?',
      whereArgs: [stage['productionOrderId'], stage['sequence']],
      orderBy: 'sequence ASC',
    );
    for (var index = 0; index < previous.length; index++) {
      final row = previous[index];
      if ((row['sequence'] as num).toInt() != index + 1 ||
          (row['status'] != 'COMPLETED' && row['status'] != 'SKIPPED')) {
        throw Exception('يجب إتمام المرحلة السابقة أولاً');
      }
    }
  }

  String _stageStartStateError(String status) => switch (status) {
    'IN_PROGRESS' => 'هذه المرحلة قيد التنفيذ بالفعل',
    'COMPLETED' => 'هذه المرحلة مكتملة',
    'SKIPPED' => 'هذه المرحلة متخطاة',
    _ => 'لا يمكن بدء هذه المرحلة في حالتها الحالية',
  };

  Future<List<ProductionMaterialRequirement>> requirements(
    String orderId,
  ) async {
    _security.require('PRODUCTION_EDIT');
    final db = await _db;
    final orderRows = await db.query(
      'production_orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (orderRows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    final order = orderRows.single;
    _requireVerifiedUnitSnapshot(order);
    final rows = await db.rawQuery(
      '''
      SELECT b.rawMaterialId, r.name AS rawMaterialName, r.code AS rawMaterialCode,
        b.unitId, u.name AS unitName, u.abbreviation AS unitAbbreviation,
        b.quantity * ? AS requiredQuantity,
        COALESCE((SELECT SUM(c.quantity) FROM production_material_consumptions c WHERE c.productionOrderId = ? AND c.rawMaterialId = b.rawMaterialId), 0) AS consumedQuantity
      FROM production_order_bom_items b
      JOIN raw_materials r ON r.id = b.rawMaterialId
      JOIN units u ON u.id = b.unitId
      WHERE b.productionOrderId = ?
      ORDER BY r.name ASC
    ''',
      [orderRows.first['plannedBaseQuantity'], orderId, orderId],
    );
    return rows
        .map(
          (row) => ProductionMaterialRequirement(
            rawMaterialId: row['rawMaterialId'] as String,
            rawMaterialName: row['rawMaterialName'] as String,
            rawMaterialCode: row['rawMaterialCode'] as String,
            unitId: row['unitId'] as String,
            unitName:
                (row['unitAbbreviation'] as String?)?.trim().isNotEmpty == true
                ? row['unitAbbreviation'] as String
                : row['unitName'] as String,
            requiredQuantity: (row['requiredQuantity'] as num).toDouble(),
            consumedQuantity: (row['consumedQuantity'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<void> consumeMaterial({
    required String orderId,
    required String rawMaterialId,
    required String warehouseId,
    required double quantity,
    required DateTime date,
    required String operationId,
    String? notes,
  }) async {
    _security.require('PRODUCTION_EDIT');
    await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty) {
      throw Exception('معرف عملية الاستهلاك مطلوب');
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw Exception('كمية الاستهلاك يجب أن تكون أكبر من صفر');
    }
    final db = await _db;
    final created = await db.transaction((txn) async {
      await _requireInProgress(txn, orderId);
      final priorOperations = await txn.query(
        'production_material_consumptions',
        where: 'operationId = ?',
        whereArgs: [normalizedOperationId],
        limit: 1,
      );
      if (priorOperations.isNotEmpty) {
        final previous = priorOperations.single;
        final matches =
            previous['productionOrderId'] == orderId &&
            previous['rawMaterialId'] == rawMaterialId &&
            previous['warehouseId'] == warehouseId &&
            (previous['quantity'] as num).toDouble() == quantity &&
            (previous['consumptionDate'] as num).toInt() ==
                date.millisecondsSinceEpoch &&
            previous['notes'] == notes;
        if (!matches) {
          throw Exception('معرف عملية الاستهلاك مستخدم لبيانات مختلفة');
        }
        return false;
      }
      final material = await _rawMaterial(txn, rawMaterialId);
      final orderRows = await txn.query(
        'production_orders',
        columns: ['productId', 'variantId', 'plannedBaseQuantity'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
      final order = orderRows.single;
      await _validateOrderVariantIdentity(
        txn,
        order['productId'] as String,
        order['variantId'] as String?,
      );
      final bom = await txn.query(
        'production_order_bom_items',
        columns: ['quantity', 'unitId'],
        where: 'productionOrderId = ? AND rawMaterialId = ?',
        whereArgs: [orderId, rawMaterialId],
        limit: 1,
      );
      if (bom.isEmpty)
        throw Exception('الخامة غير موجودة في قائمة مواد أمر الإنتاج');
      if (bom.first['unitId'] != material.unitId) {
        throw Exception('الوحدة غير متوافقة مع لقطة قائمة الخامات');
      }
      if ((await txn.query(
        'units',
        columns: ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [bom.first['unitId']],
        limit: 1,
      )).isEmpty) {
        throw Exception('وحدة لقطة قائمة الخامات غير متاحة');
      }
      final consumed = await txn.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS total FROM production_material_consumptions WHERE productionOrderId = ? AND rawMaterialId = ?',
        [orderId, rawMaterialId],
      );
      final required =
          (bom.first['quantity'] as num).toDouble() *
          (order['plannedBaseQuantity'] as num).toDouble();
      final consumedQuantity = (consumed.first['total'] as num).toDouble();
      final remaining = required - consumedQuantity;
      if (!required.isFinite || required <= 0 || remaining < 0) {
        throw Exception('بيانات متطلبات الخامة غير صالحة');
      }
      if (quantity > remaining) {
        throw Exception('الكمية تتجاوز المتبقي من الخامة');
      }
      final valuation = await _accounting.valuationWithinTransaction(
        txn,
        warehouseId,
        rawMaterialId,
        StockItemType.rawMaterial.value,
      );
      if (valuation == null || valuation.quantity < quantity) {
        throw Exception('الكمية غير متاحة في المخزن أو تقييمها غير كاف');
      }
      await _accounting.consumeInventoryValueWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        itemId: rawMaterialId,
        itemType: StockItemType.rawMaterial.value,
        quantity: quantity,
      );
      await _stock.applyStockOutWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        item: material,
        quantity: quantity,
        date: date,
        reference: 'OPERATION:PRODUCTION_CONSUMPTION:$normalizedOperationId',
        notes: notes,
      );
      await txn.insert('production_material_consumptions', {
        'id': _id('consumption'),
        'operationId': normalizedOperationId,
        'productionOrderId': orderId,
        'rawMaterialId': rawMaterialId,
        'warehouseId': warehouseId,
        'quantity': quantity,
        'unitCost': valuation.averageCost,
        'unitId': material.unitId,
        'consumptionDate': date.millisecondsSinceEpoch,
        'notes': notes,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
    if (created) {
      await _auditSafely(
        'MATERIAL_CONSUMPTION',
        'ProductionConsumption',
        orderId,
        'Operation $normalizedOperationId consumed $quantity of material $rawMaterialId from warehouse $warehouseId for production order $orderId',
      );
    }
  }

  Future<void> recordWaste({
    required String orderId,
    required String rawMaterialId,
    required String warehouseId,
    required double quantity,
    required String reason,
    required DateTime date,
    String? notes,
  }) async {
    _security.require('PRODUCTION_EDIT');
    await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
    if (quantity <= 0) throw Exception('كمية الهالك يجب أن تكون أكبر من صفر');
    if (!quantity.isFinite || quantity <= 0) {
      throw Exception('كمية الهالك يجب أن تكون أكبر من صفر');
    }
    if (reason.trim().isEmpty) throw Exception('سبب الهالك مطلوب');
    final db = await _db;
    await db.transaction((txn) async {
      await _requireInProgress(txn, orderId);
      final orderRows = await txn.query(
        'production_orders',
        columns: ['productId', 'variantId'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
      await _validateOrderVariantIdentity(
        txn,
        orderRows.first['productId'] as String,
        orderRows.first['variantId'] as String?,
      );
      final material = await _rawMaterial(txn, rawMaterialId);
      final bom = await txn.query(
        'production_order_bom_items',
        columns: ['unitId'],
        where: 'productionOrderId = ? AND rawMaterialId = ?',
        whereArgs: [orderId, rawMaterialId],
        limit: 1,
      );
      if (bom.isEmpty || bom.first['unitId'] != material.unitId) {
        throw Exception('الخامة غير موجودة في قائمة مواد أمر الإنتاج');
      }
      final valuation = await _accounting.valuationWithinTransaction(
        txn,
        warehouseId,
        rawMaterialId,
        StockItemType.rawMaterial.value,
      );
      if (valuation == null || valuation.quantity < quantity) {
        throw Exception('تقييم مخزون الخامة غير متاح أو غير كاف');
      }
      await _accounting.consumeInventoryValueWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        itemId: rawMaterialId,
        itemType: StockItemType.rawMaterial.value,
        quantity: quantity,
      );
      await _stock.applyStockOutWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        item: material,
        quantity: quantity,
        date: date,
        reference: 'WASTE:$orderId',
        notes: notes,
      );
      await txn.insert('production_waste', {
        'id': _id('waste'),
        'productionOrderId': orderId,
        'rawMaterialId': rawMaterialId,
        'warehouseId': warehouseId,
        'quantity': quantity,
        'unitId': material.unitId,
        'reason': reason.trim(),
        'notes': notes,
        'wasteDate': date.millisecondsSinceEpoch,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
    await _auditSafely(
      'WASTE',
      'ProductionWaste',
      orderId,
      'Production waste recorded',
    );
  }

  Future<void> recordOutput({
    required String orderId,
    required String warehouseId,
    required double quantity,
    required DateTime date,
    required String operationId,
    String? notes,
  }) async {
    _security.require('PRODUCTION_EDIT');
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty) {
      throw Exception('معرف عملية الإنتاج التام مطلوب');
    }
    if (!quantity.isFinite || quantity <= 0) {
      throw Exception('كمية الإنتاج يجب أن تكون رقماً صالحاً أكبر من صفر');
    }
    final db = await _db;
    var outputProductId = '';
    String? outputVariantId;
    final created = await db.transaction((txn) async {
      final orderRows = await txn.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
      final order = orderRows.single;
      _requireVerifiedUnitSnapshot(order);
      outputProductId = order['productId'] as String;
      outputVariantId = order['variantId'] as String?;
      await _validateOrderVariantIdentity(
        txn,
        outputProductId,
        outputVariantId,
      );
      final existingOutputs = await txn.query(
        'production_outputs',
        where: 'operationId = ?',
        whereArgs: [normalizedOperationId],
        limit: 1,
      );
      if (existingOutputs.isNotEmpty) {
        final existing = existingOutputs.single;
        final matches =
            existing['productionOrderId'] == orderId &&
            existing['warehouseId'] == warehouseId &&
            (existing['quantity'] as num).toDouble() == quantity &&
            (existing['outputDate'] as num).toInt() ==
                date.millisecondsSinceEpoch &&
            existing['notes'] == notes;
        if (!matches) {
          throw Exception('معرف عملية الإنتاج مستخدم لبيانات مختلفة');
        }
        _requireOutputMatchesOrderSnapshot(existing, order);
        return false;
      }
      final finalizedCosts = await txn.query(
        'production_batch_costs',
        columns: ['id'],
        where: 'productionOrderId = ? AND status = ?',
        whereArgs: [orderId, 'FINALIZED'],
        limit: 1,
      );
      if (finalizedCosts.isNotEmpty) {
        throw Exception('لا يمكن تسجيل مخرجات بعد اعتماد تكلفة أمر الإنتاج');
      }
      if (order['status'] != 'IN_PROGRESS') {
        throw Exception('يجب أن يكون أمر الإنتاج قيد التنفيذ');
      }
      final finalStages = await txn.query(
        'production_order_stages',
        where: 'productionOrderId = ?',
        whereArgs: [orderId],
        orderBy: 'sequence DESC',
        limit: 1,
      );
      if (finalStages.isEmpty || finalStages.first['status'] != 'COMPLETED') {
        throw Exception('يجب إكمال المرحلة النهائية قبل تسجيل المنتج النهائي');
      }
      final bomRows = await txn.query(
        'production_order_bom_items',
        where: 'productionOrderId = ?',
        whereArgs: [orderId],
      );
      if (!await _bomRowsAreValid(txn, bomRows)) {
        throw Exception('قائمة خامات أمر الإنتاج غير صالحة');
      }
      for (final bom in bomRows) {
        final required =
            (bom['quantity'] as num).toDouble() *
            (order['plannedBaseQuantity'] as num).toDouble();
        final consumedRows = await txn.rawQuery(
          'SELECT COALESCE(SUM(quantity), 0) AS total FROM production_material_consumptions WHERE productionOrderId = ? AND rawMaterialId = ?',
          [orderId, bom['rawMaterialId']],
        );
        final consumed = (consumedRows.single['total'] as num).toDouble();
        if (!required.isFinite ||
            required <= 0 ||
            consumed + 0.000001 < required) {
          throw Exception('لم يتم استهلاك الخامات المطلوبة بالكامل');
        }
      }
      final planned = (order['plannedBaseQuantity'] as num).toDouble();
      if (!planned.isFinite || planned <= 0) {
        _throwInvalidUnitSnapshot();
      }
      final outputRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(baseQuantity), 0) AS total FROM production_outputs WHERE productionOrderId = ?',
        [orderId],
      );
      final alreadyProduced = (outputRows.single['total'] as num).toDouble();
      final unitConversionFactor = (order['unitConversionFactor'] as num)
          .toDouble();
      final outputBaseQuantity = quantity * unitConversionFactor;
      if (!outputBaseQuantity.isFinite || outputBaseQuantity <= 0) {
        _throwInvalidUnitSnapshot();
      }
      if (!alreadyProduced.isFinite ||
          alreadyProduced < 0 ||
          alreadyProduced > planned + _quantityTolerance) {
        throw Exception('إجمالي الإنتاج المسجل غير صالح');
      }
      final remaining = (planned - alreadyProduced)
          .clamp(0, planned)
          .toDouble();
      if (outputBaseQuantity > remaining) {
        throw Exception('الكمية تتجاوز الكمية المتبقية');
      }
      await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
      final destination = await txn.query(
        'warehouses',
        columns: ['factoryId'],
        where: 'id = ? AND state = ?',
        whereArgs: [warehouseId, 'active'],
        limit: 1,
      );
      if (destination.isEmpty) throw Exception('المخزن غير متاح');
      final stageContext = await txn.query(
        'production_stages',
        columns: ['factoryId'],
        where: 'id = ?',
        whereArgs: [finalStages.first['productionStageId']],
        limit: 1,
      );
      if (stageContext.isEmpty ||
          destination.single['factoryId'] != stageContext.single['factoryId']) {
        throw Exception('المخزن لا يتبع مصنع المرحلة النهائية');
      }
      final productRows = await txn.query(
        'products',
        where: 'id = ? AND active = 1',
        whereArgs: [order['productId']],
        limit: 1,
      );
      if (productRows.isEmpty) throw Exception('المنتج غير موجود أو غير نشط');
      final variantId = order['variantId'] as String?;
      final product = StockItemOption(
        id: order['productId'] as String,
        productId: order['productId'] as String,
        variantId: variantId,
        name: productRows.first['name'] as String,
        code: productRows.first['code'] as String,
        unitId: order['unitId'] as String,
        type: StockItemType.product,
        active: true,
        identityKind: variantId == null
            ? InventoryIdentityKind.base
            : InventoryIdentityKind.variant,
      );
      await _stock.applyStockInWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        item: product,
        quantity: quantity,
        date: date,
        reference: 'PRODUCTION_OUTPUT:$normalizedOperationId',
        notes: notes,
      );
      final produced = alreadyProduced + outputBaseQuantity;
      final complete = produced >= planned;
      await txn.insert('production_outputs', {
        'id': _id('output'),
        'operationId': normalizedOperationId,
        'productionOrderId': orderId,
        'warehouseId': warehouseId,
        'quantity': quantity,
        'unitId': order['unitId'],
        'productId': product.baseProductId,
        'variantId': product.variantId,
        'baseUnitId': order['baseUnitId'],
        'unitConversionFactor': unitConversionFactor,
        'baseQuantity': outputBaseQuantity,
        'inventoryIdentityKind': product.identityKind.value,
        'identitySnapshotStatus': 'VERIFIED',
        'outputDate': date.millisecondsSinceEpoch,
        'notes': notes,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      final orderChanged = await txn.update(
        'production_orders',
        {
          'producedQuantity': produced,
          'status': complete ? 'COMPLETED' : 'IN_PROGRESS',
          'completionDate': complete ? date.millisecondsSinceEpoch : null,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [orderId, 'IN_PROGRESS'],
      );
      if (orderChanged != 1)
        throw Exception('انتقال حالة أمر الإنتاج غير مسموح');
      return true;
    });
    if (created) {
      await _auditSafely(
        'OUTPUT',
        'ProductionOutput',
        orderId,
        'Operation $normalizedOperationId recorded $quantity of product $outputProductId${outputVariantId == null ? '' : ' variant $outputVariantId'} for production order $orderId in warehouse $warehouseId',
      );
    }
  }

  Future<List<ProductionMaterialRecord>> consumptions(String orderId) async {
    final rows = await (await _db).rawQuery(
      '''
      SELECT c.*, r.name AS rawMaterialName, r.code AS rawMaterialCode,
        w.name AS warehouseName, u.name AS unitName,
        u.abbreviation AS unitAbbreviation
      FROM production_material_consumptions c
      JOIN raw_materials r ON r.id = c.rawMaterialId
      JOIN warehouses w ON w.id = c.warehouseId
      JOIN units u ON u.id = c.unitId
      WHERE c.productionOrderId = ?
      ORDER BY c.consumptionDate ASC, c.createdAt ASC
      ''',
      [orderId],
    );
    return rows
        .map(
          (row) => ProductionMaterialRecord(
            id: row['id'] as String,
            rawMaterialId: row['rawMaterialId'] as String,
            rawMaterialName: row['rawMaterialName'] as String,
            rawMaterialCode: row['rawMaterialCode'] as String,
            warehouseId: row['warehouseId'] as String,
            warehouseName: row['warehouseName'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitId: row['unitId'] as String,
            unitName:
                (row['unitAbbreviation'] as String?)?.trim().isNotEmpty == true
                ? row['unitAbbreviation'] as String
                : row['unitName'] as String,
            date: _date(row['consumptionDate']),
            unitCost: (row['unitCost'] as num).toDouble(),
            operationId: row['operationId'] as String?,
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<List<ProductionWasteRecord>> waste(String orderId) async {
    final rows = await (await _db).rawQuery(
      'SELECT w.*, r.name AS rawMaterialName FROM production_waste w JOIN raw_materials r ON r.id = w.rawMaterialId WHERE w.productionOrderId = ? ORDER BY w.wasteDate ASC',
      [orderId],
    );
    return rows
        .map(
          (row) => ProductionWasteRecord(
            id: row['id'] as String,
            rawMaterialId: row['rawMaterialId'] as String,
            rawMaterialName: row['rawMaterialName'] as String,
            warehouseId: row['warehouseId'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitId: row['unitId'] as String,
            reason: row['reason'] as String,
            date: _date(row['wasteDate']),
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<List<ProductionOutputRecord>> outputs(String orderId) async {
    final rows = await (await _db).rawQuery(
      '''
      SELECT o.*, po.productId, po.variantId, p.name AS productName,
        p.code AS productCode, pv.name AS variantName,
        w.name AS warehouseName, u.name AS unitName,
        u.abbreviation AS unitAbbreviation, bc.status AS costingStatus
      FROM production_outputs o
      JOIN production_orders po ON po.id = o.productionOrderId
      JOIN products p ON p.id = po.productId
      LEFT JOIN product_variants pv ON pv.id = po.variantId
      JOIN warehouses w ON w.id = o.warehouseId
      JOIN units u ON u.id = o.unitId
      LEFT JOIN production_batch_costs bc ON bc.productionOrderId = po.id
      WHERE o.productionOrderId = ?
      ORDER BY o.outputDate ASC, o.createdAt ASC
      ''',
      [orderId],
    );
    return rows
        .map(
          (row) => ProductionOutputRecord(
            id: row['id'] as String,
            productionOrderId: row['productionOrderId'] as String,
            productId: row['productId'] as String,
            productName: row['productName'] as String,
            productCode: row['productCode'] as String,
            variantId: row['variantId'] as String?,
            variantName: row['variantName'] as String?,
            warehouseId: row['warehouseId'] as String,
            warehouseName: row['warehouseName'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitId: row['unitId'] as String,
            unitName:
                (row['unitAbbreviation'] as String?)?.trim().isNotEmpty == true
                ? row['unitAbbreviation'] as String
                : row['unitName'] as String,
            date: _date(row['outputDate']),
            operationId: row['operationId'] as String?,
            costingStatus: row['costingStatus'] as String?,
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<ProductionRoute> _route(Map<String, Object?> row) async {
    final stages = await (await _db).rawQuery(
      'SELECT rs.*, ps.name AS stageName FROM production_route_stages rs JOIN production_stages ps ON ps.id = rs.productionStageId WHERE rs.routeId = ? ORDER BY rs.sequence ASC',
      [row['id']],
    );
    return ProductionRoute(
      id: row['id'] as String,
      productId: row['productId'] as String,
      createdAt: _date(row['createdAt']),
      updatedAt: _date(row['updatedAt']),
      stages: stages
          .map(
            (stage) => ProductionRouteStage(
              id: stage['id'] as String,
              productionStageId: stage['productionStageId'] as String,
              sequence: stage['sequence'] as int,
              stageName: stage['stageName'] as String,
              notes: stage['notes'] as String?,
            ),
          )
          .toList(),
    );
  }

  Future<ProductionOrder> _order(DatabaseExecutor db, String id) async {
    final rows = await db.rawQuery(
      'SELECT po.*, p.name AS productName FROM production_orders po JOIN products p ON p.id = po.productId WHERE po.id = ?',
      [id],
    );
    if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    final row = rows.first;
    final stages = await db.rawQuery(
      'SELECT os.*, ps.name AS stageName FROM production_order_stages os JOIN production_stages ps ON ps.id = os.productionStageId WHERE os.productionOrderId = ? ORDER BY os.sequence ASC',
      [id],
    );
    return ProductionOrder(
      id: row['id'] as String,
      orderNumber: row['orderNumber'] as String,
      productId: row['productId'] as String,
      productName: row['productName'] as String?,
      variantId: row['variantId'] as String?,
      routeId: row['routeId'] as String?,
      plannedQuantity: (row['plannedQuantity'] as num).toDouble(),
      producedQuantity: (row['producedQuantity'] as num).toDouble(),
      status: _status(row['status'] as String),
      unitId: row['unitId'] as String?,
      baseUnitId: row['baseUnitId'] as String?,
      unitConversionFactor: (row['unitConversionFactor'] as num?)?.toDouble(),
      plannedBaseQuantity: (row['plannedBaseQuantity'] as num?)?.toDouble(),
      unitSnapshotStatus: ProductionUnitSnapshotStatusValue.fromValue(
        row['unitSnapshotStatus'],
      ),
      startDate: row['startDate'] == null ? null : _date(row['startDate']),
      completionDate: row['completionDate'] == null
          ? null
          : _date(row['completionDate']),
      notes: row['notes'] as String?,
      createdAt: _date(row['createdAt']),
      updatedAt: _date(row['updatedAt']),
      stages: stages
          .map(
            (stage) => ProductionOrderStage(
              id: stage['id'] as String,
              productionOrderId: id,
              productionStageId: stage['productionStageId'] as String,
              sequence: stage['sequence'] as int,
              status: _stageStatus(stage['status'] as String),
              stageName: stage['stageName'] as String,
              startedAt: stage['startedAt'] == null
                  ? null
                  : _date(stage['startedAt']),
              completedAt: stage['completedAt'] == null
                  ? null
                  : _date(stage['completedAt']),
              notes: stage['notes'] as String?,
            ),
          )
          .toList(),
    );
  }

  Future<void> _changeStatus(
    String id,
    ProductionOrderStatus from,
    ProductionOrderStatus to,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
      if (_status(rows.single['status'] as String) != from) {
        throw Exception('انتقال حالة أمر الإنتاج غير مسموح');
      }
      if (to == ProductionOrderStatus.planned) {
        _requireVerifiedUnitSnapshot(rows.single);
      }
      final changed = await txn.update(
        'production_orders',
        {
          'status': _statusValue(to),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, _statusValue(from)],
      );
      if (changed != 1) throw Exception('انتقال حالة أمر الإنتاج غير مسموح');
    });
  }

  Future<Map<String, Object?>> _stageRow(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'production_order_stages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('مرحلة أمر الإنتاج غير موجودة');
    return rows.first;
  }

  Future<void> _requireInProgress(DatabaseExecutor db, String orderId) async {
    final rows = await db.query(
      'production_orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    if (rows.first['status'] != 'IN_PROGRESS') {
      throw Exception('يجب أن يكون أمر الإنتاج قيد التنفيذ');
    }
    _requireVerifiedUnitSnapshot(rows.first);
  }

  void _requireVerifiedUnitSnapshot(Map<String, Object?> order) {
    final unitId = order['unitId'];
    final baseUnitId = order['baseUnitId'];
    final factorValue = order['unitConversionFactor'];
    final plannedValue = order['plannedQuantity'];
    final plannedBaseValue = order['plannedBaseQuantity'];
    if (order['unitSnapshotStatus'] !=
            ProductionUnitSnapshotStatus.verified.value ||
        unitId is! String ||
        unitId.trim().isEmpty ||
        baseUnitId is! String ||
        baseUnitId.trim().isEmpty ||
        factorValue is! num ||
        plannedValue is! num ||
        plannedBaseValue is! num) {
      _throwInvalidUnitSnapshot();
    }
    final factor = factorValue.toDouble();
    final planned = plannedValue.toDouble();
    final plannedBase = plannedBaseValue.toDouble();
    final calculatedBase = planned * factor;
    if (unitId != baseUnitId ||
        !factor.isFinite ||
        factor <= 0 ||
        factor != 1.0 ||
        !planned.isFinite ||
        planned <= 0 ||
        !plannedBase.isFinite ||
        plannedBase <= 0 ||
        !calculatedBase.isFinite ||
        (plannedBase - calculatedBase).abs() > _quantityTolerance) {
      _throwInvalidUnitSnapshot();
    }
  }

  Never
  _throwInvalidUnitSnapshot() => throw const ProductionUnitSnapshotException(
    'لقطة الوحدة التاريخية لأمر الإنتاج غير معروفة أو غير صالحة؛ أوقف العملية واطلب تسوية قبل المتابعة.',
  );

  void _requireOutputMatchesOrderSnapshot(
    Map<String, Object?> output,
    Map<String, Object?> order,
  ) {
    final quantityValue = output['quantity'];
    final baseQuantityValue = output['baseQuantity'];
    final factorValue = output['unitConversionFactor'];
    final quantity = (quantityValue as num?)?.toDouble();
    final baseQuantity = (baseQuantityValue as num?)?.toDouble();
    final factor = (factorValue as num?)?.toDouble();
    final variantId = order['variantId'] as String?;
    final identityKind = variantId == null
        ? InventoryIdentityKind.base
        : InventoryIdentityKind.variant;
    if (output['productId'] != order['productId'] ||
        output['variantId'] != variantId ||
        output['unitId'] != order['unitId'] ||
        output['baseUnitId'] != order['baseUnitId'] ||
        output['inventoryIdentityKind'] != identityKind.value ||
        output['identitySnapshotStatus'] != 'VERIFIED' ||
        quantity == null ||
        baseQuantity == null ||
        factor == null ||
        !quantity.isFinite ||
        quantity <= 0 ||
        !baseQuantity.isFinite ||
        baseQuantity <= 0 ||
        factor != 1.0 ||
        (baseQuantity - quantity).abs() > _quantityTolerance) {
      _throwInvalidUnitSnapshot();
    }
  }

  Future<StockItemOption> _rawMaterial(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'raw_materials',
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الخامة غير موجودة أو غير نشطة');
    return StockItemOption(
      id: id,
      name: rows.first['name'] as String,
      code: rows.first['code'] as String,
      unitId: rows.first['unitId'] as String,
      type: StockItemType.rawMaterial,
      active: true,
    );
  }

  Future<void> _validateOrderVariantIdentity(
    DatabaseExecutor db,
    String productId,
    String? variantId,
  ) async {
    final variants = await db.query(
      'product_variants',
      columns: ['id'],
      where: 'productId = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (variants.isEmpty) {
      if (variantId != null) {
        throw Exception('بديل المنتج لا ينتمي إلى المنتج المحدد');
      }
      return;
    }
    if (variantId == null) throw Exception('يجب اختيار بديل المنتج');
    final selected = await db.query(
      'product_variants',
      columns: ['id'],
      where: 'id = ? AND productId = ? AND active = 1',
      whereArgs: [variantId, productId],
      limit: 1,
    );
    if (selected.isEmpty) {
      throw Exception('بديل المنتج غير موجود أو غير نشط');
    }
  }

  Future<void> _auditSafely(
    String action,
    String entityType,
    String entityId,
    String description,
  ) async {
    try {
      await _security.audit(
        action: action,
        module: 'Production',
        entityType: entityType,
        entityId: entityId,
        description: description,
      );
    } catch (_) {
      // Audit failure must not break a successful production mutation.
    }
  }

  ProductionOrderStatus _status(String value) => ProductionOrderStatus.values
      .firstWhere((item) => _statusValue(item) == value);
  String _statusValue(ProductionOrderStatus value) => switch (value) {
    ProductionOrderStatus.draft => 'DRAFT',
    ProductionOrderStatus.planned => 'PLANNED',
    ProductionOrderStatus.inProgress => 'IN_PROGRESS',
    ProductionOrderStatus.completed => 'COMPLETED',
    ProductionOrderStatus.cancelled => 'CANCELLED',
  };
  ProductionStageStatus _stageStatus(String value) =>
      ProductionStageStatus.values.firstWhere(
        (item) =>
            item.name.replaceAll('inProgress', 'IN_PROGRESS').toUpperCase() ==
            value,
      );
  DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
}
