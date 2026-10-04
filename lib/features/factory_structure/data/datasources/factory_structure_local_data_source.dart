import 'dart:async';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/features/factory_structure/domain/entities/factory_profile.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/section.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/factory_structure/domain/entities/workshop.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class FactoryStructureLocalDataSource {
  FactoryStructureLocalDataSource([SecurityLocalDataSource? security])
    : _security = security ?? SecurityLocalDataSource();

  final SecurityLocalDataSource _security;

  Future<Database> get database async => FurnexaDatabase.instance.database;

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('production_outputs');
    await db.delete('production_waste');
    await db.delete('production_material_consumptions');
    await db.delete('production_order_stages');
    await db.delete('production_orders');
    await db.delete('production_route_stages');
    await db.delete('production_routes');
    await db.delete('sales_delivery_items');
    await db.delete('sales_deliveries');
    await db.delete('sales_order_items');
    await db.delete('sales_orders');
    await db.delete('quotation_items');
    await db.delete('quotations');
    await db.delete('customers');
    await db.delete('purchase_receipt_items');
    await db.delete('purchase_receipts');
    await db.delete('purchase_order_items');
    await db.delete('purchase_orders');
    await db.delete('purchase_request_items');
    await db.delete('purchase_requests');
    await db.delete('suppliers');
    await db.delete('payroll_records');
    await db.delete('payroll_periods');
    await db.delete('deductions');
    await db.delete('leave_records');
    await db.delete('attendance_records');
    await db.delete('worker_assignments');
    await db.delete('workers');
    await db.delete('shifts');
    await db.delete('warehouses');
    await db.delete('production_stages');
    await db.delete('workshops');
    await db.delete('sections');
    await db.delete('factories');
  }

  Future<void> initializeSchema() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS factories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        phone TEXT,
        email TEXT,
        address TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sections (
        id TEXT PRIMARY KEY,
        factoryId TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        description TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        UNIQUE(factoryId, code),
        FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS workshops (
        id TEXT PRIMARY KEY,
        factoryId TEXT NOT NULL,
        sectionId TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        description TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        UNIQUE(sectionId, code),
        FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT,
        FOREIGN KEY (sectionId) REFERENCES sections(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_stages (
        id TEXT PRIMARY KEY,
        factoryId TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        description TEXT,
        sequence INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        UNIQUE(factoryId, code),
        FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id TEXT PRIMARY KEY,
        factoryId TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        type TEXT,
        state TEXT NOT NULL DEFAULT 'active',
        notes TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        UNIQUE(factoryId, code),
        FOREIGN KEY (factoryId) REFERENCES factories(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sections_factory_id ON sections(factoryId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workshops_section_id ON workshops(sectionId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workshops_factory_id ON workshops(factoryId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_production_stages_factory_id ON production_stages(factoryId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_warehouses_factory_id ON warehouses(factoryId)',
    );
  }

  Future<void> migrateDatabase() async {
    final db = await database;
    await db.execute('PRAGMA foreign_keys = ON');
    await initializeSchema();
  }

  Future<FactoryProfile?> getFactory() async {
    _security.require('FACTORY_VIEW');
    final db = await database;
    final maps = await db.query('factories', limit: 1);
    if (maps.isEmpty) return null;
    return FactoryProfile.fromMap(maps.first);
  }

  Future<void> upsertFactory(FactoryProfile factory) async {
    _security.require('FACTORY_EDIT');
    final db = await database;
    if (await _factoryCodeExists(factory.code, excludeId: factory.id)) {
      throw Exception('Factory code must be unique');
    }
    final existing = await db.query('factories');
    if (existing.any((row) => row['id'] != factory.id)) {
      throw Exception('لا يمكن إنشاء أكثر من ملف مصنع واحد');
    }

    final existingFactory = existing.where((row) => row['id'] == factory.id);
    final values = factory.toMap();
    if (existingFactory.isNotEmpty) {
      values['createdAt'] = existingFactory.first['createdAt'];
    }

    final updated = await db.update(
      'factories',
      values,
      where: 'id = ?',
      whereArgs: [factory.id],
    );
    if (updated == 0) {
      await db.insert('factories', values);
    }
    await _security.audit(
      action: updated == 0 ? 'CREATE' : 'UPDATE',
      module: 'Factory',
      entityType: 'Factory',
      entityId: factory.id,
      description: 'Factory profile changed',
    );
  }

  Future<bool> _factoryCodeExists(String code, {String? excludeId}) async {
    final db = await database;
    final result = await db.query(
      'factories',
      where: 'code = ? AND id != ?',
      whereArgs: [code.trim(), excludeId ?? ''],
    );
    return result.isNotEmpty;
  }

  Future<List<Section>> getSections() async {
    _security.require('FACTORY_VIEW');
    final db = await database;
    final maps = _visible(
      await db.query('sections', orderBy: 'name ASC'),
      'sections',
    );
    return maps.map(Section.fromMap).toList();
  }

  Future<List<Section>> searchSections(String query) async {
    _security.require('FACTORY_VIEW');
    final db = await database;
    final normalized = query.trim();
    if (normalized.isEmpty) return getSections();

    final maps = await db.query(
      'sections',
      where: 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: [
        '%${normalized.toLowerCase()}%',
        '%${normalized.toLowerCase()}%',
      ],
      orderBy: 'name ASC',
    );
    return _visible(maps, 'sections').map(Section.fromMap).toList();
  }

  Future<void> upsertSection(Section section) async {
    _security.require('FACTORY_EDIT');
    final db = await database;
    if ((await db.query(
      'sections',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [section.id],
      limit: 1,
    )).isNotEmpty) {
      await _security.requireResourceScope(ScopeType.section, section.id);
    }
    final existingSection = await db.query(
      'sections',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [section.id],
      limit: 1,
    );
    final duplicate = await db.query(
      'sections',
      where: 'factoryId = ? AND code = ? AND id != ?',
      whereArgs: [section.factoryId, section.code.trim(), section.id],
    );
    if (duplicate.isNotEmpty) {
      throw Exception('Section code must be unique within the factory');
    }

    await db.insert(
      'sections',
      section.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _security.audit(
      action: existingSection.isEmpty
          ? 'CREATE'
          : section.active
          ? 'UPDATE'
          : 'DEACTIVATE',
      module: 'Factory',
      entityType: 'Section',
      entityId: section.id,
      description: 'Section changed',
    );
  }

  Future<List<Workshop>> getWorkshops() async {
    _security.require('FACTORY_VIEW');
    final db = await database;
    final maps = _visible(
      await db.query('workshops', orderBy: 'name ASC'),
      'workshops',
    );
    return maps.map(Workshop.fromMap).toList();
  }

  Future<List<Workshop>> searchWorkshops(String query) async {
    _security.require('FACTORY_VIEW');
    final db = await database;
    final normalized = query.trim();
    if (normalized.isEmpty) return getWorkshops();

    final maps = await db.query(
      'workshops',
      where: 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: [
        '%${normalized.toLowerCase()}%',
        '%${normalized.toLowerCase()}%',
      ],
      orderBy: 'name ASC',
    );
    return _visible(maps, 'workshops').map(Workshop.fromMap).toList();
  }

  Future<void> upsertWorkshop(Workshop workshop) async {
    _security.require('FACTORY_EDIT');
    final db = await database;
    final section = await db.query(
      'sections',
      where: 'id = ? AND factoryId = ? AND active = 1',
      whereArgs: [workshop.sectionId, workshop.factoryId],
    );

    if (section.isEmpty) {
      throw Exception('A workshop requires an active section');
    }
    if (section.first['factoryId'] != workshop.factoryId) {
      throw Exception('الورشة يجب أن تتبع مصنع القسم');
    }
    final existingWorkshop = await db.query(
      'workshops',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [workshop.id],
      limit: 1,
    );
    if (existingWorkshop.isNotEmpty) {
      await _security.requireResourceScope(ScopeType.workshop, workshop.id);
    } else {
      await _security.requireResourceScope(
        ScopeType.section,
        workshop.sectionId,
      );
    }

    final duplicate = await db.query(
      'workshops',
      where: 'sectionId = ? AND code = ? AND id != ?',
      whereArgs: [workshop.sectionId, workshop.code.trim(), workshop.id],
    );
    if (duplicate.isNotEmpty) {
      throw Exception('Workshop code must be unique within the section');
    }

    await db.insert(
      'workshops',
      workshop.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _security.audit(
      action: existingWorkshop.isEmpty
          ? 'CREATE'
          : workshop.active
          ? 'UPDATE'
          : 'DEACTIVATE',
      module: 'Factory',
      entityType: 'Workshop',
      entityId: workshop.id,
      description: 'Workshop changed',
    );
  }

  Future<List<ProductionStage>> getProductionStages() async {
    _security.require('FACTORY_VIEW');
    final db = await database;
    final maps = _visible(
      await db.query('production_stages', orderBy: 'sequence ASC, name ASC'),
      'production_stages',
    );
    return maps.map(ProductionStage.fromMap).toList();
  }

  Future<List<ProductionStage>> searchProductionStages(String query) async {
    _security.require('FACTORY_VIEW');
    final db = await database;
    final normalized = query.trim();
    if (normalized.isEmpty) return getProductionStages();

    final maps = await db.query(
      'production_stages',
      where: 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: [
        '%${normalized.toLowerCase()}%',
        '%${normalized.toLowerCase()}%',
      ],
      orderBy: 'sequence ASC, name ASC',
    );
    return _visible(
      maps,
      'production_stages',
    ).map(ProductionStage.fromMap).toList();
  }

  Future<void> upsertProductionStage(ProductionStage stage) async {
    _security.require('FACTORY_EDIT');
    final db = await database;
    if ((await db.query(
      'production_stages',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [stage.id],
      limit: 1,
    )).isNotEmpty) {
      await _security.requireResourceScope(ScopeType.productionStage, stage.id);
    }
    final exists = await db.query(
      'production_stages',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [stage.id],
      limit: 1,
    );
    if (stage.sequence <= 0) {
      throw Exception('Production sequence must be a positive integer');
    }

    final duplicate = await db.query(
      'production_stages',
      where: 'factoryId = ? AND code = ? AND id != ?',
      whereArgs: [stage.factoryId, stage.code.trim(), stage.id],
    );
    if (duplicate.isNotEmpty) {
      throw Exception(
        'Production stage code must be unique within the factory',
      );
    }

    await db.insert(
      'production_stages',
      stage.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _security.audit(
      action: exists.isEmpty
          ? 'CREATE'
          : stage.active
          ? 'UPDATE'
          : 'DEACTIVATE',
      module: 'Factory',
      entityType: 'ProductionStage',
      entityId: stage.id,
      description: 'Production stage changed',
    );
  }

  Future<List<Warehouse>> getWarehouses() async {
    _security.require('WAREHOUSE_STOCK_VIEW');
    final db = await database;
    final rows = await db.query('warehouses', orderBy: 'name ASC');
    final visibleRows = _visible(rows, 'warehouses');
    final warehouses = visibleRows.map(Warehouse.fromMap).toList();
    await FurnexaDatabaseDiagnostics.capture(
      source: 'factoryStructure.warehouses',
      stageCounts: {
        'sqliteRows': rows.length,
        'scopeFilteredRows': visibleRows.length,
        'mappedEntities': warehouses.length,
        'finalRepositoryRows': warehouses.length,
      },
    );
    return warehouses;
  }

  Future<List<Warehouse>> searchWarehouses(String query) async {
    _security.require('WAREHOUSE_STOCK_VIEW');
    final db = await database;
    final normalized = query.trim();
    if (normalized.isEmpty) return getWarehouses();

    final rows = await db.query(
      'warehouses',
      where: 'LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(type) LIKE ?',
      whereArgs: [
        '%${normalized.toLowerCase()}%',
        '%${normalized.toLowerCase()}%',
        '%${normalized.toLowerCase()}%',
      ],
      orderBy: 'name ASC',
    );
    final visibleRows = _visible(rows, 'warehouses');
    final warehouses = visibleRows.map(Warehouse.fromMap).toList();
    await FurnexaDatabaseDiagnostics.capture(
      source: 'factoryStructure.searchWarehouses',
      warehouseSearch: query,
      stageCounts: {
        'sqliteRowsAfterSearch': rows.length,
        'scopeFilteredRows': visibleRows.length,
        'mappedEntities': warehouses.length,
        'finalRepositoryRows': warehouses.length,
      },
    );
    return warehouses;
  }

  Future<void> upsertWarehouse(Warehouse warehouse) async {
    _security.require('WAREHOUSE_STOCK_EDIT');
    final db = await database;
    if ((await db.query(
      'warehouses',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [warehouse.id],
      limit: 1,
    )).isNotEmpty) {
      await _security.requireResourceScope(ScopeType.warehouse, warehouse.id);
    }
    final exists = await db.query(
      'warehouses',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [warehouse.id],
      limit: 1,
    );
    final duplicate = await db.query(
      'warehouses',
      where: 'factoryId = ? AND code = ? AND id != ?',
      whereArgs: [warehouse.factoryId, warehouse.code.trim(), warehouse.id],
    );
    if (duplicate.isNotEmpty) {
      throw Exception('Warehouse code must be unique within the factory');
    }

    await db.insert(
      'warehouses',
      warehouse.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await FurnexaDatabaseDiagnostics.capture(
      source: 'warehouse.create',
      entityType: 'warehouse',
      entityId: warehouse.id,
    );
    await _security.audit(
      action: exists.isEmpty
          ? 'CREATE'
          : warehouse.state == 'inactive'
          ? 'DEACTIVATE'
          : 'UPDATE',
      module: 'Warehouse',
      entityType: 'Warehouse',
      entityId: warehouse.id,
      description: 'Warehouse changed',
    );
  }

  List<Map<String, Object?>> _visible(
    List<Map<String, Object?>> rows,
    String table,
  ) {
    final session = _security.session;
    if (session == null || session.isSystemAdmin) return rows;
    final scopes = session.scopes;
    final type = switch (table) {
      'sections' => ScopeType.section,
      'workshops' => ScopeType.workshop,
      'production_stages' => ScopeType.productionStage,
      'warehouses' => ScopeType.warehouse,
      _ => null,
    };
    if (type == null) return rows;
    final direct = scopes
        .where((scope) => scope.type == type)
        .map((scope) => scope.scopeId)
        .toSet();
    final sectionIds = scopes
        .where((scope) => scope.type == ScopeType.section)
        .map((scope) => scope.scopeId)
        .toSet();
    if (direct.isEmpty && (type != ScopeType.workshop || sectionIds.isEmpty)) {
      return rows;
    }
    return rows.where((row) {
      if (direct.contains(row['id'])) return true;
      return type == ScopeType.workshop &&
          sectionIds.contains(row['sectionId']);
    }).toList();
  }
}
