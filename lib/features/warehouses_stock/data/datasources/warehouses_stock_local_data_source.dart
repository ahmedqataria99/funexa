import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'package:furnexa/features/notifications/data/datasources/notifications_local_data_source.dart';

class WarehousesStockLocalDataSource {
  static int _idSequence = 0;
  final AccountingLocalDataSource _accounting;
  final SecurityLocalDataSource _security = SecurityLocalDataSource();

  WarehousesStockLocalDataSource([AccountingLocalDataSource? accounting])
    : _accounting = accounting ?? AccountingLocalDataSource();

  Future<Database> get _db async => FurnexaDatabase.instance.database;
  Future<List<Warehouse>> warehouses() async {
    final rows = await (await _db).query(
      'warehouses',
      where: 'state = ?',
      whereArgs: ['active'],
      orderBy: 'name ASC',
    );
    final warehouses = rows.map(Warehouse.fromMap).toList();
    await FurnexaDatabaseDiagnostics.capture(
      source: 'stock.activeWarehouses',
      stageCounts: {
        'sqliteActiveRows': rows.length,
        'mappedEntities': warehouses.length,
        'scopeFilteredRows': null,
        'finalRepositoryRows': warehouses.length,
      },
    );
    return warehouses;
  }

  Future<List<StockItemOption>> activeItems() async {
    final db = await _db;
    final raw = await db.query(
      'raw_materials',
      where: 'active = 1',
      orderBy: 'name ASC',
    );
    final products = await db.query(
      'products',
      where: 'active = 1',
      orderBy: 'name ASC',
    );
    return [
      ...raw.map(
        (row) => StockItemOption(
          id: row['id'] as String,
          name: row['name'] as String,
          code: row['code'] as String,
          unitId: row['unitId'] as String,
          type: StockItemType.rawMaterial,
          active: true,
        ),
      ),
      ...products.map(
        (row) => StockItemOption(
          id: row['id'] as String,
          name: row['name'] as String,
          code: row['code'] as String,
          unitId: row['unitId'] as String,
          type: StockItemType.product,
          active: true,
        ),
      ),
    ];
  }

