import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/raw_materials_products/data/datasources/raw_materials_products_local_data_source.dart';
import 'package:furnexa/features/raw_materials_products/presentation/pages/raw_materials_products_page.dart';
import 'test_helpers/database_test_helper.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

void main() {
  late RawMaterialsProductsLocalDataSource dataSource;
  late SecurityLocalDataSource security;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    dataSource = RawMaterialsProductsLocalDataSource(security);
    final db = await FurnexaDatabase.instance.database;
    await db.delete('sales_delivery_items');
    await db.delete('sales_deliveries');
    await db.delete('sales_order_items');
    await db.delete('sales_orders');
    await db.delete('quotation_items');
    await db.delete('quotations');
    await db.delete('customers');
    await db.delete('stock_transactions');
    await db.delete('stock_balances');
    await db.delete('purchase_receipt_items');
    await db.delete('purchase_receipts');
    await db.delete('purchase_order_items');
    await db.delete('purchase_orders');
    await db.delete('purchase_request_items');
    await db.delete('purchase_requests');
    await db.delete('suppliers');
    await db.delete('product_bom_items');
    await db.delete('product_dimensions');
    await db.delete('product_variants');
    await db.delete('products');
    await db.delete('raw_materials');
    await db.delete('colors');
    await db.delete('units');
    await db.delete('categories');
  });

  testWidgets(
    'Windows inventory list scrollbars use their ListView controllers',
    (tester) async {
      final now = DateTime.now();
      await dataSource.saveCategory(
        Category(
          id: 'scroll-category',
          name: 'تصنيف اختبار التمرير',
          code: 'SCROLL',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveUnit(
        UnitEntity(
          id: 'scroll-unit',
          name: 'قطعة',
          abbreviation: 'PCS',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveColor(
        ItemColor(
          id: 'scroll-color',
          name: 'لون اختبار التمرير',
          code: 'SCROLL-COLOR',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveRawMaterial(
        RawMaterial(
          id: 'scroll-material',
          name: 'خامة اختبار التمرير',
          code: 'SCROLL-MAT',
          categoryId: 'scroll-category',
          unitId: 'scroll-unit',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: RawMaterialsProductsPage(security: security),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tab in ['الوحدات', 'الألوان', 'الخامات', 'المنتجات']) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  test('Feature 2 migration creates tables and version 3', () async {
    expect(
      await FurnexaDatabase.instance.getDatabaseVersion(),
      AppConstants.databaseVersion,
    );
    final tables = await (await FurnexaDatabase.instance.database).query(
      'sqlite_master',
      where: 'type = ?',
      whereArgs: ['table'],
    );
    expect(
      tables.map((row) => row['name']),
      containsAll([
        'categories',
        'units',
        'colors',
        'raw_materials',
        'products',
        'product_variants',
        'product_dimensions',
        'product_bom_items',
      ]),
    );
  });

  test('catalogs persist, search, update, and deactivate', () async {
    final now = DateTime.now();
    final category = Category(
      id: 'cat-1',
      name: 'أخشاب',
      code: 'WOOD',
      createdAt: now,
      updatedAt: now,
    );
    await dataSource.saveCategory(category);
    expect((await dataSource.categories('خش')).single.id, category.id);
    await dataSource.saveCategory(
      Category(
        id: category.id,
        name: 'ألواح خشب',
        code: category.code,
        active: false,
        createdAt: now,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    );
    expect((await dataSource.categories()).single.active, isFalse);
    await dataSource.saveUnit(
      UnitEntity(
        id: 'unit-1',
        name: 'قطعة',
        abbreviation: 'قط',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveCategory(
      Category(
        id: 'product-category',
        name: 'تصنيف منتج نشط',
        code: 'PRODUCT-CATEGORY',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveProduct(
      Product(
        id: 'scroll-product',
        name: 'منتج اختبار التمرير',
        code: 'SCROLL-PRODUCT',
        categoryId: 'product-category',
        unitId: 'unit-1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveColor(
      ItemColor(
        id: 'color-1',
        name: 'بني',
        code: 'BRN',
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(await dataSource.units(), hasLength(1));
    expect(await dataSource.colors(), hasLength(1));
  });

  test('raw materials and products require active references', () async {
    final now = DateTime.now();
    await dataSource.saveCategory(
      Category(
        id: 'cat-1',
        name: 'أخشاب',
        code: 'WOOD',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveUnit(
      UnitEntity(
        id: 'unit-1',
        name: 'قطعة',
        abbreviation: 'قط',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final material = RawMaterial(
      id: 'mat-1',
      name: 'خشب زان',
      code: 'BEECH',
      categoryId: 'cat-1',
      unitId: 'unit-1',
      createdAt: now,
      updatedAt: now,
    );
    await dataSource.saveRawMaterial(material);
    await dataSource.saveProduct(
      Product(
        id: 'product-1',
        name: 'كرسي',
        code: 'CHAIR',
        categoryId: 'cat-1',
        unitId: 'unit-1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect((await dataSource.rawMaterials('زان')).single.id, material.id);
    expect((await dataSource.products('كرسي')).single.code, 'CHAIR');
    await dataSource.saveCategory(
      Category(
        id: 'cat-1',
        name: 'أخشاب',
        code: 'WOOD',
        active: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(
      () => dataSource.saveProduct(
        Product(
          id: 'product-2',
          name: 'طاولة',
          code: 'TABLE',
          categoryId: 'cat-1',
          unitId: 'unit-1',
          createdAt: now,
          updatedAt: now,
        ),
      ),
      throwsException,
    );
  });

  test(
    'base-unit changes are blocked by nonterminal production orders only',
    () async {
      final now = DateTime.now();
      await dataSource.saveCategory(
        Category(
          id: 'unit-guard-category',
          name: 'Unit Guard',
          code: 'UNIT-GUARD',
          createdAt: now,
          updatedAt: now,
        ),
      );
      for (final unit in [
        UnitEntity(
          id: 'unit-guard-base',
          name: 'Base Unit',
          abbreviation: 'BU',
          createdAt: now,
          updatedAt: now,
        ),
        UnitEntity(
          id: 'unit-guard-alternate',
          name: 'Alternate Unit',
          abbreviation: 'AU',
          createdAt: now,
          updatedAt: now,
        ),
      ]) {
        await dataSource.saveUnit(unit);
      }

      final db = await FurnexaDatabase.instance.database;
      for (final status in ['DRAFT', 'PLANNED', 'IN_PROGRESS']) {
        final productId = 'unit-guard-$status';
        final routeId = 'unit-guard-route-$status';
        await dataSource.saveProduct(
          Product(
            id: productId,
            name: 'Unit Guard Product $status',
            code: 'UNIT-GUARD-$status',
            categoryId: 'unit-guard-category',
            unitId: 'unit-guard-base',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.insert('production_routes', {
          'id': routeId,
          'productId': productId,
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        });
        await db.insert('production_orders', {
          'id': 'unit-guard-order-$status',
          'orderNumber': 'UNIT-GUARD-ORDER-$status',
          'productId': productId,
          'routeId': routeId,
          'plannedQuantity': 2,
          'producedQuantity': 0,
          'status': status,
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        });

        await expectLater(
          dataSource.saveProduct(
            Product(
              id: productId,
              name: 'Changed Name $status',
              code: 'UNIT-GUARD-$status',
              categoryId: 'unit-guard-category',
              unitId: 'unit-guard-alternate',
              createdAt: now,
              updatedAt: now,
            ),
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString(),
              'message',
              contains('أوامر إنتاج مفتوحة'),
            ),
          ),
        );

        final unchanged = (await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
        )).single;
        expect(unchanged['unitId'], 'unit-guard-base');
        expect(unchanged['name'], 'Unit Guard Product $status');
        expect(
          (await db.query(
            'production_orders',
            where: 'id = ?',
            whereArgs: ['unit-guard-order-$status'],
          )).single['status'],
          status,
        );

        await dataSource.saveProduct(
          Product(
            id: productId,
            name: 'Updated Metadata $status',
            code: 'UNIT-GUARD-$status',
            categoryId: 'unit-guard-category',
            unitId: 'unit-guard-base',
            createdAt: now,
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
        );
        expect(
          (await db.query(
            'products',
            columns: ['name', 'unitId'],
            where: 'id = ?',
            whereArgs: [productId],
          )).single,
          {'name': 'Updated Metadata $status', 'unitId': 'unit-guard-base'},
        );
      }

      for (final status in ['COMPLETED', 'CANCELLED']) {
        final productId = 'unit-guard-terminal-$status';
        final routeId = 'unit-guard-terminal-route-$status';
        await dataSource.saveProduct(
          Product(
            id: productId,
            name: 'Terminal Product $status',
            code: 'UNIT-GUARD-TERMINAL-$status',
            categoryId: 'unit-guard-category',
            unitId: 'unit-guard-base',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.insert('production_routes', {
          'id': routeId,
          'productId': productId,
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        });
        await db.insert('production_orders', {
          'id': 'unit-guard-terminal-order-$status',
          'orderNumber': 'UNIT-GUARD-TERMINAL-ORDER-$status',
          'productId': productId,
          'routeId': routeId,
          'plannedQuantity': 2,
          'producedQuantity': status == 'COMPLETED' ? 2 : 0,
          'status': status,
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        });

        await dataSource.saveProduct(
          Product(
            id: productId,
            name: 'Terminal Product $status',
            code: 'UNIT-GUARD-TERMINAL-$status',
            categoryId: 'unit-guard-category',
            unitId: 'unit-guard-alternate',
            createdAt: now,
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
        );
        expect(
          (await db.query(
            'products',
            columns: ['unitId'],
            where: 'id = ?',
            whereArgs: [productId],
          )).single['unitId'],
          'unit-guard-alternate',
        );
      }

      final conversionProductId = 'unit-guard-conversion-product';
      await dataSource.saveProduct(
        Product(
          id: conversionProductId,
          name: 'Conversion Product',
          code: 'UNIT-GUARD-CONVERSION',
          categoryId: 'unit-guard-category',
          unitId: 'unit-guard-base',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.insert('production_routes', {
        'id': 'unit-guard-conversion-route',
        'productId': conversionProductId,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.insert('production_orders', {
        'id': 'unit-guard-conversion-order',
        'orderNumber': 'UNIT-GUARD-CONVERSION-ORDER',
        'productId': conversionProductId,
        'routeId': 'unit-guard-conversion-route',
        'plannedQuantity': 2,
        'producedQuantity': 0,
        'status': 'DRAFT',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      final conversion = ProductUnitConversion(
        id: 'unit-guard-conversion',
        productId: conversionProductId,
        unitId: 'unit-guard-alternate',
        factorToBase: 12,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.saveUnitConversion(conversion);
      await dataSource.saveUnitConversion(
        ProductUnitConversion(
          id: conversion.id,
          productId: conversion.productId,
          unitId: conversion.unitId,
          factorToBase: 24,
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 1)),
        ),
      );
      expect(
        (await db.query(
          'product_unit_conversions',
          where: 'id = ?',
          whereArgs: [conversion.id],
        )).single['factorToBase'],
        24,
      );
    },
  );

  test(
    'base-unit changes remain blocked by stock activity and valuation',
    () async {
      final now = DateTime.now();
      await dataSource.saveCategory(
        Category(
          id: 'unit-activity-category',
          name: 'Unit Activity',
          code: 'UNIT-ACTIVITY',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveUnit(
        UnitEntity(
          id: 'unit-activity-base',
          name: 'Base Unit',
          abbreviation: 'BA',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveUnit(
        UnitEntity(
          id: 'unit-activity-new',
          name: 'New Unit',
          abbreviation: 'NU',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final db = await FurnexaDatabase.instance.database;
      await db.insert('factories', {
        'id': 'unit-activity-factory',
        'name': 'Unit Activity Factory',
        'code': 'UNIT-ACTIVITY-FACTORY',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.insert('warehouses', {
        'id': 'unit-activity-warehouse',
        'factoryId': 'unit-activity-factory',
        'name': 'Unit Activity Warehouse',
        'code': 'UNIT-ACTIVITY-WH',
        'state': 'active',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      Future<void> createProduct(String id) => dataSource.saveProduct(
        Product(
          id: id,
          name: id,
          code: id,
          categoryId: 'unit-activity-category',
          unitId: 'unit-activity-base',
          createdAt: now,
          updatedAt: now,
        ),
      );

      Future<void> changeUnit(String id) => dataSource.saveProduct(
        Product(
          id: id,
          name: id,
          code: id,
          categoryId: 'unit-activity-category',
          unitId: 'unit-activity-new',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await createProduct('unit-transaction-product');
      await db.insert('stock_transactions', {
        'id': 'unit-transaction-record',
        'warehouseId': 'unit-activity-warehouse',
        'itemId': 'unit-transaction-product',
        'itemType': 'PRODUCT',
        'productId': 'unit-transaction-product',
        'inventoryIdentityKind': 'BASE',
        'transactionType': 'STOCK_IN',
        'quantity': 1,
        'unitId': 'unit-activity-base',
        'transactionDate': now.millisecondsSinceEpoch,
        'createdAt': now.millisecondsSinceEpoch,
      });
      await expectLater(
        changeUnit('unit-transaction-product'),
        throwsException,
      );
      expect(
        (await db.query(
          'products',
          columns: ['unitId'],
          where: 'id = ?',
          whereArgs: ['unit-transaction-product'],
        )).single['unitId'],
        'unit-activity-base',
      );

      await createProduct('unit-valuation-product');
      await db.insert('inventory_valuations', {
        'id': 'unit-valuation-record',
        'warehouseId': 'unit-activity-warehouse',
        'itemId': 'unit-valuation-product',
        'itemType': 'PRODUCT',
        'productId': 'unit-valuation-product',
        'inventoryIdentityKind': 'BASE',
        'unitId': 'unit-activity-base',
        'quantity': 2,
        'averageCost': 8,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await expectLater(changeUnit('unit-valuation-product'), throwsException);
      expect(
        (await db.query(
          'products',
          columns: ['unitId'],
          where: 'id = ?',
          whereArgs: ['unit-valuation-product'],
        )).single['unitId'],
        'unit-activity-base',
      );
    },
  );

  test(
    'variants, dimensions, and BOM maintain relationships and validate quantity',
    () async {
      final now = DateTime.now();
      await dataSource.saveCategory(
        Category(
          id: 'cat-1',
          name: 'أثاث',
          code: 'FURN',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveUnit(
        UnitEntity(
          id: 'unit-1',
          name: 'قطعة',
          abbreviation: 'قط',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveColor(
        ItemColor(
          id: 'color-1',
          name: 'رمادي',
          code: 'GREY',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveRawMaterial(
        RawMaterial(
          id: 'mat-1',
          name: 'خشب',
          code: 'WOOD',
          categoryId: 'cat-1',
          unitId: 'unit-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveProduct(
        Product(
          id: 'product-1',
          name: 'كرسي',
          code: 'CHAIR',
          categoryId: 'cat-1',
          unitId: 'unit-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveVariant(
        ProductVariant(
          id: 'variant-1',
          productId: 'product-1',
          name: 'رمادي',
          code: 'GREY-1',
          colorId: 'color-1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveDimensions(
        ProductDimension(
          id: 'dimension-1',
          productId: 'product-1',
          variantId: 'variant-1',
          length: 100,
          width: 50,
          height: 80,
          unit: 'سم',
        ),
      );
      await dataSource.saveBomItem(
        BomItem(
          id: 'bom-1',
          productId: 'product-1',
          rawMaterialId: 'mat-1',
          quantity: 2,
        ),
      );
      expect(
        (await dataSource.variants('product-1')).single.colorId,
        'color-1',
      );
      expect((await dataSource.dimensions('product-1')).single.length, 100);
      expect((await dataSource.bom('product-1')).single.quantity, 2);
      expect(
        () => BomItem(
          id: 'bad',
          productId: 'product-1',
          rawMaterialId: 'mat-1',
          quantity: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => dataSource.saveBomItem(
          BomItem(
            id: 'bom-2',
            productId: 'product-1',
            rawMaterialId: 'mat-1',
            quantity: 1,
          ),
        ),
        throwsException,
      );
    },
  );

  test('rejects dimensions for a variant from another product', () async {
    final now = DateTime.now();
    await dataSource.saveCategory(
      Category(
        id: 'cat',
        name: 'أثاث',
        code: 'CAT',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveUnit(
      UnitEntity(
        id: 'unit',
        name: 'قطعة',
        abbreviation: 'PCS',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveProduct(
      Product(
        id: 'product-a',
        name: 'أ',
        code: 'A',
        categoryId: 'cat',
        unitId: 'unit',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveProduct(
      Product(
        id: 'product-b',
        name: 'ب',
        code: 'B',
        categoryId: 'cat',
        unitId: 'unit',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await dataSource.saveVariant(
      ProductVariant(
        id: 'variant-b',
        productId: 'product-b',
        name: 'ب',
        code: 'VB',
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(
      () => dataSource.saveDimensions(
        ProductDimension(
          id: 'dimension-cross',
          productId: 'product-a',
          variantId: 'variant-b',
          length: 1,
        ),
      ),
      throwsException,
    );
  });

  test(
    'rejects invalid persisted product state and preserves dimension uniqueness',
    () async {
      final now = DateTime.now();
      expect(
        () => Product.fromMap({
          'id': 'invalid',
          'name': 'منتج',
          'code': 'INVALID',
          'categoryId': 'cat',
          'unitId': 'unit',
          'productState': 'invalid',
          'active': 1,
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        }),
        throwsArgumentError,
      );
    },
  );

  test(
    'allows one product-level dimension and multiple variant dimensions',
    () async {
      final now = DateTime.now();
      await dataSource.saveCategory(
        Category(
          id: 'cat',
          name: 'أثاث',
          code: 'CAT',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveUnit(
        UnitEntity(
          id: 'unit',
          name: 'قطعة',
          abbreviation: 'PCS',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveProduct(
        Product(
          id: 'product',
          name: 'منتج',
          code: 'PRODUCT',
          categoryId: 'cat',
          unitId: 'unit',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await dataSource.saveDimensions(
        ProductDimension(
          id: 'dimension-product',
          productId: 'product',
          length: 1,
        ),
      );
      final db = await FurnexaDatabase.instance.database;
      expect(
        () => db.insert('product_dimensions', {
          'id': 'dimension-product-duplicate',
          'productId': 'product',
          'variantId': null,
          'length': 2,
        }),
        throwsException,
      );
    },
  );
}
