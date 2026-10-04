import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class RawMaterialsProductsLocalDataSource {
  RawMaterialsProductsLocalDataSource([SecurityLocalDataSource? security])
    : _security = security ?? SecurityLocalDataSource();

  final SecurityLocalDataSource _security;
  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<List<Category>> categories([String query = '']) async =>
      _catalogSearch<Category>('categories', query, [
        'name',
        'code',
      ], Category.fromMap);
  Future<List<UnitEntity>> units([String query = '']) async =>
      _catalogSearch<UnitEntity>('units', query, [
        'name',
        'abbreviation',
      ], UnitEntity.fromMap);
  Future<List<ItemColor>> colors([String query = '']) async =>
      _catalogSearch<ItemColor>('colors', query, [
        'name',
        'code',
      ], ItemColor.fromMap);
  Future<List<RawMaterial>> rawMaterials([
    String query = '',
    String? categoryId,
  ]) async {
    _security.require('PRODUCTS_VIEW');
    final db = await _db;
    final parts = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      parts.add('(LOWER(name) LIKE ? OR LOWER(code) LIKE ?)');
      args.addAll([
        '%${query.trim().toLowerCase()}%',
        '%${query.trim().toLowerCase()}%',
      ]);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      parts.add('categoryId = ?');
      args.add(categoryId);
    }
    final rows = await db.query(
      'raw_materials',
      where: parts.isEmpty ? null : parts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return rows.map(RawMaterial.fromMap).toList();
  }

  Future<List<Product>> products([
    String query = '',
    String? categoryId,
    ProductState? state,
  ]) async {
    _security.require('PRODUCTS_VIEW');
    final db = await _db;
    final parts = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      parts.add('(LOWER(name) LIKE ? OR LOWER(code) LIKE ?)');
      args.addAll([
        '%${query.trim().toLowerCase()}%',
        '%${query.trim().toLowerCase()}%',
      ]);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      parts.add('categoryId = ?');
      args.add(categoryId);
    }
    if (state != null) {
      parts.add('productState = ?');
      args.add(state.name);
    }
    final rows = await db.query(
      'products',
      where: parts.isEmpty ? null : parts.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<List<ProductVariant>> variants(String productId) async => _catalogRows(
    'product_variants',
    'productId = ?',
    [productId],
    ProductVariant.fromMap,
  );

  Future<List<ProductAlternative>> getAlternatives(
    String sourceProductId,
  ) async {
    _security.require('PRODUCTS_VIEW');
    final rows = await (await _db).rawQuery(
      '''
      SELECT
        alternative.id AS alternativeId,
        alternative.sourceProductId,
        alternative.targetProductId,
        alternative.priority AS alternativePriority,
        alternative.createdAt AS alternativeCreatedAt,
        alternative.updatedAt AS alternativeUpdatedAt,
        ${_alternativeTargetColumns('target')}
      FROM product_alternatives alternative
      JOIN products target ON target.id = alternative.targetProductId
      JOIN categories category ON category.id = target.categoryId
      WHERE alternative.sourceProductId = ?
      ORDER BY alternative.priority ASC, target.name COLLATE NOCASE, target.id
    ''',
      [sourceProductId],
    );
    return rows.map(_alternativeFromRow).toList();
  }

  Future<List<ProductAlternativeCandidate>> getEligibleAlternativeCandidates(
    String sourceProductId,
    String searchQuery,
  ) async {
    _security.require('PRODUCTS_VIEW');
    final normalized = searchQuery.trim().toLowerCase();
    final searchClause = normalized.isEmpty
        ? ''
        : 'AND (LOWER(target.name) LIKE ? OR LOWER(target.code) LIKE ?)';
    final args = <Object?>[sourceProductId];
    if (normalized.isNotEmpty) {
      args.addAll(['%$normalized%', '%$normalized%']);
    }
    final rows = await (await _db).rawQuery('''
      SELECT ${_alternativeTargetColumns('target')}
      FROM products source
      JOIN products target ON target.categoryId = source.categoryId
      JOIN categories category ON category.id = target.categoryId
      WHERE source.id = ?
        AND source.active = 1
        AND target.active = 1
        AND target.id != source.id
        AND NOT EXISTS (
          SELECT 1 FROM product_alternatives existing
          WHERE existing.sourceProductId = source.id
            AND existing.targetProductId = target.id
        )
        $searchClause
      ORDER BY
        CASE WHEN target.productState = source.productState THEN 0 ELSE 1 END,
        target.name COLLATE NOCASE,
        target.code COLLATE NOCASE,
        target.id
    ''', args);
    return rows.map(_alternativeCandidateFromRow).toList();
  }

  Future<void> addAlternative(
    String sourceProductId,
    String targetProductId,
    int priority,
  ) async {
    _security.require('PRODUCTS_EDIT');
    if (sourceProductId == targetProductId) {
      throw Exception('لا يمكن اختيار المنتج نفسه كبديل');
    }
    if (priority < 1) throw ArgumentError.value(priority, 'priority');

    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'alternative-${DateTime.now().microsecondsSinceEpoch}';
    final shiftedIds = await db.transaction((txn) async {
      final products = <String, Map<String, Object?>>{};
      for (final productId in [sourceProductId, targetProductId]) {
        final rows = await txn.query(
          'products',
          columns: ['id', 'categoryId', 'active'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (rows.isEmpty || rows.single['active'] != 1) {
          throw Exception('المنتج غير نشط أو غير موجود');
        }
        products[productId] = rows.single;
      }
      if (products[sourceProductId]!['categoryId'] !=
          products[targetProductId]!['categoryId']) {
        throw Exception('يجب أن ينتمي البديل إلى تصنيف المنتج نفسه');
      }
      final duplicate = await txn.query(
        'product_alternatives',
        columns: ['id'],
        where: 'sourceProductId = ? AND targetProductId = ?',
        whereArgs: [sourceProductId, targetProductId],
        limit: 1,
      );
      if (duplicate.isNotEmpty) throw Exception('البديل مضاف مسبقاً');

      final siblings = await txn.query(
        'product_alternatives',
        columns: ['id', 'priority'],
        where: 'sourceProductId = ?',
        whereArgs: [sourceProductId],
        orderBy: 'priority ASC',
      );
      if (priority > siblings.length + 1) {
        throw ArgumentError.value(priority, 'priority');
      }
      final shifted = siblings
          .where((row) => (row['priority'] as int) >= priority)
          .toList();
      final maxPriority = siblings.isEmpty
          ? 0
          : siblings
                .map((row) => row['priority'] as int)
                .reduce((left, right) => left > right ? left : right);
      final offset = maxPriority + siblings.length + 1;
      for (final row in shifted) {
        await txn.update(
          'product_alternatives',
          {'priority': (row['priority'] as int) + offset},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      for (final row in shifted) {
        await txn.update(
          'product_alternatives',
          {'priority': (row['priority'] as int) + 1, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      await txn.insert('product_alternatives', {
        'id': id,
        'sourceProductId': sourceProductId,
        'targetProductId': targetProductId,
        'priority': priority,
        'createdAt': now,
        'updatedAt': now,
      });
      return shifted.map((row) => row['id'] as String).toList();
    });
    await _auditAlternative(id, 'CREATE', 'Product alternative added');
    for (final shiftedId in shiftedIds) {
      await _auditAlternative(
        shiftedId,
        'UPDATE',
        'Product alternative priority shifted',
      );
    }
  }

  Future<void> updateAlternativePriority(
    String alternativeId,
    int priority,
  ) async {
    _security.require('PRODUCTS_EDIT');
    if (priority < 1) throw ArgumentError.value(priority, 'priority');
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changedIds = await db.transaction((txn) async {
      final rows = await txn.query(
        'product_alternatives',
        where: 'id = ?',
        whereArgs: [alternativeId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('البديل غير موجود');
      final relation = rows.single;
      final sourceProductId = relation['sourceProductId'] as String;
      final targetProductId = relation['targetProductId'] as String;
      final products = <String, Map<String, Object?>>{};
      for (final productId in [sourceProductId, targetProductId]) {
        final productRows = await txn.query(
          'products',
          columns: ['id', 'categoryId', 'active'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (productRows.isEmpty || productRows.single['active'] != 1) {
          throw Exception('المنتج غير نشط أو غير موجود');
        }
        products[productId] = productRows.single;
      }
      if (products[sourceProductId]!['categoryId'] !=
          products[targetProductId]!['categoryId']) {
        throw Exception('يجب أن ينتمي البديل إلى تصنيف المنتج نفسه');
      }
      final siblings = await txn.query(
        'product_alternatives',
        columns: ['id', 'priority'],
        where: 'sourceProductId = ?',
        whereArgs: [sourceProductId],
        orderBy: 'priority ASC',
      );
      if (priority > siblings.length) {
        throw ArgumentError.value(priority, 'priority');
      }
      final oldPriority = relation['priority'] as int;
      if (oldPriority == priority) return <String>[];

      final moved = <Map<String, Object?>>[];
      for (final row in siblings) {
        final rowPriority = row['priority'] as int;
        if (row['id'] == alternativeId ||
            (priority < oldPriority &&
                rowPriority >= priority &&
                rowPriority < oldPriority) ||
            (priority > oldPriority &&
                rowPriority > oldPriority &&
                rowPriority <= priority)) {
          moved.add(row);
        }
      }
      final maxPriority = siblings
          .map((row) => row['priority'] as int)
          .reduce((left, right) => left > right ? left : right);
      final offset = maxPriority + siblings.length + 1;
      for (final row in moved) {
        await txn.update(
          'product_alternatives',
          {'priority': (row['priority'] as int) + offset},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      for (final row in moved) {
        final isMoved = row['id'] == alternativeId;
        final old = row['priority'] as int;
        final next = isMoved
            ? priority
            : priority < oldPriority
            ? old + 1
            : old - 1;
        await txn.update(
          'product_alternatives',
          {'priority': next, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      return moved.map((row) => row['id'] as String).toList();
    });
    for (final changedId in changedIds) {
      await _auditAlternative(
        changedId,
        'UPDATE',
        'Product alternative priority changed',
      );
    }
  }

  Future<void> removeAlternative(String alternativeId) async {
    _security.require('PRODUCTS_EDIT');
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await db.transaction((txn) async {
      final rows = await txn.query(
        'product_alternatives',
        where: 'id = ?',
        whereArgs: [alternativeId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('البديل غير موجود');
      final relation = rows.single;
      final sourceProductId = relation['sourceProductId'] as String;
      final removedPriority = relation['priority'] as int;
      await txn.delete(
        'product_alternatives',
        where: 'id = ?',
        whereArgs: [alternativeId],
      );
      final shifted = await txn.query(
        'product_alternatives',
        columns: ['id', 'priority'],
        where: 'sourceProductId = ? AND priority > ?',
        whereArgs: [sourceProductId, removedPriority],
        orderBy: 'priority ASC',
      );
      final maxPriority = shifted.isEmpty
          ? removedPriority
          : shifted
                .map((row) => row['priority'] as int)
                .reduce((left, right) => left > right ? left : right);
      final offset = maxPriority + shifted.length + 1;
      for (final row in shifted) {
        await txn.update(
          'product_alternatives',
          {'priority': (row['priority'] as int) + offset},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      for (final row in shifted) {
        await txn.update(
          'product_alternatives',
          {'priority': (row['priority'] as int) - 1, 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
      return shifted.map((row) => row['id'] as String).toList();
    });
    await _auditAlternative(
      alternativeId,
      'DELETE',
      'Product alternative removed',
    );
    for (final shiftedId in result) {
      await _auditAlternative(
        shiftedId,
        'UPDATE',
        'Product alternative priority shifted',
      );
    }
  }

  Future<void> _auditAlternative(
    String id,
    String action,
    String description,
  ) => _security.audit(
    action: action,
    module: 'Products',
    entityType: 'ProductAlternative',
    entityId: id,
    description: description,
  );

  ProductAlternative _alternativeFromRow(Map<String, Object?> row) =>
      ProductAlternative(
        id: row['alternativeId'] as String,
        sourceProductId: row['sourceProductId'] as String,
        target: _alternativeCandidateFromRow(row),
        priority: row['alternativePriority'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['alternativeCreatedAt'] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['alternativeUpdatedAt'] as int,
        ),
      );

  ProductAlternativeCandidate _alternativeCandidateFromRow(
    Map<String, Object?> row,
  ) => ProductAlternativeCandidate(
    product: Product.fromMap(row),
    categoryName: row['alternativeCategoryName'] as String,
    colorNames: row['alternativeColorNames'] as String?,
  );

  String _alternativeTargetColumns(String alias) =>
      '''
    $alias.*,
    category.name AS alternativeCategoryName,
    (
      SELECT GROUP_CONCAT(DISTINCT color.name)
      FROM product_variants variant
      JOIN colors color ON color.id = variant.colorId
      WHERE variant.productId = $alias.id
        AND variant.active = 1
        AND color.active = 1
    ) AS alternativeColorNames
  ''';
  Future<List<ProductDimension>> dimensions(String productId) async =>
      _catalogRows('product_dimensions', 'productId = ?', [
        productId,
      ], ProductDimension.fromMap);
  Future<List<BomItem>> bom(String productId) async => _catalogRows(
    'product_bom_items',
    'productId = ?',
    [productId],
    BomItem.fromMap,
  );

  Future<void> saveCategory(Category value) =>
      _save('categories', value.id, value.toMap());
  Future<void> saveUnit(UnitEntity value) =>
      _save('units', value.id, value.toMap());
  Future<void> saveColor(ItemColor value) =>
      _save('colors', value.id, value.toMap());

  Future<void> saveRawMaterial(RawMaterial value) async {
    await _requireActive('categories', value.categoryId, 'التصنيف');
    await _requireActive('units', value.unitId, 'الوحدة');
    await _save('raw_materials', value.id, value.toMap());
  }

  Future<void> saveProduct(Product value) async {
    await _requireActive('categories', value.categoryId, 'التصنيف');
    await _requireActive('units', value.unitId, 'الوحدة');
    await _save('products', value.id, value.toMap());
  }

  Future<void> saveVariant(ProductVariant value) async {
    await _requireActive('products', value.productId, 'المنتج');
    if (value.colorId != null) {
      await _requireActive('colors', value.colorId!, 'اللون');
    }
    await _save('product_variants', value.id, value.toMap());
  }

  Future<void> saveDimensions(ProductDimension value) async {
    final db = await _db;
    _security.require('PRODUCTS_EDIT');
    await _requireExists('products', value.productId, 'المنتج');
    if (value.variantId != null) {
      final variant = await db.query(
        'product_variants',
        columns: ['productId'],
        where: 'id = ?',
        whereArgs: [value.variantId],
        limit: 1,
      );
      if (variant.isEmpty || variant.first['productId'] != value.productId) {
        throw Exception('البديل لا يتبع المنتج المحدد');
      }
    }
    final where = value.variantId == null
        ? 'productId = ? AND variantId IS NULL'
        : 'productId = ? AND variantId = ?';
    final args = value.variantId == null
        ? [value.productId]
        : [value.productId, value.variantId];
    final existing = await db.query(
      'product_dimensions',
      where: where,
      whereArgs: args,
      limit: 1,
    );
    if (existing.isNotEmpty && existing.first['id'] != value.id) {
      await db.update(
        'product_dimensions',
        value.toMap(),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await _save('product_dimensions', value.id, value.toMap());
    }
    await _security.audit(
      action: 'UPDATE',
      module: 'Products',
      entityType: 'ProductDimension',
      entityId: value.id,
      description: 'Product dimensions changed',
    );
  }

  Future<void> saveBomItem(BomItem value) async {
    await _requireExists('products', value.productId, 'المنتج');
    await _requireActive('raw_materials', value.rawMaterialId, 'الخامة');
    await _save('product_bom_items', value.id, value.toMap());
  }

  Future<void> deleteBomItem(String id) async => _deleteBomItem(id);

  Future<void> setActive(String table, String id, bool active) async {
    const allowed = {
      'categories',
      'units',
      'colors',
      'raw_materials',
      'products',
    };
    if (!allowed.contains(table)) throw Exception('الجدول غير مسموح');
    _security.require('PRODUCTS_EDIT');
    final updated = await (await _db).update(
      table,
      {
        'active': active ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) throw Exception('السجل غير موجود');
    await _security.audit(
      action: active ? 'ACTIVATE' : 'DEACTIVATE',
      module: 'Products',
      entityType: table,
      entityId: id,
      description: 'Master data status changed',
    );
  }

  Future<void> _deleteBomItem(String id) async {
    _security.require('PRODUCTS_EDIT');
    final deleted = await (await _db).delete(
      'product_bom_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (deleted == 0) throw Exception('عنصر الوصفة غير موجود');
    await _security.audit(
      action: 'DELETE',
      module: 'Products',
      entityType: 'BomItem',
      entityId: id,
      description: 'BOM item removed',
    );
  }

  Future<void> _save(
    String table,
    String id,
    Map<String, Object?> values,
  ) async {
    final db = await _db;
    _security.require('PRODUCTS_EDIT');
    final count = await db.transaction((txn) async {
      final updated = await txn.update(
        table,
        values,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated == 0) await txn.insert(table, values);
      return updated;
    });
    await _security.audit(
      action: count == 0 ? 'CREATE' : 'UPDATE',
      module: 'Products',
      entityType: table,
      entityId: id,
      description: 'Master data changed',
    );
  }

  Future<void> _requireExists(String table, String id, String label) async {
    final rows = await (await _db).query(
      table,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('$label غير موجود');
  }

  Future<void> _requireActive(String table, String id, String label) async {
    final rows = await (await _db).query(
      table,
      columns: ['id'],
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('$label غير نشط أو غير موجود');
  }

  Future<List<T>> _search<T>(
    String table,
    String query,
    List<String> columns,
    T Function(Map<String, Object?>) fromMap,
  ) async {
    final db = await _db;
    final normalized = query.trim().toLowerCase();
    final where = normalized.isEmpty
        ? null
        : columns.map((column) => 'LOWER($column) LIKE ?').join(' OR ');
    final args = normalized.isEmpty
        ? null
        : columns.map((_) => '%$normalized%').toList();
    final rows = await db.query(
      table,
      where: where,
      whereArgs: args,
      orderBy: 'name ASC',
    );
    return rows.map(fromMap).toList();
  }

  Future<List<T>> _rows<T>(
    String table,
    String where,
    List<Object?> args,
    T Function(Map<String, Object?>) fromMap,
  ) async => (await (await _db).query(
    table,
    where: where,
    whereArgs: args,
    orderBy: table == 'product_dimensions' || table == 'product_bom_items'
        ? 'id ASC'
        : 'name ASC',
  )).map(fromMap).toList();

  Future<List<T>> _catalogSearch<T>(
    String table,
    String query,
    List<String> columns,
    T Function(Map<String, Object?>) fromMap,
  ) async {
    _security.require('PRODUCTS_VIEW');
    return _search(table, query, columns, fromMap);
  }

  Future<List<T>> _catalogRows<T>(
    String table,
    String where,
    List<Object?> args,
    T Function(Map<String, Object?>) fromMap,
  ) async {
    _security.require('PRODUCTS_VIEW');
    return _rows(table, where, args, fromMap);
  }
}
