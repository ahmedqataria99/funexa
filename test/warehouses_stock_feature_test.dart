import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  Future<void> seedStockAndValuation(
    String warehouseId, {
    double quantity = 10,
  }) async {
    await dataSource.stockIn(
      warehouseId: warehouseId,
      item: item,
      quantity: quantity,
      date: now,
    );
    await (await FurnexaDatabase.instance.database)
        .insert('inventory_valuations', {
          'id': 'purpose-valuation-$warehouseId',
          'warehouseId': warehouseId,
          'itemId': item.inventoryId,
          'itemType': item.type.value,
          'unitId': item.unitId,
          'quantity': quantity,
          'averageCost': 3,
          'updatedAt': now.millisecondsSinceEpoch,
        });
  }

  Future<Map<String, Object?>> stockMutationSnapshot() async {
    final db = await FurnexaDatabase.instance.database;
    return {
      'balances': await db.query('stock_balances', orderBy: 'id ASC'),
      'valuations': await db.query('inventory_valuations', orderBy: 'id ASC'),
      'transactions': await db.query('stock_transactions', orderBy: 'id ASC'),
      'journalEntries': await db.query('journal_entries', orderBy: 'id ASC'),
      'journalLines': await db.query('journal_lines', orderBy: 'id ASC'),
      'journalParties': await db.query(
        'journal_parties',
        orderBy: 'journalEntryId ASC',
      ),
    };
  }

  Future<void> expectStockOutRejectedFor(WarehousePurpose purpose) async {
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'warehouses',
      {'purpose': purpose.value},
      where: 'id = ?',
      whereArgs: [source],
    );
    await seedStockAndValuation(source);
    final before = await stockMutationSnapshot();

    await expectLater(
      dataSource.stockOut(
        warehouseId: source,
        item: item,
        quantity: 2,
        date: now,
      ),
      throwsA(predicate((error) => error.toString().contains(purpose.value))),
    );

    expect(await stockMutationSnapshot(), before);
  }

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

  test(
    'purpose migration keeps legacy warehouse and stock identity sellable',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final legacyDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      try {
        await legacyDb.execute('PRAGMA foreign_keys = OFF');
        await FurnexaDatabase.instance.migrate(legacyDb, 0, 36);
        final stamp = now.millisecondsSinceEpoch;
        await legacyDb.insert('factories', {
          'id': 'legacy-purpose-factory',
          'name': 'Legacy Purpose Factory',
          'code': 'LP-F',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await legacyDb.insert('warehouses', {
          'id': 'legacy-purpose-warehouse',
          'factoryId': 'legacy-purpose-factory',
          'name': 'Legacy Main Warehouse',
          'code': 'LP-W',
          'type': 'مواد خام',
          'state': 'active',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await legacyDb.insert('stock_balances', {
          'id': 'legacy-purpose-balance',
          'warehouseId': 'legacy-purpose-warehouse',
          'itemId': 'legacy-purpose-item',
          'itemType': 'RAW_MATERIAL',
          'quantity': 7,
          'createdAt': stamp,
          'updatedAt': stamp,
          'inventoryIdentityKind': 'BASE',
        });

        await FurnexaDatabase.instance.migrate(legacyDb, 36, 37);

        final warehouse = (await legacyDb.query(
          'warehouses',
          where: 'id = ?',
          whereArgs: ['legacy-purpose-warehouse'],
        )).single;
        final balance = (await legacyDb.query(
          'stock_balances',
          where: 'id = ?',
          whereArgs: ['legacy-purpose-balance'],
        )).single;
        expect(warehouse['purpose'], 'SELLABLE');
        expect(warehouse['type'], 'مواد خام');
        expect(balance['warehouseId'], 'legacy-purpose-warehouse');
        expect(balance['itemId'], 'legacy-purpose-item');
        expect(balance['quantity'], 7);
        expect(balance['inventoryIdentityKind'], 'BASE');
      } finally {
        await legacyDb.close();
      }
    },
  );

  test('legacy and unknown warehouse purposes remain sellable', () async {
    final db = await FurnexaDatabase.instance.database;
    final row = (await db.query(
      'warehouses',
      where: 'id = ?',
      whereArgs: [source],
    )).single;
    expect(row['purpose'], 'SELLABLE');

    final legacyNullPurpose = Warehouse.fromMap({
      ...row,
      'type': 'مواد خام',
      'purpose': null,
    });
    final unknownPurpose = Warehouse.fromMap({
      ...row,
      'purpose': 'UNRECOGNIZED_LEGACY_VALUE',
    });
    expect(legacyNullPurpose.type, 'مواد خام');
    expect(legacyNullPurpose.purpose, WarehousePurpose.sellable);
    expect(unknownPurpose.purpose, WarehousePurpose.sellable);
  });

  test('sellable warehouse permits normal stock-out', () async {
    await seedStockAndValuation(source);
    await dataSource.stockOut(
      warehouseId: source,
      item: item,
      quantity: 2,
      date: now,
    );
    expect(await dataSource.balance(source, item.id, item.type), 8);
  });

  test('restricted warehouses still accept physical stock-in', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'warehouses',
      {'purpose': 'QUARANTINE'},
      where: 'id = ?',
      whereArgs: [source],
    );

    await dataSource.stockIn(
      warehouseId: source,
      item: item,
      quantity: 4,
      date: now,
      reference: 'QUARANTINE-RECEIPT',
    );

    expect(await dataSource.balance(source, item.id, item.type), 4);
    expect(
      await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND reference = ?',
        whereArgs: [source, 'QUARANTINE-RECEIPT'],
      ),
      hasLength(1),
    );
  });

  test('quarantine warehouse rejects stock-out without mutations', () async {
    await expectStockOutRejectedFor(WarehousePurpose.quarantine);
  });

  test('rework warehouse rejects stock-out without mutations', () async {
    await expectStockOutRejectedFor(WarehousePurpose.rework);
  });

  test('damaged warehouse rejects stock-out without mutations', () async {
    await expectStockOutRejectedFor(WarehousePurpose.damaged);
  });

  test(
    'generic transfers reject restricted sources and destinations',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await seedStockAndValuation(source);
      await seedStockAndValuation(destination);
      await db.update(
        'warehouses',
        {'purpose': 'QUARANTINE'},
        where: 'id = ?',
        whereArgs: [source],
      );
      var before = await stockMutationSnapshot();

      await expectLater(
        dataSource.transfer(
          sourceWarehouseId: source,
          destinationWarehouseId: destination,
          item: item,
          quantity: 2,
          date: now,
        ),
        throwsA(predicate((error) => error.toString().contains('QUARANTINE'))),
      );
      expect(await stockMutationSnapshot(), before);

      await db.update(
        'warehouses',
        {'purpose': 'SELLABLE'},
        where: 'id = ?',
        whereArgs: [source],
      );
      await db.update(
        'warehouses',
        {'purpose': 'DAMAGED'},
        where: 'id = ?',
        whereArgs: [destination],
      );
      before = await stockMutationSnapshot();
      await expectLater(
        dataSource.transfer(
          sourceWarehouseId: source,
          destinationWarehouseId: destination,
          item: item,
          quantity: 2,
          date: now,
        ),
        throwsA(predicate((error) => error.toString().contains('DAMAGED'))),
      );
      expect(await stockMutationSnapshot(), before);
    },
  );

  test(
    'restricted warehouses reject positive and negative adjustments',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'warehouses',
        {'purpose': 'REWORK'},
        where: 'id = ?',
        whereArgs: [source],
      );
      await seedStockAndValuation(source);
      final before = await stockMutationSnapshot();

      for (final difference in [2.0, -2.0]) {
        await expectLater(
          dataSource.adjust(
            warehouseId: source,
            item: item,
            difference: difference,
            date: now,
            reason: 'purpose guard',
          ),
          throwsA(predicate((error) => error.toString().contains('REWORK'))),
        );
        expect(await stockMutationSnapshot(), before);
      }
    },
  );

  test('direct valuation consumption rejects restricted warehouses', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'warehouses',
      {'purpose': 'DAMAGED'},
      where: 'id = ?',
      whereArgs: [source],
    );
    await seedStockAndValuation(source);
    final before = await stockMutationSnapshot();

    await expectLater(
      AccountingLocalDataSource().consumeInventoryValue(
        warehouseId: source,
        itemId: item.inventoryId,
        itemType: item.type.value,
        quantity: 2,
      ),
      throwsA(predicate((error) => error.toString().contains('DAMAGED'))),
    );

    expect(await stockMutationSnapshot(), before);
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
        () => dataSource.stockOut(
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
