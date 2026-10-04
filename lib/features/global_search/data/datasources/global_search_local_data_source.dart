import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/global_search/domain/entities/global_search_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class GlobalSearchLocalDataSource {
  static int _sequence = 0;

  GlobalSearchLocalDataSource({SecurityLocalDataSource? security})
    : security = security ?? SecurityLocalDataSource();

  final SecurityLocalDataSource security;

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<List<GlobalSearchResultItem>> search(
    String query, {
    GlobalSearchEntityCategory filter = GlobalSearchEntityCategory.all,
    int limit = 20,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty || security.session == null) {
      return const <GlobalSearchResultItem>[];
    }
    await security.refreshSession();

    await saveRecentQuery(normalized);

    final results = <GlobalSearchResultItem>[];
    if (_matchesFilter(filter, GlobalSearchEntityCategory.products) &&
        security.session!.can('PRODUCTS_VIEW')) {
      results.addAll(await _searchProducts(normalized));
    }
    if (_matchesFilter(filter, GlobalSearchEntityCategory.customers) &&
        security.session!.can('SALES_VIEW')) {
      results.addAll(await _searchCustomers(normalized));
    }
    if (_matchesFilter(filter, GlobalSearchEntityCategory.salesOrders) &&
        security.session!.can('SALES_VIEW')) {
      results.addAll(await _searchSalesOrders(normalized));
    }
    if (_matchesFilter(filter, GlobalSearchEntityCategory.productionOrders) &&
        security.session!.can('PRODUCTION_VIEW')) {
      results.addAll(await _searchProductionOrders(normalized));
    }
    if (_matchesFilter(filter, GlobalSearchEntityCategory.workers) &&
        security.session!.can('HR_VIEW')) {
      results.addAll(await _searchWorkers(normalized));
    }
    if (_matchesFilter(filter, GlobalSearchEntityCategory.warehouses) &&
        security.session!.can('WAREHOUSE_STOCK_VIEW')) {
      results.addAll(await _searchWarehouses(normalized));
    }
    if (_matchesFilter(filter, GlobalSearchEntityCategory.sections) &&
        security.session!.can('FACTORY_VIEW')) {
      results.addAll(await _searchSections(normalized));
    }
    if (_matchesFilter(filter, GlobalSearchEntityCategory.workshops) &&
        security.session!.can('FACTORY_VIEW')) {
      results.addAll(await _searchWorkshops(normalized));
    }
    if (_matchesFilter(filter, GlobalSearchEntityCategory.stages) &&
        security.session!.can('PRODUCTION_VIEW')) {
      results.addAll(await _searchProductionStages(normalized));
    }

    final deduped = _dedupe(results);
    return deduped.take(limit).toList();
  }

  Future<List<String>> recentSearches() async {
    await _ensureHistoryTable();
    final db = await _db;
    final rows = await db.query(
      'global_search_history',
      orderBy: 'createdAt DESC',
      limit: 10,
    );
    return rows
        .map((row) => (row['query'] as String?) ?? '')
        .where((query) => query.isNotEmpty)
        .toList();
  }

  Future<void> saveRecentQuery(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    await _ensureHistoryTable();
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'global_search_history',
        where: 'query = ?',
        whereArgs: [normalized],
      );
      final latestRows = await txn.query(
        'global_search_history',
        columns: ['createdAt'],
        orderBy: 'createdAt DESC',
        limit: 1,
      );
      final latestCreatedAt = latestRows.isEmpty
          ? 0
          : (latestRows.first['createdAt'] as int? ?? 0);
      final createdAt = DateTime.now().microsecondsSinceEpoch;
      await txn.insert('global_search_history', {
        'id': _id('search'),
        'query': normalized,
        'createdAt': createdAt > latestCreatedAt
            ? createdAt
            : latestCreatedAt + 1,
      });
      final rows = await txn.query(
        'global_search_history',
        orderBy: 'createdAt DESC',
      );
      if (rows.length > 10) {
        final extra = rows.skip(10).toList();
        for (final row in extra) {
          final id = row['id'] as String?;
          if (id != null) {
            await txn.delete(
              'global_search_history',
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }
    });
  }

  Future<void> clearRecentSearches() async {
    await _ensureHistoryTable();
    final db = await _db;
    await db.delete('global_search_history');
  }

  bool _matchesFilter(
    GlobalSearchEntityCategory filter,
    GlobalSearchEntityCategory candidate,
  ) => filter == GlobalSearchEntityCategory.all || filter == candidate;

  List<GlobalSearchResultItem> _dedupe(Iterable<GlobalSearchResultItem> items) {
    final byId = <String, GlobalSearchResultItem>{};
    for (final item in items) {
      final key = '${item.entityType.name}:${item.id}';
      byId.putIfAbsent(key, () => item);
    }
    return byId.values.toList();
  }

  Future<List<GlobalSearchResultItem>> _searchProducts(String query) async {
    final db = await _db;
    final q = query.toLowerCase();
    final rows = await db.query(
      'products',
      where:
          'LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(description) LIKE ?',
      whereArgs: ['%$q%', '%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    return rows.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.product,
        category: GlobalSearchEntityCategory.products,
        title: row['name'] as String,
        subtitle: 'Product',
        codeOrNumber: row['code'] as String?,
        navigationTarget: '/products/${row['id']}',
        match: row['code'] as String?,
      );
    }).toList();
  }

  Future<List<GlobalSearchResultItem>> _searchCustomers(String query) async {
    final db = await _db;
    final q = query.toLowerCase();
    final rows = await db.query(
      'customers',
      where:
          'LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(email) LIKE ?',
      whereArgs: ['%$q%', '%$q%', '%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    return rows.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.customer,
        category: GlobalSearchEntityCategory.customers,
        title: row['name'] as String,
        subtitle: row['phone'] as String? ?? row['email'] as String?,
        codeOrNumber: row['code'] as String?,
        navigationTarget: '/customers/${row['id']}',
        match: row['phone'] as String?,
      );
    }).toList();
  }

  Future<List<GlobalSearchResultItem>> _searchSalesOrders(String query) async {
    final db = await _db;
    final q = query.toLowerCase();
    final rows = await db.rawQuery(
      '''
        SELECT so.id, so.orderNumber, so.customerId, so.status,
               c.name AS customerName
        FROM sales_orders so
        LEFT JOIN customers c ON c.id = so.customerId
        WHERE LOWER(so.orderNumber) LIKE ?
           OR LOWER(c.name) LIKE ?
           OR LOWER(c.code) LIKE ?
        ORDER BY so.orderDate DESC
      ''',
      ['%$q%', '%$q%', '%$q%'],
    );
    return rows.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.salesOrder,
        category: GlobalSearchEntityCategory.salesOrders,
        title: row['customerName'] as String? ?? 'Sales order',
        subtitle: row['orderNumber'] as String?,
        codeOrNumber: row['orderNumber'] as String?,
        navigationTarget: '/sales-orders/${row['id']}',
        match: row['status'] as String?,
      );
    }).toList();
  }

  Future<List<GlobalSearchResultItem>> _searchProductionOrders(
    String query,
  ) async {
    final db = await _db;
    final q = query.toLowerCase();
    final args = <Object?>['%$q%', '%$q%', '%$q%'];
    final scope = _productionOrderScope(args);
    if (scope == '1 = 0') return const [];
    final rows = await db.rawQuery('''
        SELECT po.id, po.orderNumber, po.productId, po.status, p.name AS productName
        FROM production_orders po
        LEFT JOIN products p ON p.id = po.productId
          WHERE (LOWER(po.orderNumber) LIKE ?
            OR LOWER(p.name) LIKE ?
            OR LOWER(p.code) LIKE ?)
           AND $scope
        ORDER BY po.updatedAt DESC
      ''', args);
    return rows.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.productionOrder,
        category: GlobalSearchEntityCategory.productionOrders,
        title: row['productName'] as String? ?? 'Production order',
        subtitle: row['orderNumber'] as String?,
        codeOrNumber: row['orderNumber'] as String?,
        navigationTarget: '/production-orders/${row['id']}',
        match: row['status'] as String?,
      );
    }).toList();
  }

  Future<List<GlobalSearchResultItem>> _searchWorkers(String query) async {
    final db = await _db;
    final q = query.toLowerCase();
    final rows = await db.query(
      'workers',
      where:
          'LOWER(name) LIKE ? OR LOWER(employeeCode) LIKE ? OR LOWER(phone) LIKE ?',
      whereArgs: ['%$q%', '%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    final allowed = _applyWorkerScopeFilter(
      rows,
      security.session?.scopes ?? const <UserScope>[],
    );
    return allowed.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.worker,
        category: GlobalSearchEntityCategory.workers,
        title: row['name'] as String,
        subtitle: row['employeeCode'] as String?,
        codeOrNumber: row['employeeCode'] as String?,
        navigationTarget: '/workers/${row['id']}',
        match: row['phone'] as String?,
      );
    }).toList();
  }

  Future<List<GlobalSearchResultItem>> _searchWarehouses(String query) async {
    final db = await _db;
    final q = query.toLowerCase();
    final rows = await db.query(
      'warehouses',
      where: 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    final allowed = _applyScopeFilter(
      rows,
      security.session?.scopes ?? const <UserScope>[],
      ScopeType.warehouse,
    );
    return allowed.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.warehouse,
        category: GlobalSearchEntityCategory.warehouses,
        title: row['name'] as String,
        subtitle: 'Warehouse',
        codeOrNumber: row['code'] as String?,
        navigationTarget: '/warehouses/${row['id']}',
        match: row['code'] as String?,
      );
    }).toList();
  }

  Future<List<GlobalSearchResultItem>> _searchSections(String query) async {
    final db = await _db;
    final q = query.toLowerCase();
    final rows = await db.query(
      'sections',
      where: 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    final allowed = _applyScopeFilter(
      rows,
      security.session?.scopes ?? const <UserScope>[],
      ScopeType.section,
    );
    return allowed.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.section,
        category: GlobalSearchEntityCategory.sections,
        title: row['name'] as String,
        subtitle: 'Section',
        codeOrNumber: row['code'] as String?,
        navigationTarget: '/sections/${row['id']}',
        match: row['code'] as String?,
      );
    }).toList();
  }

  Future<List<GlobalSearchResultItem>> _searchWorkshops(String query) async {
    final db = await _db;
    final q = query.toLowerCase();
    final rows = await db.query(
      'workshops',
      where: 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    final allowed = _applyWorkshopScopeFilter(
      rows,
      security.session?.scopes ?? const <UserScope>[],
    );
    return allowed.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.workshop,
        category: GlobalSearchEntityCategory.workshops,
        title: row['name'] as String,
        subtitle: 'Workshop',
        codeOrNumber: row['code'] as String?,
        navigationTarget: '/workshops/${row['id']}',
        match: row['code'] as String?,
      );
    }).toList();
  }

  Future<List<GlobalSearchResultItem>> _searchProductionStages(
    String query,
  ) async {
    final db = await _db;
    final q = query.toLowerCase();
    final rows = await db.query(
      'production_stages',
      where: 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'sequence ASC',
    );
    final allowed = _applyScopeFilter(
      rows,
      security.session?.scopes ?? const <UserScope>[],
      ScopeType.productionStage,
    );
    return allowed.map((row) {
      return GlobalSearchResultItem(
        id: row['id'] as String,
        entityType: GlobalSearchEntityType.productionStage,
        category: GlobalSearchEntityCategory.stages,
        title: row['name'] as String,
        subtitle: 'Production stage',
        codeOrNumber: row['code'] as String?,
        navigationTarget: '/production-stages/${row['id']}',
        match: row['code'] as String?,
      );
    }).toList();
  }

  List<Map<String, Object?>> _applyScopeFilter(
    List<Map<String, Object?>> rows,
    List<UserScope> scopes,
    ScopeType type,
  ) {
    if (security.session?.isSystemAdmin ?? false) return rows;
    final ids = scopes
        .where((scope) => scope.type == type)
        .map((scope) => scope.scopeId)
        .toSet();
    if (ids.isEmpty) return const [];
    final column = switch (type) {
      ScopeType.section => 'id',
      ScopeType.warehouse => 'id',
      ScopeType.productionStage => 'id',
      ScopeType.workshop => 'id',
    };
    return rows.where((row) => ids.contains(row[column])).toList();
  }

  List<Map<String, Object?>> _applyWorkerScopeFilter(
    List<Map<String, Object?>> rows,
    List<UserScope> scopes,
  ) {
    if (security.session?.isSystemAdmin ?? false) return rows;
    final sectionIds = scopes
        .where((scope) => scope.type == ScopeType.section)
        .map((scope) => scope.scopeId)
        .toSet();
    final workshopIds = scopes
        .where((scope) => scope.type == ScopeType.workshop)
        .map((scope) => scope.scopeId)
        .toSet();
    final stageIds = scopes
        .where((scope) => scope.type == ScopeType.productionStage)
        .map((scope) => scope.scopeId)
        .toSet();
    if (sectionIds.isEmpty && workshopIds.isEmpty && stageIds.isEmpty) {
      return const [];
    }
    return rows.where((row) {
      return sectionIds.contains(row['sectionId']) ||
          workshopIds.contains(row['workshopId']) ||
          stageIds.contains(row['productionStageId']);
    }).toList();
  }

  List<Map<String, Object?>> _applyWorkshopScopeFilter(
    List<Map<String, Object?>> rows,
    List<UserScope> scopes,
  ) {
    if (security.session?.isSystemAdmin ?? false) return rows;
    final workshopIds = scopes
        .where((scope) => scope.type == ScopeType.workshop)
        .map((scope) => scope.scopeId)
        .toSet();
    final sectionIds = scopes
        .where((scope) => scope.type == ScopeType.section)
        .map((scope) => scope.scopeId)
        .toSet();
    return rows.where((row) {
      final id = row['id'];
      final sectionId = row['sectionId'];
      return (id != null && workshopIds.contains(id)) ||
          (sectionId != null && sectionIds.contains(sectionId));
    }).toList();
  }

  String _productionOrderScope(List<Object?> args) {
    final session = security.session!;
    if (session.isSystemAdmin) return '1 = 1';
    final clauses = <String>[];
    for (final scope in [
      ScopeType.productionStage,
      ScopeType.workshop,
      ScopeType.section,
    ]) {
      final ids = session.scopes
          .where((value) => value.type == scope)
          .map((value) => value.scopeId)
          .toList();
      if (ids.isEmpty) continue;
      if (scope == ScopeType.productionStage) {
        args.addAll(ids);
        clauses.add(
          'EXISTS (SELECT 1 FROM production_order_stages pos '
          'WHERE pos.productionOrderId = po.id '
          'AND pos.productionStageId IN (${List.filled(ids.length, '?').join(',')}))',
        );
      }
    }
    final warehouseIds = session.scopes
        .where((scope) => scope.type == ScopeType.warehouse)
        .map((scope) => scope.scopeId)
        .toList();
    if (warehouseIds.isNotEmpty) {
      args.addAll(warehouseIds);
      clauses.add(
        'EXISTS (SELECT 1 FROM production_outputs scoped_output '
        'WHERE scoped_output.productionOrderId = po.id '
        'AND scoped_output.warehouseId IN (${List.filled(warehouseIds.length, '?').join(',')}))',
      );
    }
    return clauses.isEmpty ? '1 = 0' : '(${clauses.join(' OR ')})';
  }

  Future<void> _ensureHistoryTable() async {
    final db = await _db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS global_search_history (
        id TEXT PRIMARY KEY,
        query TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  String _id(String prefix) {
    final suffix = _sequence++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}
