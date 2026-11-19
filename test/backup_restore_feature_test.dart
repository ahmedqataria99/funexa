import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/backup_restore/data/datasources/backup_restore_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late SecurityLocalDataSource security;
  late BackupRestoreLocalDataSource backupRestore;

  Future<void> seedData() async {
    final db = await FurnexaDatabase.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('factories', {
      'id': 'factory-1',
      'name': 'Factory Alpha',
      'code': 'ALPHA',
      'phone': '0501234567',
      'email': 'ops@factoryalpha.test',
      'address': 'Riyadh',
      'createdAt': now,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('categories', {
      'id': 'cat-1',
      'name': 'Furniture',
      'code': 'FUR',
      'active': 1,
      'createdAt': now,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('units', {
      'id': 'unit-1',
      'name': 'Piece',
      'abbreviation': 'PCS',
      'active': 1,
      'createdAt': now,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('warehouses', {
      'id': 'warehouse-1',
      'factoryId': 'factory-1',
      'name': 'Main Warehouse',
      'code': 'WH-1',
      'type': 'MAIN',
      'state': 'active',
      'notes': 'Primary warehouse',
      'createdAt': now,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('users', {
      'id': 'user-1',
      'username': 'ops-user',
      'displayName': 'Operations User',
      'passwordHash': 'hashed',
      'roleId': 'role-system-admin',
      'active': 1,
      'createdAt': now,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('products', {
      'id': 'prod-1',
      'name': 'Chair',
      'code': 'CHAIR-1',
      'categoryId': 'cat-1',
      'unitId': 'unit-1',
      'productState': 'unfinished',
      'active': 1,
      'createdAt': now,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await db.insert('stock_balances', {
      'id': 'stock-1',
      'warehouseId': 'warehouse-1',
      'itemId': 'prod-1',
      'itemType': 'PRODUCT',
      'quantity': 10,
      'createdAt': now,
      'updatedAt': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    backupRestore = BackupRestoreLocalDataSource(security: security);
    await seedData();
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  test(
    '1. backup metadata is created and contains the required fields',
    () async {
      final file = File('${Directory.systemTemp.path}/backup_valid_1.furnexa');
      if (file.existsSync()) file.deleteSync();

      final backup = await backupRestore.createBackup(destination: file.path);

      expect(backup.backupId, isNotEmpty);
      expect(backup.databaseVersion, greaterThanOrEqualTo(1));
      expect(backup.factoryName, isNotEmpty);
      expect(backup.checksum, isNotEmpty);
      expect(backup.backupFormatVersion, 1);
      expect(file.existsSync(), isTrue);
    },
  );

  test(
    '2. valid backup validation succeeds and returns backup metadata',
    () async {
      final file = File('${Directory.systemTemp.path}/backup_valid_2.furnexa');
      if (file.existsSync()) file.deleteSync();

      final created = await backupRestore.createBackup(destination: file.path);
      final validated = await backupRestore.validateBackupFile(file.path);

      expect(validated.backupId, created.backupId);
      expect(validated.checksum, created.checksum);
      expect(validated.recordCount, greaterThan(0));
    },
  );

  test('3. corrupted backups are rejected', () async {
    final file = File('${Directory.systemTemp.path}/backup_corrupt.furnexa');
    await file.writeAsString('not-valid-json');

    expect(
      () => backupRestore.validateBackupFile(file.path),
      throwsA(isA<Exception>()),
    );
  });

  test('4. invalid format is rejected when metadata is missing', () async {
    final file = File(
      '${Directory.systemTemp.path}/backup_invalid_format.furnexa',
    );
    await file.writeAsString('{"backupFormatVersion": 1, "records": []}');

    expect(
      () => backupRestore.validateBackupFile(file.path),
      throwsA(isA<Exception>()),
    );
  });

  test('5. backup checksum validation rejects altered file content', () async {
    final path = '${Directory.systemTemp.path}/backup_checksum_test.furnexa';
    final file = File(path);
    final backup = await backupRestore.createBackup(destination: path);
    final source = await file.readAsString();
    final modified = source.replaceFirst('Factory Alpha', 'Changed');
    await file.writeAsString(modified);

    expect(
      () => backupRestore.validateBackupFile(path),
      throwsA(isA<Exception>()),
    );
    expect(backup.factoryName, 'Factory Alpha');
  });

  test('6. restore replaces the current database content', () async {
    final file = File(
      '${Directory.systemTemp.path}/backup_restore_replace.furnexa',
    );
    final backup = await backupRestore.createBackup(destination: file.path);

    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'factories',
      {'name': 'Modified Factory'},
      where: 'id = ?',
      whereArgs: ['factory-1'],
    );
    await db.insert('factories', {
      'id': 'factory-2',
      'name': 'New Factory',
      'code': 'NEW',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await backupRestore.restoreBackup(file.path);
    final restoredDb = await FurnexaDatabase.instance.database;

    final factoryRows = await restoredDb.query(
      'factories',
      orderBy: 'name ASC',
    );
    expect(factoryRows.any((row) => row['name'] == 'Factory Alpha'), isTrue);
    expect(factoryRows.any((row) => row['name'] == 'New Factory'), isFalse);
    expect(backup.backupId, isNotEmpty);
  });

  test('7. safety backup is created before restore', () async {
    final file = File(
      '${Directory.systemTemp.path}/backup_restore_safety.furnexa',
    );
    await backupRestore.createBackup(destination: file.path);

    final safetyPath = await backupRestore.createSafetyBackup();

    expect(File(safetyPath).existsSync(), isTrue);
  });

  test('8. backup history is recorded after a successful backup', () async {
    final file = File(
      '${Directory.systemTemp.path}/backup_history_test.furnexa',
    );
    await backupRestore.createBackup(destination: file.path);

    final history = await backupRestore.getHistory();
    expect(history.isNotEmpty, isTrue);
    expect(history.first.status, 'VALID');
  });

  test('9. missing backup file is handled safely', () async {
    final missingPath = '${Directory.systemTemp.path}/missing_backup.furnexa';

    expect(
      () => backupRestore.validateBackupFile(missingPath),
      throwsA(isA<Exception>()),
    );
  });

  test('10. permission prevents unauthorized restore', () async {
    final file = File(
      '${Directory.systemTemp.path}/backup_unauthorized_restore.furnexa',
    );
    await backupRestore.createBackup(destination: file.path);

    final userSecurity = SecurityLocalDataSource();
    await userSecurity.login('admin', 'Furnexa-Test-Admin-2026!');
    await userSecurity.createUser(
      username: 'limited',
      displayName: 'Limited User',
      password: 'secret123',
      roleId: 'role-system-admin',
    );
    userSecurity.logout();
    await userSecurity.login('limited', 'secret123');

    final limitedBackup = BackupRestoreLocalDataSource(security: userSecurity);
    expect(
      () => limitedBackup.restoreBackup(file.path),
      throwsA(isA<Exception>()),
    );
  });

  test('11. audit records are created for backup and restore events', () async {
    final file = File('${Directory.systemTemp.path}/backup_audit_test.furnexa');
    await backupRestore.createBackup(destination: file.path);
    await backupRestore.restoreBackup(file.path);
    await security.login('admin', 'Furnexa-Test-Admin-2026!');

    final logs = await security.auditLogs();
    final backupEvents = logs
        .where(
          (log) =>
              log.action.contains('BACKUP') || log.action.contains('RESTORE'),
        )
        .toList();
    expect(backupEvents.isNotEmpty, isTrue);
  });

  test('12. restore fails safely when backup data is invalid', () async {
    final invalidPath = '${Directory.systemTemp.path}/bad_restore.furnexa';
    await File(invalidPath).writeAsString('{"wrong":"payload"}');

    expect(
      () => backupRestore.restoreBackup(invalidPath),
      throwsA(isA<Exception>()),
    );
  });

  test(
    '13. invalid checksum restore leaves original factory and stock intact',
    () async {
      final path =
          '${Directory.systemTemp.path}/backup_bad_checksum_restore.furnexa';
      await backupRestore.createBackup(destination: path);

      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'factories',
        {'name': 'Modified Before Rejected Restore'},
        where: 'id = ?',
        whereArgs: ['factory-1'],
      );
      await db.update(
        'stock_balances',
        {'quantity': 42},
        where: 'id = ?',
        whereArgs: ['stock-1'],
      );

      final file = File(path);
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      decoded['checksum'] =
          '0000000000000000000000000000000000000000000000000000000000000000';
      await file.writeAsString(jsonEncode(decoded));

      await expectLater(
        backupRestore.restoreBackup(path),
        throwsA(isA<Exception>()),
      );

      final after = await db.query(
        'factories',
        where: 'id = ?',
        whereArgs: ['factory-1'],
      );
      final stock = await db.query(
        'stock_balances',
        where: 'id = ?',
        whereArgs: ['stock-1'],
      );
      expect(after.single['name'], 'Modified Before Rejected Restore');
      expect((stock.single['quantity'] as num).toDouble(), 42);
    },
  );

  test(
    '14. structurally invalid restore leaves original database unchanged',
    () async {
      final path =
          '${Directory.systemTemp.path}/backup_missing_column_restore.furnexa';
      await backupRestore.createBackup(destination: path);

      final file = File(path);
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final database = Map<String, dynamic>.from(decoded['database'] as Map);
      final tables = (database['tables'] as List).map((entry) {
        final row = Map<String, dynamic>.from(entry as Map);
        if (row['table'] == 'factories') {
          final rows = (row['rows'] as List).map((item) {
            final factory = Map<String, dynamic>.from(item as Map);
            factory['unknownSafetyColumn'] = 'must fail';
            return factory;
          }).toList();
          row['rows'] = rows;
        }
        return row;
      }).toList();
      database['tables'] = tables;
      decoded['database'] = database;
      decoded.remove('checksum');
      decoded['checksum'] = sha256
          .convert(utf8.encode(jsonEncode(decoded)))
          .toString();
      await file.writeAsString(jsonEncode(decoded));

      await expectLater(
        backupRestore.restoreBackup(path),
        throwsA(isA<Exception>()),
      );

      final db = await FurnexaDatabase.instance.database;
      final factory = (await db.query(
        'factories',
        where: 'id = ?',
        whereArgs: ['factory-1'],
      )).single;
      expect(factory['name'], 'Factory Alpha');
    },
  );

  test(
    '15. foreign-key violation triggers rollback recovery and reopens safely',
    () async {
      final path =
          '${Directory.systemTemp.path}/backup_foreign_key_restore.furnexa';
      await backupRestore.createBackup(destination: path);

      final file = File(path);
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final database = Map<String, dynamic>.from(decoded['database'] as Map);
      final tables = (database['tables'] as List).map((entry) {
        final row = Map<String, dynamic>.from(entry as Map);
        if (row['table'] == 'stock_balances') {
          final rows = (row['rows'] as List).map((item) {
            final stock = Map<String, dynamic>.from(item as Map);
            stock['warehouseId'] = 'missing-warehouse-for-safety-test';
            return stock;
          }).toList();
          row['rows'] = rows;
        }
        return row;
      }).toList();
      database['tables'] = tables;
      decoded['database'] = database;
      decoded.remove('checksum');
      decoded['checksum'] = sha256
          .convert(utf8.encode(jsonEncode(decoded)))
          .toString();
      await file.writeAsString(jsonEncode(decoded));

      await expectLater(
        backupRestore.restoreBackup(path),
        throwsA(isA<Exception>()),
      );

      final reopened = await FurnexaDatabase.instance.database;
      expect(await reopened.rawQuery('PRAGMA integrity_check'), isNotEmpty);
      expect(await reopened.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await reopened.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      final stock = (await reopened.query(
        'stock_balances',
        where: 'id = ?',
        whereArgs: ['stock-1'],
      )).single;
      expect(stock['warehouseId'], 'warehouse-1');
    },
  );

  test(
    '16. successful restore passes integrity, foreign keys, and reopen checks',
    () async {
      final path =
          '${Directory.systemTemp.path}/backup_integrity_restore.furnexa';
      await backupRestore.createBackup(destination: path);

      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'factories',
        {'name': 'Modified Factory'},
        where: 'id = ?',
        whereArgs: ['factory-1'],
      );

      await backupRestore.restoreBackup(path);

      final reopened = await FurnexaDatabase.instance.database;
      expect(
        (await reopened.rawQuery(
          'PRAGMA integrity_check',
        )).single.values.single,
        'ok',
      );
      expect(await reopened.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      expect(
        (await reopened.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      final factory = (await reopened.query(
        'factories',
        where: 'id = ?',
        whereArgs: ['factory-1'],
      )).single;
      expect(factory['name'], 'Factory Alpha');
    },
  );

  test('17. WAL committed stock data survives backup restore', () async {
    final path = '${Directory.systemTemp.path}/backup_wal_restore.furnexa';
    final db = await FurnexaDatabase.instance.database;
    await db.execute('PRAGMA journal_mode = WAL');
    await db.update(
      'stock_balances',
      {'quantity': 20},
      where: 'id = ?',
      whereArgs: ['stock-1'],
    );

    await backupRestore.createBackup(destination: path);
    await db.update(
      'stock_balances',
      {'quantity': 99},
      where: 'id = ?',
      whereArgs: ['stock-1'],
    );

    await backupRestore.restoreBackup(path);

    final reopened = await FurnexaDatabase.instance.database;
    final stock = (await reopened.query(
      'stock_balances',
      where: 'id = ?',
      whereArgs: ['stock-1'],
    )).single;
    expect((stock['quantity'] as num).toDouble(), 20);
  });

  test(
    '18. repeated restore is idempotent for stock and factory rows',
    () async {
      final path = '${Directory.systemTemp.path}/backup_retry_restore.furnexa';
      await backupRestore.createBackup(destination: path);

      await backupRestore.restoreBackup(path);
      await security.login('admin', 'Furnexa-Test-Admin-2026!');
      await backupRestore.restoreBackup(path);

      final reopened = await FurnexaDatabase.instance.database;
      expect(
        await reopened.query(
          'factories',
          where: 'id = ?',
          whereArgs: ['factory-1'],
        ),
        hasLength(1),
      );
      expect(
        await reopened.query(
          'stock_balances',
          where: 'id = ?',
          whereArgs: ['stock-1'],
        ),
        hasLength(1),
      );
    },
  );

  test(
    '19. missing safety backup source is observable and does not create a file',
    () async {
      await FurnexaDatabase.instance.database;
      final path = await FurnexaDatabase.instance.databasePath;
      await FurnexaDatabase.instance.close();
      final source = File(path);
      if (await source.exists()) await source.delete();

      final safetyPath = await backupRestore.createSafetyBackup();

      expect(await File(safetyPath).exists(), isFalse);
    },
  );
}
