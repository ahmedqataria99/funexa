import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

void main() {
  late WarehousesStockLocalDataSource dataSource;
  late StockItemOption item;
  const source = 'warehouse-stock-source';
  const destination = 'warehouse-stock-destination';
  final now = DateTime(2026, 9, 17);

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login('admin', 'Furnexa-Test-Admin-2026!');
    final db = await FurnexaDatabase.instance.database;
    dataSource = WarehousesStockLocalDataSource();
    await db.delete('purchase_receipt_items');
    await db.delete('purchase_receipts');
    await db.delete('purchase_order_items');
    await db.delete('purchase_orders');
    await db.delete('purchase_request_items');
    await db.delete('purchase_requests');
    await db.delete('suppliers');
    await db.delete('sales_delivery_items');
    await db.delete('sales_deliveries');
    await db.delete('sales_order_items');
    await db.delete('sales_orders');
    await db.delete('quotation_items');
    await db.delete('quotations');
    await db.delete('customers');
    await db.delete('stock_transactions');
    await db.delete('stock_balances');
    await db.delete('product_bom_items');
    await db.delete('product_dimensions');
    await db.delete('product_variants');
    await db.delete('raw_materials');
    await db.delete('products');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('warehouses');
    await db.delete('workshops');
    await db.delete('production_stages');
    await db.delete('sections');
    await db.delete('factories');
    await db.insert('factories', {
      'id': 'factory-stock',
      'name': 'مصنع اختبار',
      'code': 'STOCK-F',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    for (final warehouse in [source, destination]) {
      await db.insert('warehouses', {
        'id': warehouse,
        'factoryId': 'factory-stock',
        'name': warehouse,
        'code': warehouse,
        'state': 'active',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
    }
    await db.insert('categories', {
      'id': 'category-stock',
      'name': 'خامات اختبار',
      'code': 'STOCK-C',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('units', {
      'id': 'unit-stock',
      'name': 'قطعة اختبار',
      'abbreviation': 'قط',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('raw_materials', {
      'id': 'material-stock',
      'name': 'خشب اختبار',
      'code': 'STOCK-M',
      'categoryId': 'category-stock',
      'unitId': 'unit-stock',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    item = const StockItemOption(
      id: 'material-stock',
      name: 'خشب اختبار',
      code: 'STOCK-M',
      unitId: 'unit-stock',
      type: StockItemType.rawMaterial,
      active: true,
    );
  });

  tearDown(() async {
    SecurityLocalDataSource().logout();
    await DatabaseTestHelper.reset();
  });

  test('migration creates stock tables and initial balance is zero', () async {
    expect(await dataSource.balance(source, item.id, item.type), 0);
    final tables = await (await FurnexaDatabase.instance.database).query(
      'sqlite_master',
      where: 'type = ?',
      whereArgs: ['table'],
    );
    expect(
      tables.map((row) => row['name']),
      containsAll(['stock_balances', 'stock_transactions']),
    );
  });

  test('stock in and out update balances and persist transactions', () async {
    await dataSource.stockIn(
      warehouseId: source,
      item: item,
      quantity: 100,
      date: now,
      reference: 'IN-1',
    );
    expect(await dataSource.balance(source, item.id, item.type), 100);
    expect((await dataSource.stock(source)).single.balance.quantity, 100);
    await dataSource.stockOut(
      warehouseId: source,
      item: item,
      quantity: 30,
      date: now,
      reference: 'OUT-1',
    );
    expect(await dataSource.balance(source, item.id, item.type), 70);
    expect((await dataSource.stock(source)).single.balance.quantity, 70);
    final ledger = await dataSource.ledger(source, item.id, item.type);
    expect(ledger, hasLength(2));
    expect(ledger.last.balanceAfter, 70);
  });

  test(
    'stock out and transfer reject insufficient or same-warehouse operations atomically',
    () async {
      await dataSource.stockIn(
        warehouseId: source,
        item: item,
        quantity: 20,
        date: now,
      );
      expect(
        () => dataSource.stockOut(
          warehouseId: source,
          item: item,
          quantity: 21,
          date: now,
        ),
        throwsException,
      );
      expect(await dataSource.balance(source, item.id, item.type), 20);
      expect(
        () => dataSource.transfer(
          sourceWarehouseId: source,
          destinationWarehouseId: source,
          item: item,
          quantity: 1,
          date: now,
        ),
        throwsException,
      );
      expect(
        () => dataSource.transfer(
          sourceWarehouseId: source,
          destinationWarehouseId: destination,
          item: item,
          quantity: 21,
          date: now,
        ),
        throwsException,
      );
      expect(await dataSource.balance(destination, item.id, item.type), 0);
    },
  );

  test(
    'transfer and signed adjustments update both balances and ledger',
    () async {
      await dataSource.stockIn(
        warehouseId: source,
        item: item,
        quantity: 100,
        date: now,
      );
      await dataSource.transfer(
        sourceWarehouseId: source,
        destinationWarehouseId: destination,
        item: item,
        quantity: 25,
        date: now,
        reference: 'TR-1',
      );
      expect(await dataSource.balance(source, item.id, item.type), 75);
      expect(await dataSource.balance(destination, item.id, item.type), 25);
      expect((await dataSource.stock(source)).single.balance.quantity, 75);
      expect((await dataSource.stock(destination)).single.balance.quantity, 25);
      await dataSource.adjust(
        warehouseId: destination,
        item: item,
        difference: -5,
        date: now,
        reason: 'جرد',
      );
      expect(await dataSource.balance(destination, item.id, item.type), 20);
      expect((await dataSource.stock(destination)).single.balance.quantity, 20);
      expect(
        (await dataSource.ledger(
          destination,
          item.id,
          item.type,
        )).last.transaction.signedQuantity,
        -5,
      );
      expect(
        () => dataSource.adjust(
          warehouseId: destination,
          item: item,
          difference: -21,
          date: now,
          reason: 'تسوية خاطئة',
        ),
        throwsException,
      );
      expect(await dataSource.balance(destination, item.id, item.type), 20);
    },
  );

  test('inactive items cannot receive new stock', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'raw_materials',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [item.id],
    );
    expect(
      () => dataSource.stockIn(
        warehouseId: source,
        item: item,
        quantity: 1,
        date: now,
      ),
      throwsException,
    );
    expect(await dataSource.balance(source, item.id, item.type), 0);
  });

  test(
    'restricted users cannot bypass stock permissions or warehouse scopes',
    () async {
      final security = SecurityLocalDataSource();
      final role = await security.createRole(
        name: 'Scoped Stock ${DateTime.now().microsecondsSinceEpoch}',
      );
      await security.setRolePermissions(role.id, ['WAREHOUSE_STOCK_EDIT']);
      final user = await security.createUser(
        username: 'scoped-stock-${DateTime.now().microsecondsSinceEpoch}',
        displayName: 'Scoped Stock',
        password: 'secret',
        roleId: role.id,
      );
      await security.setUserScopes(user.id, [
        UserScope(
          id: 'scope-source',
          userId: user.id,
          type: ScopeType.warehouse,
          scopeId: source,
        ),
      ]);
      security.logout();
      await security.login(user.username, 'secret');
      expect(
        () => dataSource.stockIn(
          warehouseId: destination,
          item: item,
          quantity: 1,
          date: now,
        ),
        throwsException,
      );
      expect(
        () => dataSource.transfer(
          sourceWarehouseId: source,
          destinationWarehouseId: destination,
          item: item,
          quantity: 1,
          date: now,
        ),
        throwsException,
      );
      expect(
        () => dataSource.adjust(
          warehouseId: destination,
          item: item,
          difference: 1,
          date: now,
          reason: 'scope',
        ),
        throwsException,
      );
    },
  );

  test(
    'operation IDs prevent duplicate stock posting and adjustments store positive quantities',
    () async {
      await dataSource.stockIn(
        warehouseId: source,
        item: item,
        quantity: 10,
        date: now,
        operationId: 'stock-op-1',
      );
      expect(
        () => dataSource.stockIn(
          warehouseId: source,
          item: item,
          quantity: 10,
          date: now,
          operationId: 'stock-op-1',
        ),
        throwsException,
      );
      await dataSource.adjust(
        warehouseId: source,
        item: item,
        difference: -3,
        date: now,
        reason: 'count',
      );
      final rows = await (await FurnexaDatabase.instance.database).query(
        'stock_transactions',
        where: 'warehouseId = ?',
        whereArgs: [source],
        orderBy: 'createdAt DESC',
      );
      expect((rows.first['quantity'] as num).toDouble(), 3);
      expect(
        (await dataSource.ledger(source, item.id, item.type)).last.balanceAfter,
        7,
      );
    },
  );

  test(
    'stock query scopes a warehouse and aggregates totals across all warehouses',
    () async {
      await dataSource.stockIn(
        warehouseId: source,
        item: item,
        quantity: 15,
        date: now,
      );
      await dataSource.stockIn(
        warehouseId: destination,
        item: item,
        quantity: 7,
        date: now,
      );

      final sourceRows = await dataSource.stock(
        source,
        query: 'خشب',
        itemType: StockItemType.rawMaterial,
      );
      expect(sourceRows, hasLength(1));
      expect(sourceRows.single.balance.quantity, 15);

      final allRows = await dataSource.stock(
        null,
        query: 'خشب',
        itemType: StockItemType.rawMaterial,
      );
      expect(allRows, hasLength(1));
      expect(allRows.single.balance.quantity, 22);
      expect(allRows.single.balance.warehouseId, 'ALL_WAREHOUSES');
    },
  );
}
