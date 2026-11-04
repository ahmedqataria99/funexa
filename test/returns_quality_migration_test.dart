import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'version 35 preserves old return and inspection rows without guessing sources',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      try {
        await db.execute('PRAGMA foreign_keys = OFF');
        await FurnexaDatabase.instance.migrate(db, 0, 34);
        final stamp = DateTime.utc(2026, 10, 10).millisecondsSinceEpoch;
        await db.insert('purchase_returns', {
          'id': 'legacy-purchase-return',
          'returnNumber': 'PR-LEGACY',
          'purchaseOrderId': 'legacy-purchase-order',
          'supplierId': 'legacy-supplier',
          'warehouseId': 'legacy-warehouse',
          'returnDate': stamp,
          'status': 'PENDING',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('purchase_return_items', {
          'id': 'legacy-purchase-return-item',
          'purchaseReturnId': 'legacy-purchase-return',
          'itemId': 'legacy-product',
          'productId': 'legacy-product',
          'itemType': 'PRODUCT',
          'quantity': 2,
          'unitId': 'legacy-unit',
          'baseUnitId': 'legacy-unit',
          'unitConversionFactor': 1,
          'baseQuantity': 2,
          'inventoryIdentityKind': 'LEGACY_UNASSIGNED',
          'identitySnapshotStatus': 'UNVERIFIED',
          'unitPrice': 6,
          'qualityStatus': 'PENDING',
          'createdAt': stamp,
        });
        await db.insert('quality_inspections', {
          'id': 'legacy-quality-inspection',
          'inspectionNumber': 'QI-LEGACY',
          'sourceType': 'SALES_RETURN',
          'sourceId': 'legacy-sales-return',
          'warehouseId': 'legacy-warehouse',
          'itemId': 'legacy-product',
          'itemType': 'PRODUCT',
          'inspectionDate': stamp,
          'status': 'PENDING',
          'result': 'PASSED',
          'createdAt': stamp,
          'updatedAt': stamp,
        });
        await db.insert('quality_inspection_items', {
          'id': 'legacy-quality-item',
          'inspectionId': 'legacy-quality-inspection',
          'itemId': 'legacy-product',
          'productId': 'legacy-product',
          'itemType': 'PRODUCT',
          'requestedQuantity': 2,
          'inspectedQuantity': 2,
          'acceptedQuantity': 0,
          'rejectedQuantity': 2,
          'result': 'QUARANTINED',
          'createdAt': stamp,
        });

        await db.transaction(
          (txn) => FurnexaDatabase.instance.migrate(txn, 34, 35),
        );

        expect(
          (await db.rawQuery('PRAGMA user_version')).single['user_version'],
          35,
        );
        final purchaseItem = (await db.query(
          'purchase_return_items',
          where: 'id = ?',
          whereArgs: ['legacy-purchase-return-item'],
        )).single;
        expect(purchaseItem['productId'], 'legacy-product');
        expect(purchaseItem['baseQuantity'], 2);
        expect(purchaseItem['inventoryIdentityKind'], 'LEGACY_UNASSIGNED');
        expect(purchaseItem['purchaseOrderItemId'], isNull);
        expect(purchaseItem['sourceReceiptId'], isNull);

        final qualityItem = (await db.query(
          'quality_inspection_items',
          where: 'id = ?',
          whereArgs: ['legacy-quality-item'],
        )).single;
        expect(qualityItem['productId'], 'legacy-product');
        expect(qualityItem['sourceReturnItemId'], isNull);
        expect(qualityItem['identitySnapshotStatus'], 'UNVERIFIED');
        expect(qualityItem['unitConversionFactor'], 1);
        expect(qualityItem['requestedBaseQuantity'], 0);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'reopening the migrated database keeps the current schema available',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await DatabaseTestHelper.reset(createInitialAdmin: false);
      try {
        final firstOpen = await FurnexaDatabase.instance.database;
        expect(
          (await firstOpen.rawQuery(
            'PRAGMA user_version',
          )).single['user_version'],
          AppConstants.databaseVersion,
        );
        await FurnexaDatabase.instance.close();

        final reopened = await FurnexaDatabase.instance.database;
        expect(
          (await reopened.rawQuery(
            'PRAGMA user_version',
          )).single['user_version'],
          AppConstants.databaseVersion,
        );
        final returnColumns = await reopened.rawQuery(
          'PRAGMA table_info("purchase_return_items")',
        );
        final inspectionColumns = await reopened.rawQuery(
          'PRAGMA table_info("quality_inspection_items")',
        );
        expect(
          returnColumns.where((column) => column['name'] == 'sourceReceiptId'),
          hasLength(1),
        );
        expect(
          inspectionColumns.where(
            (column) => column['name'] == 'sourceReturnItemId',
          ),
          hasLength(1),
        );
      } finally {
        await FurnexaDatabase.instance.close();
      }
    },
  );
}
