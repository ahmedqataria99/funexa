import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/import_export/data/datasources/import_export_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late ImportExportLocalDataSource importExport;
  late SecurityLocalDataSource security;
  late Database db;
  late String factoryId;
  late String warehouseId;
  late String categoryId;
  late String unitId;
  late String productId;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    importExport = ImportExportLocalDataSource(security: security);
    db = await FurnexaDatabase.instance.database;

    await db.delete('stock_transactions');
    await db.delete('stock_balances');
    await db.delete('product_bom_items');
    await db.delete('products');
    await db.delete('raw_materials');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('warehouses');
    await db.delete('factories');

    final now = DateTime(2026, 9, 17);
    factoryId = 'factory-import-$now';
    warehouseId = 'warehouse-import-$now';
    categoryId = 'category-import-$now';
    unitId = 'unit-import-$now';
    productId = 'product-import-$now';

    await db.insert('factories', {
      'id': factoryId,
      'name': 'Import Factory',
      'code': 'IMPORT-FAC-$now',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'Central Warehouse',
      'code': 'WH-IMPORT-$now',
      'state': 'active',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'Core Category',
      'code': 'CAT-IMPORT-$now',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'Pieces',
      'abbreviation': 'PCS$now',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'Imported Product',
      'code': 'PROD-IMPORT-$now',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    await security.ensureInitialAdmin();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  test(
    '1. exportData creates a JSON export payload and stores audit history',
    () async {
      final exportResult = await importExport.exportData(module: 'products');

      expect(exportResult.module, 'products');
      expect(exportResult.payload, isNotEmpty);
      expect(exportResult.records, greaterThan(0));
      expect(jsonDecode(exportResult.payload)['module'], 'products');
      expect(jsonDecode(exportResult.payload)['records'], isNotEmpty);

      final history = await importExport.history(module: 'products');
      expect(history, isNotEmpty);
      expect(history.first.type, 'EXPORT');
    },
  );

  test('2. importData inserts valid records transactionally', () async {
    final payload = jsonEncode({
      'module': 'products',
      'records': [
        {
          'table': 'products',
          'rows': [
            {
              'id': 'product-import-new',
              'name': 'Imported Product New',
              'code': 'PROD-IMP-NEW',
              'categoryId': categoryId,
              'unitId': unitId,
              'productState': 'finished',
              'active': 1,
              'createdAt': DateTime(2026, 9, 18).millisecondsSinceEpoch,
              'updatedAt': DateTime(2026, 9, 18).millisecondsSinceEpoch,
            },
          ],
        },
      ],
    });

    final result = await importExport.importData(payload);

    expect(result.recordsCreated, 1);
    expect(result.recordsUpdated, 0);

    final inserted = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: ['product-import-new'],
      limit: 1,
    );
    expect(inserted, isNotEmpty);
    expect(inserted.single['code'], 'PROD-IMP-NEW');
  });

  test('3. invalid imports are rejected before commit', () async {
    final payload = jsonEncode({
      'module': 'products',
      'records': [
        {
          'table': 'products',
          'rows': [
            {
              'id': 'product-import-bad',
              'name': '',
              'code': '',
              'categoryId': 'missing-category',
              'unitId': unitId,
              'productState': 'finished',
              'active': 1,
              'createdAt': DateTime(2026, 9, 18).millisecondsSinceEpoch,
              'updatedAt': DateTime(2026, 9, 18).millisecondsSinceEpoch,
            },
          ],
        },
      ],
    });

    await expectLater(importExport.importData(payload), throwsException);
  });

  test('4. unauthenticated users cannot export or import', () async {
    security.logout();

    await expectLater(
      importExport.exportData(module: 'products'),
      throwsException,
    );
    await expectLater(
      importExport.importData(
        jsonEncode({'module': 'products', 'records': []}),
      ),
      throwsException,
    );
  });

  test(
    'unsupported financial, stock, and audit tables cannot be imported',
    () async {
      for (final table in [
        'journal_entries',
        'journal_lines',
        'stock_balances',
        'inventory_valuations',
        'accounting_periods',
        'audit_logs',
        'users',
        'role_permissions',
      ]) {
        await expectLater(
          importExport.importData(
            jsonEncode({
              'module': 'products',
              'records': [
                {
                  'table': table,
                  'rows': [
                    {'id': 'untrusted-record'},
                  ],
                },
              ],
            }),
          ),
          throwsException,
          reason: '$table must not be writable through product import',
        );
      }
    },
  );

  test('imports outside the system-admin permission are rejected', () async {
    final role = await security.createRole(name: 'Import Viewer');
    await security.setRolePermissions(role.id, ['PRODUCTS_VIEW']);
    final user = await security.createUser(
      username: 'import-viewer',
      displayName: 'Import Viewer',
      password: 'secret123',
      roleId: role.id,
    );
    security.logout();
    await security.login(user.username, 'secret123');
    await expectLater(
      importExport.importData(
        jsonEncode({
          'module': 'products',
          'records': [
            {
              'table': 'products',
              'rows': [
                {
                  'id': 'unauthorized-product',
                  'name': 'Unauthorized',
                  'code': 'UNAUTHORIZED',
                  'categoryId': categoryId,
                  'unitId': unitId,
                },
              ],
            },
          ],
        }),
      ),
      throwsException,
    );
  });
}
