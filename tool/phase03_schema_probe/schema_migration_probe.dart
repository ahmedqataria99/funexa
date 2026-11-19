import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';

const targetVersion = 41;
const requiredTriggers = <String>{
  'prevent_audit_update',
  'prevent_audit_delete',
  'trg_purchase_requests_supplier_insert',
  'trg_purchase_requests_supplier_update',
};

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Pass the existing schema SQL path for migration comments.');
  }

  final existingSql = File(args.single);
  if (!await existingSql.exists()) {
    throw ArgumentError('Existing schema SQL not found: ${existingSql.path}');
  }

  final probeDirectory = Directory.fromUri(Platform.script.resolve('.'));
  final runDirectory = Directory(
    p.join(
      probeDirectory.path,
      'run-${DateTime.now().toUtc().microsecondsSinceEpoch}',
    ),
  );
  await runDirectory.create(recursive: true);

  final migratedPath = p.join(runDirectory.path, 'migrated_from_zero.db');
  final candidatePath = p.join(runDirectory.path, 'schema_only_candidate.db');
  final schemaPath = p.join(runDirectory.path, 'candidate_schema.sql');
  final metadataPath = p.join(runDirectory.path, 'schema_metadata.json');

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Database? migrated;
  Database? schemaOnly;
  try {
    migrated = await databaseFactoryFfi.openDatabase(
      migratedPath,
      options: OpenDatabaseOptions(
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );

    final before = await _pragmaInt(migrated, 'user_version');
    if (before != 0) {
      throw StateError('Expected an empty version-0 database; got $before.');
    }
    await FurnexaDatabase.instance.migrate(migrated, 0, targetVersion);
    final migratedVersion = await _pragmaInt(migrated, 'user_version');
    if (migratedVersion != targetVersion) {
      throw StateError(
        'Migration ended at user_version=$migratedVersion, expected $targetVersion.',
      );
    }

    final migratedObjects = await _schemaObjects(migrated);
    final triggerNames = migratedObjects
        .where((object) => object['type'] == 'trigger')
        .map((object) => object['name'] as String)
        .toSet();
    final missingTriggers = requiredTriggers.difference(triggerNames);
    if (missingTriggers.isNotEmpty) {
      throw StateError('Migration omitted required triggers: $missingTriggers');
    }

    final migrationCommentMap = await _tableMigrationComments(existingSql);
    final sql = _schemaSql(migratedObjects, migrationCommentMap);
    await File(schemaPath).writeAsString(sql, flush: true);

    schemaOnly = await databaseFactoryFfi.openDatabase(
      candidatePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    for (final object in migratedObjects) {
      await schemaOnly.execute('${object['sql']};');
    }
    await schemaOnly.execute('PRAGMA user_version = $targetVersion');

    final candidateObjects = await _schemaObjects(schemaOnly);
    _assertSameSchemaObjects(migratedObjects, candidateObjects);
    final metadata = await _validateDatabase(
      schemaOnly,
      expectedObjects: migratedObjects,
      requiredTriggers: requiredTriggers,
    );
    await File(metadataPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata),
      flush: true,
    );

    stdout.writeln(jsonEncode({
      'migrationFrom': 0,
      'migrationTo': migratedVersion,
      'tables': metadata['tables'],
      'explicitIndexes': metadata['explicitIndexes'],
      'triggers': metadata['triggers'],
      'views': metadata['views'],
      'rowsInSchemaOnlyDatabase': metadata['totalRows'],
      'foreignKeyViolations': metadata['foreignKeyViolations'],
      'integrityCheck': metadata['integrityCheck'],
      'candidateSchema': schemaPath,
      'candidateDatabase': candidatePath,
      'metadata': metadataPath,
      'requiredTriggersValidated': requiredTriggers.toList()..sort(),
    }));
  } finally {
    await schemaOnly?.close();
    await migrated?.close();
  }
}

Future<int> _pragmaInt(DatabaseExecutor db, String pragma) async {
  final rows = await db.rawQuery('PRAGMA $pragma');
  if (rows.isEmpty) {
    throw StateError('PRAGMA $pragma returned no rows.');
  }
  return (rows.first.values.first as num).toInt();
}

Future<List<Map<String, Object?>>> _schemaObjects(DatabaseExecutor db) async {
  final rows = await db.rawQuery('''
    SELECT type, name, tbl_name, sql
    FROM sqlite_master
    WHERE type IN ('table', 'index', 'view', 'trigger')
      AND name NOT LIKE 'sqlite_%'
      AND sql IS NOT NULL
    ORDER BY CASE type
      WHEN 'table' THEN 0
      WHEN 'index' THEN 1
      WHEN 'view' THEN 2
      WHEN 'trigger' THEN 3
      ELSE 4
    END, name
  ''');
  return rows;
}

Future<Map<String, String>> _tableMigrationComments(File source) async {
  final contents = await source.readAsString();
  final result = <String, String>{};
  final pattern = RegExp(
    r'-- table: ([^\r\n]+)\r?\n-- Source migration: version (\d+)',
  );
  for (final match in pattern.allMatches(contents)) {
    result[match.group(1)!.trim()] = match.group(2)!;
  }
  return result;
}

