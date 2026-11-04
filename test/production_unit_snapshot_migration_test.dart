import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fresh database supports complete verified production snapshots',
    () async {
      await DatabaseTestHelper.reset(createInitialAdmin: false);
      try {
        final db = await FurnexaDatabase.instance.database;
        expect(
          (await db.rawQuery('PRAGMA user_version')).single['user_version'],
          AppConstants.databaseVersion,
        );
        final columns = await db.rawQuery(
          'PRAGMA table_info(production_orders)',
        );
        final columnNames = columns.map((column) => column['name']).toSet();
        expect(
          columnNames,
          containsAll([
            'unitId',
            'baseUnitId',
            'unitConversionFactor',
            'plannedBaseQuantity',
            'unitSnapshotStatus',
          ]),
        );

        final stamp = DateTime.utc(2026, 10, 13).millisecondsSinceEpoch;
        await db.insert('categories', {
          'id': 'snapshot-category',
          'name': 'Snapshot Category',
          'code': 'SNAP-CAT',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('units', {
          'id': 'snapshot-unit',
          'name': 'Snapshot Unit',
          'abbreviation': 'SU',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('products', {
          'id': 'snapshot-product',
          'name': 'Snapshot Product',
          'code': 'SNAP-PROD',
          'categoryId': 'snapshot-category',
          'unitId': 'snapshot-unit',
          'productState': 'finished',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('production_routes', {
          'id': 'snapshot-route',
          'productId': 'snapshot-product',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('production_orders', {
          'id': 'snapshot-order',
          'orderNumber': 'SNAP-ORDER',
          'productId': 'snapshot-product',
          'routeId': 'snapshot-route',
          'plannedQuantity': 2.5,
          'producedQuantity': 0,
          'status': 'DRAFT',
          'unitId': 'snapshot-unit',
          'baseUnitId': 'snapshot-unit',
          'unitConversionFactor': 1,
          'plannedBaseQuantity': 2.5,
          'unitSnapshotStatus': 'VERIFIED',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        final verified = (await db.query(
          'production_orders',
          where: 'id = ?',
          whereArgs: ['snapshot-order'],
        )).single;
        expect(verified['unitSnapshotStatus'], 'VERIFIED');
        expect(verified['plannedBaseQuantity'], 2.5);
        await expectLater(
          db.insert('production_orders', {
            'id': 'incomplete-snapshot-order',
            'orderNumber': 'SNAP-ORDER-INCOMPLETE',
            'productId': 'snapshot-product',
            'routeId': 'snapshot-route',
            'plannedQuantity': 1,
            'producedQuantity': 0,
            'status': 'DRAFT',
            'unitSnapshotStatus': 'VERIFIED',
            'createdAt': stamp,
            'updatedAt': stamp,
          }),
          throwsException,
        );

        await FurnexaDatabase.instance.close();
        final reopened = await FurnexaDatabase.instance.database;
        expect(
          (await reopened.rawQuery(
            'PRAGMA user_version',
          )).single['user_version'],
          AppConstants.databaseVersion,
        );
        expect(
          (await reopened.rawQuery(
            'PRAGMA table_info(production_orders)',
          )).where((column) => column['name'] == 'unitSnapshotStatus'),
          hasLength(1),
        );
        expect(
          (await reopened.query(
            'production_orders',
            where: 'id = ?',
            whereArgs: ['snapshot-order'],
          )).single['unitSnapshotStatus'],
          'VERIFIED',
        );
      } finally {
        await FurnexaDatabase.instance.close();
      }
    },
  );

  test(
    'version 36 preserves legacy orders and output snapshots as unknown',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      try {
        await db.execute('PRAGMA foreign_keys = OFF');
        await FurnexaDatabase.instance.migrate(db, 0, 35);
        final stamp = DateTime.utc(2026, 10, 13).millisecondsSinceEpoch;
        await db.insert('units', {
          'id': 'current-product-unit',
          'name': 'Current Unit',
          'abbreviation': 'CU',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('units', {
          'id': 'historical-output-unit',
          'name': 'Historical Output Unit',
          'abbreviation': 'HOU',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('products', {
          'id': 'legacy-product',
          'name': 'Legacy Product',
          'code': 'LEGACY-PROD',
          'categoryId': 'legacy-category',
          'unitId': 'current-product-unit',
          'productState': 'finished',
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('product_unit_conversions', {
          'id': 'current-conversion',
          'productId': 'legacy-product',
          'unitId': 'historical-output-unit',
          'factorToBase': 12,
          'active': 1,
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('production_orders', {
          'id': 'legacy-production-order',
          'orderNumber': 'LEGACY-PRODUCTION-ORDER',
          'productId': 'legacy-product',
          'variantId': 'legacy-variant',
          'routeId': 'legacy-route',
          'plannedQuantity': 7.5,
          'producedQuantity': 2.25,
          'status': 'IN_PROGRESS',
          'startDate': stamp - 1000,
          'notes': 'Keep existing notes',
          'createdAt': stamp - 2000,
          'updatedAt': stamp,
        });
        await db.insert('production_outputs', {
          'id': 'legacy-output',
          'operationId': 'legacy-output-operation',
          'productionOrderId': 'legacy-production-order',
          'warehouseId': 'legacy-warehouse',
          'quantity': 3,
          'unitId': 'historical-output-unit',
          'outputDate': stamp,
          'createdAt': stamp,
          'productId': 'legacy-product',
          'variantId': 'legacy-variant',
          'baseUnitId': 'historical-output-unit',
          'unitConversionFactor': 4,
          'baseQuantity': 12,
          'inventoryIdentityKind': 'VARIANT',
          'identitySnapshotStatus': 'VERIFIED',
        });
        final outputBefore = (await db.query(
          'production_outputs',
          where: 'id = ?',
          whereArgs: ['legacy-output'],
        )).single;

        await db.transaction(
          (txn) => FurnexaDatabase.instance.migrate(txn, 35, 36),
        );
        final orderAfterMigration = (await db.query(
          'production_orders',
          where: 'id = ?',
          whereArgs: ['legacy-production-order'],
        )).single;
        expect(
          (await db.rawQuery('PRAGMA user_version')).single['user_version'],
          36,
        );
        expect(orderAfterMigration['orderNumber'], 'LEGACY-PRODUCTION-ORDER');
        expect(orderAfterMigration['productId'], 'legacy-product');
        expect(orderAfterMigration['variantId'], 'legacy-variant');
        expect(orderAfterMigration['routeId'], 'legacy-route');
        expect(orderAfterMigration['plannedQuantity'], 7.5);
        expect(orderAfterMigration['producedQuantity'], 2.25);
        expect(orderAfterMigration['status'], 'IN_PROGRESS');
        expect(orderAfterMigration['notes'], 'Keep existing notes');
        expect(orderAfterMigration['unitId'], isNull);
        expect(orderAfterMigration['baseUnitId'], isNull);
        expect(orderAfterMigration['unitConversionFactor'], isNull);
        expect(orderAfterMigration['plannedBaseQuantity'], isNull);
        expect(orderAfterMigration['unitSnapshotStatus'], 'UNVERIFIED');

        await db.transaction(
          (txn) => FurnexaDatabase.instance.migrate(txn, 35, 36),
        );
        final orderAfterReapply = (await db.query(
          'production_orders',
          where: 'id = ?',
          whereArgs: ['legacy-production-order'],
        )).single;
        expect(orderAfterReapply, orderAfterMigration);
        expect(
          (await db.rawQuery(
            'PRAGMA table_info(production_orders)',
          )).where((column) => column['name'] == 'unitSnapshotStatus'),
          hasLength(1),
        );
        expect(
          (await db.query(
            'production_outputs',
            where: 'id = ?',
            whereArgs: ['legacy-output'],
          )).single,
          outputBefore,
        );
        expect(
          (await db.query(
            'product_unit_conversions',
            where: 'id = ?',
            whereArgs: ['current-conversion'],
          )).single['factorToBase'],
          12,
        );
      } finally {
        await db.close();
      }
    },
  );
}