  Future<List<StockLine>> stock(
    String? warehouseId, {
    String query = '',
    StockItemType? itemType,
  }) async {
    final db = await _db;
    final items = await _allItems(db);
    final units = await db.query('units');
    final normalized = query.trim().toLowerCase();

    final rows = warehouseId == null
        ? await db.query(
            'stock_balances',
            columns: ['itemId', 'itemType', 'SUM(quantity) AS quantity'],
            where: itemType == null
                ? 'quantity > 0'
                : 'quantity > 0 AND itemType = ?',
            whereArgs: itemType == null ? const [] : [itemType.value],
            groupBy: 'itemId, itemType',
            orderBy: 'itemId ASC',
          )
        : await db.query(
            'stock_balances',
            columns: [
              'id',
              'warehouseId',
              'itemId',
              'itemType',
              'quantity',
              'createdAt',
              'updatedAt',
            ],
            where: itemType == null
                ? 'warehouseId = ? AND quantity > 0'
                : 'warehouseId = ? AND quantity > 0 AND itemType = ?',
            whereArgs: itemType == null
                ? [warehouseId]
                : [warehouseId, itemType.value],
            orderBy: 'updatedAt DESC',
          );

    var catalogMatches = 0;
    var inactiveCatalogMatches = 0;
    var searchMatches = 0;
    final stockLines = <StockLine>[];
    for (final row in rows) {
      final itemId = row['itemId'] as String;
      final type = row['itemType'] == 'PRODUCT'
          ? StockItemType.product
          : StockItemType.rawMaterial;
      final item = items
          .where((value) => value.id == itemId && value.type == type)
          .firstOrNull;
      if (item == null) continue;
      catalogMatches++;
      if (!item.active) inactiveCatalogMatches++;
      if (normalized.isNotEmpty &&
          !'${item.name} ${item.code}'.toLowerCase().contains(normalized)) {
        continue;
      }
      searchMatches++;
      final quantity = (row['quantity'] as num).toDouble();
      final balance = StockBalance(
        id: warehouseId == null
            ? 'ALL:$itemId:${type.value}'
            : (row['id'] as String),
        warehouseId: warehouseId ?? 'ALL_WAREHOUSES',
        itemId: itemId,
        itemType: type,
        quantity: quantity,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      final unit = units
          .where((value) => value['id'] == item.unitId)
          .firstOrNull;
      stockLines.add(
        StockLine(
          balance: balance,
          item: item,
          unitName: unit?['name'] as String? ?? '-',
        ),
      );
    }
    await FurnexaDatabaseDiagnostics.capture(
      source: 'stock.stockStages',
      stockQuery: query,
      stockItemTypeFilter: itemType?.value,
      warehouseId: warehouseId,
      stageCounts: {
        'sqliteStockRowsAfterWarehouseQuantityAndTypeFilters': rows.length,
        'catalogRowsLoaded': items.length,
        'idAndTypeMatchedRows': catalogMatches,
        'inactiveMatchedRowsNotFilteredByCurrentCode': inactiveCatalogMatches,
        'searchMatchedRows': searchMatches,
        'mappedStockLines': stockLines.length,
        'finalDataSourceRows': stockLines.length,
      },
    );
    return stockLines;
  }

  Future<List<StockLedgerLine>> ledger(
    String warehouseId,
    String itemId,
    StockItemType itemType,
  ) async {
    final rows = await (await _db).query(
      'stock_transactions',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType.value],
      orderBy: 'transactionDate ASC, createdAt ASC, id ASC',
    );
    var running = 0.0;
    return rows.map(StockTransaction.fromMap).map((transaction) {
      running += transaction.signedQuantity;
      return StockLedgerLine(transaction: transaction, balanceAfter: running);
    }).toList();
  }

  Future<double> balance(
    String warehouseId,
    String itemId,
    StockItemType itemType,
  ) async {
    final row = await (await _db).query(
      'stock_balances',
      columns: ['quantity'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType.value],
      limit: 1,
    );
    return row.isEmpty ? 0 : (row.first['quantity'] as num).toDouble();
  }

  Future<void> stockIn({
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  }) async {
    _security.require('WAREHOUSE_STOCK_EDIT');
    await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
    await _movement(
      warehouseId: warehouseId,
      item: item,
      quantity: quantity,
      date: date,
      type: StockTransactionType.stockIn,
      reference: reference,
      notes: notes,
      operationId: operationId,
    );
    await _auditSafely(
      action: 'STOCK_IN',
      entityId: operationId ?? reference ?? item.id,
      description: 'Stock in posted to $warehouseId',
    );
    await NotificationsLocalDataSource().evaluateStock(
      warehouseId: warehouseId,
      itemId: item.id,
      itemType: item.type.value,
    );
  }

  Future<void> applyStockInWithinTransaction({
    required DatabaseExecutor executor,
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  }) async {
    _positive(quantity);
    await _validateWarehouse(executor, warehouseId);
    await _validateItem(executor, item);
    final current = await _getBalance(executor, warehouseId, item);
    await _writeBalance(executor, warehouseId, item, current + quantity);
    await _writeTransaction(
      executor,
      warehouseId,
      item,
      StockTransactionType.stockIn,
      quantity,
      date,
      reference,
      notes,
      operationId: operationId,
    );
  }

  Future<void> stockOut({
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  }) async {
    _security.require('WAREHOUSE_STOCK_EDIT');
    await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
    await _movement(
      warehouseId: warehouseId,
      item: item,
      quantity: quantity,
      date: date,
      type: StockTransactionType.stockOut,
      reference: reference,
      notes: notes,
      operationId: operationId,
    );
    await _auditSafely(
      action: 'STOCK_OUT',
      entityId: operationId ?? reference ?? item.id,
      description: 'Stock out posted from $warehouseId',
    );
    await NotificationsLocalDataSource().evaluateStock(
      warehouseId: warehouseId,
      itemId: item.id,
      itemType: item.type.value,
    );
  }

