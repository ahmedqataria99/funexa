import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/backup_restore/domain/entities/backup_restore_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class BackupRestoreLocalDataSource {
  BackupRestoreLocalDataSource({SecurityLocalDataSource? security})
    : security = security ?? SecurityLocalDataSource();

  final SecurityLocalDataSource security;
  static const int _backupFormatVersion = 1;

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<BackupMetadata> createBackup({required String destination}) async {
    security.require('BACKUP_CREATE');

    final db = await _db;
    final backupId = _uniqueId('backup');
    final createdAt = DateTime.now().toUtc();
    final databaseVersion = await FurnexaDatabase.instance.getDatabaseVersion();
    late String factoryName;
    late String factoryCode;
    late List<Map<String, dynamic>> tableRows;
    await db.transaction((txn) async {
      final factory = await txn.query('factories', limit: 1);
      factoryName = factory.isNotEmpty
          ? (factory.first['name'] as String?) ?? 'Unknown'
          : 'Unknown';
      factoryCode = factory.isNotEmpty
          ? (factory.first['code'] as String?) ?? ''
          : '';
      tableRows = <Map<String, dynamic>>[];
      final tables = await _tableNamesFromTxn(txn);
      for (final table in tables) {
        final rows = await txn.query(table);
        if (rows.isNotEmpty) tableRows.add({'table': table, 'rows': rows});
      }
    });

    final payload = <String, dynamic>{
      'backupId': backupId,
      'createdAt': createdAt.toIso8601String(),
      'appVersion': AppConstants.appName,
      'databaseVersion': databaseVersion,
      'factoryName': factoryName,
      'factoryCode': factoryCode,
      'recordCount': tableRows.fold<int>(
        0,
        (sum, item) => sum + (item['rows'] as List).length,
      ),
      'backupFormatVersion': _backupFormatVersion,
      'fileName': p.basename(destination),
      'location': p.dirname(destination),
      'database': {'tables': tableRows},
    };

    final canonical = jsonEncode(payload);
    final checksum = sha256.convert(utf8.encode(canonical)).toString();
    final fullPayload = <String, dynamic>{...payload, 'checksum': checksum};
    final file = File(destination);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(fullPayload));

    final metadata = BackupMetadata(
      backupId: backupId,
      createdAt: createdAt,
      appVersion: AppConstants.appName,
      databaseVersion: databaseVersion,
      factoryName: factoryName,
      factoryCode: factoryCode,
      recordCount: fullPayload['recordCount'] as int,
      checksum: checksum,
      backupFormatVersion: _backupFormatVersion,
      fileName: p.basename(destination),
      location: p.dirname(destination),
      database: {'tables': tableRows},
    );

    await _recordHistory(
      metadata,
      status: 'VALID',
      sizeBytes: await file.length(),
    );
    await security.audit(
      action: 'BACKUP_CREATED',
      module: 'BackupRestore',
      entityType: 'Backup',
      entityId: backupId,
      description: 'Backup created: ${p.basename(destination)}',
    );
    return metadata;
  }

  Future<BackupMetadata> validateBackupFile(String path) async {
    if (!security.can('BACKUP_VIEW') && !security.can('BACKUP_RESTORE')) {
      security.require('BACKUP_VIEW');
    }
    final file = File(path);
    if (!file.existsSync()) throw Exception('Backup file not found');
    if (!path.toLowerCase().endsWith('.furnexa'))
      throw Exception('Invalid backup extension');

    final source = await file.readAsString();
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid backup file format');
    }

    final backupId = decoded['backupId']?.toString() ?? '';
    final formatVersion =
        int.tryParse('${decoded['backupFormatVersion'] ?? 0}') ?? 0;
    final databaseVersion =
        int.tryParse('${decoded['databaseVersion'] ?? 0}') ?? 0;
    final recordCount = int.tryParse('${decoded['recordCount'] ?? 0}') ?? 0;
    final checksum = decoded['checksum']?.toString() ?? '';
    final factoryName = decoded['factoryName']?.toString() ?? '';
    final factoryCode = decoded['factoryCode']?.toString() ?? '';
    final database = decoded['database'];

    if (backupId.isEmpty)
      throw Exception('Backup metadata is missing backupId');
    if (formatVersion != _backupFormatVersion)
      throw Exception('Unsupported backup format version');
    if (databaseVersion <= 0)
      throw Exception('Invalid database version in backup');
    if (database is! Map || database['tables'] is! List)
      throw Exception('Backup database payload is invalid');
    if (factoryName.isEmpty && factoryCode.isEmpty)
      throw Exception('Backup metadata is missing factory information');
    if (recordCount < 0) throw Exception('Invalid record count in backup');
    if (checksum.isEmpty) throw Exception('Missing backup checksum');

    final sanitized = Map<String, dynamic>.from(decoded);
    sanitized.remove('checksum');
    final computed = sha256
        .convert(utf8.encode(jsonEncode(sanitized)))
        .toString();
    if (computed != checksum)
      throw Exception('Backup checksum validation failed');

    final currentVersion = await FurnexaDatabase.instance.getDatabaseVersion();
    if (databaseVersion > currentVersion) {
      throw Exception(
        'Backup database version is newer than the application can restore',
      );
    }

    final allowedTables = (await _tableNames()).toSet();
    final seenTables = <String>{};
    for (final entry in database['tables'] as List) {
      if (entry is! Map ||
          entry['table'] is! String ||
          entry['rows'] is! List) {
        throw Exception('Backup table payload is invalid');
      }
      final table = entry['table'] as String;
      if (!allowedTables.contains(table)) {
        throw Exception('Backup contains an unsupported table');
      }
      if (!seenTables.add(table)) throw Exception('Duplicate backup table');
      for (final row in entry['rows'] as List) {
        if (row is! Map || row.isEmpty) {
          throw Exception('Backup contains an invalid record');
        }
      }
    }
    const requiredTables = ['factories', 'users', 'roles', 'permissions'];
    if (!seenTables.containsAll(requiredTables)) {
      throw Exception('Backup is missing required tables');
    }

    return BackupMetadata.fromJson(decoded);
  }

  Future<void> restoreBackup(String path) async {
    security.require('BACKUP_RESTORE');
    final validated = await validateBackupFile(path);
    final currentVersion = await FurnexaDatabase.instance.getDatabaseVersion();
    if (validated.databaseVersion > currentVersion) {
      throw Exception('Cannot restore a newer database version');
    }

    final safetyPath = await _createSafetyBackup();
    await security.audit(
      action: 'BACKUP_RESTORE_STARTED',
      module: 'BackupRestore',
      entityType: 'Backup',
      entityId: validated.backupId,
      description: 'Restore began for ${p.basename(path)}',
    );

    try {
      final backupJson =
          jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
      final database = backupJson['database'];
      if (database is! Map || database['tables'] is! List) {
        throw Exception('Backup payload is missing database tables');
      }

      final db = await _db;
      await db.execute('PRAGMA foreign_keys = OFF');
      try {
        await db.transaction((txn) async {
          final tables = await _tableNamesFromTxn(txn);
          for (final table in tables) {
            if (table == 'audit_logs') continue;
            await txn.delete(table);
          }
          for (final entry in database['tables'] as List) {
            final row = Map<String, dynamic>.from(entry as Map);
            final table = row['table']?.toString();
            final rows = row['rows'];
            if (table == null || rows is! List || table == 'audit_logs')
              continue;
            for (final item in rows) {
              final map = Map<String, dynamic>.from(item as Map);
              await txn.insert(
                table,
                map,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        });
      } finally {
        await db.execute('PRAGMA foreign_keys = ON');
      }

      await _verifyRestoredDatabase();
      await _recordHistory(
        validated,
        status: 'RESTORED',
        sizeBytes: await File(path).length(),
      );
      await security.audit(
        action: 'BACKUP_RESTORED',
        module: 'BackupRestore',
        entityType: 'Backup',
        entityId: validated.backupId,
        description: 'Backup restored successfully',
      );
      await FurnexaDatabase.instance.close();
      security.logout();

      if (safetyPath.isNotEmpty) {
        try {
          final safetyFile = File(safetyPath);
          if (safetyFile.existsSync()) {
            await safetyFile.delete();
          }
        } catch (_) {}
      }
    } catch (error) {
      final failure = error.toString();
      final safetyFile = File(safetyPath);
      if (safetyFile.existsSync()) {
        await FurnexaDatabase.instance.close();
        final target = File(await _databasePath());
        if (target.existsSync()) {
          await target.delete();
        }
        await safetyFile.copy(target.path);
      }
      await security.audit(
        action: 'BACKUP_RESTORE_FAILED',
        module: 'BackupRestore',
        entityType: 'Backup',
        entityId: validated.backupId,
        description: failure,
      );
      throw Exception('Restore failed: $failure');
    }
  }

  Future<List<BackupHistoryEntry>> getHistory() async {
    security.require('BACKUP_VIEW');
    final db = await _db;
    final rows = await db.query(
      'audit_logs',
      where: 'module = ?',
      whereArgs: ['BackupRestore'],
      orderBy: 'timestamp DESC',
    );
    final entries = <BackupHistoryEntry>[];
    for (final row in rows) {
      final action = row['action']?.toString() ?? '';
      final description = row['description']?.toString() ?? '';
      if (action == 'BACKUP_CREATED' ||
          action == 'BACKUP_RESTORED' ||
          action == 'BACKUP_RESTORE_FAILED') {
        entries.add(
          BackupHistoryEntry(
            id: row['id'] as String,
            backupId: row['entityId']?.toString() ?? '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['timestamp'] as int,
            ),
            factoryName: '',
            factoryCode: '',
            databaseVersion: await FurnexaDatabase.instance
                .getDatabaseVersion(),
            fileName: description
                .replaceFirst('Backup created: ', '')
                .replaceFirst('Backup restored: ', ''),
            sizeBytes: 0,
            status: action == 'BACKUP_CREATED'
                ? 'VALID'
                : action == 'BACKUP_RESTORED'
                ? 'RESTORED'
                : 'FAILED',
            checksum: '',
            filePath: description,
          ),
        );
      }
    }
    return entries;
  }

  Future<String> createSafetyBackup() async {
    security.require('BACKUP_CREATE');
    return _createSafetyBackup();
  }

  Future<String> _createSafetyBackup() async {
    final dbPath = await _databasePath();
    final file = File(
      p.join(
        Directory.systemTemp.path,
        'furnexa_safety_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );
    final source = File(dbPath);
    if (source.existsSync()) {
      await FurnexaDatabase.instance.close();
      await file.parent.create(recursive: true);
      await source.copy(file.path);
    }
    return file.path;
  }

  Future<List<String>> _tableNames() async {
    final db = await _db;
    return _tableNamesFromTxn(db);
  }

  Future<List<String>> _tableNamesFromTxn(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT IN ('android_metadata', 'sqlite_sequence') ORDER BY name",
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<String> _databasePath() async {
    return FurnexaDatabase.instance.databasePath;
  }

  Future<void> _recordHistory(
    BackupMetadata metadata, {
    required String status,
    required int sizeBytes,
  }) async {
    final db = await _db;
    await db.insert('audit_logs', {
      'id': _uniqueId('audit_backup'),
      'userId': security.session?.user.id,
      'usernameSnapshot': security.session?.user.username ?? 'SYSTEM',
      'action': status == 'VALID'
          ? 'BACKUP_CREATED'
          : status == 'RESTORED'
          ? 'BACKUP_RESTORED'
          : 'BACKUP_RESTORE_FAILED',
      'module': 'BackupRestore',
      'entityType': 'Backup',
      'entityId': metadata.backupId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'description': status == 'VALID'
          ? 'Backup created: ${metadata.fileName}'
          : 'Backup restored: ${metadata.fileName}',
    });
  }

  Future<void> _verifyRestoredDatabase() async {
    final db = await _db;
    final required = [
      'factories',
      'users',
      'roles',
      'permissions',
      'audit_logs',
      'stock_balances',
      'journal_entries',
      'production_orders',
      'sales_orders',
      'purchase_orders',
    ];
    for (final table in required) {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [table],
      );
      if (rows.isEmpty) {
        throw Exception('Missing required table: $table');
      }
    }
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.single.values.single != 'ok') {
      throw Exception('Restored database integrity check failed');
    }
    final foreignKeyViolations = await db.rawQuery('PRAGMA foreign_key_check');
    if (foreignKeyViolations.isNotEmpty) {
      throw Exception('Restored database has foreign-key violations');
    }
    await db.execute('PRAGMA foreign_keys = ON');
  }

  String _uniqueId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
