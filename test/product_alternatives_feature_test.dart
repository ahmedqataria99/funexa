import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/raw_materials_products/data/datasources/raw_materials_products_local_data_source.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late SecurityLocalDataSource security;
  late RawMaterialsProductsLocalDataSource dataSource;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.login('admin', DatabaseTestHelper.adminPassword);
    dataSource = RawMaterialsProductsLocalDataSource(security);
    final now = DateTime.now();
    await dataSource.saveCategory(
      Category(
        id: 'category-bedroom',
        name: 'Bedroom Furniture',
        code: 'BEDROOM',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveCategory(
      Category(
        id: 'category-office',
        name: 'Office Furniture',
        code: 'OFFICE',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveUnit(
      UnitEntity(
        id: 'unit-piece',
        name: 'Piece',
        abbreviation: 'PC',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    security.logout();
    await DatabaseTestHelper.reset();
  });

  Future<Product> saveProduct(
    String id,
    String name,
    String code, {
    String categoryId = 'category-bedroom',
    ProductState state = ProductState.unfinished,
    bool active = true,
  }) async {
    final now = DateTime.now();
    final product = Product(
      id: id,
      name: name,
      code: code,
      categoryId: categoryId,
      unitId: 'unit-piece',
      state: state,
      active: active,
      createdAt: now,
      updatedAt: now,
    );
    await dataSource.saveProduct(product);
    return product;
  }

  test('adds a valid existing product as an alternative', () async {
    await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
    final target = await saveProduct('target', 'Bedroom Target', 'BED-TARGET');

    await dataSource.addAlternative('source', target.id, 1);
    final alternatives = await dataSource.getAlternatives('source');

    expect(alternatives, hasLength(1));
    expect(alternatives.single.targetProductId, target.id);
    expect(alternatives.single.target.product.name, target.name);
  });

  test('rejects an alternative from another category', () async {
    await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
    await saveProduct(
      'other-category',
      'Office Desk',
      'OFFICE-DESK',
      categoryId: 'category-office',
    );

    await expectLater(
      dataSource.addAlternative('source', 'other-category', 1),
      throwsException,
    );
  });

  test('rejects an inactive target product', () async {
    await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
    await saveProduct(
      'inactive',
      'Inactive Bedroom',
      'BED-INACTIVE',
      active: false,
    );

    await expectLater(
      dataSource.addAlternative('source', 'inactive', 1),
      throwsException,
    );
  });

  test('rejects self-alternatives', () async {
    await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');

    await expectLater(
      dataSource.addAlternative('source', 'source', 1),
      throwsException,
    );
  });

  test(
    'rejects duplicate alternatives in business logic and database',
    () async {
      await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
      await saveProduct('target', 'Bedroom Target', 'BED-TARGET');
      await dataSource.addAlternative('source', 'target', 1);

      await expectLater(
        dataSource.addAlternative('source', 'target', 2),
        throwsException,
      );
      final db = await FurnexaDatabase.instance.database;
      await expectLater(
        db.insert('product_alternatives', {
          'id': 'duplicate-relation',
          'sourceProductId': 'source',
          'targetProductId': 'target',
          'priority': 2,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }),
        throwsException,
      );
    },
  );

  test('database prevents a self-alternative', () async {
    await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
    final db = await FurnexaDatabase.instance.database;

    await expectLater(
      db.insert('product_alternatives', {
        'id': 'self-relation',
        'sourceProductId': 'source',
        'targetProductId': 'source',
        'priority': 1,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
      throwsException,
    );
  });

  test(
    'same-state candidates rank before different-state candidates',
    () async {
      await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
      await saveProduct(
        'finished',
        'A Finished Bedroom',
        'BED-FINISHED',
        state: ProductState.finished,
      );
      await saveProduct('unfinished', 'Z Unfinished Bedroom', 'BED-UNFINISHED');
      await saveProduct(
        'office',
        'A Office Product',
        'OFFICE-PRODUCT',
        categoryId: 'category-office',
      );

      final candidates = await dataSource.getEligibleAlternativeCandidates(
        'source',
        '',
      );

      expect(candidates.map((candidate) => candidate.product.id), [
        'unfinished',
        'finished',
      ]);
    },
  );

  test(
    'search stays within active same-category candidates and excludes self',
    () async {
      await saveProduct('source', 'Bedroom Source Desk', 'BED-SOURCE');
      await saveProduct('active-match', 'Bedroom Desk', 'BED-DESK');
      await saveProduct(
        'inactive-match',
        'Inactive Bedroom Desk',
        'BED-INACTIVE',
        active: false,
      );
      await saveProduct(
        'other-category-match',
        'Office Desk',
        'OFFICE-DESK',
        categoryId: 'category-office',
      );

      final candidates = await dataSource.getEligibleAlternativeCandidates(
        'source',
        'desk',
      );

      expect(candidates.map((candidate) => candidate.product.id), [
        'active-match',
      ]);
      expect(
        await dataSource.getEligibleAlternativeCandidates('source', 'office'),
        isEmpty,
      );
      expect(
        candidates.any((candidate) => candidate.product.id == 'source'),
        isFalse,
      );
    },
  );

  test(
    'candidate search omits products already linked as alternatives',
    () async {
      await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
      await saveProduct('target', 'Bedroom Target', 'BED-TARGET');
      await dataSource.addAlternative('source', 'target', 1);

      expect(
        await dataSource.getEligibleAlternativeCandidates('source', 'target'),
        isEmpty,
      );
    },
  );

  test(
    'priority persists, orders, updates, and compacts after removal',
    () async {
      await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
      await saveProduct('first', 'First Bedroom', 'BED-FIRST');
      await saveProduct('second', 'Second Bedroom', 'BED-SECOND');
      await dataSource.addAlternative('source', 'first', 1);
      await dataSource.addAlternative('source', 'second', 2);

      var alternatives = await dataSource.getAlternatives('source');
      expect(alternatives.map((value) => value.targetProductId), [
        'first',
        'second',
      ]);
      expect(alternatives.map((value) => value.priority), [1, 2]);

      await dataSource.updateAlternativePriority(alternatives.last.id, 1);
      alternatives = await dataSource.getAlternatives('source');
      expect(alternatives.map((value) => value.targetProductId), [
        'second',
        'first',
      ]);
      expect(alternatives.map((value) => value.priority), [1, 2]);

      await dataSource.removeAlternative(alternatives.first.id);
      alternatives = await dataSource.getAlternatives('source');
      expect(alternatives.map((value) => value.targetProductId), ['first']);
      expect(alternatives.single.priority, 1);
    },
  );

  test('alternative creation, reordering, and deletion are audited', () async {
    await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
    await saveProduct('first', 'First Bedroom', 'BED-FIRST');
    await saveProduct('second', 'Second Bedroom', 'BED-SECOND');
    await dataSource.addAlternative('source', 'first', 1);
    await dataSource.addAlternative('source', 'second', 2);
    final alternatives = await dataSource.getAlternatives('source');
    await dataSource.updateAlternativePriority(alternatives.last.id, 1);
    await dataSource.removeAlternative(alternatives.first.id);

    final logs = await (await FurnexaDatabase.instance.database).query(
      'audit_logs',
      where: 'entityType = ?',
      whereArgs: ['ProductAlternative'],
    );
    expect(logs.map((row) => row['action']), contains('CREATE'));
    expect(logs.map((row) => row['action']), contains('UPDATE'));
    expect(logs.map((row) => row['action']), contains('DELETE'));
  });

  test('alternative mutations require product edit permission', () async {
    await saveProduct('source', 'Bedroom Source', 'BED-SOURCE');
    await saveProduct('target', 'Bedroom Target', 'BED-TARGET');
    final role = await security.createRole(name: 'Alternative Viewer');
    await security.setRolePermissions(role.id, ['PRODUCTS_VIEW']);
    final viewer = await security.createUser(
      username: 'alternative-viewer',
      displayName: 'Alternative Viewer',
      password: 'viewer-secret',
      roleId: role.id,
    );
    security.logout();
    await security.login(viewer.username, 'viewer-secret');

    await expectLater(
      dataSource.addAlternative('source', 'target', 1),
      throwsException,
    );
    await expectLater(
      dataSource.updateAlternativePriority('missing', 1),
      throwsException,
    );
    await expectLater(dataSource.removeAlternative('missing'), throwsException);
  });
}
