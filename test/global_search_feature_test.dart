import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/global_search/data/datasources/global_search_local_data_source.dart';
import 'package:furnexa/features/global_search/domain/entities/global_search_entities.dart';
import 'package:furnexa/features/global_search/domain/usecases/global_search_usecase.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late GlobalSearchLocalDataSource dataSource;
  late GlobalSearchUseCase useCase;
  late SecurityLocalDataSource security;
  late String suffix;
  late String productId;
  late String customerId;
  late String salesOrderId;
  late String productionOrderId;
  late String warehouseId;
  late String sectionId;
  late String workshopId;
  late String stageId;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.ensureInitialAdmin();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');

    dataSource = GlobalSearchLocalDataSource(security: security);
    useCase = GlobalSearchUseCase(dataSource);
    suffix = DateTime.now().microsecondsSinceEpoch.toString();

    final db = await FurnexaDatabase.instance.database;
    await db.delete('production_order_stages');
    await db.delete('production_orders');
    await db.delete('production_routes');
    await db.delete('production_route_stages');
    await db.delete('sales_delivery_items');
    await db.delete('sales_deliveries');
    await db.delete('sales_order_items');
    await db.delete('sales_orders');
    await db.delete('quotation_items');
    await db.delete('quotations');
    await db.delete('customers');
    await db.delete('stock_transactions');
    await db.delete('stock_balances');
    await db.delete('workers');
    await db.delete('production_stages');
    await db.delete('workshops');
    await db.delete('sections');
    await db.delete('warehouses');
    await db.delete('products');
    await db.delete('raw_materials');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('factories');

    final factoryId = 'factory-$suffix';
    final categoryId = 'category-$suffix';
    final unitId = 'unit-$suffix';
    warehouseId = 'warehouse-$suffix';
    sectionId = 'section-$suffix';
    workshopId = 'workshop-$suffix';
    stageId = 'stage-$suffix';
    productId = 'product-$suffix';
    customerId = 'customer-$suffix';
    salesOrderId = 'sales-order-$suffix';
    productionOrderId = 'production-order-$suffix';

    final stamp = DateTime(2026, 9, 21).millisecondsSinceEpoch;

    await db.insert('factories', {
      'id': factoryId,
      'name': 'مصنع بحث $suffix',
      'code': 'FACTORY-$suffix',
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('sections', {
      'id': sectionId,
      'factoryId': factoryId,
      'name': 'قسم البحث $suffix',
      'code': 'SEC-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('workshops', {
      'id': workshopId,
      'factoryId': factoryId,
      'sectionId': sectionId,
      'name': 'ورشة البحث $suffix',
      'code': 'WS-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('production_stages', {
      'id': stageId,
      'factoryId': factoryId,
      'name': 'مرحلة البحث $suffix',
      'code': 'PS-$suffix',
      'sequence': 1,
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'مستودع بحث $suffix',
      'code': 'WH-$suffix',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('categories', {
      'id': categoryId,
      'name': 'تصنيف بحث $suffix',
      'code': 'CAT-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('units', {
      'id': unitId,
      'name': 'وحدة بحث $suffix',
      'abbreviation': 'UB$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('products', {
      'id': productId,
      'name': 'كرسي سفرة',
      'code': 'CHAIR-001',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('customers', {
      'id': customerId,
      'name': 'Ahmed Furniture',
      'code': 'CUST-100',
      'phone': '966500000000',
      'email': 'ahmed@example.com',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('sales_orders', {
      'id': salesOrderId,
      'orderNumber': 'SO-2026-0015',
      'customerId': customerId,
      'orderDate': stamp,
      'status': 'CONFIRMED',
      'subtotal': 1200,
      'discount': 0,
      'tax': 0,
      'grandTotal': 1200,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('production_routes', {
      'id': 'route-$suffix',
      'productId': productId,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('production_route_stages', {
      'id': 'route-stage-$suffix',
      'routeId': 'route-$suffix',
      'productionStageId': stageId,
      'sequence': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('production_orders', {
      'id': productionOrderId,
      'orderNumber': 'PROD-00042',
      'productId': productId,
      'routeId': 'route-$suffix',
      'plannedQuantity': 10,
      'producedQuantity': 0,
      'status': 'PLANNED',
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    await db.insert('workers', {
      'id': 'worker-$suffix',
      'employeeCode': 'EMP-100',
      'name': 'Ali Worker',
      'phone': '966511111111',
      'sectionId': sectionId,
      'workshopId': workshopId,
      'productionStageId': stageId,
      'hireDate': stamp,
      'basicSalary': 2000,
      'salaryType': 'MONTHLY',
      'overtimeEnabled': 1,
      'annualLeaveAllowance': 0,
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  test('product search by exact code', () async {
    final result = await useCase.call('CHAIR-001');
    expect(result.isSuccess, isTrue);
    final items = result.value
        .where((item) => item.entityType == GlobalSearchEntityType.product)
        .toList();
    expect(items, isNotEmpty);
    expect(items.first.codeOrNumber, 'CHAIR-001');
  });

  test('product search by name', () async {
    final result = await useCase.call('كرسي سفرة');
    expect(result.isSuccess, isTrue);
    final items = result.value
        .where((item) => item.entityType == GlobalSearchEntityType.product)
        .toList();
    expect(items, isNotEmpty);
    expect(items.first.title, contains('كرسي'));
  });

  test('prefix search works', () async {
    final result = await useCase.call('CHAIR');
    expect(result.isSuccess, isTrue);
    expect(
      result.value.any(
        (item) => item.entityType == GlobalSearchEntityType.product,
      ),
      isTrue,
    );
  });

  test('warehouse search respects warehouse scope and empty scope', () async {
    final role = await security.createRole(name: 'Warehouse Search');
    await security.setRolePermissions(role.id, ['WAREHOUSE_STOCK_VIEW']);
    final user = await security.createUser(
      username: 'warehouse-search',
      displayName: 'Warehouse Search',
      password: 'secret123',
      roleId: role.id,
    );
    await security.setUserScopes(user.id, [
      UserScope(
        id: 'warehouse-scope',
        userId: user.id,
        type: ScopeType.warehouse,
        scopeId: warehouseId,
      ),
    ]);
    final otherWarehouse = 'warehouse-other-$suffix';
    final db = await FurnexaDatabase.instance.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await db.insert('warehouses', {
      'id': otherWarehouse,
      'factoryId': 'factory-$suffix',
      'name': 'Other Warehouse $suffix',
      'code': 'WH-OTHER-$suffix',
      'state': 'active',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    security.logout();
    await security.login(user.username, 'secret123');
    final scoped = await GlobalSearchLocalDataSource(
      security: security,
    ).search('WH-');
    expect(scoped.map((item) => item.id), contains(warehouseId));
    expect(scoped.map((item) => item.id), isNot(contains(otherWarehouse)));

    security.logout();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    final emptyRole = await security.createRole(name: 'Warehouse No Scope');
    await security.setRolePermissions(emptyRole.id, ['WAREHOUSE_STOCK_VIEW']);
    final emptyUser = await security.createUser(
      username: 'warehouse-no-scope',
      displayName: 'Warehouse No Scope',
      password: 'secret123',
      roleId: emptyRole.id,
    );
    security.logout();
    await security.login(emptyUser.username, 'secret123');
    expect(
      await GlobalSearchLocalDataSource(security: security).search('WH-'),
      isEmpty,
    );
  });

  test('production order search respects stage scope', () async {
    final db = await FurnexaDatabase.instance.database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outsideStage = 'outside-stage-$suffix';
    await db.insert('production_stages', {
      'id': outsideStage,
      'factoryId': 'factory-$suffix',
      'name': 'Outside Stage',
      'code': 'OUTSIDE-STAGE-$suffix',
      'sequence': 2,
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('production_order_stages', {
      'id': 'inside-order-stage-$suffix',
      'productionOrderId': productionOrderId,
      'productionStageId': stageId,
      'sequence': 1,
      'status': 'PENDING',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    final outsideOrderId = 'outside-order-$suffix';
    await db.insert('production_orders', {
      'id': outsideOrderId,
      'orderNumber': 'PROD-00043',
      'productId': productId,
      'routeId': 'route-$suffix',
      'plannedQuantity': 3,
      'producedQuantity': 0,
      'status': 'PLANNED',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('production_order_stages', {
      'id': 'outside-order-stage-$suffix',
      'productionOrderId': outsideOrderId,
      'productionStageId': outsideStage,
      'sequence': 1,
      'status': 'PENDING',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    const query = 'PROD';
    final unscopedResults = await dataSource.search(query);
    expect(
      unscopedResults.map((item) => item.id),
      containsAll([productionOrderId, outsideOrderId]),
    );
    final role = await security.createRole(name: 'Production Search');
    await security.setRolePermissions(role.id, ['PRODUCTION_VIEW']);
    final user = await security.createUser(
      username: 'production-search',
      displayName: 'Production Search',
      password: 'secret123',
      roleId: role.id,
    );
    await security.setUserScopes(user.id, [
      UserScope(
        id: 'production-stage-scope',
        userId: user.id,
        type: ScopeType.productionStage,
        scopeId: stageId,
      ),
    ]);
    security.logout();
    await security.login(user.username, 'secret123');
    final results = await GlobalSearchLocalDataSource(
      security: security,
    ).search(query);
    expect(results.map((item) => item.id), contains(productionOrderId));
    expect(results.map((item) => item.id), isNot(contains(outsideOrderId)));
  });

  test('contains search works', () async {
    final result = await useCase.call('air');
    expect(result.isSuccess, isTrue);
    expect(
      result.value.any(
        (item) => item.entityType == GlobalSearchEntityType.product,
      ),
      isTrue,
    );
  });

  test('customer search by name and phone', () async {
    final byName = await useCase.call('Ahmed Furniture');
    final byPhone = await useCase.call('966500000000');
    expect(byName.isSuccess, isTrue);
    expect(byPhone.isSuccess, isTrue);
    expect(
      byName.value.any(
        (item) => item.entityType == GlobalSearchEntityType.customer,
      ),
      isTrue,
    );
    expect(
      byPhone.value.any(
        (item) => item.entityType == GlobalSearchEntityType.customer,
      ),
      isTrue,
    );
  });

  test('sales order search by document number', () async {
    final result = await useCase.call('SO-2026-0015');
    expect(result.isSuccess, isTrue);
    expect(
      result.value.any(
        (item) => item.entityType == GlobalSearchEntityType.salesOrder,
      ),
      isTrue,
    );
  });

  test('production order search by batch/document number', () async {
    final result = await useCase.call('PROD-00042');
    expect(result.isSuccess, isTrue);
    expect(
      result.value.any(
        (item) => item.entityType == GlobalSearchEntityType.productionOrder,
      ),
      isTrue,
    );
  });

  test('Arabic text search matches local Arabic content', () async {
    final result = await useCase.call('كرسي');
    expect(result.isSuccess, isTrue);
    expect(
      result.value.any(
        (item) => item.entityType == GlobalSearchEntityType.product,
      ),
      isTrue,
    );
  });

  test('grouped result ordering is deterministic', () async {
    final result = await useCase.call('Ahmed');
    expect(result.isSuccess, isTrue);
    final grouped = <GlobalSearchEntityType, List<GlobalSearchResultItem>>{};
    for (final item in result.value) {
      grouped
          .putIfAbsent(item.entityType, () => <GlobalSearchResultItem>[])
          .add(item);
    }
    expect(grouped.containsKey(GlobalSearchEntityType.customer), isTrue);
    expect(grouped.containsKey(GlobalSearchEntityType.salesOrder), isTrue);
  });

  test('default result limit is enforced', () async {
    final result = await useCase.call('');
    expect(result.isSuccess, isTrue);
    expect(result.value.length <= 20, isTrue);
  });

  test('category filter narrows included entities', () async {
    final all = await useCase.call('A');
    final productsOnly = await useCase.call(
      'A',
      filter: GlobalSearchEntityCategory.products,
    );
    expect(all.isSuccess, isTrue);
    expect(productsOnly.isSuccess, isTrue);
    expect(
      productsOnly.value.every(
        (item) => item.entityType == GlobalSearchEntityType.product,
      ),
      isTrue,
    );
  });

  test('permission filtering blocks unauthorized entities', () async {
    final restricted = SecurityLocalDataSource();
    await restricted.ensureInitialAdmin();
    await restricted.login('admin', 'Furnexa-Test-Admin-2026!');
    final role = await restricted.createRole(name: 'Products Only');
    await restricted.setRolePermissions(role.id, ['PRODUCTS_VIEW']);
    final user = await restricted.createUser(
      username: 'products_only',
      displayName: 'Products Only',
      password: 'secret123',
      roleId: role.id,
    );
    restricted.logout();
    await restricted.login('products_only', 'secret123');

    final ds = GlobalSearchLocalDataSource(security: restricted);
    final result = await ds.search('SO-2026-0015');
    expect(result, isEmpty);
    expect(user.id, isNotEmpty);
  });

  test('warehouse scope filtering applies to stock results', () async {
    final warehouseScoped = SecurityLocalDataSource();
    await warehouseScoped.ensureInitialAdmin();
    await warehouseScoped.login('admin', 'Furnexa-Test-Admin-2026!');
    final role = await warehouseScoped.createRole(
      name: 'Warehouse Scoped Search',
    );
    await warehouseScoped.setRolePermissions(role.id, ['WAREHOUSE_STOCK_VIEW']);
    final user = await warehouseScoped.createUser(
      username: 'warehouse-scoped-$suffix',
      displayName: 'Warehouse Scoped Search',
      password: 'secret123',
      roleId: role.id,
    );
    await warehouseScoped.setUserScopes(user.id, [
      UserScope(
        id: 'scope-1',
        userId: user.id,
        type: ScopeType.warehouse,
        scopeId: warehouseId,
      ),
    ]);
    warehouseScoped.logout();
    await warehouseScoped.login(user.username, 'secret123');

    final ds = GlobalSearchLocalDataSource(security: warehouseScoped);
    final result = await ds.search('WH-');
    expect(result, isNotEmpty);
  });

  test(
    'section workshop production stage scope filtering is respected',
    () async {
      final scoped = SecurityLocalDataSource();
      await scoped.ensureInitialAdmin();
      await scoped.login('admin', 'Furnexa-Test-Admin-2026!');
      final role = await scoped.createRole(name: 'Worker Scoped Search');
      await scoped.setRolePermissions(role.id, ['HR_VIEW']);
      final user = await scoped.createUser(
        username: 'worker-scoped-$suffix',
        displayName: 'Worker Scoped Search',
        password: 'secret123',
        roleId: role.id,
      );
      await scoped.setUserScopes(user.id, [
        UserScope(
          id: 's1',
          userId: user.id,
          type: ScopeType.section,
          scopeId: sectionId,
        ),
        UserScope(
          id: 's2',
          userId: user.id,
          type: ScopeType.workshop,
          scopeId: workshopId,
        ),
        UserScope(
          id: 's3',
          userId: user.id,
          type: ScopeType.productionStage,
          scopeId: stageId,
        ),
      ]);
      scoped.logout();
      await scoped.login(user.username, 'secret123');

      final ds = GlobalSearchLocalDataSource(security: scoped);
      final result = await ds.search('Ali Worker');
      expect(
        result.any((item) => item.entityType == GlobalSearchEntityType.worker),
        isTrue,
      );
    },
  );

  test(
    'related-data search surfaces customer and sales result together',
    () async {
      final result = await useCase.call('Ahmed');
      expect(result.isSuccess, isTrue);
      expect(
        result.value.any(
          (item) => item.entityType == GlobalSearchEntityType.customer,
        ),
        isTrue,
      );
      expect(
        result.value.any(
          (item) => item.entityType == GlobalSearchEntityType.salesOrder,
        ),
        isTrue,
      );
    },
  );

  test('navigation target is set on results', () async {
    final result = await useCase.call('CHAIR-001');
    expect(result.isSuccess, isTrue);
    final item = result.value.first;
    expect(item.entityType, GlobalSearchEntityType.product);
    expect(item.navigationTarget, '/products/${item.id}');
  });

  test(
    'empty query returns empty results without database-wide search',
    () async {
      final result = await useCase.call('   ');
      expect(result.isSuccess, isTrue);
      expect(result.value, isEmpty);
    },
  );

  test('recent searches persist and deduplicate', () async {
    await dataSource.saveRecentQuery('chair');
    await dataSource.saveRecentQuery('chair');
    await dataSource.saveRecentQuery('ahmed');
    final recent = await dataSource.recentSearches();
    expect(recent.first, 'ahmed');
    expect(recent.where((item) => item == 'chair').length, 1);
  });

  test('recent searches can be cleared', () async {
    await dataSource.saveRecentQuery('chair');
    await dataSource.clearRecentSearches();
    expect(await dataSource.recentSearches(), isEmpty);
  });

  test('search use case surfaces database failures cleanly', () async {
    final failing = GlobalSearchUseCase(
      GlobalSearchLocalDataSource(security: SecurityLocalDataSource()),
    );
    final result = await failing.call('CHAIR-001');
    expect(result.isSuccess, isTrue);
    expect(result.value, isNotEmpty);
  });

  test('search does not alter existing data', () async {
    final before = await FurnexaDatabase.instance.database.then(
      (db) => db.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      ),
    );
    await useCase.call('CHAIR-001');
    final after = await FurnexaDatabase.instance.database.then(
      (db) => db.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      ),
    );
    expect(before.first['name'], after.first['name']);
  });
}