String _schemaSql(
  List<Map<String, Object?>> objects,
  Map<String, String> tableMigrations,
) {
  final output = StringBuffer()
    ..writeln('-- Extracted from sqlite_master after Furnexa migrations 1-41.')
    ..writeln('-- Source: FurnexaDatabase.migrate on a disposable version-0 database.')
    ..writeln('-- This schema contains no business records.')
    ..writeln('PRAGMA foreign_keys = ON;')
    ..writeln('PRAGMA user_version = $targetVersion;')
    ..writeln();

  for (final object in objects) {
    final type = object['type'] as String;
    final name = object['name'] as String;
    if (type == 'table' && tableMigrations.containsKey(name)) {
      output
        ..writeln('-- table: $name')
        ..writeln('-- Source migration: version ${tableMigrations[name]}');
    } else {
      output.writeln('-- $type: $name (extracted after migrations 1-41)');
    }
    output
      ..writeln(object['sql'] as String)
      ..writeln(';')
      ..writeln();
  }
  return output.toString();
}

void _assertSameSchemaObjects(
  List<Map<String, Object?>> source,
  List<Map<String, Object?>> candidate,
) {
  String key(Map<String, Object?> object) =>
      '${object['type']}\u0000${object['name']}';
  final sourceByKey = {for (final object in source) key(object): object};
  final candidateByKey = {for (final object in candidate) key(object): object};
  if (sourceByKey.keys.toSet().difference(candidateByKey.keys.toSet()).isNotEmpty ||
      candidateByKey.keys.toSet().difference(sourceByKey.keys.toSet()).isNotEmpty) {
    throw StateError('Schema-only candidate object inventory differs from migration output.');
  }
  for (final entry in sourceByKey.entries) {
    if ((entry.value['sql'] as String).trim() !=
        (candidateByKey[entry.key]!['sql'] as String).trim()) {
      throw StateError('Schema SQL differs for ${entry.value['name']}.');
    }
  }
}

Future<Map<String, Object?>> _validateDatabase(
  Database db, {
  required List<Map<String, Object?>> expectedObjects,
  required Set<String> requiredTriggers,
}) async {
  final tables = expectedObjects
      .where((object) => object['type'] == 'table')
      .map((object) => object['name'] as String)
      .toList()
    ..sort();
  final indexes = expectedObjects
      .where((object) => object['type'] == 'index')
      .map((object) => object['name'] as String)
      .toList()
    ..sort();
  final triggers = expectedObjects
      .where((object) => object['type'] == 'trigger')
      .map((object) => object['name'] as String)
      .toList()
    ..sort();
  final views = expectedObjects
      .where((object) => object['type'] == 'view')
      .map((object) => object['name'] as String)
      .toList()
    ..sort();

  final version = await _pragmaInt(db, 'user_version');
  if (version != targetVersion) {
    throw StateError('Schema-only database user_version is $version, not $targetVersion.');
  }
  final foreignKeysEnabled = await _pragmaInt(db, 'foreign_keys');
  if (foreignKeysEnabled != 1) {
    throw StateError('Foreign-key enforcement is disabled on the schema-only database.');
  }

  final tableInfo = <String, List<Map<String, Object?>>>{};
  final foreignKeyInfo = <String, List<Map<String, Object?>>>{};
  final indexInfo = <String, List<Map<String, Object?>>>{};
  var totalRows = 0;
  for (final table in tables) {
    final quotedTable = _quoteIdentifier(table);
    final columns = await db.rawQuery('PRAGMA table_info($quotedTable)');
    final foreignKeys = await db.rawQuery('PRAGMA foreign_key_list($quotedTable)');
    final tableIndexes = await db.rawQuery('PRAGMA index_list($quotedTable)');
    final rowCount = await db.rawQuery(
      'SELECT COUNT(*) AS row_count FROM $quotedTable',
    );
    final count = (rowCount.single['row_count'] as num).toInt();
    if (count != 0) {
      throw StateError('Schema-only table $table contains $count rows.');
    }
    totalRows += count;
    tableInfo[table] = columns;
    foreignKeyInfo[table] = foreignKeys;
    indexInfo[table] = tableIndexes;
  }

  final tableList = await db.rawQuery('PRAGMA table_list');
  final userTableList = tableList
      .where((row) => row['schema'] == 'main' && !(row['name'] as String).startsWith('sqlite_'))
      .toList();
  if (userTableList.length != tables.length) {
    throw StateError('PRAGMA table_list did not match the extracted table inventory.');
  }

  final foreignKeyViolations = await db.rawQuery('PRAGMA foreign_key_check');
  if (foreignKeyViolations.isNotEmpty) {
    throw StateError('Schema-only database has foreign-key violations: $foreignKeyViolations');
  }
  final integrityRows = await db.rawQuery('PRAGMA integrity_check');
  final integrityCheck = integrityRows.map((row) => row.values.first.toString()).join(', ');
  if (integrityCheck != 'ok') {
    throw StateError('SQLite integrity_check failed: $integrityCheck');
  }
  final missingTriggers = requiredTriggers.difference(triggers.toSet());
  if (missingTriggers.isNotEmpty) {
    throw StateError('Schema-only database is missing triggers: $missingTriggers');
  }

  return {
    'userVersion': version,
    'tables': tables,
    'explicitIndexes': indexes,
    'triggers': triggers,
    'views': views,
    'tableList': userTableList,
    'tableInfo': tableInfo,
    'foreignKeyInfo': foreignKeyInfo,
    'indexInfo': indexInfo,
    'foreignKeyViolations': foreignKeyViolations,
    'integrityCheck': integrityCheck,
    'totalRows': totalRows,
  };
}

String _quoteIdentifier(String value) => '"${value.replaceAll('"', '""')}"';