import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late String originalDirectory;
  late Directory testDirectory;

  setUp(() async {
    originalDirectory = Directory.current.path;
    testDirectory = await Directory.systemTemp.createTemp(
      'furnexa-database-reset-',
    );
    Directory.current = testDirectory.path;
    await FurnexaDatabase.instance.resetForTesting();
  });

  tearDown(() async {
    await FurnexaDatabase.instance.close();
    Directory.current = originalDirectory;
    await testDirectory.delete(recursive: true);
  });

  test('backs up existing data and recreates a fresh database', () async {
    final original = await FurnexaDatabase.instance.database;
    final originalPath = original.path;
    await original.insert('factories', {
      'id': 'reset-preserved-factory',
      'name': 'Reset Preservation Test',
      'code': 'RESET-PRESERVATION',
      'createdAt': 1,
      'updatedAt': 1,
    });
    await original.update(
      'app_setup_state',
      {'completed': 1},
      where: 'id = ?',
      whereArgs: [1],
    );

    final result = await FurnexaDatabase.instance.resetForLocalDevelopment();

    expect(result.databasePath, originalPath);
    expect(result.backupPath, isNotNull);
    final backup = await databaseFactoryFfi.openDatabase(
      result.backupPath!,
      options: OpenDatabaseOptions(readOnly: true),
    );
    expect(
      await backup.query(
        'factories',
        where: 'id = ?',
        whereArgs: ['reset-preserved-factory'],
      ),
      hasLength(1),
    );
    await backup.close();

    final recreated = await FurnexaDatabase.instance.database;
    expect(recreated.path, originalPath);
    expect(await recreated.query('factories'), isEmpty);
    expect(
      await FurnexaDatabase.instance.getDatabaseVersion(),
      AppConstants.databaseVersion,
    );
    expect(await SecurityLocalDataSource().initialAdminSetupRequired(), isTrue);
  });

  test('preserves WAL and SHM files in the verified backup', () async {
    final original = await FurnexaDatabase.instance.database;
    final originalPath = original.path;
    await original.close();
    await FurnexaDatabase.instance.close();

    final walBytes = [1, 2, 3, 4];
    final shmBytes = [5, 6, 7, 8];
    await File('$originalPath-wal').writeAsBytes(walBytes);
    await File('$originalPath-shm').writeAsBytes(shmBytes);

    final result = await FurnexaDatabase.instance.resetForLocalDevelopment();

    expect(await File('${result.backupPath}-wal').readAsBytes(), walBytes);
    expect(await File('${result.backupPath}-shm').readAsBytes(), shmBytes);
    expect(await File('$originalPath-wal').exists(), isFalse);
    expect(await File('$originalPath-shm').exists(), isFalse);
    expect((await FurnexaDatabase.instance.database).isOpen, isTrue);
  });
}
