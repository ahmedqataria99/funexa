import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/factory_structure/data/datasources/factory_structure_local_data_source.dart';
import 'package:furnexa/features/factory_structure/domain/entities/factory_profile.dart';
import 'package:furnexa/features/factory_structure/presentation/pages/factory_structure_page.dart';
import 'test_helpers/database_test_helper.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/section.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/factory_structure/domain/entities/workshop.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

void main() {
  group('Factory structure feature', () {
    late FactoryStructureLocalDataSource dataSource;
    late SecurityLocalDataSource security;

    setUp(() async {
      await DatabaseTestHelper.reset();
      security = SecurityLocalDataSource();
      await security.login('admin', 'Furnexa-Test-Admin-2026!');
      dataSource = FactoryStructureLocalDataSource(security);
      await dataSource.clearAll();
    });

    tearDown(() async {
      await DatabaseTestHelper.reset();
    });

    Future<Warehouse> createPurposeWarehouse(
      String id,
      WarehousePurpose purpose,
    ) async {
      final now = DateTime.now();
      final factory = FactoryProfile(
        id: 'purpose-factory-$id',
        name: 'Purpose Factory $id',
        code: 'PF-$id',
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertFactory(factory);
      final warehouse = Warehouse(
        id: id,
        factoryId: factory.id,
        name: 'Purpose Warehouse $id',
        code: 'PW-$id',
        purpose: purpose,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.upsertWarehouse(warehouse);
      return warehouse;
    }

    Future<void> seedPurposeBalance(
      String warehouseId, {
      required double quantity,
    }) async {
      final db = await FurnexaDatabase.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('stock_balances', {
        'id': 'purpose-balance-$warehouseId',
        'warehouseId': warehouseId,
        'itemId': 'purpose-item-$warehouseId',
        'itemType': 'RAW_MATERIAL',
        'quantity': quantity,
        'inventoryIdentityKind': 'BASE',
        'createdAt': now,
        'updatedAt': now,
      });
    }

    Future<void> seedPurposeValuation(
      String warehouseId, {
      required double quantity,
      required double averageCost,
    }) async {
      final db = await FurnexaDatabase.instance.database;
      await db.insert('inventory_valuations', {
        'id': 'purpose-valuation-$warehouseId',
        'warehouseId': warehouseId,
        'itemId': 'purpose-item-$warehouseId',
        'itemType': 'RAW_MATERIAL',
        'quantity': quantity,
        'averageCost': averageCost,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }

    Future<Map<String, Object?>> purposeState(String warehouseId) async {
      final db = await FurnexaDatabase.instance.database;
      return {
        'warehouse': await db.query(
          'warehouses',
          where: 'id = ?',
          whereArgs: [warehouseId],
        ),
        'balances': await db.query(
          'stock_balances',
          where: 'warehouseId = ?',
          whereArgs: [warehouseId],
          orderBy: 'id ASC',
        ),
        'valuations': await db.query(
          'inventory_valuations',
          where: 'warehouseId = ?',
          whereArgs: [warehouseId],
          orderBy: 'id ASC',
        ),
        'transactions': await db.query(
          'stock_transactions',
          where: 'warehouseId = ?',
          whereArgs: [warehouseId],
          orderBy: 'id ASC',
        ),
        'journalEntries': await db.query('journal_entries', orderBy: 'id ASC'),
        'journalLines': await db.query('journal_lines', orderBy: 'id ASC'),
        'journalParties': await db.query(
          'journal_parties',
          orderBy: 'journalEntryId ASC',
        ),
      };
    }

    Future<void> expectPurposeChangeRejected(
      Warehouse warehouse,
      WarehousePurpose purpose,
    ) async {
      final before = await purposeState(warehouse.id);
      await expectLater(
        dataSource.upsertWarehouse(warehouse.copyWith(purpose: purpose)),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'Cannot change warehouse purpose while it contains stock or inventory value',
            ),
          ),
        ),
      );
      expect(await purposeState(warehouse.id), before);
    }

    test('database migration creates all required tables', () async {
      final db = await dataSource.database;
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );

      final names = tables.map((row) => row['name'] as String).toList();
      expect(
        names,
        containsAll([
          'factories',
          'sections',
          'workshops',
          'production_stages',
          'warehouses',
        ]),
      );
    });

    test('creates and persists a factory profile', () async {
      final factoryProfile = FactoryProfile(
        id: 'factory-1',
        name: 'مصنع النخبة',
        code: 'F-001',
        phone: '0500000000',
        email: 'info@factory.com',
        address: 'الرياض',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dataSource.upsertFactory(factoryProfile);
      final result = await dataSource.getFactory();

      expect(result, isNotNull);
      expect(result!.code, 'F-001');
      expect(result.name, 'مصنع النخبة');
    });

    testWidgets(
      'System Admin can open first factory setup before child actions',
      (tester) async {
        await tester.pumpWidget(_factoryStructureApp(security));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        for (var attempt = 0; attempt < 20; attempt++) {
          if (find.text('إعداد بيانات المصنع').evaluate().isNotEmpty ||
              find
                  .text('حدث خطأ أثناء تحميل هيكل المصنع.')
                  .evaluate()
                  .isNotEmpty) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text('حدث خطأ أثناء تحميل هيكل المصنع.'), findsNothing);
        final setupButton = _buttonWithText('إعداد بيانات المصنع');
        expect(tester.widget<FilledButton>(setupButton).onPressed, isNotNull);
        for (final label in [
          'إضافة قسم',
          'إضافة ورشة',
          'إضافة مرحلة',
          'إضافة مخزن',
        ]) {
          expect(
            tester.widget<FilledButton>(_buttonWithText(label)).onPressed,
            isNull,
          );
        }

        await tester.tap(setupButton);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('اسم المصنع *'), findsOneWidget);
      },
    );

    test('prevents duplicate factory codes', () async {
      final first = FactoryProfile(
        id: 'factory-1',
        name: 'مصنع أول',
        code: 'F-001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final second = FactoryProfile(
        id: 'factory-2',
        name: 'مصنع ثاني',
        code: 'F-001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dataSource.upsertFactory(first);
      expect(() async => dataSource.upsertFactory(second), throwsException);
    });

    test('allows only one factory profile', () async {
      final now = DateTime.now();
      await dataSource.upsertFactory(
        FactoryProfile(
          id: 'factory-1',
          name: 'مصنع أول',
          code: 'F-001',
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(
        () => dataSource.upsertFactory(
          FactoryProfile(
            id: 'factory-2',
            name: 'مصنع ثان',
            code: 'F-002',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsException,
      );
    });

    test('rejects unauthenticated structure mutations', () async {
      security.logout();
      expect(
        () => dataSource.upsertFactory(
          FactoryProfile(
            id: 'factory-unauthorized',
            name: 'مصنع',
            code: 'F-UNAUTH',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        throwsException,
      );
    });

    test('enforces role permissions and section scopes', () async {
      final now = DateTime.now();
      await dataSource.upsertFactory(
        FactoryProfile(
          id: 'factory-sec',
          name: 'مصنع أمني',
          code: 'SEC-F',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.upsertSection(
        Section(
          id: 'section-in-scope',
          factoryId: 'factory-sec',
          name: 'قسم مسموح',
          code: 'SEC-IN',
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.upsertSection(
        Section(
          id: 'section-out-scope',
          factoryId: 'factory-sec',
          name: 'قسم غير مسموح',
          code: 'SEC-OUT',
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final role = await security.createRole(name: 'Scoped Factory Role');
      await security.setRolePermissions(role.id, [
        'FACTORY_EDIT',
        'FACTORY_VIEW',
      ]);
      final user = await security.createUser(
        username: 'scoped-factory',
        displayName: 'Scoped Factory',
        password: 'secret',
        roleId: role.id,
      );
      await security.setUserScopes(user.id, [
        UserScope(
          id: '',
          userId: user.id,
          type: ScopeType.section,
          scopeId: 'section-in-scope',
        ),
      ]);
      await security.login('scoped-factory', 'secret');
      expect(
        () => dataSource.upsertSection(
          Section(
            id: 'section-out-scope',
            factoryId: 'factory-sec',
            name: 'تعديل مرفوض',
            code: 'SEC-OUT',
            active: true,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsException,
      );
      expect(
        (await dataSource.getSections()).map((value) => value.id),
        isNot(contains('section-out-scope')),
      );
    });

    test(
      'updates an existing factory without replacing related records',
      () async {
        final createdAt = DateTime(2026, 1, 1);
        final original = FactoryProfile(
          id: 'factory-1',
          name: 'مصنع أول',
          code: 'F-001',
          createdAt: createdAt,
          updatedAt: createdAt,
        );
        await dataSource.upsertFactory(original);
        await dataSource.upsertSection(
          Section(
            id: 'section-1',
            factoryId: original.id,
            name: 'النجارة',
            code: 'SEC-001',
            active: true,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );

        final updatedAt = DateTime(2026, 1, 2);
        await dataSource.upsertFactory(
          FactoryProfile(
            id: original.id,
            name: 'مصنع محدث',
            code: 'F-002',
            phone: '0500000000',
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );

        final result = await dataSource.getFactory();
        expect(result!.id, original.id);
        expect(result.name, 'مصنع محدث');
        expect(result.createdAt, createdAt);
        expect(result.updatedAt, updatedAt);
        expect(await dataSource.searchSections(''), hasLength(1));
      },
    );

    test('creates and searches sections', () async {
      final factory = FactoryProfile(
        id: 'factory-1',
        name: 'مصنع النخبة',
        code: 'F-001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await dataSource.upsertFactory(factory);

      final section = Section(
        id: 'section-1',
        factoryId: factory.id,
        name: 'النجارة',
        code: 'SEC-001',
        description: 'قسم النجارة',
        active: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dataSource.upsertSection(section);
      final results = await dataSource.searchSections('نجارة');

      expect(results, hasLength(1));
      expect(results.first.name, 'النجارة');
    });

    test('creates workshops only under an active section', () async {
      final factory = FactoryProfile(
        id: 'factory-1',
        name: 'مصنع النخبة',
        code: 'F-001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await dataSource.upsertFactory(factory);

      final section = Section(
        id: 'section-1',
        factoryId: factory.id,
        name: 'النجارة',
        code: 'SEC-001',
        active: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await dataSource.upsertSection(section);

      final workshop = Workshop(
        id: 'workshop-1',
        factoryId: factory.id,
        sectionId: section.id,
        name: 'ورشة CNC',
        code: 'WS-001',
        description: 'ورشة cnc',
        active: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dataSource.upsertWorkshop(workshop);
      final results = await dataSource.searchWorkshops('CNC');

      expect(results, hasLength(1));
      expect(results.first.sectionId, section.id);
    });

    test('rejects a workshop whose factory differs from its section', () async {
      final now = DateTime.now();
      await dataSource.upsertFactory(
        FactoryProfile(
          id: 'factory-a',
          name: 'مصنع أ',
          code: 'FA',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final db = await dataSource.database;
      await db.insert('factories', {
        'id': 'factory-b',
        'name': 'مصنع ب',
        'code': 'FB',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await dataSource.upsertSection(
        Section(
          id: 'section-a',
          factoryId: 'factory-a',
          name: 'قسم أ',
          code: 'SA',
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(
        () => dataSource.upsertWorkshop(
          Workshop(
            id: 'workshop-cross',
            factoryId: 'factory-b',
            sectionId: 'section-a',
            name: 'ورشة',
            code: 'W-CROSS',
            active: true,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsException,
      );
    });

    test('records a factory structure audit event', () async {
      final now = DateTime.now();
      await dataSource.upsertFactory(
        FactoryProfile(
          id: 'factory-audit',
          name: 'مصنع تدقيق',
          code: 'AUDIT-F',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final rows = await (await dataSource.database).query(
        'audit_logs',
        where: 'entityId = ?',
        whereArgs: ['factory-audit'],
      );
      expect(rows, isNotEmpty);
    });

    test('creates production stages with sequence order', () async {
      final factory = FactoryProfile(
        id: 'factory-1',
        name: 'مصنع النخبة',
        code: 'F-001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await dataSource.upsertFactory(factory);

      final stage = ProductionStage(
        id: 'stage-1',
        factoryId: factory.id,
        name: 'التقطيع',
        code: 'STAGE-001',
        description: 'مرحلة التقطيع',
        sequence: 1,
        active: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dataSource.upsertProductionStage(stage);
      final results = await dataSource.searchProductionStages('تقطيع');

      expect(results, hasLength(1));
      expect(results.first.sequence, 1);
    });

    test('creates warehouse entries with factory relationship', () async {
      final factory = FactoryProfile(
        id: 'factory-1',
        name: 'مصنع النخبة',
        code: 'F-001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await dataSource.upsertFactory(factory);

      final warehouse = Warehouse(
        id: 'warehouse-1',
        factoryId: factory.id,
        name: 'مخزن المواد',
        code: 'WH-001',
        type: 'مواد خام',
        state: 'active',
        notes: 'مخزن المواد الخام',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dataSource.upsertWarehouse(warehouse);
      final results = await dataSource.searchWarehouses('مواد');

      expect(results, hasLength(1));
      expect(results.first.factoryId, factory.id);
      expect(results.first.type, 'مواد خام');
      expect(results.first.purpose, WarehousePurpose.sellable);
      final persisted = (await dataSource.database).query(
        'warehouses',
        where: 'id = ?',
        whereArgs: [warehouse.id],
      );
      expect((await persisted).single['type'], 'مواد خام');
      expect((await persisted).single['purpose'], 'SELLABLE');
    });

    test(
      'blocks QUARANTINE to SELLABLE while stock quantity is non-zero',
      () async {
        final warehouse = await createPurposeWarehouse(
          'purpose-stock-quarantine',
          WarehousePurpose.quarantine,
        );
        await seedPurposeBalance(warehouse.id, quantity: 5);
        await seedPurposeValuation(warehouse.id, quantity: 5, averageCost: 2);

        await expectPurposeChangeRejected(warehouse, WarehousePurpose.sellable);
      },
    );

    test(
      'blocks purpose change for an exact small non-zero valuation',
      () async {
        final warehouse = await createPurposeWarehouse(
          'purpose-value-rework',
          WarehousePurpose.rework,
        );
        await seedPurposeBalance(warehouse.id, quantity: 0);
        await seedPurposeValuation(
          warehouse.id,
          quantity: 0.0000001,
          averageCost: 0.0000001,
        );

        await expectPurposeChangeRejected(warehouse, WarehousePurpose.sellable);
      },
    );

    test(
      'blocks DAMAGED to SELLABLE with stock and zero valuation value',
      () async {
        final warehouse = await createPurposeWarehouse(
          'purpose-stock-damaged',
          WarehousePurpose.damaged,
        );
        await seedPurposeBalance(warehouse.id, quantity: 3);
        await seedPurposeValuation(warehouse.id, quantity: 0, averageCost: 0);

        await expectPurposeChangeRejected(warehouse, WarehousePurpose.sellable);
      },
    );

    test(
      'allows purpose change when balance and valuation values are zero',
      () async {
        final warehouse = await createPurposeWarehouse(
          'purpose-zero-rows',
          WarehousePurpose.quarantine,
        );
        await seedPurposeBalance(warehouse.id, quantity: 0);
        await seedPurposeValuation(warehouse.id, quantity: 0, averageCost: 8);

        await dataSource.upsertWarehouse(
          warehouse.copyWith(purpose: WarehousePurpose.sellable),
        );

        final state = await purposeState(warehouse.id);
        expect((state['warehouse'] as List).single['purpose'], 'SELLABLE');
        expect((state['balances'] as List).single['quantity'], 0);
        expect((state['valuations'] as List).single['quantity'], 0);
        expect(
          (state['valuations'] as List).single['quantity'] *
              (state['valuations'] as List).single['averageCost'],
          0,
        );
      },
    );

    test(
      'allows purpose change when no balance or valuation rows exist',
      () async {
        final warehouse = await createPurposeWarehouse(
          'purpose-no-rows',
          WarehousePurpose.rework,
        );

        await dataSource.upsertWarehouse(
          warehouse.copyWith(purpose: WarehousePurpose.damaged),
        );

        final state = await purposeState(warehouse.id);
        expect((state['warehouse'] as List).single['purpose'], 'DAMAGED');
      },
    );

    test(
      'allows unrelated warehouse edits while purpose is unchanged',
      () async {
        final warehouse = await createPurposeWarehouse(
          'purpose-name-edit',
          WarehousePurpose.quarantine,
        );
        await seedPurposeBalance(warehouse.id, quantity: 2);
        await seedPurposeValuation(warehouse.id, quantity: 2, averageCost: 5);

        await dataSource.upsertWarehouse(
          warehouse.copyWith(name: 'Updated quarantined warehouse'),
        );

        final state = await purposeState(warehouse.id);
        final persisted = (state['warehouse'] as List).single;
        expect(persisted['name'], 'Updated quarantined warehouse');
        expect(persisted['purpose'], 'QUARANTINE');
        expect((state['balances'] as List).single['quantity'], 2);
        expect((state['valuations'] as List).single['quantity'], 2);
      },
    );

    test('persists an explicit controlled warehouse purpose', () async {
      final factory = FactoryProfile(
        id: 'factory-purpose',
        name: 'مصنع الأغراض',
        code: 'F-PURPOSE',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await dataSource.upsertFactory(factory);
      final warehouse = Warehouse(
        id: 'warehouse-quarantine',
        factoryId: factory.id,
        name: 'مخزن الحجر',
        code: 'WH-QUARANTINE',
        purpose: WarehousePurpose.quarantine,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await dataSource.upsertWarehouse(warehouse);

      final loaded = await dataSource.searchWarehouses('WH-QUARANTINE');
      expect(loaded.single.purpose, WarehousePurpose.quarantine);
      expect(loaded.single.type, isNull);
    });

    test('rejects invalid warehouse state at runtime', () async {
      expect(
        () => Warehouse(
          id: 'warehouse-invalid',
          factoryId: 'factory-1',
          name: 'مخزن',
          code: 'WH-INVALID',
          state: 'ACTIVE',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });
}

Widget _factoryStructureApp(SecurityLocalDataSource security) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: FactoryStructurePage(security: security),
);

Finder _buttonWithText(String text) => find.ancestor(
  of: find.text(text),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);
