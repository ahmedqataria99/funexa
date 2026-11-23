import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'demo_data_seeder.dart';

Future<void> main() async {
  try {
    await _run();
  } catch (error) {
    stderr.writeln('Synthetic developer database replacement aborted: $error');
    exitCode = 1;
  }
}

Future<void> _run() async {
  if (!Platform.isWindows) {
    throw UnsupportedError('This utility is intended for Windows development.');
  }
  final processCheck = await Process.run('tasklist.exe', [
    '/FI',
    'IMAGENAME eq furnexa.exe',
    '/FO',
    'CSV',
    '/NH',
  ]);
  if (processCheck.exitCode != 0) {
    throw StateError('Could not verify whether Furnexa is running.');
  }
  if (processCheck.stdout.toString().toLowerCase().contains('"furnexa.exe"')) {
    throw StateError('Close Furnexa before replacing the developer database.');
  }

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final database = FurnexaDatabase.instance;
  final activePath = await database.databasePath;
  final source = File(activePath);
  if (!await source.exists()) {
    throw StateError('The developer database does not exist: $activePath');
  }
  for (final suffix in const ['-wal', '-shm']) {
    if (await File('$activePath$suffix').exists()) {
      throw StateError('Close all SQLite users before replacing the database.');
    }
  }

  final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[^0-9TZ]'),
    '',
  );
  final backupDirectory = Directory(p.join(p.dirname(activePath), 'backups'));
  await backupDirectory.create(recursive: true);
  final backupPath = p.join(
    backupDirectory.path,
    'furnexa-pre-synthetic-$timestamp.db',
  );
  await source.copy(backupPath);
  final sourceHash = await _hash(source);
  final backupHash = await _hash(File(backupPath));
  if (sourceHash != backupHash) {
    throw StateError('Database backup verification failed.');
  }

  final stagingPath = p.join(
    p.dirname(activePath),
    'furnexa-synthetic-$timestamp.db',
  );
  final stagingFile = File(stagingPath);
  if (await stagingFile.exists()) {
    throw StateError('Staging database already exists: $stagingPath');
  }
  FurnexaDatabase.setLocalDevelopmentDatabasePath(stagingPath);
  await database.database;

  final security = SecurityLocalDataSource();
  final password = _temporaryPassword();
  await security.setupInitialAdmin(
    username: 'furnexa-synthetic-staging-admin',
    displayName: 'Synthetic staging administrator',
    password: password,
  );
  await security.login('furnexa-synthetic-staging-admin', password);
  final summary = await DemoDataSeeder(security: security).seed();
  final generated = await database.database;
  final deliveryCounts = await generated.rawQuery('''
    SELECT COUNT(*) AS deliveryCount,
           COUNT(DISTINCT deliveryDate) AS distinctDates,
           COUNT(*) * 4 AS expectedHistoryLines
    FROM sales_deliveries
    WHERE operationId LIKE 'DEMO-HISTORY-DELIVERY-%'
      AND status = 'DELIVERED' AND inventoryPosted = 1
  ''');
  final historyCount = (deliveryCounts.single['deliveryCount'] as num).toInt();
  final distinctDates = (deliveryCounts.single['distinctDates'] as num).toInt();
  final historyLines = await generated.rawQuery('''
    SELECT COUNT(*) AS n FROM sales_delivery_items sdi
    JOIN sales_deliveries sd ON sd.id = sdi.salesDeliveryId
    WHERE sd.operationId LIKE 'DEMO-HISTORY-DELIVERY-%'
      AND sd.status = 'DELIVERED' AND sd.inventoryPosted = 1
  ''');
  if (historyCount != 365 ||
      distinctDates != 365 ||
      (historyLines.single['n'] as num).toInt() != 1460) {
    throw StateError('Synthetic daily delivery history is incomplete.');
  }
  if ((await generated.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
    throw StateError('Synthetic staging database has foreign-key violations.');
  }
  await database.close();
  security.logout();

  final staging = await databaseFactoryFfi.openDatabase(
    stagingPath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  try {
    await staging.execute('ATTACH DATABASE ? AS preserved', [activePath]);
    final oldAdminRows = await staging.rawQuery('''
      SELECT u.* FROM preserved.users u
      JOIN preserved.roles r ON r.id = u.roleId
      WHERE r.isSystemRole = 1
      ORDER BY u.createdAt ASC LIMIT 1
    ''');
    final stagedAdminRows = await staging.query(
      'users',
      where: 'username = ?',
      whereArgs: ['furnexa-synthetic-staging-admin'],
      limit: 1,
    );
    if (oldAdminRows.isEmpty || stagedAdminRows.isEmpty) {
      throw StateError('Could not preserve the existing system administrator.');
    }
    final oldAdmin = oldAdminRows.single;
    final stagedAdminId = stagedAdminRows.single['id'] as String;
    await staging.transaction((txn) async {
      await txn.execute('''
        INSERT INTO roles SELECT * FROM preserved.roles WHERE 1
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          description = excluded.description,
          active = excluded.active,
          isSystemRole = excluded.isSystemRole,
          updatedAt = excluded.updatedAt
      ''');
      await txn.execute('''
        INSERT INTO permissions SELECT * FROM preserved.permissions WHERE 1
        ON CONFLICT(id) DO UPDATE SET
          code = excluded.code,
          module = excluded.module,
          action = excluded.action,
          description = excluded.description
      ''');
      await txn.delete('role_permissions');
      await txn.execute(
        'INSERT OR IGNORE INTO role_permissions SELECT * FROM preserved.role_permissions',
      );
      await txn.update(
        'users',
        {
          'username': oldAdmin['username'],
          'displayName': oldAdmin['displayName'],
          'phone': oldAdmin['phone'],
          'email': oldAdmin['email'],
          'passwordHash': oldAdmin['passwordHash'],
          'roleId': oldAdmin['roleId'],
          'active': oldAdmin['active'],
          'createdAt': oldAdmin['createdAt'],
          'updatedAt': oldAdmin['updatedAt'],
          'lastLoginAt': oldAdmin['lastLoginAt'],
        },
        where: 'id = ?',
        whereArgs: [stagedAdminId],
      );
      await txn.execute(
        '''
        INSERT OR IGNORE INTO users
        SELECT * FROM preserved.users WHERE id != ?
      ''',
        [oldAdmin['id']],
      );
      await txn.delete('user_scopes');
      final oldScopes = await txn.rawQuery(
        'SELECT * FROM preserved.user_scopes',
      );
      for (final scope in oldScopes) {
        final values = Map<String, Object?>.from(scope)
          ..['userId'] = scope['userId'] == oldAdmin['id']
              ? stagedAdminId
              : scope['userId'];
        await txn.insert(
          'user_scopes',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.execute(
        'UPDATE app_setup_state SET completed = 1 WHERE id = 1',
      );
    });
    final violations = await staging.rawQuery('PRAGMA foreign_key_check');
    if (violations.isNotEmpty) {
      throw StateError(
        'Authentication preservation caused foreign-key violations.',
      );
    }
    await staging.execute('DETACH DATABASE preserved');
  } finally {
    await staging.close();
  }

  final displacedPath = '$activePath.pre-synthetic-$timestamp';
  await source.rename(displacedPath);
  try {
    await stagingFile.rename(activePath);
  } catch (_) {
    await File(displacedPath).rename(activePath);
    rethrow;
  }

  final installed = await databaseFactoryFfi.openDatabase(
    activePath,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );
  try {
    final counts = <String, int>{};
    for (final table in const [
      'factories',
      'products',
      'product_variants',
      'warehouses',
      'customers',
      'sales_orders',
      'sales_deliveries',
      'sales_delivery_items',
      'users',
    ]) {
      final result = await installed.rawQuery(
        'SELECT COUNT(*) AS n FROM "$table"',
      );
      counts[table] = (result.single['n'] as num).toInt();
    }
    stdout.writeln('Developer database replaced and verified.');
    stdout.writeln('Database: $activePath');
    stdout.writeln('Backup: $backupPath');
    stdout.writeln('Backup SHA-256: $backupHash');
    stdout.writeln('Superseded database: $displacedPath');
    stdout.writeln('Synthetic seed path: ${summary.databasePath}');
    stdout.writeln('Synthetic counts: $counts');
    stdout.writeln('Posted historical deliveries: $historyCount');
    stdout.writeln('Distinct historical dates: $distinctDates');
    stdout.writeln(
      'Historical delivery lines: ${(historyLines.single['n'] as num).toInt()}',
    );
  } finally {
    await installed.close();
  }
}

String _temporaryPassword() {
  const alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
  final random = Random.secure();
  return List.generate(
    32,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

Future<String> _hash(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
