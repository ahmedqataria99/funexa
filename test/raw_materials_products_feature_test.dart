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
    await dataSource.saveProduct(
      Product(
        id: 'scroll-product',
        name: 'منتج اختبار التمرير',
        code: 'SCROLL-PRODUCT',
        categoryId: 'scroll-category',
        unitId: 'scroll-unit',
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
