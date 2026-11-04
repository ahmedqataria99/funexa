import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'version 34 preserves verified base and unassigned legacy inventory',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      try {
        await FurnexaDatabase.instance.migrate(db, 0, 33);
        await db.execute('PRAGMA foreign_keys = ON');
        final stamp = DateTime(2026, 10, 9).millisecondsSinceEpoch;
        await db.insert('factories', {
          'id': 'm03-factory',
          'name': 'M03 Factory',
          'code': 'M03-F',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('warehouses', {
          'id': 'm03-warehouse',
          'factoryId': 'm03-factory',
          'name': 'M03 Warehouse',
          'code': 'M03-W',
          'state': 'active',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('warehouses', {
          'id': 'm03-warehouse-secondary',
          'factoryId': 'm03-factory',
          'name': 'M03 Secondary Warehouse',
          'code': 'M03-W2',
          'state': 'active',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('categories', {
          'id': 'm03-category',
          'name': 'M03 Category',
          'code': 'M03-C',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('units', {
          'id': 'm03-unit',
          'name': 'M03 Unit',
          'abbreviation': 'M03U',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        for (final product in [
          ('m03-base-product', 'M03-BASE'),
          ('m03-variant-product', 'M03-VARIANT'),
        ]) {
          await db.insert('products', {
            'id': product.$1,
            'name': product.$1,
            'code': product.$2,
            'categoryId': 'm03-category',
            'unitId': 'm03-unit',
            'productState': 'finished',
            'active': 1,
            'createdAt': stamp,
            'updatedAt': stamp,
          });
        }
        await db.insert('product_variants', {
          'id': 'collision-variant',
          'productId': 'm03-variant-product',
          'name': 'Collision Variant',
          'code': 'COL-V',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('product_variants', {
          'id': 'm03-variant-red',
          'productId': 'm03-variant-product',
          'name': 'Red',
          'code': 'M03-RED',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('product_variants', {
          'id': 'm03-variant-blue',
          'productId': 'm03-variant-product',
          'name': 'Blue',
          'code': 'M03-BLUE',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });

        await _insertInventory(
          db,
          stamp: stamp,
          productId: 'm03-base-product',
          quantity: 12,
          received: 20,
          issued: 8,
          averageCost: 4.5,
        );
        await _insertInventory(
          db,
          stamp: stamp,
          warehouseId: 'm03-warehouse-secondary',
          productId: 'm03-base-product',
          quantity: 5,
          received: 5,
          issued: 0,
          averageCost: 6,
        );
        await _insertInventory(
          db,
          stamp: stamp,
          productId: 'm03-variant-product',
          quantity: 7,
          received: 7,
          issued: 0,
          averageCost: 8,
        );
        await db.insert('stock_minimum_levels', {
          'id': 'm03-base-minimum',
          'warehouseId': 'm03-warehouse',
          'itemId': 'm03-base-product',
          'itemType': 'PRODUCT',
          'minimumQuantity': 2,
          'createdAt': stamp,
          'updatedAt': stamp,
        });

        final beforeQuantity = (await db.rawQuery(
          'SELECT SUM(quantity) total FROM stock_balances',
        )).single['total'];
        final beforeValue = (await db.rawQuery(
          'SELECT SUM(quantity * averageCost) total FROM inventory_valuations',
        )).single['total'];
        final beforeValuationQuantity = (await db.rawQuery(
          'SELECT SUM(quantity) total FROM inventory_valuations',
        )).single['total'];

        await FurnexaDatabase.instance.migrate(db, 33, 34);

        final base = (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND productId = ?',
          whereArgs: ['m03-warehouse', 'm03-base-product'],
        )).single;
        expect(base['itemId'], 'm03-base-product');
        expect(base['inventoryIdentityKind'], 'BASE');
        expect(base['unitId'], 'm03-unit');
        final secondaryBase = (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND productId = ?',
          whereArgs: ['m03-warehouse-secondary', 'm03-base-product'],
        )).single;
        expect(secondaryBase['itemId'], 'm03-base-product');
        expect(secondaryBase['inventoryIdentityKind'], 'BASE');
        expect(secondaryBase['quantity'], 5);

        const legacyKey = '__FURNEXA_LEGACY_UNASSIGNED__:m03-variant-product';
        final legacyBalance = (await db.query(
          'stock_balances',
          where: 'productId = ?',
          whereArgs: ['m03-variant-product'],
        )).single;
        expect(legacyBalance['itemId'], legacyKey);
        expect(legacyBalance['inventoryIdentityKind'], 'LEGACY_UNASSIGNED');
        expect(legacyBalance['quantity'], 7);
        expect(legacyBalance['variantId'], isNull);
        expect(
          await db.query(
            'stock_balances',
            where: 'productId = ? AND variantId IS NOT NULL',
            whereArgs: ['m03-variant-product'],
          ),
          isEmpty,
        );

        final legacyTransaction = (await db.query(
          'stock_transactions',
          where: 'productId = ?',
          whereArgs: ['m03-variant-product'],
        )).single;
        expect(legacyTransaction['itemId'], legacyKey);
        expect(legacyTransaction['inventoryIdentityKind'], 'LEGACY_UNASSIGNED');

        final legacyValuation = (await db.query(
          'inventory_valuations',
          where: 'productId = ?',
          whereArgs: ['m03-variant-product'],
        )).single;
        expect(legacyValuation['itemId'], legacyKey);
        expect(legacyValuation['inventoryIdentityKind'], 'LEGACY_UNASSIGNED');
        expect(legacyValuation['quantity'], 7);
        expect(legacyValuation['averageCost'], 8);

        expect(
          (await db.rawQuery(
            'SELECT SUM(quantity) total FROM stock_balances',
          )).single['total'],
          beforeQuantity,
        );
        expect(
          (await db.rawQuery(
            'SELECT SUM(quantity * averageCost) total FROM inventory_valuations',
          )).single['total'],
          beforeValue,
        );
        expect(
          (await db.rawQuery(
            'SELECT SUM(quantity) total FROM inventory_valuations',
          )).single['total'],
          beforeValuationQuantity,
        );
        final secondaryValuation = (await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND productId = ?',
          whereArgs: ['m03-warehouse-secondary', 'm03-base-product'],
        )).single;
        expect(secondaryValuation['quantity'], 5);
        expect(secondaryValuation['averageCost'], 6);
        expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
        expect(
          (await db.rawQuery('PRAGMA user_version')).single['user_version'],
          34,
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'synthetic legacy-key collisions fail without partial migration',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      try {
        await FurnexaDatabase.instance.migrate(db, 0, 33);
        await db.execute('PRAGMA foreign_keys = ON');
        await _seedCollisionFixture(db);
        await db.execute('PRAGMA user_version = 33');

        await expectLater(
          db.transaction(
            (txn) => FurnexaDatabase.instance.migrate(txn, 33, 34),
          ),
          throwsA(isA<StateError>()),
        );

        expect(
          (await db.rawQuery('PRAGMA user_version')).single['user_version'],
          33,
        );
        expect(
          (await db.rawQuery(
            'PRAGMA table_info(stock_balances)',
          )).any((column) => column['name'] == 'productId'),
          isFalse,
        );
        expect(
          (await db.query('stock_balances')).single['itemId'],
          'collision-source',
        );
        expect(
          (await db.query('inventory_valuations')).single['itemId'],
          'collision-source',
        );
        expect(
          (await db.query('stock_transactions')).single['itemId'],
          'collision-source',
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'late migration failure rolls back prior inventory identity updates',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      try {
        await FurnexaDatabase.instance.migrate(db, 0, 33);
        await db.execute('PRAGMA foreign_keys = ON');
        await _seedCollisionFixture(db);
        await db.delete(
          'products',
          where: 'id = ?',
          whereArgs: ['__FURNEXA_LEGACY_UNASSIGNED__:collision-source'],
        );
        await db.execute('PRAGMA user_version = 33');
        await db.execute('''
        CREATE TRIGGER fail_m03_valuation_update
        BEFORE UPDATE ON inventory_valuations
        BEGIN
          SELECT RAISE(ABORT, 'injected migration failure');
        END
      ''');

        await expectLater(
          db.transaction(
            (txn) => FurnexaDatabase.instance.migrate(txn, 33, 34),
          ),
          throwsException,
        );

        expect(
          (await db.rawQuery('PRAGMA user_version')).single['user_version'],
          33,
        );
        for (final table in [
          'stock_balances',
          'stock_transactions',
          'inventory_valuations',
        ]) {
          expect(
            (await db.rawQuery(
              'PRAGMA table_info("$table")',
            )).any((column) => column['name'] == 'productId'),
            isFalse,
            reason: '$table schema change should roll back',
          );
          expect((await db.query(table)).single['itemId'], 'collision-source');
        }
      } finally {
        await db.close();
      }
    },
  );
}

Future<void> _insertInventory(
  DatabaseExecutor db, {
  required int stamp,
  String warehouseId = 'm03-warehouse',
  required String productId,
  required double quantity,
  required double received,
  required double issued,
  required double averageCost,
}) async {
  await db.insert('stock_balances', {
    'id': 'balance-$warehouseId-$productId',
    'warehouseId': warehouseId,
    'itemId': productId,
    'itemType': 'PRODUCT',
    'quantity': quantity,
    'createdAt': stamp,
    'updatedAt': stamp,
  });
  if (received > 0) {
    await db.insert('stock_transactions', {
      'id': 'in-$warehouseId-$productId',
      'warehouseId': warehouseId,
      'itemId': productId,
      'itemType': 'PRODUCT',
      'transactionType': 'STOCK_IN',
      'quantity': received,
      'unitId': 'm03-unit',
      'reference': 'M03-RECEIPT',
      'transactionDate': stamp,
      'createdAt': stamp,
    });
  }
  if (issued > 0) {
    await db.insert('stock_transactions', {
      'id': 'out-$warehouseId-$productId',
      'warehouseId': warehouseId,
      'itemId': productId,
      'itemType': 'PRODUCT',
      'transactionType': 'STOCK_OUT',
      'quantity': issued,
      'unitId': 'm03-unit',
      'reference': 'M03-ISSUE',
      'transactionDate': stamp,
      'createdAt': stamp,
    });
  }
  await db.insert('inventory_valuations', {
    'id': 'valuation-$warehouseId-$productId',
    'warehouseId': warehouseId,
    'itemId': productId,
    'itemType': 'PRODUCT',
    'quantity': quantity,
    'averageCost': averageCost,
    'updatedAt': stamp,
  });
}

Future<void> _seedCollisionFixture(DatabaseExecutor db) async {
  final stamp = DateTime(2026, 10, 9).millisecondsSinceEpoch;
  await db.insert('factories', {
    'id': 'collision-factory',
    'name': 'Collision Factory',
    'code': 'COL-F',
    'createdAt': stamp,
    'updatedAt': stamp,
  });
  await db.insert('warehouses', {
    'id': 'collision-warehouse',
    'factoryId': 'collision-factory',
    'name': 'Collision Warehouse',
    'code': 'COL-W',
    'state': 'active',
    'createdAt': stamp,
    'updatedAt': stamp,
  });
  await db.insert('categories', {
    'id': 'collision-category',
    'name': 'Collision Category',
    'code': 'COL-C',
    'active': 1,
    'createdAt': stamp,
    'updatedAt': stamp,
  });
  await db.insert('units', {
    'id': 'collision-unit',
    'name': 'Collision Unit',
    'abbreviation': 'COL-U',
    'active': 1,
    'createdAt': stamp,
    'updatedAt': stamp,
  });
  for (final product in [
    ('collision-source', 'COL-1'),
    ('__FURNEXA_LEGACY_UNASSIGNED__:collision-source', 'COL-2'),
  ]) {
    await db.insert('products', {
      'id': product.$1,
      'name': product.$1,
      'code': product.$2,
      'categoryId': 'collision-category',
      'unitId': 'collision-unit',
      'productState': 'finished',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
  }
  await db.insert('product_variants', {
    'id': 'collision-source-variant',
    'productId': 'collision-source',
    'name': 'Collision Source Variant',
    'code': 'COL-SOURCE-V',
    'active': 1,
    'createdAt': stamp,
    'updatedAt': stamp,
  });
  await db.insert('stock_balances', {
    'id': 'collision-balance',
    'warehouseId': 'collision-warehouse',
    'itemId': 'collision-source',
    'itemType': 'PRODUCT',
    'quantity': 3,
    'createdAt': stamp,
    'updatedAt': stamp,
  });
  await db.insert('stock_transactions', {
    'id': 'collision-transaction',
    'warehouseId': 'collision-warehouse',
    'itemId': 'collision-source',
    'itemType': 'PRODUCT',
    'transactionType': 'STOCK_IN',
    'quantity': 3,
    'unitId': 'collision-unit',
    'reference': 'LEGACY',
    'transactionDate': stamp,
    'createdAt': stamp,
  });
  await db.insert('inventory_valuations', {
    'id': 'collision-valuation',
    'warehouseId': 'collision-warehouse',
    'itemId': 'collision-source',
    'itemType': 'PRODUCT',
    'quantity': 3,
    'averageCost': 2,
    'updatedAt': stamp,
  });
}
