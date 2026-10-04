import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/features/factory_structure/data/datasources/factory_structure_local_data_source.dart';
import 'package:furnexa/features/factory_structure/data/repositories/factory_structure_repository_impl.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/data/repositories/purchasing_repository_impl.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/repositories/warehouses_stock_repository_impl.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/warehouses_stock/presentation/pages/warehouses_stock_page.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'package:furnexa/features/purchasing/presentation/pages/purchasing_page.dart';

void main() {
  late String originalDirectory;
  late Directory testDirectory;
  late SecurityLocalDataSource security;

  setUp(() async {
    originalDirectory = Directory.current.path;
    testDirectory = await Directory.systemTemp.createTemp(
      'furnexa-persistence-test-',
    );
    Directory.current = testDirectory.path;
    await FurnexaDatabase.instance.resetForTesting();
    security = SecurityLocalDataSource();
    await security.setupInitialAdmin(
      username: 'persistence-admin',
      displayName: 'Persistence Test Admin',
      password: 'Furnexa-Persistence-2026!',
    );
    await security.login('persistence-admin', 'Furnexa-Persistence-2026!');
  });

  tearDown(() async {
    await FurnexaDatabase.instance.close();
    security.logout();
    Directory.current = originalDirectory;
    await testDirectory.delete(recursive: true);
  });

  test('Windows database path is stable and per-user', () {
    expect(
      FurnexaDatabase.windowsDatabasePath(
        localAppData: r'C:\Users\test\AppData\Local',
        fileName: 'furnexa.db',
      ),
      r'C:\Users\test\AppData\Local\Furnexa\furnexa.db',
    );
  });

  test(
    'warehouse and request persist through real repository read paths',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final writePath = db.path;
      final now = DateTime.now();
      final stamp = now.millisecondsSinceEpoch;
      const factoryId = 'persistence-factory';
      const unitId = 'persistence-unit';
      const categoryId = 'persistence-category';
      const materialId = 'persistence-material';

      await db.insert('factories', {
        'id': factoryId,
        'name': 'Persistence Test Factory',
        'code': 'PERSISTENCE-FACTORY',
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await db.insert('categories', {
        'id': categoryId,
        'name': 'Persistence Test Category',
        'code': 'PERSISTENCE-CATEGORY',
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await db.insert('units', {
        'id': unitId,
        'name': 'Persistence Test Unit',
        'abbreviation': 'PST',
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
      await db.insert('raw_materials', {
        'id': materialId,
        'name': 'Persistence Test Material',
        'code': 'PERSISTENCE-MATERIAL',
        'categoryId': categoryId,
        'unitId': unitId,
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });

      final warehouse = Warehouse(
        id: 'persistence-warehouse',
        factoryId: factoryId,
        name: 'Persistence Test Warehouse',
        code: 'PERSISTENCE-WAREHOUSE',
        createdAt: now,
        updatedAt: now,
      );
      final factoryRepository = FactoryStructureRepositoryImpl(
        dataSource: FactoryStructureLocalDataSource(security),
      );
      await factoryRepository.saveWarehouse(warehouse);

      final insertedWarehouse = await db.query(
        'warehouses',
        where: 'id = ?',
        whereArgs: [warehouse.id],
      );
      expect(insertedWarehouse, hasLength(1));
      expect(insertedWarehouse.single['factoryId'], factoryId);
      final warehouseList = await factoryRepository.searchWarehouses('');
      expect(warehouseList.map((value) => value.id), contains(warehouse.id));

      final stockRepository = WarehousesStockRepositoryImpl();
      const stockItem = StockItemOption(
        id: materialId,
        name: 'Persistence Test Material',
        code: 'PERSISTENCE-MATERIAL',
        unitId: unitId,
        type: StockItemType.rawMaterial,
        active: true,
      );
      await stockRepository.stockIn(
        warehouseId: warehouse.id,
        item: stockItem,
        quantity: 42,
        date: now,
      );
      expect(
        (await stockRepository.stock(warehouse.id)).single.balance.quantity,
        42,
      );

      final request = PurchaseRequest(
        id: 'persistence-request',
        requestNumber: 'PERSISTENCE-REQUEST',
        requestDate: now,
        requestedBy: 'Persistence Test',
        status: PurchaseRequestStatus.draft,
        createdAt: now,
        updatedAt: now,
        items: const [
          PurchasingItem(
            id: 'persistence-request-item',
            itemId: materialId,
            itemType: PurchasingItemType.rawMaterial,
            quantity: 1,
            unitId: unitId,
          ),
        ],
      );
      final purchasingRepository = PurchasingRepositoryImpl(
        PurchasingLocalDataSource(),
      );
      await purchasingRepository.saveRequest(request);

      final insertedRequest = await db.query(
        'purchase_requests',
        where: 'id = ?',
        whereArgs: [request.id],
      );
      expect(insertedRequest, hasLength(1));
      final requestList = await purchasingRepository.requests();
      expect(requestList.map((value) => value.id), contains(request.id));
      expect(await FurnexaDatabase.instance.databasePath, writePath);

      await FurnexaDatabase.instance.close();
      final otherWorkingDirectory = await Directory.systemTemp.createTemp(
        'furnexa-persistence-other-cwd-',
      );
      Directory.current = otherWorkingDirectory.path;
      final reopenedDb = await FurnexaDatabase.instance.database;
      expect(reopenedDb.path, writePath);
      expect(
        await reopenedDb.query(
          'warehouses',
          where: 'id = ?',
          whereArgs: [warehouse.id],
        ),
        hasLength(1),
      );
      expect(
        (await factoryRepository.searchWarehouses('')).map((value) => value.id),
        contains(warehouse.id),
      );
      expect(
        await reopenedDb.query(
          'purchase_requests',
          where: 'id = ?',
          whereArgs: [request.id],
        ),
        hasLength(1),
      );
      expect(
        (await purchasingRepository.requests()).map((value) => value.id),
        contains(request.id),
      );
      expect(
        (await stockRepository.stock(warehouse.id)).single.balance.quantity,
        42,
      );
      if (FurnexaDatabaseDiagnostics.enabled) {
        final diagnosticLog = await File(
          await FurnexaDatabaseDiagnostics.logFilePath,
        ).readAsString();
        expect(diagnosticLog, contains('"databasePath"'));
        expect(diagnosticLog, contains('"databaseVersion":27'));
        expect(diagnosticLog, contains('"session"'));
        expect(diagnosticLog, contains('"sqliteWarehouseCount":1'));
        expect(diagnosticLog, contains('"sqlitePurchaseRequestCount":1'));
        expect(diagnosticLog, contains('"warehouseSqlRows":1'));
        expect(diagnosticLog, contains('"stockSqlRows":1'));
        expect(diagnosticLog, contains('"requestSqlRows":1'));
        expect(diagnosticLog, contains('"stockRepositoryRows":1'));
        expect(diagnosticLog, contains('"purchaseRequestRepositoryRows":1'));
      }
      Directory.current = testDirectory.path;
      await otherWorkingDirectory.delete(recursive: true);
    },
  );

  testWidgets('stock and Purchase Request rows reach their page widgets', (
    tester,
  ) async {
    final db = await FurnexaDatabase.instance.database;
    final now = DateTime.now();
    final stamp = now.millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': 'page-factory',
      'name': 'Page Test Factory',
      'code': 'PAGE-FACTORY',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': 'page-category',
      'name': 'Page Test Category',
      'code': 'PAGE-CATEGORY',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': 'page-unit',
      'name': 'Page Test Unit',
      'abbreviation': 'PG',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('raw_materials', {
      'id': 'page-material',
      'name': 'Visible MDF',
      'code': 'VISIBLE-MDF',
      'categoryId': 'page-category',
      'unitId': 'page-unit',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    final warehouse = Warehouse(
      id: 'page-warehouse',
      factoryId: 'page-factory',
      name: 'Page Test Warehouse',
      code: 'PAGE-WAREHOUSE',
      createdAt: now,
      updatedAt: now,
    );
    await FactoryStructureRepositoryImpl(
      dataSource: FactoryStructureLocalDataSource(security),
    ).saveWarehouse(warehouse);

    final stockRepository = WarehousesStockRepositoryImpl();
    const item = StockItemOption(
      id: 'page-material',
      name: 'Visible MDF',
      code: 'VISIBLE-MDF',
      unitId: 'page-unit',
      type: StockItemType.rawMaterial,
      active: true,
    );
    await stockRepository.stockIn(
      warehouseId: warehouse.id,
      item: item,
      quantity: 42,
      date: now,
    );
    await PurchasingRepositoryImpl(PurchasingLocalDataSource()).saveRequest(
      PurchaseRequest(
        id: 'page-request',
        requestNumber: 'VISIBLE-REQUEST',
        requestDate: now,
        requestedBy: 'Page Test',
        status: PurchaseRequestStatus.draft,
        createdAt: now,
        updatedAt: now,
        items: const [
          PurchasingItem(
            id: 'page-request-item',
            itemId: 'page-material',
            itemType: PurchasingItemType.rawMaterial,
            quantity: 1,
            unitId: 'page-unit',
          ),
        ],
      ),
    );

    await tester.pumpWidget(_localizedApp(const WarehousesStockPage()));
    await tester.pumpAndSettle();
    expect(find.textContaining('VISIBLE-MDF'), findsOneWidget);
    expect(find.text('42.0'), findsOneWidget);

    await tester.pumpWidget(_localizedApp(const PurchasingPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلبات الشراء').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('VISIBLE-REQUEST'), findsOneWidget);
  });

  test('authenticated scoped user reads stock and request rows', () async {
    final db = await FurnexaDatabase.instance.database;
    final now = DateTime.now();
    final stamp = now.millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': 'scoped-factory',
      'name': 'Scoped Test Factory',
      'code': 'SCOPED-FACTORY',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': 'scoped-category',
      'name': 'Scoped Category',
      'code': 'SCOPED-CATEGORY',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': 'scoped-unit',
      'name': 'Scoped Unit',
      'abbreviation': 'SC',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('raw_materials', {
      'id': 'scoped-material',
      'name': 'Scoped MDF',
      'code': 'SCOPED-MDF',
      'categoryId': 'scoped-category',
      'unitId': 'scoped-unit',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });

    final factoryRepository = FactoryStructureRepositoryImpl(
      dataSource: FactoryStructureLocalDataSource(security),
    );
    final scopedWarehouse = Warehouse(
      id: 'allowed-warehouse',
      factoryId: 'scoped-factory',
      name: 'Allowed Warehouse',
      code: 'ALLOWED-WAREHOUSE',
      createdAt: now,
      updatedAt: now,
    );
    final outOfScopeWarehouse = Warehouse(
      id: 'out-of-scope-warehouse',
      factoryId: 'scoped-factory',
      name: 'Out of Scope Warehouse',
      code: 'OUT-OF-SCOPE',
      createdAt: now,
      updatedAt: now,
    );
    await factoryRepository.saveWarehouse(scopedWarehouse);
    await factoryRepository.saveWarehouse(outOfScopeWarehouse);

    const item = StockItemOption(
      id: 'scoped-material',
      name: 'Scoped MDF',
      code: 'SCOPED-MDF',
      unitId: 'scoped-unit',
      type: StockItemType.rawMaterial,
      active: true,
    );
    final stockRepository = WarehousesStockRepositoryImpl();
    await stockRepository.stockIn(
      warehouseId: outOfScopeWarehouse.id,
      item: item,
      quantity: 7,
      date: now,
    );

    final role = await security.createRole(name: 'Scoped Purchasing');
    await security.setRolePermissions(role.id, [
      'WAREHOUSE_STOCK_VIEW',
      'WAREHOUSE_STOCK_EDIT',
      'PURCHASING_VIEW',
    ]);
    final user = await security.createUser(
      username: 'scoped-user',
      displayName: 'Scoped User',
      password: 'Furnexa-Scoped-User-2026!',
      roleId: role.id,
    );
    await security.setUserScopes(user.id, [
      UserScope(
        id: 'test-scope',
        userId: user.id,
        type: ScopeType.warehouse,
        scopeId: scopedWarehouse.id,
      ),
    ]);
    security.logout();
    final session = await security.login(
      'scoped-user',
      'Furnexa-Scoped-User-2026!',
    );
    expect(session.isSystemAdmin, isFalse);
    expect(session.scopes.single.scopeId, scopedWarehouse.id);

    final newlyCreatedWarehouse = Warehouse(
      id: 'created-by-scoped-user',
      factoryId: 'scoped-factory',
      name: 'Created by Scoped User',
      code: 'SCOPED-CREATED',
      createdAt: now,
      updatedAt: now,
    );
    await factoryRepository.saveWarehouse(newlyCreatedWarehouse);

    final factoryVisible = await factoryRepository.searchWarehouses('');
    expect(
      factoryVisible.map((warehouse) => warehouse.id),
      isNot(contains(newlyCreatedWarehouse.id)),
    );
    final stockWarehouses = await stockRepository.warehouses();
    expect(
      stockWarehouses.map((warehouse) => warehouse.id),
      contains(newlyCreatedWarehouse.id),
    );
    final stockRows = await stockRepository.stock(outOfScopeWarehouse.id);
    expect(stockRows.single.item.id, item.id);
    expect(stockRows.single.balance.quantity, 7);

    final request = PurchaseRequest(
      id: 'scoped-request',
      requestNumber: 'SCOPED-REQUEST',
      requestDate: now,
      requestedBy: user.displayName,
      status: PurchaseRequestStatus.draft,
      createdAt: now,
      updatedAt: now,
      items: const [
        PurchasingItem(
          id: 'scoped-request-item',
          itemId: 'scoped-material',
          itemType: PurchasingItemType.rawMaterial,
          quantity: 3,
          unitId: 'scoped-unit',
        ),
      ],
    );
    final purchasingRepository = PurchasingRepositoryImpl(
      PurchasingLocalDataSource(),
    );
    await purchasingRepository.saveRequest(request);
    expect(
      (await purchasingRepository.requests()).map((value) => value.id),
      contains(request.id),
    );
  });
}

Widget _localizedApp(Widget home) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);
