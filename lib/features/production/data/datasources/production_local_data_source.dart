import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';
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

  String _number() => 'PRD-${DateTime.now().millisecondsSinceEpoch}';

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
    required double plannedQuantity,
    String? notes,
  }) async {
    _security.require('PRODUCTION_EDIT');
    if (plannedQuantity <= 0)
      throw Exception('كمية الإنتاج يجب أن تكون أكبر من صفر');
    final db = await _db;
    return db.transaction((txn) async {
      final productRows = await txn.query(
        'products',
        where: 'id = ? AND active = 1',
        whereArgs: [productId],
        limit: 1,
      );
      if (productRows.isEmpty) throw Exception('المنتج غير موجود أو غير نشط');
      if (variantId != null &&
          (await txn.query(
            'product_variants',
            columns: ['id'],
            where: 'id = ? AND productId = ? AND active = 1',
            whereArgs: [variantId, productId],
            limit: 1,
          )).isEmpty) {
        throw Exception('بديل المنتج غير موجود أو غير نشط');
      }
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
          where: 'id = ? AND active = 1',
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
    final rows = await db.query(
      'production_orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    if (_status(rows.first['status'] as String) !=
        ProductionOrderStatus.planned) {
      throw Exception('يجب تخطيط أمر الإنتاج قبل البدء');
    }
    await db.update(
      'production_orders',
      {
        'status': 'IN_PROGRESS',
        'startDate': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final rows = await db.query(
      'production_orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    final status = _status(rows.first['status'] as String);
    if (status != ProductionOrderStatus.draft &&
        status != ProductionOrderStatus.planned) {
      throw Exception('لا يمكن إلغاء أمر إنتاج بدأ أو اكتمل');
    }
    await db.update(
      'production_orders',
      {
        'status': 'CANCELLED',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
    await db.transaction((txn) async {
      final row = await _stageRow(txn, id);
      await _security.requireResourceScope(
        ScopeType.productionStage,
        row['productionStageId'] as String,
      );
      await _requireInProgress(txn, row['productionOrderId'] as String);
      if (row['status'] != 'PENDING') throw Exception('المرحلة ليست معلقة');
      final previous = await txn.query(
        'production_order_stages',
        where: 'productionOrderId = ? AND sequence < ?',
        whereArgs: [row['productionOrderId'], row['sequence']],
        orderBy: 'sequence DESC',
        limit: 1,
      );
      if (previous.isNotEmpty &&
          !['COMPLETED', 'SKIPPED'].contains(previous.first['status'])) {
        throw Exception('يجب إكمال المرحلة السابقة أولاً');
      }
      await txn.update(
        'production_order_stages',
        {
          'status': 'IN_PROGRESS',
          'startedAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> completeStage(String id) async {
    _security.require('PRODUCTION_EDIT');
    final db = await _db;
    final row = await _stageRow(db, id);
    await _security.requireResourceScope(
      ScopeType.productionStage,
      row['productionStageId'] as String,
    );
    await _requireInProgress(db, row['productionOrderId'] as String);
    if (row['status'] != 'IN_PROGRESS')
      throw Exception('لا يمكن إكمال مرحلة غير قيد التنفيذ');
    await db.update(
      'production_order_stages',
      {
        'status': 'COMPLETED',
        'completedAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _auditSafely(
      'STAGE_COMPLETE',
      'ProductionStage',
      id,
      'Production stage completed',
    );
  }

  Future<void> skipStage(String id, String reason) async {
    _security.require('PRODUCTION_EDIT');
    if (reason.trim().isEmpty) throw Exception('سبب تخطي المرحلة مطلوب');
    final db = await _db;
    final row = await _stageRow(db, id);
    await _security.requireResourceScope(
      ScopeType.productionStage,
      row['productionStageId'] as String,
    );
    await _requireInProgress(db, row['productionOrderId'] as String);
    if (row['status'] != 'PENDING' && row['status'] != 'IN_PROGRESS')
      throw Exception('لا يمكن تخطي المرحلة الحالية');
    await db.update(
      'production_order_stages',
      {
        'status': 'SKIPPED',
        'completedAt': DateTime.now().millisecondsSinceEpoch,
        'notes': reason.trim(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _auditSafely(
      'STAGE_SKIP',
      'ProductionStage',
      id,
      'Production stage skipped',
    );
  }

  Future<List<ProductionMaterialRequirement>> requirements(
    String orderId,
  ) async {
    _security.require('PRODUCTION_EDIT');
    final db = await _db;
    final orderRows = await db.query(
      'production_orders',
      columns: ['productId', 'plannedQuantity'],
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (orderRows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    final rows = await db.rawQuery(
      '''
      SELECT b.rawMaterialId, r.name AS rawMaterialName, r.unitId,
        b.quantity * ? AS requiredQuantity,
        COALESCE((SELECT SUM(c.quantity) FROM production_material_consumptions c WHERE c.productionOrderId = ? AND c.rawMaterialId = b.rawMaterialId), 0) AS consumedQuantity
      FROM production_order_bom_items b JOIN raw_materials r ON r.id = b.rawMaterialId
      WHERE b.productionOrderId = ?
      ORDER BY r.name ASC
    ''',
      [orderRows.first['plannedQuantity'], orderId, orderId],
    );
    return rows
        .map(
          (row) => ProductionMaterialRequirement(
            rawMaterialId: row['rawMaterialId'] as String,
            rawMaterialName: row['rawMaterialName'] as String,
            unitId: row['unitId'] as String,
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
    String? notes,
  }) async {
    _security.require('PRODUCTION_EDIT');
    await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
    if (quantity <= 0)
      throw Exception('كمية الاستهلاك يجب أن تكون أكبر من صفر');
    final db = await _db;
    await db.transaction((txn) async {
      await _requireInProgress(txn, orderId);
      final material = await _rawMaterial(txn, rawMaterialId);
      final order = await txn.query(
        'production_orders',
        columns: ['productId', 'plannedQuantity'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      final bom = await txn.query(
        'production_order_bom_items',
        columns: ['quantity', 'unitId'],
        where: 'productionOrderId = ? AND rawMaterialId = ?',
        whereArgs: [orderId, rawMaterialId],
        limit: 1,
      );
      if (bom.isEmpty)
        throw Exception('الخامة غير موجودة في قائمة مواد المنتج');
      if (bom.first['unitId'] != material.unitId) {
        throw Exception('وحدة الخامة غير متوافقة مع أمر الإنتاج');
      }
      final consumed = await txn.rawQuery(
        'SELECT COALESCE(SUM(quantity), 0) AS total FROM production_material_consumptions WHERE productionOrderId = ? AND rawMaterialId = ?',
        [orderId, rawMaterialId],
      );
      final remaining =
          (bom.first['quantity'] as num).toDouble() *
              (order.first['plannedQuantity'] as num).toDouble() -
          (consumed.first['total'] as num).toDouble();
      if (quantity > remaining)
        throw Exception('الكمية تتجاوز الكمية المتبقية حسب أمر الإنتاج');
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
        reference: 'PROD:$orderId',
        notes: notes,
      );
      await txn.insert('production_material_consumptions', {
        'id': _id('consumption'),
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
    });
    await _auditSafely(
      'MATERIAL_CONSUMPTION',
      'ProductionConsumption',
      orderId,
      'Production material consumed',
    );
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
    if (reason.trim().isEmpty) throw Exception('سبب الهالك مطلوب');
    final db = await _db;
    await db.transaction((txn) async {
      await _requireInProgress(txn, orderId);
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
    String? notes,
  }) async {
    _security.require('PRODUCTION_EDIT');
    await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
    if (quantity <= 0) throw Exception('كمية الإنتاج يجب أن تكون أكبر من صفر');
    final db = await _db;
    await db.transaction((txn) async {
      await _requireInProgress(txn, orderId);
      final orderRows = await txn.query(
        'production_orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      final order = orderRows.first;
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
      final remaining =
          (order['plannedQuantity'] as num).toDouble() -
          (order['producedQuantity'] as num).toDouble();
      if (quantity > remaining)
        throw Exception('كمية الإنتاج تتجاوز الكمية المتبقية');
      final productRows = await txn.query(
        'products',
        where: 'id = ? AND active = 1',
        whereArgs: [order['productId']],
        limit: 1,
      );
      if (productRows.isEmpty) throw Exception('المنتج غير موجود أو غير نشط');
      final product = StockItemOption(
        id: order['productId'] as String,
        name: productRows.first['name'] as String,
        code: productRows.first['code'] as String,
        unitId: productRows.first['unitId'] as String,
        type: StockItemType.product,
        active: true,
      );
      await _stock.applyStockInWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        item: product,
        quantity: quantity,
        date: date,
        reference: 'PROD:${order['orderNumber']}',
        notes: notes,
      );
      final produced = (order['producedQuantity'] as num).toDouble() + quantity;
      final complete = produced >= (order['plannedQuantity'] as num).toDouble();
      await txn.insert('production_outputs', {
        'id': _id('output'),
        'productionOrderId': orderId,
        'warehouseId': warehouseId,
        'quantity': quantity,
        'unitId': product.unitId,
        'outputDate': date.millisecondsSinceEpoch,
        'notes': notes,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await txn.update(
        'production_orders',
        {
          'producedQuantity': produced,
          'status': complete ? 'COMPLETED' : 'IN_PROGRESS',
          'completionDate': complete ? date.millisecondsSinceEpoch : null,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
    await _auditSafely(
      'OUTPUT',
      'ProductionOutput',
      orderId,
      'Production output recorded',
    );
  }

  Future<List<ProductionMaterialRecord>> consumptions(String orderId) async {
    final rows = await (await _db).rawQuery(
      'SELECT c.*, r.name AS rawMaterialName FROM production_material_consumptions c JOIN raw_materials r ON r.id = c.rawMaterialId WHERE c.productionOrderId = ? ORDER BY c.consumptionDate ASC',
      [orderId],
    );
    return rows
        .map(
          (row) => ProductionMaterialRecord(
            id: row['id'] as String,
            rawMaterialId: row['rawMaterialId'] as String,
            rawMaterialName: row['rawMaterialName'] as String,
            warehouseId: row['warehouseId'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitId: row['unitId'] as String,
            date: _date(row['consumptionDate']),
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
    final rows = await (await _db).query(
      'production_outputs',
      where: 'productionOrderId = ?',
      whereArgs: [orderId],
      orderBy: 'outputDate ASC',
    );
    return rows
        .map(
          (row) => ProductionOutputRecord(
            id: row['id'] as String,
            warehouseId: row['warehouseId'] as String,
            quantity: (row['quantity'] as num).toDouble(),
            unitId: row['unitId'] as String,
            date: _date(row['outputDate']),
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
    final rows = await db.query(
      'production_orders',
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    if (_status(rows.first['status'] as String) != from)
      throw Exception('انتقال حالة أمر الإنتاج غير مسموح');
    await db.update(
      'production_orders',
      {
        'status': _statusValue(to),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
      columns: ['status'],
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('أمر الإنتاج غير موجود');
    if (rows.first['status'] != 'IN_PROGRESS')
      throw Exception('يجب أن يكون أمر الإنتاج قيد التنفيذ');
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
