import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/import_export/domain/entities/import_export_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class ImportExportLocalDataSource {
  ImportExportLocalDataSource({SecurityLocalDataSource? security})
    : security = security ?? SecurityLocalDataSource();

  final SecurityLocalDataSource security;

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  void _requireAccess() {
    security.require('SYSTEM_ADMIN');
  }

  Future<ImportExportExport> exportData({required String module}) async {
    _requireAccess();
    final db = await _db;
    final tableNames = _tableNamesForModule(module);
    final rows = <Map<String, dynamic>>[];
    for (final table in tableNames) {
      final data = await db.query(table);
      if (data.isNotEmpty) {
        rows.addAll(data);
      }
    }
    final payload = jsonEncode({
      'module': module,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'records': rows,
    });

    await db.insert('audit_logs', {
      'id': _id('audit'),
      'userId': security.session?.user.id,
      'usernameSnapshot': security.session?.user.username ?? 'SYSTEM',
      'action': 'EXPORT',
      'module': module,
      'entityType': 'ImportExport',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'description': 'Exported $module data',
    });

    return ImportExportExport(
      module: module,
      payload: payload,
      records: rows.length,
      exportedAt: DateTime.now(),
    );
  }

  Future<ImportExportImportSummary> importData(String payload) async {
    _requireAccess();
    final json = jsonDecode(payload) as Map<String, dynamic>;
    final module = (json['module'] ?? '').toString().toLowerCase();
    final allowedTable = switch (module) {
      'products' => 'products',
      'raw_materials' => 'raw_materials',
      _ => null,
    };
    if (allowedTable == null) {
      throw Exception('Unsupported import module');
    }
    final records = (json['records'] as List?) ?? const [];
    if (module.isEmpty) {
      throw Exception('Module is required');
    }
    if (records.isEmpty) {
      throw Exception('No records to import');
    }

    final db = await _db;
    final created = <String>[];
    final updated = <String>[];
    final tableRows = records.cast<Map<String, dynamic>>();

    await db.transaction((txn) async {
      for (final item in tableRows) {
        final table = (item['table'] ?? '').toString();
        if (table != allowedTable) {
          throw Exception('Import table is not allowed for this module');
        }
        final rows = item['rows'];
        if (rows is! List) {
          throw Exception('Import row data is invalid');
        }
        for (final row in rows) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = (map['id'] ?? '').toString();
          if (id.isEmpty) {
            throw Exception('Import row is missing an id');
          }
          final existing = await txn.query(
            table,
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          final validated = _validateRecord(table, map);
          await _validateReferences(txn, table, validated);
          if (existing.isEmpty) {
            await txn.insert(table, validated);
            created.add(id);
          } else {
            await txn.update(
              table,
              validated,
              where: 'id = ?',
              whereArgs: [id],
            );
            updated.add(id);
          }
        }
      }
    });

    await db.insert('audit_logs', {
      'id': _id('audit'),
      'userId': security.session?.user.id,
      'usernameSnapshot': security.session?.user.username ?? 'SYSTEM',
      'action': 'IMPORT',
      'module': module,
      'entityType': 'ImportExport',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'description': 'Imported $module data',
    });

    return ImportExportImportSummary(
      module: module,
      recordsCreated: created.length,
      recordsUpdated: updated.length,
      importedAt: DateTime.now(),
    );
  }

  Future<List<ImportExportHistoryEntry>> history({String? module}) async {
    final db = await _db;
    final where = module == null || module.isEmpty ? null : 'module = ?';
    final args = module == null || module.isEmpty ? null : [module];
    final rows = await db.query(
      'audit_logs',
      where: where,
      whereArgs: args,
      orderBy: 'timestamp DESC',
      limit: 50,
    );
    return rows.map(ImportExportHistoryEntry.fromMap).where((entry) {
      return entry.type == 'EXPORT' || entry.type == 'IMPORT';
    }).toList();
  }

  Map<String, dynamic> _validateRecord(String table, Map<String, dynamic> map) {
    final cleaned = <String, dynamic>{};
    for (final entry in map.entries) {
      if (entry.key == 'id') {
        cleaned[entry.key] = entry.value;
        continue;
      }
      cleaned[entry.key] = entry.value;
    }

    switch (table) {
      case 'products':
        if ((cleaned['name'] ?? '').toString().trim().isEmpty) {
          throw Exception('Product name is required');
        }
        if ((cleaned['code'] ?? '').toString().trim().isEmpty) {
          throw Exception('Product code is required');
        }
        if ((cleaned['categoryId'] ?? '').toString().trim().isEmpty) {
          throw Exception('Category is required');
        }
        if ((cleaned['unitId'] ?? '').toString().trim().isEmpty) {
          throw Exception('Unit is required');
        }
        break;
      case 'raw_materials':
        if ((cleaned['name'] ?? '').toString().trim().isEmpty) {
          throw Exception('Raw material name is required');
        }
        if ((cleaned['code'] ?? '').toString().trim().isEmpty) {
          throw Exception('Raw material code is required');
        }
        break;
      default:
        break;
    }
    return cleaned;
  }

  Future<void> _validateReferences(
    DatabaseExecutor txn,
    String table,
    Map<String, dynamic> record,
  ) async {
    if (table == 'products') {
      for (final key in ['categoryId', 'unitId']) {
        final reference = record[key]?.toString() ?? '';
        final target = key == 'categoryId' ? 'categories' : 'units';
        if (reference.isEmpty ||
            (await txn.query(
              target,
              columns: ['id'],
              where: 'id = ? AND active = 1',
              whereArgs: [reference],
              limit: 1,
            )).isEmpty) {
          throw Exception('Product reference is missing or inactive');
        }
      }
    }
    if (table == 'raw_materials') {
      final unitId = record['unitId']?.toString();
      if (unitId != null &&
          unitId.isNotEmpty &&
          (await txn.query(
            'units',
            columns: ['id'],
            where: 'id = ? AND active = 1',
            whereArgs: [unitId],
            limit: 1,
          )).isEmpty) {
        throw Exception('Raw material unit is missing or inactive');
      }
    }
  }

  List<String> _tableNamesForModule(String module) {
    switch (module.toLowerCase()) {
      case 'products':
        return ['products'];
      case 'raw_materials':
        return ['raw_materials'];
      case 'warehouse_stock':
      case 'warehouses_stock':
        return ['stock_balances', 'stock_transactions'];
      default:
        return ['products', 'raw_materials'];
    }
  }

  String _id(String prefix) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_$stamp';
  }
}