  Future<void> applyStockOutWithinTransaction({
    required DatabaseExecutor executor,
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
  }) async {
    _positive(quantity);
    await _validateWarehouse(executor, warehouseId);
    await _validateItem(executor, item);
    final current = await _getBalance(executor, warehouseId, item);
    if (current < quantity) {
      throw Exception('الكمية المتاحة في المخزن غير كافية');
    }
    await _writeBalance(executor, warehouseId, item, current - quantity);
    await _writeTransaction(
      executor,
      warehouseId,
      item,
      StockTransactionType.stockOut,
      quantity,
      date,
      reference,
      notes,
    );
  }

  Future<void> _movement({
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    required StockTransactionType type,
    String? reference,
    String? notes,
    String? operationId,
  }) async {
    if (operationId != null && operationId.trim().isEmpty) {
      throw Exception('معرف العملية غير صالح');
    }
    _positive(quantity);
    final db = await _db;
    await db.transaction((txn) async {
      await _validateWarehouse(txn, warehouseId);
      await _validateItem(txn, item);
      if (operationId != null &&
          await _operationExists(txn, operationId.trim())) {
        throw Exception('تم تسجيل العملية من قبل');
      }
      final current = await _getBalance(txn, warehouseId, item);
      final next = type == StockTransactionType.stockOut
          ? current - quantity
          : current + quantity;
      if (next < 0) throw Exception('الكمية المتاحة غير كافية');
      await _writeBalance(txn, warehouseId, item, next);
      await _writeTransaction(
        txn,
        warehouseId,
        item,
        type,
        quantity,
        date,
        reference,
        notes,
        operationId: operationId,
      );
    });
    await FurnexaDatabaseDiagnostics.capture(
      source: 'stock.movement',
      warehouseId: warehouseId,
      itemId: item.id,
      itemType: item.type.value,
    );
  }

  Future<void> transfer({
    required String sourceWarehouseId,
    required String destinationWarehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  }) async {
    _security.require('WAREHOUSE_STOCK_EDIT');
    await _security.requireResourceScope(
      ScopeType.warehouse,
      sourceWarehouseId,
    );
    await _security.requireResourceScope(
      ScopeType.warehouse,
      destinationWarehouseId,
    );
    _positive(quantity);
    if (sourceWarehouseId == destinationWarehouseId) {
      throw Exception('لا يمكن التحويل إلى نفس المخزن');
    }
    final db = await _db;
    await db.transaction((txn) async {
      await _validateWarehouse(txn, sourceWarehouseId);
      await _validateWarehouse(txn, destinationWarehouseId);
      await _validateItem(txn, item);
      if (operationId != null &&
          await _operationExists(txn, operationId.trim())) {
        throw Exception('تم تسجيل العملية من قبل');
      }
      final current = await _getBalance(txn, sourceWarehouseId, item);
      if (current < quantity) throw Exception('الكمية المتاحة غير كافية');
      final transferId =
          reference ??
          'TRANSFER:$sourceWarehouseId:$destinationWarehouseId:${item.id}:${date.millisecondsSinceEpoch}';
      final valuation = await _accounting.valuationWithinTransaction(
        txn,
        sourceWarehouseId,
        item.id,
        item.type.value,
      );
      await _writeBalance(txn, sourceWarehouseId, item, current - quantity);
      await _writeBalance(
        txn,
        destinationWarehouseId,
        item,
        await _getBalance(txn, destinationWarehouseId, item) + quantity,
      );
      await _writeTransaction(
        txn,
        sourceWarehouseId,
        item,
        StockTransactionType.transferOut,
        quantity,
        date,
        reference ?? transferId,
        notes,
        operationId: operationId,
      );
      await _writeTransaction(
        txn,
        destinationWarehouseId,
        item,
        StockTransactionType.transferIn,
        quantity,
        date,
        reference ?? transferId,
        notes,
        operationId: operationId,
      );
      if (valuation != null && valuation.averageCost > 0) {
        final value = quantity * valuation.averageCost;
        await _accounting.consumeInventoryValueWithinTransaction(
          executor: txn,
          warehouseId: sourceWarehouseId,
          itemId: item.id,
          itemType: item.type.value,
          quantity: quantity,
        );
        await _accounting.receiveInventoryValueWithinTransaction(
          executor: txn,
          warehouseId: destinationWarehouseId,
          itemId: item.id,
          itemType: item.type.value,
          quantity: quantity,
          unitCost: valuation.averageCost,
        );
        await _accounting.postInventoryTransferWithinTransaction(
          executor: txn,
          referenceId: transferId,
          date: date,
          value: value,
        );
      }
    });
    await _auditSafely(
      action: 'TRANSFER',
      entityId: operationId ?? reference ?? item.id,
      description:
          'Stock transferred from $sourceWarehouseId to $destinationWarehouseId',
    );
    await NotificationsLocalDataSource().evaluateStock(
      warehouseId: sourceWarehouseId,
      itemId: item.id,
      itemType: item.type.value,
    );
    await NotificationsLocalDataSource().evaluateStock(
      warehouseId: destinationWarehouseId,
      itemId: item.id,
      itemType: item.type.value,
    );
  }

