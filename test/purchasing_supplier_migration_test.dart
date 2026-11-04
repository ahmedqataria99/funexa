import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers/database_test_helper.dart';

void main() {
  late Directory legacyDirectory;
  Database? legacyDatabase;
  final now = DateTime.utc(2026, 10, 5);

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login(
      'admin',
      DatabaseTestHelper.adminPassword,
    );
  });

  tearDown(() async {
    SecurityLocalDataSource().logout();
    await legacyDatabase?.close();
    legacyDatabase = null;
    if (legacyDirectory.existsSync()) {
      await legacyDirectory.delete(recursive: true);
    }
    await DatabaseTestHelper.reset();
  });

  test('version 28 upgrades legacy requests without losing data', () async {
    legacyDirectory = await Directory.systemTemp.createTemp(
      'furnexa-purchase-request-migration-',
    );
    legacyDatabase = await databaseFactoryFfi.openDatabase(
      '${legacyDirectory.path}${Platform.pathSeparator}legacy.db',
    );
    final db = legacyDatabase!;
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        active INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE units (id TEXT PRIMARY KEY)
    ''');
    await db.execute('''
      CREATE TABLE raw_materials (
        id TEXT PRIMARY KEY,
        unitId TEXT NOT NULL,
        active INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE purchase_requests (
        id TEXT PRIMARY KEY,
        requestNumber TEXT NOT NULL UNIQUE,
        requestDate INTEGER NOT NULL,
        requestedBy TEXT NOT NULL,
        notes TEXT,
        status TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE purchase_request_items (
        id TEXT PRIMARY KEY,
        purchaseRequestId TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemType TEXT NOT NULL,
        quantity REAL NOT NULL,
        unitId TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.insert('suppliers', {
      'id': 'migration-supplier',
      'name': 'Migration Supplier',
      'code': 'MIG-SUP',
      'active': 1,
    });
    await db.insert('units', {'id': 'migration-unit'});
    await db.insert('raw_materials', {
      'id': 'migration-material',
      'unitId': 'migration-unit',
      'active': 1,
    });
    await db.insert('purchase_requests', {
      'id': 'legacy-request',
      'requestNumber': 'PR-LEGACY-1',
      'requestDate': now.millisecondsSinceEpoch,
      'requestedBy': 'Legacy requester',
      'notes': 'Keep this note',
      'status': 'DRAFT',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('purchase_request_items', {
      'id': 'legacy-line',
      'purchaseRequestId': 'legacy-request',
      'itemId': 'migration-material',
      'itemType': 'RAW_MATERIAL',
      'quantity': 3,
      'unitId': 'migration-unit',
      'notes': 'Keep this line',
    });
    await db.execute('PRAGMA user_version = 27');

    await FurnexaDatabase.instance.migrate(db, 27, 28);

    final columns = await db.rawQuery('PRAGMA table_info(purchase_requests)');
    expect(columns.any((column) => column['name'] == 'supplierId'), isTrue);
    final migratedVersion = await db.rawQuery('PRAGMA user_version');
    expect(migratedVersion.single['user_version'], 28);
    final foreignKeys = await db.rawQuery(
      'PRAGMA foreign_key_list(purchase_requests)',
    );
    expect(
      foreignKeys.any(
        (key) => key['from'] == 'supplierId' && key['table'] == 'suppliers',
      ),
      isTrue,
    );

    final preserved = (await db.query(
      'purchase_requests',
      where: 'id = ?',
      whereArgs: ['legacy-request'],
    )).single;
    expect(preserved['requestNumber'], 'PR-LEGACY-1');
    expect(preserved['requestedBy'], 'Legacy requester');
    expect(preserved['notes'], 'Keep this note');
    expect(preserved['supplierId'], isNull);
    expect(
      await db.query(
        'purchase_request_items',
        where: 'purchaseRequestId = ?',
        whereArgs: ['legacy-request'],
      ),
      hasLength(1),
    );

    final repository = PurchasingLocalDataSource.withDatabase(db);
    final legacyRequest = (await repository.requests()).single;
    expect(legacyRequest.supplierId, isEmpty);
    expect(legacyRequest.notes, 'Keep this note');

    final legacyWithExplicitSupplier = PurchaseRequest(
      id: legacyRequest.id,
      requestNumber: legacyRequest.requestNumber,
      requestDate: legacyRequest.requestDate,
      supplierId: 'migration-supplier',
      requestedBy: legacyRequest.requestedBy,
      notes: legacyRequest.notes,
      status: legacyRequest.status,
      createdAt: legacyRequest.createdAt,
      updatedAt: now,
      items: legacyRequest.items,
    );
    await repository.saveRequest(legacyWithExplicitSupplier);

    final newRequest = PurchaseRequest(
      id: 'new-request',
      requestNumber: 'PR-NEW-1',
      requestDate: now,
      supplierId: 'migration-supplier',
      requestedBy: 'New requester',
      status: PurchaseRequestStatus.draft,
      createdAt: now,
      updatedAt: now,
      items: const [
        PurchasingItem(
          id: 'new-line',
          itemId: 'migration-material',
          itemType: PurchasingItemType.rawMaterial,
          quantity: 2,
          unitId: 'migration-unit',
        ),
      ],
    );
    await repository.saveRequest(newRequest);

    final savedRequests = await repository.requests();
    expect(savedRequests, hasLength(2));
    expect(
      savedRequests
          .singleWhere((request) => request.id == 'legacy-request')
          .supplierId,
      'migration-supplier',
    );
    final savedNewRequest = savedRequests.singleWhere(
      (request) => request.id == 'new-request',
    );
    expect(savedNewRequest.supplierId, 'migration-supplier');
    expect(savedNewRequest.items.single.quantity, 2);

    await FurnexaDatabase.instance.migrate(db, 27, 28);
    expect((await repository.requests()).map((request) => request.id).toSet(), {
      'legacy-request',
      'new-request',
    });
  });

  test('fresh database creates supplierId as required', () async {
    final db = await FurnexaDatabase.instance.database;
    final columns = await db.rawQuery('PRAGMA table_info(purchase_requests)');
    final supplierColumn = columns.singleWhere(
      (column) => column['name'] == 'supplierId',
    );

    expect(supplierColumn['notnull'], 1);
    expect(
      await FurnexaDatabase.instance.getDatabaseVersion(),
      AppConstants.databaseVersion,
    );
  });
}
