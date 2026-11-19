import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDirectory;
  late Database database;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDirectory = await Directory.systemTemp.createTemp(
      'furnexa-sales-delivery-migration-',
    );
    database = await databaseFactoryFfi.openDatabase(
      '${tempDirectory.path}${Platform.pathSeparator}legacy.db',
    );
    await database.execute('PRAGMA foreign_keys = OFF');
    await FurnexaDatabase.instance.migrate(database, 0, 39);
  });

  tearDown(() async {
    await database.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'version 41 preserves legacy inventory and treats deliveries as posted',
    () async {
      await database.insert('sales_deliveries', {
        'id': 'legacy-pending-delivery',
        'deliveryNumber': 'DL-LEGACY-PENDING',
        'salesOrderId': 'legacy-order',
        'warehouseId': 'legacy-warehouse',
        'deliveryDate': 1000,
        'status': 'PENDING',
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await database.insert('stock_balances', {
        'id': 'legacy-stock-balance',
        'warehouseId': 'legacy-warehouse',
        'itemId': 'legacy-product',
        'itemType': 'PRODUCT',
        'quantity': 25,
        'createdAt': 1000,
        'updatedAt': 1000,
      });
      await database.insert('inventory_valuations', {
        'id': 'legacy-inventory-valuation',
        'warehouseId': 'legacy-warehouse',
        'itemId': 'legacy-product',
        'itemType': 'PRODUCT',
        'quantity': 25,
        'averageCost': 4,
        'updatedAt': 1000,
      });
      final stockBefore = (await database.query('stock_balances')).single;
      final valuationBefore = (await database.query(
        'inventory_valuations',
      )).single;
      final deliveryCountBefore = (await database.query(
        'sales_deliveries',
      )).length;

      await FurnexaDatabase.instance.migrate(database, 39, 40);
      await FurnexaDatabase.instance.migrate(database, 40, 41);

      expect(AppConstants.databaseVersion, 41);
      expect(
        (await database.rawQuery('PRAGMA user_version')).single['user_version'],
        41,
      );
      expect(
        (await database.query(
          'sales_deliveries',
          where: 'id = ?',
          whereArgs: ['legacy-pending-delivery'],
        )).single['inventoryPosted'],
        1,
      );
      expect((await database.query('stock_balances')).single, stockBefore);
      expect(
        (await database.query('inventory_valuations')).single,
        valuationBefore,
      );
      expect(
        (await database.query('sales_deliveries')).length,
        deliveryCountBefore,
      );
      expect(
        await database.query(
          'sales_deliveries',
          where: 'inventoryPosted = 0 AND status IN (?, ?, ?)',
          whereArgs: ['PENDING', 'DISPATCHED', 'IN_TRANSIT'],
        ),
        isEmpty,
      );

      await database.insert('sales_deliveries', {
        'id': 'new-reservation-delivery',
        'deliveryNumber': 'DL-NEW-RESERVATION',
        'salesOrderId': 'new-order',
        'warehouseId': 'legacy-warehouse',
        'deliveryDate': 2000,
        'status': 'PENDING',
        'inventoryPosted': 0,
        'createdAt': 2000,
        'updatedAt': 2000,
      });
      expect(
        (await database.query(
          'sales_deliveries',
          where: 'id = ?',
          whereArgs: ['new-reservation-delivery'],
        )).single['inventoryPosted'],
        0,
      );
    },
  );

  test('fresh database initialization creates the version 41 schema', () async {
    await database.close();
    database = await databaseFactoryFfi.openDatabase(
      '${tempDirectory.path}${Platform.pathSeparator}fresh.db',
      options: OpenDatabaseOptions(
        version: AppConstants.databaseVersion,
        onCreate: (db, version) =>
            FurnexaDatabase.instance.migrate(db, 0, version),
      ),
    );

    expect(
      (await database.rawQuery('PRAGMA user_version')).single['user_version'],
      41,
    );
    final columns = await database.rawQuery(
      'PRAGMA table_info(sales_deliveries)',
    );
    final inventoryPosted = columns.singleWhere(
      (column) => column['name'] == 'inventoryPosted',
    );
    expect(inventoryPosted['dflt_value'], '1');
    expect(
      (await database.rawQuery(
        'PRAGMA table_info(sales_order_items)',
      )).any((column) => column['name'] == 'invoicedQuantity'),
      isTrue,
    );
    expect(
      await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sales_invoices'",
      ),
      hasLength(1),
    );
    expect(await database.query('stock_balances'), isEmpty);
    expect(await database.query('inventory_valuations'), isEmpty);

    await database.insert('sales_deliveries', {
      'id': 'fresh-pending-delivery',
      'deliveryNumber': 'DL-FRESH-PENDING',
      'salesOrderId': 'fresh-order',
      'warehouseId': 'fresh-warehouse',
      'deliveryDate': 2000,
      'status': 'PENDING',
      'createdAt': 2000,
      'updatedAt': 2000,
    });
    expect(
      (await database.query(
        'sales_deliveries',
        where: 'id = ?',
        whereArgs: ['fresh-pending-delivery'],
      )).single['inventoryPosted'],
      1,
    );
  });
}