  Future<void> adjust({
    required String warehouseId,
    required StockItemOption item,
    required double difference,
    required DateTime date,
    required String reason,
    String? notes,
    String? operationId,
  }) async {
    _security.require('WAREHOUSE_STOCK_EDIT');
    await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
    if (difference == 0) throw Exception('قيمة التسوية يجب ألا تساوي صفراً');
    final db = await _db;
    await db.transaction((txn) async {
      await _validateWarehouse(txn, warehouseId);
      await _validateItem(txn, item);
      if (operationId != null &&
          await _operationExists(txn, operationId.trim())) {
        throw Exception('تم تسجيل العملية من قبل');
      }
      final next = await _getBalance(txn, warehouseId, item) + difference;
      if (next < 0) throw Exception('لا يمكن أن يصبح المخزون سالباً');
      final transactionId =
          'ADJUSTMENT:$warehouseId:${item.id}:${date.millisecondsSinceEpoch}:$reason';
      final valuation = await _accounting.valuationWithinTransaction(
        txn,
        warehouseId,
        item.id,
        item.type.value,
      );
      await _writeBalance(txn, warehouseId, item, next);
      await _writeTransaction(
        txn,
        warehouseId,
        item,
        StockTransactionType.adjustment,
        difference.abs(),
        date,
        difference < 0 ? 'ADJUSTMENT_OUT:$reason' : reason,
        notes,
        operationId: operationId,
      );
      if (valuation != null && valuation.averageCost > 0) {
        final value = difference * valuation.averageCost;
        await _accounting.adjustInventoryValueWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          itemId: item.id,
          itemType: item.type.value,
          difference: difference,
        );
        await _accounting.postInventoryAdjustmentWithinTransaction(
          executor: txn,
          referenceId: transactionId,
          date: date,
          value: value,
        );
      }
    });
    await _auditSafely(
      action: 'ADJUSTMENT',
      entityId: operationId ?? reason,
      description: 'Stock adjusted in $warehouseId',
    );
    await NotificationsLocalDataSource().evaluateStock(
      warehouseId: warehouseId,
      itemId: item.id,
      itemType: item.type.value,
      adjustment: true,
    );
  }

  Future<List<StockItemOption>> _allItems(DatabaseExecutor db) async {
    final raw = await db.query('raw_materials');
    final products = await db.query('products');
    return [
      ...raw.map(
        (row) => StockItemOption(
          id: row['id'] as String,
          name: row['name'] as String,
          code: row['code'] as String,
          unitId: row['unitId'] as String,
          type: StockItemType.rawMaterial,
          active: row['active'] == 1,
        ),
      ),
      ...products.map(
        (row) => StockItemOption(
          id: row['id'] as String,
          name: row['name'] as String,
          code: row['code'] as String,
          unitId: row['unitId'] as String,
          type: StockItemType.product,
          active: row['active'] == 1,
        ),
      ),
    ];
  }

  Future<void> _validateWarehouse(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'warehouses',
      columns: ['id'],
      where: 'id = ? AND state = ?',
      whereArgs: [id, 'active'],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('المخزن غير موجود أو غير نشط');
  }

  Future<void> _validateItem(DatabaseExecutor db, StockItemOption item) async {
    final table = item.type == StockItemType.rawMaterial
        ? 'raw_materials'
        : 'products';
    final rows = await db.query(
      table,
      columns: ['id', 'unitId'],
      where: 'id = ? AND active = 1',
      whereArgs: [item.id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الصنف غير موجود أو غير نشط');
    if (rows.first['unitId'] != item.unitId) {
      throw Exception('وحدة الصنف غير متوافقة');
    }
  }

  Future<double> _getBalance(
    DatabaseExecutor db,
    String warehouseId,
    StockItemOption item,
  ) async {
    final rows = await db.query(
      'stock_balances',
      columns: ['quantity'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, item.id, item.type.value],
      limit: 1,
    );
    return rows.isEmpty ? 0 : (rows.first['quantity'] as num).toDouble();
  }

  Future<void> _writeBalance(
    DatabaseExecutor db,
    String warehouseId,
    StockItemOption item,
    double quantity,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'stock_balances',
      columns: ['id'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, item.id, item.type.value],
      limit: 1,
    );
    final values = <String, Object?>{'quantity': quantity, 'updatedAt': now};
    if (rows.isEmpty) {
      values.addAll({
        'id': _id('balance'),
        'warehouseId': warehouseId,
        'itemId': item.id,
        'itemType': item.type.value,
        'createdAt': now,
      });
      await db.insert('stock_balances', values);
    } else {
      await db.update(
        'stock_balances',
        values,
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    }
  }

  Future<void> _writeTransaction(
    DatabaseExecutor db,
    String warehouseId,
    StockItemOption item,
    StockTransactionType type,
    double quantity,
    DateTime date,
    String? reference,
    String? notes, {
    String? operationId,
  }) async {
    await db.insert('stock_transactions', {
      'id': _id('transaction'),
      'warehouseId': warehouseId,
      'itemId': item.id,
      'itemType': item.type.value,
      'transactionType': type.value,
      'quantity': quantity,
      'unitId': item.unitId,
      'reference': operationId == null
          ? reference?.trim()
          : 'OPERATION:${operationId.trim()}',
      'notes': notes?.trim(),
      'transactionDate': date.millisecondsSinceEpoch,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _auditSafely({
    required String action,
    required String entityId,
    required String description,
  }) async {
    try {
      await _security.audit(
        action: action,
        module: 'Warehouse',
        entityType: 'StockTransaction',
        entityId: entityId,
        description: description,
      );
    } catch (_) {
      // Audit failure must not roll back a committed stock mutation.
    }
  }

  Future<bool> _operationExists(DatabaseExecutor db, String operationId) async {
    final rows = await db.query(
      'stock_transactions',
      columns: ['id'],
      where: 'reference = ?',
      whereArgs: ['OPERATION:$operationId'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  void _positive(double quantity) {
    if (quantity <= 0) throw Exception('الكمية يجب أن تكون أكبر من صفر');
  }

  String _id(String prefix) {
    _idSequence++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idSequence';
  }
}
