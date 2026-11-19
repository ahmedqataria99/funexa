import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'demo_data_seeder.dart';

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } catch (error) {
    stderr.writeln('Demo seed aborted: $error');
    exitCode = 1;
  }
}

Future<void> _run(List<String> args) async {
  if (!Platform.isWindows) {
    throw UnsupportedError('This seeder is intended for Windows development.');
  }
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln('Usage: dart run tool/seed_demo_data.dart');
    stdout.writeln(
      'Seeds the separate %LOCALAPPDATA%\\Furnexa\\demo\\furnexa-demo.db database.',
    );
    return;
  }

  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData == null || localAppData.trim().isEmpty) {
    throw StateError('LOCALAPPDATA is not available.');
  }
  final database = FurnexaDatabase.instance;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final activeDatabasePath = await database.databasePath;
  final demoDatabasePath = p.normalize(
    p.join(localAppData, 'Furnexa', 'demo', 'furnexa-demo.db'),
  );
  if (_samePath(activeDatabasePath, demoDatabasePath)) {
    throw StateError(
      'The demo path must not be the active production database.',
    );
  }

  final runningApp = await Process.run('tasklist.exe', [
    '/FI',
    'IMAGENAME eq furnexa.exe',
    '/FO',
    'CSV',
    '/NH',
  ]);
  if (runningApp.exitCode != 0) {
    throw StateError('Could not verify whether Furnexa is running.');
  }
  if (runningApp.stdout.toString().toLowerCase().contains('"furnexa.exe"')) {
    throw StateError('Close Furnexa before seeding demo data.');
  }

  final demoFile = File(demoDatabasePath);
  if (await demoFile.exists() && !await _hasDemoMarker(demoDatabasePath)) {
    throw StateError(
      'The dedicated demo database already exists but is not marked as a Furnexa demo database. It was left unchanged.',
    );
  }

  stdout.writeln(
    'Active app database (will not be modified): $activeDatabasePath',
  );
  stdout.writeln('Dedicated demo database: $demoDatabasePath');
  stdout.writeln('Type SEED DEMO DATA $demoDatabasePath to continue:');
  final confirmation =
      Platform.environment['FURNEXA_DEMO_CONFIRMATION'] ?? stdin.readLineSync();
  if (confirmation != 'SEED DEMO DATA $demoDatabasePath') {
    stdout.writeln('Seeding cancelled.');
    return;
  }

  String? backupPath;
  if (await demoFile.exists()) {
    backupPath = await _backupDatabase(demoDatabasePath);
    stdout.writeln('Backup created: $backupPath');
  } else {
    await demoFile.parent.create(recursive: true);
    stdout.writeln('No backup needed; the dedicated demo database is new.');
  }

  FurnexaDatabase.setLocalDevelopmentDatabasePath(demoDatabasePath);
  try {
    final db = await database.database;
    final security = SecurityLocalDataSource();
    String username;
    String password;
    if (await security.initialAdminSetupRequired()) {
      stdout.write('Create the System Administrator username: ');
      username =
          Platform.environment['FURNEXA_DEMO_ADMIN_USERNAME'] ??
          _requiredInput();
      stdout.write('Administrator display name: ');
      final displayName =
          Platform.environment['FURNEXA_DEMO_ADMIN_DISPLAY_NAME'] ??
          _requiredInput();
      stdout.write('Choose the new demo database administrator password: ');
      password =
          Platform.environment['FURNEXA_DEMO_ADMIN_PASSWORD'] ??
          _requiredSecret();
      await security.setupInitialAdmin(
        username: username,
        displayName: displayName,
        password: password,
      );
    } else {
      stdout.write('System Administrator username: ');
      username =
          Platform.environment['FURNEXA_DEMO_ADMIN_USERNAME'] ??
          _requiredInput();
      stdout.write('System Administrator password: ');
      password =
          Platform.environment['FURNEXA_DEMO_ADMIN_PASSWORD'] ??
          _requiredSecret();
    }
    final session = await security.login(username, password);
    if (!session.isSystemAdmin) {
      security.logout();
      throw StateError('The demo seeder requires the System Administrator.');
    }

    final summary = await DemoDataSeeder(security: security).seed();
    final foreignKeyViolations = await db.rawQuery('PRAGMA foreign_key_check');
    if (foreignKeyViolations.isNotEmpty) {
      throw StateError(
        'Demo seed left ${foreignKeyViolations.length} foreign-key violations.',
      );
    }
    stdout.writeln('Demo data verified.');
    stdout.writeln('Database path: ${summary.databasePath}');
    stdout.writeln('Administrator username: ${session.user.username}');
    stdout.writeln('No additional demo users were created.');
    stdout.writeln(
      'The administrator password was not printed or stored by the utility.',
    );
    for (final entry in summary.counts.entries) {
      stdout.writeln('${entry.key}: ${entry.value}');
    }
    stdout.writeln('Release launcher: tool/run_demo_release.ps1');
    if (backupPath != null) stdout.writeln('Backup path: $backupPath');
    security.logout();
    await database.close();
  } catch (_) {
    await database.close();
    rethrow;
  }
}

String _requiredInput() {
  final value = stdin.readLineSync();
  if (value == null || value.trim().isEmpty) {
    throw const FormatException('A required value was not provided.');
  }
  return value.trim();
}

String _requiredSecret() {
  if (!stdin.hasTerminal) {
    throw StateError('Run the seeder in an interactive terminal.');
  }
  final echoMode = stdin.echoMode;
  try {
    stdin.echoMode = false;
    final value = stdin.readLineSync();
    if (value == null || value.isEmpty) {
      throw const FormatException('A required password was not provided.');
    }
    return value;
  } finally {
    stdin.echoMode = echoMode;
    stdout.writeln();
  }
}

Future<bool> _hasDemoMarker(String path) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );
  try {
    final manifest = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'demo_seed_manifest'",
    );
    if (manifest.isEmpty) return false;
    final marker = await db.query(
      'demo_seed_manifest',
      columns: ['seedKey'],
      where: 'seedKey = ?',
      whereArgs: ['DEMO_FURNEXA_V1'],
      limit: 1,
    );
    return marker.isNotEmpty;
  } finally {
    await db.close();
  }
}

Future<String> _backupDatabase(String path) async {
  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '')
      .replaceAll('-', '')
      .replaceAll('.', '');
  final backupDirectory = Directory(p.join(p.dirname(path), 'backups'));
  await backupDirectory.create(recursive: true);
  final backupPath = p.join(backupDirectory.path, 'furnexa-demo-$timestamp.db');
  await File(path).copy(backupPath);
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$path$suffix');
    if (await sidecar.exists()) {
      await sidecar.copy('$backupPath$suffix');
    }
  }
  return backupPath;
}

bool _samePath(String first, String second) =>
    p.normalize(p.absolute(first)).toLowerCase() ==
    p.normalize(p.absolute(second)).toLowerCase();
