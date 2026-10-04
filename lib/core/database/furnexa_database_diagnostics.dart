import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class FurnexaDatabaseDiagnostics {
  FurnexaDatabaseDiagnostics._();

  static const bool enabled = bool.fromEnvironment(
    'FURNEXA_DB_DIAGNOSTICS',
    defaultValue: false,
  );

  static Future<String> get logFilePath async {
    final database = await FurnexaDatabase.instance.database;
    return p.join(p.dirname(database.path), 'furnexa_diagnostics.log');
  }

  static Future<void> capture({
    required String source,
    int? factoryWarehouseRepositoryRows,
    int? stockWarehouseRepositoryRows,
    int? stockRepositoryRows,
    int? purchaseRequestRepositoryRows,
    String? warehouseSearch,
    String? stockQuery,
    String? stockItemTypeFilter,
    String? purchaseRequestQuery,
    String? entityType,
    String? entityId,
    String? warehouseId,
    String? itemId,
    String? itemType,
    Map<String, Object?> stageCounts = const {},
  }) async {
    if (!enabled) return;

    final database = await FurnexaDatabase.instance.database;
    final session = SecurityLocalDataSource().session;
    final versionRows = await database.rawQuery('PRAGMA user_version');
    final warehouseCount = await _count(database, 'warehouses');
    final activeWarehouseCount = await _countWhere(
      database,
      'warehouses',
      'state = ?',
      ['active'],
    );
    final requestCount = await _count(database, 'purchase_requests');
    final stockBalanceCount = await _count(database, 'stock_balances');
    final warehouseSqlRows = warehouseSearch == null
        ? null
        : await _countWarehouseSearch(database, warehouseSearch);
    final stockSqlRows = stockQuery == null
        ? null
        : await _countStockQuery(
            database,
            warehouseId: warehouseId,
            itemType: stockItemTypeFilter,
          );
    final requestSqlRows = purchaseRequestQuery == null
        ? null
        : await _countRequestQuery(database, purchaseRequestQuery);
    final recordCount = switch (entityType) {
      'warehouse' when entityId != null => await _countWhere(
        database,
        'warehouses',
        'id = ?',
        [entityId],
      ),
      'purchaseRequest' when entityId != null => await _countWhere(
        database,
        'purchase_requests',
        'id = ?',
        [entityId],
      ),
      _ => null,
    };
    final targetBalanceRows =
        warehouseId != null && itemId != null && itemType != null
        ? await _countWhere(
            database,
            'stock_balances',
            'warehouseId = ? AND itemId = ? AND itemType = ?',
            [warehouseId, itemId, itemType],
          )
        : null;
    final factoryRows = await database.query(
      'factories',
      columns: ['id', 'name', 'code'],
      orderBy: 'id ASC',
    );

    final record = <String, Object?>{
      'timestamp': DateTime.now().toIso8601String(),
      'source': source,
      'databasePath': database.path,
      'resolvedDatabasePath': await FurnexaDatabase.instance.databasePath,
      'databaseVersion': versionRows.isEmpty
          ? null
          : versionRows.first['user_version'],
      'session': session == null
          ? null
          : {
              'userId': session.user.id,
              'username': session.user.username,
              'roleId': session.role.id,
              'roleName': session.role.name,
              'isSystemAdmin': session.isSystemAdmin,
              'databaseFactoryIds': factoryRows
                  .map((row) => row['id'])
                  .toList(),
              'permissions': session.permissions.toList()..sort(),
              'warehousePermissions': {
                'WAREHOUSE_STOCK_VIEW': session.can('WAREHOUSE_STOCK_VIEW'),
                'WAREHOUSE_STOCK_EDIT': session.can('WAREHOUSE_STOCK_EDIT'),
                'PURCHASING_VIEW': session.can('PURCHASING_VIEW'),
                'PURCHASING_RECEIVE': session.can('PURCHASING_RECEIVE'),
              },
              'scopes': session.scopes
                  .map(
                    (scope) => {
                      'type': scope.type.name,
                      'scopeId': scope.scopeId,
                    },
                  )
                  .toList(),
            },
      'sqliteWarehouseCount': warehouseCount,
      'sqliteActiveWarehouseCount': activeWarehouseCount,
      'sqlitePurchaseRequestCount': requestCount,
      'sqliteStockBalanceCount': stockBalanceCount,
      'warehouseSqlRows': warehouseSqlRows,
      'stockSqlRows': stockSqlRows,
      'requestSqlRows': requestSqlRows,
      'factoryWarehouseRepositoryRows': factoryWarehouseRepositoryRows,
      'stockWarehouseRepositoryRows': stockWarehouseRepositoryRows,
      'stockRepositoryRows': stockRepositoryRows,
      'purchaseRequestRepositoryRows': purchaseRequestRepositoryRows,
      'warehouseSearch': warehouseSearch,
      'stockQuery': stockQuery,
      'stockItemTypeFilter': stockItemTypeFilter,
      'purchaseRequestQuery': purchaseRequestQuery,
      'entityType': entityType,
      'entityId': entityId,
      'entityRowsInSqlite': recordCount,
      'warehouseId': warehouseId,
      'itemId': itemId,
      'itemType': itemType,
      'matchingBalanceRowsInSqlite': targetBalanceRows,
      'stageCounts': stageCounts,
      'factoryContext': factoryRows,
    };
    final line = jsonEncode(record);
    final logPath = await logFilePath;

    await _appendLine(line, logPath);
    debugPrint('FURNEXA_DB_DIAGNOSTICS $line');
  }

  static Future<void> reportFailure({
    required String source,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    if (!enabled) return;

    final record = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'source': source,
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    });
    final logPath = await logFilePath;
    await _appendLine(record, logPath);
    debugPrint('FURNEXA_DB_DIAGNOSTICS $record');
  }

  static Future<void> recordUiPipeline({
    required String feature,
    required String layer,
    required String state,
    required String reason,
    int? repositoryCount,
    int? viewModelCount,
    int? emittedStateCount,
    int? pageStateCount,
    int? renderItemCount,
    int? receivedItemCount,
    int? renderedRowCount,
    int? requestId,
  }) async {
    if (!enabled) return;

    final record = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'ui.$feature.$layer',
      'feature': feature,
      'layer': layer,
      'state': state,
      'reason': reason,
      'repositoryCount': repositoryCount,
      'viewModelCount': viewModelCount,
      'emittedStateCount': emittedStateCount,
      'pageStateCount': pageStateCount,
      'renderItemCount': renderItemCount,
      'receivedItemCount': receivedItemCount,
      'renderedRowCount': renderedRowCount,
      'requestId': requestId,
    });
    final logPath = await logFilePath;
    await _appendLine(record, logPath);
    debugPrint('FURNEXA_DB_DIAGNOSTICS $record');
  }

  static Future<void> _appendLine(String line, String logPath) async {
    try {
      await File(
        logPath,
      ).writeAsString('$line\n', mode: FileMode.append, flush: true);
    } on FileSystemException catch (error) {
      debugPrint('Furnexa diagnostics could not write $logPath: $error');
    }
  }

  static Future<int> _count(DatabaseExecutor database, String table) async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS recordCount FROM $table',
    );
    return (rows.single['recordCount'] as num).toInt();
  }

  static Future<int> _countWhere(
    DatabaseExecutor database,
    String table,
    String where,
    List<Object?> whereArgs,
  ) async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS recordCount FROM $table WHERE $where',
      whereArgs,
    );
    return (rows.single['recordCount'] as num).toInt();
  }

  static Future<int> _countWarehouseSearch(
    DatabaseExecutor database,
    String query,
  ) async {
    final normalized = query.trim().toLowerCase();
    final where = normalized.isEmpty
        ? null
        : 'LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(type) LIKE ?';
    final whereArgs = normalized.isEmpty
        ? const <Object?>[]
        : ['%$normalized%', '%$normalized%', '%$normalized%'];
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS recordCount FROM warehouses'
      '${where == null ? '' : ' WHERE $where'}',
      whereArgs,
    );
    return (rows.single['recordCount'] as num).toInt();
  }

  static Future<int> _countStockQuery(
    DatabaseExecutor database, {
    required String? warehouseId,
    required String? itemType,
  }) async {
    final itemFilter = itemType == null ? '' : ' AND itemType = ?';
    final args = <Object?>[];
    if (warehouseId == null) {
      if (itemType != null) args.add(itemType);
      final rows = await database.rawQuery(
        'SELECT COUNT(*) AS recordCount FROM ('
        'SELECT itemId, itemType FROM stock_balances '
        'WHERE quantity > 0$itemFilter GROUP BY itemId, itemType)',
        args,
      );
      return (rows.single['recordCount'] as num).toInt();
    }
    args.add(warehouseId);
    if (itemType != null) args.add(itemType);
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS recordCount FROM stock_balances '
      'WHERE warehouseId = ? AND quantity > 0$itemFilter',
      args,
    );
    return (rows.single['recordCount'] as num).toInt();
  }

  static Future<int> _countRequestQuery(
    DatabaseExecutor database,
    String query,
  ) async {
    final normalized = query.trim().toLowerCase();
    final where = normalized.isEmpty ? null : 'LOWER(requestNumber) LIKE ?';
    final args = normalized.isEmpty ? const <Object?>[] : ['%$normalized%'];
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS recordCount FROM purchase_requests'
      '${where == null ? '' : ' WHERE $where'}',
      args,
    );
    return (rows.single['recordCount'] as num).toInt();
  }
}
