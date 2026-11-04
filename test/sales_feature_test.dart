import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/sales/presentation/pages/sales_page.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late SalesLocalDataSource dataSource;
  late String suffix;
  late DateTime now;
  late String warehouseId, unitId, productId, customerId;

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login('admin', 'Furnexa-Test-Admin-2026!');
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime(2026, 9, 17);
    dataSource = SalesLocalDataSource();
    final db = await FurnexaDatabase.instance.database;
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
    await db.delete('stock_transactions');
    await db.delete('inventory_valuations');
    await db.delete('stock_balances');
    await db.delete('product_bom_items');
    await db.delete('product_dimensions');
    await db.delete('product_variants');
    await db.delete('products');
    await db.delete('raw_materials');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('warehouses');
    await db.delete('production_stages');
    await db.delete('factories');
    final stamp = now.millisecondsSinceEpoch;
    final factoryId = 'sales-factory-$suffix';
    final categoryId = 'sales-category-$suffix';
    warehouseId = 'sales-warehouse-$suffix';
    unitId = 'sales-unit-$suffix';
    productId = 'sales-product-$suffix';
    customerId = 'sales-customer-$suffix';
    await db.insert('factories', {
      'id': factoryId,
      'name': 'مصنع مبيعات $suffix',
      'code': 'SF-$suffix',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'مخزن مبيعات $suffix',
      'code': 'SW-$suffix',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'تصنيف مبيعات $suffix',
      'code': 'SC-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'وحدة مبيعات $suffix',
      'abbreviation': 'SU$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'منتج مبيعات $suffix',
      'code': 'SP-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('customers', {
      'id': customerId,
      'name': 'عميل مبيعات $suffix',
      'code': 'CU-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('stock_balances', {
      'id': 'sales-balance-$suffix',
      'warehouseId': warehouseId,
      'itemId': productId,
      'itemType': 'PRODUCT',
      'quantity': 100,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  test(
    'customer search matches code and phone and rejects duplicate codes',
    () async {
      final customer = Customer(
        id: 'sales-customer-search-$suffix',
        name: 'عميل بحث مبيعات',
        code: 'CUS-SEARCH-$suffix',
        phone: '01012345678',
        email: 'search@example.com',
        active: true,
        createdAt: now,
        updatedAt: now,
      );
      await dataSource.saveCustomer(customer);

      final byPhone = await dataSource.customers('01012345678');
      expect(byPhone.single.id, customer.id);

      final byCode = await dataSource.customers('CUS-SEARCH');
      expect(byCode.single.id, customer.id);

      expect(
        () => dataSource.saveCustomer(
          Customer(
            id: 'sales-customer-duplicate-$suffix',
            name: 'عميل مكرر',
            code: customer.code,
            phone: '01099999999',
            active: true,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsException,
      );
    },
  );

  test('multi-line sales draft persists items and totals on reload', () async {
    final db = await FurnexaDatabase.instance.database;
    final secondProductId = 'sales-product-2-$suffix';
    await db.insert('products', {
      'id': secondProductId,
      'name': 'منتج مبيعات 2 $suffix',
      'code': 'SP2-$suffix',
      'categoryId': 'sales-category-$suffix',
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    final quotation = Quotation(
      id: 'multi-quotation-$suffix',
      quotationNumber: 'QT-MULTI-$suffix',
      customerId: customerId,
      quotationDate: now,
      status: QuotationStatus.draft,
      subtotal: 175,
      discount: 5,
      tax: 12.5,
      grandTotal: 182.5,
      createdAt: now,
      updatedAt: now,
      items: [
        SalesItem(
          id: 'multi-item-a-$suffix',
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 10,
          unitId: unitId,
          unitPrice: 10,
          discount: 2,
          tax: 5,
          lineTotal: 103,
        ),
        SalesItem(
          id: 'multi-item-b-$suffix',
          itemId: secondProductId,
          itemType: SalesItemType.product,
          quantity: 5,
          unitId: unitId,
          unitPrice: 15,
          discount: 3,
          tax: 7.5,
          lineTotal: 79.5,
        ),
      ],
    );
    await dataSource.saveQuotation(quotation);
    final saved = (await dataSource.quotations()).single;
    expect(saved.items, hasLength(2));
    expect(saved.subtotal, 175);
    expect(saved.discount, 5);
    expect(saved.tax, 12.5);
    expect(saved.grandTotal, 182.5);
    expect(
      saved.items.map((item) => item.itemId),
      containsAll([productId, secondProductId]),
    );
  });

  test(
    'sales document pdf generation resolves persisted customer and product identities',
    () async {
      final catalog = [
        StockItemOption(
          id: productId,
          name: 'منتج مبيعات $suffix',
          code: 'SP-$suffix',
          unitId: unitId,
          type: StockItemType.product,
          active: true,
        ),
      ];
      final bytes = await generateSalesDocumentPdf(
        factoryName: 'مصنع مبيعات $suffix',
        title: 'عرض سعر',
        number: 'QT-TEST-$suffix',
        date: now,
        customer: Customer(
          id: customerId,
          name: 'عميل مبيعات $suffix',
          code: 'CU-$suffix',
          phone: '01012345678',
          createdAt: now,
          updatedAt: now,
        ),
        notes: 'ملاحظات التسعير',
        items: [
          SalesItem(
            id: 'line-$suffix',
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 3,
            unitId: unitId,
            unitPrice: 40,
            discount: 5,
            tax: 6,
            lineTotal: 123,
          ),
        ],
        catalog: catalog,
      );
      expect(bytes, isNotEmpty);
    },
  );

  SalesOrder order(String id, {double delivered = 0}) => SalesOrder(
    id: id,
    orderNumber: 'SO-$id',
    customerId: customerId,
    orderDate: now,
    status: SalesOrderStatus.confirmed,
    subtotal: 100,
    discount: 0,
    tax: 0,
    grandTotal: 100,
    createdAt: now,
    updatedAt: now,
    items: [
      SalesItem(
        id: '$id-item',
        itemId: productId,
        itemType: SalesItemType.product,
        quantity: 100,
        unitId: unitId,
        unitPrice: 1,
        deliveredQuantity: delivered,
        lineTotal: 100,
      ),
    ],
  );

  SalesOrder orderWithItems(String id, List<SalesItem> items) => SalesOrder(
    id: id,
    orderNumber: 'SO-$id',
    customerId: customerId,
    orderDate: now,
    status: SalesOrderStatus.confirmed,
    subtotal: 100,
    discount: 0,
    tax: 0,
    grandTotal: 100,
    createdAt: now,
    updatedAt: now,
    items: items,
  );

  SalesOrder copyOrder(
    SalesOrder value, {
    SalesOrderStatus? status,
    String? notes,
    List<SalesItem>? items,
  }) => SalesOrder(
    id: value.id,
    orderNumber: value.orderNumber,
    customerId: value.customerId,
    quotationId: value.quotationId,
    orderDate: value.orderDate,
    expectedDeliveryDate: value.expectedDeliveryDate,
    status: status ?? value.status,
    subtotal: value.subtotal,
    discount: value.discount,
    tax: value.tax,
    grandTotal: value.grandTotal,
    notes: notes ?? value.notes,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
    items: items ?? value.items,
  );

  Future<void> seedProductValuation({
    double quantity = 100,
    double averageCost = 5,
  }) async {
    final db = await FurnexaDatabase.instance.database;
    await db.insert('inventory_valuations', {
      'id': 'sales-valuation-$suffix',
      'warehouseId': warehouseId,
      'itemId': productId,
      'itemType': 'PRODUCT',
      'productId': productId,
      'variantId': null,
      'inventoryIdentityKind': 'BASE',
      'unitId': unitId,
      'quantity': quantity,
      'averageCost': averageCost,
      'updatedAt': now.millisecondsSinceEpoch,
    });
  }

  Future<void> seedVariantInventory({
    required String variantId,
    required double quantity,
    required double averageCost,
  }) async {
    final db = await FurnexaDatabase.instance.database;
    final inventoryId = inventoryItemKey(
      productId: productId,
      type: StockItemType.product,
      variantId: variantId,
      identityKind: InventoryIdentityKind.variant,
    );
    await db.insert('stock_balances', {
      'id': 'sales-balance-$variantId-$suffix',
      'warehouseId': warehouseId,
      'itemId': inventoryId,
      'itemType': 'PRODUCT',
      'productId': productId,
      'variantId': variantId,
      'inventoryIdentityKind': 'VARIANT',
      'unitId': unitId,
      'quantity': quantity,
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    await db.insert('inventory_valuations', {
      'id': 'sales-valuation-$variantId-$suffix',
      'warehouseId': warehouseId,
      'itemId': inventoryId,
      'itemType': 'PRODUCT',
      'productId': productId,
      'variantId': variantId,
      'inventoryIdentityKind': 'VARIANT',
      'unitId': unitId,
      'quantity': quantity,
      'averageCost': averageCost,
      'updatedAt': now.millisecondsSinceEpoch,
    });
  }

  Future<String> createSecondaryWarehouse() async {
    final db = await FurnexaDatabase.instance.database;
    final primary = (await db.query(
      'warehouses',
      columns: ['factoryId'],
      where: 'id = ?',
      whereArgs: [warehouseId],
    )).single;
    final id = 'sales-warehouse-secondary-$suffix';
    await db.insert('warehouses', {
      'id': id,
      'factoryId': primary['factoryId'],
      'name': 'مخزن ثانوي $suffix',
      'code': 'SWS-$suffix',
      'state': 'active',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });
    return id;
  }

  Future<void> seedBaseStock(String targetWarehouseId, double quantity) async {
    final db = await FurnexaDatabase.instance.database;
    final existing = await db.query(
      'stock_balances',
      columns: ['id'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [targetWarehouseId, productId, 'PRODUCT'],
    );
    final values = {
      'quantity': quantity,
      'productId': productId,
      'variantId': null,
      'inventoryIdentityKind': 'BASE',
      'unitId': unitId,
      'updatedAt': now.millisecondsSinceEpoch,
    };
    if (existing.isEmpty) {
      await db.insert('stock_balances', {
        'id': 'sales-base-balance-$targetWarehouseId-$suffix',
        'warehouseId': targetWarehouseId,
        'itemId': productId,
        'itemType': 'PRODUCT',
        'createdAt': now.millisecondsSinceEpoch,
        ...values,
      });
    } else {
      await db.update(
        'stock_balances',
        values,
        where: 'id = ?',
        whereArgs: [existing.single['id']],
      );
    }
  }

  Future<void> seedBaseValuation(
    String targetWarehouseId, {
    required double quantity,
    required double averageCost,
  }) async {
    final db = await FurnexaDatabase.instance.database;
    final existing = await db.query(
      'inventory_valuations',
      columns: ['id'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [targetWarehouseId, productId, 'PRODUCT'],
    );
    final values = {
      'quantity': quantity,
      'averageCost': averageCost,
      'productId': productId,
      'variantId': null,
      'inventoryIdentityKind': 'BASE',
      'unitId': unitId,
      'updatedAt': now.millisecondsSinceEpoch,
    };
    if (existing.isEmpty) {
      await db.insert('inventory_valuations', {
        'id': 'sales-base-valuation-$targetWarehouseId-$suffix',
        'warehouseId': targetWarehouseId,
        'itemId': productId,
        'itemType': 'PRODUCT',
        ...values,
      });
    } else {
      await db.update(
        'inventory_valuations',
        values,
        where: 'id = ?',
        whereArgs: [existing.single['id']],
      );
    }
  }

  Future<Map<String, Object?>> deliveryIdentityMutationState(
    String orderId,
  ) async {
    final db = await FurnexaDatabase.instance.database;
    return {
      'deliveries': await db.query(
        'sales_deliveries',
        where: 'salesOrderId = ?',
        whereArgs: [orderId],
      ),
      'deliveryItems': await db.rawQuery(
        '''
        SELECT sdi.* FROM sales_delivery_items sdi
        JOIN sales_deliveries sd ON sd.id = sdi.salesDeliveryId
        WHERE sd.salesOrderId = ?
        ''',
        [orderId],
      ),
      'stockBalances': await db.query(
        'stock_balances',
        where: 'itemType = ? AND (itemId = ? OR productId = ?)',
        whereArgs: ['PRODUCT', productId, productId],
      ),
      'valuations': await db.query(
        'inventory_valuations',
        where: 'itemType = ? AND (itemId = ? OR productId = ?)',
        whereArgs: ['PRODUCT', productId, productId],
      ),
      'stockTransactions': await db.query(
        'stock_transactions',
        where: 'itemType = ? AND (itemId = ? OR productId = ?)',
        whereArgs: ['PRODUCT', productId, productId],
      ),
      'orderItems': await db.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [orderId],
      ),
      'order': await db.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [orderId],
      ),
      'journalEntries': await db.query('journal_entries', orderBy: 'id ASC'),
      'journalLines': await db.query('journal_lines', orderBy: 'id ASC'),
      'journalParties': await db.query(
        'journal_parties',
        orderBy: 'journalEntryId ASC',
      ),
    };
  }

  Future<Map<String, Object?>> deliveryMutationState(String orderId) async {
    final db = await FurnexaDatabase.instance.database;
    return {
      'deliveries': await db.query(
        'sales_deliveries',
        where: 'salesOrderId = ?',
        whereArgs: [orderId],
      ),
      'deliveryItems': await db.rawQuery(
        '''
        SELECT sdi.* FROM sales_delivery_items sdi
        JOIN sales_deliveries sd ON sd.id = sdi.salesDeliveryId
        WHERE sd.salesOrderId = ?
        ''',
        [orderId],
      ),
      'stockBalances': await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      ),
      'valuations': await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      ),
      'stockTransactions': await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      ),
      'orderItems': await db.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [orderId],
      ),
      'order': await db.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [orderId],
      ),
      'journalEntries': await db.query('journal_entries', orderBy: 'id ASC'),
      'journalLines': await db.query('journal_lines', orderBy: 'id ASC'),
      'journalParties': await db.query(
        'journal_parties',
        orderBy: 'journalEntryId ASC',
      ),
    };
  }

  test('delivery operation ID rejects a mismatched quantity payload', () async {
    final value = order('operation-payload-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation();
    const operationId = 'delivery-operation-payload-mismatch';
    await dataSource.postDelivery(
      order: value,
      operationId: operationId,
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: value.items.single.id,
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 10,
          unitId: unitId,
        ),
      ],
    );
    final beforeRetry = await deliveryMutationState(value.id);

    await expectLater(
      dataSource.postDelivery(
        order: value,
        operationId: operationId,
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 11,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );

    expect(await deliveryMutationState(value.id), beforeRetry);
  });

  test(
    'delivery operation ID replays an identical line-notes payload',
    () async {
      final value = order('operation-notes-replay-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final requestItem = SalesItem(
        id: value.items.single.id,
        itemId: productId,
        itemType: SalesItemType.product,
        quantity: 10,
        unitId: unitId,
        notes: 'Fragile - keep upright',
      );
      const operationId = 'delivery-operation-identical-notes';
      final first = await dataSource.postDelivery(
        order: value,
        operationId: '$operationId-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [requestItem],
      );
      final db = await FurnexaDatabase.instance.database;
      final firstLine = (await db.query(
        'sales_delivery_items',
        where: 'salesDeliveryId = ?',
        whereArgs: [first.id],
      )).single;
      expect(firstLine['notes'], 'Fragile - keep upright');
      final beforeReplay = await deliveryMutationState(value.id);

      final replay = await dataSource.postDelivery(
        order: value,
        operationId: '$operationId-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [requestItem],
      );

      expect(replay.id, first.id);
      expect(replay.deliveryNumber, first.deliveryNumber);
      expect(await deliveryMutationState(value.id), beforeReplay);
      expect(
        await db.query(
          'sales_deliveries',
          where: 'salesOrderId = ?',
          whereArgs: [value.id],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'sales_delivery_items',
          where: 'salesDeliveryId = ?',
          whereArgs: [first.id],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'reference = ?',
          whereArgs: [first.deliveryNumber],
        ),
        hasLength(1),
      );
      final journals = await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['SALES_DELIVERY', first.id],
      );
      expect(journals, hasLength(1));
      expect(
        await db.query(
          'journal_lines',
          where: 'journalEntryId = ?',
          whereArgs: [journals.single['id']],
        ),
        hasLength(4),
      );
    },
  );

  test(
    'delivery operation ID rejects changed line notes without writes',
    () async {
      final value = order('operation-notes-mismatch-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final first = await dataSource.postDelivery(
        order: value,
        operationId: 'delivery-operation-changed-notes-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 10,
            unitId: unitId,
            notes: 'First note',
          ),
        ],
      );
      final beforeRetry = await deliveryMutationState(value.id);

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: 'delivery-operation-changed-notes-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 10,
              unitId: unitId,
              notes: 'Second note',
            ),
          ],
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'معرف عملية التسليم مستخدم لبيانات مختلفة',
            ),
          ),
        ),
      );

      expect(await deliveryMutationState(value.id), beforeRetry);
      final db = await FurnexaDatabase.instance.database;
      expect(
        (await db.query(
          'sales_delivery_items',
          where: 'salesDeliveryId = ?',
          whereArgs: [first.id],
        )).single['notes'],
        'First note',
      );
    },
  );

  test(
    'delivery operation ID distinguishes null and empty line notes',
    () async {
      final value = order('operation-notes-null-empty-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final first = await dataSource.postDelivery(
        order: value,
        operationId: 'delivery-operation-null-empty-notes-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 10,
            unitId: unitId,
            notes: null,
          ),
        ],
      );
      final beforeRetry = await deliveryMutationState(value.id);

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: 'delivery-operation-null-empty-notes-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 10,
              unitId: unitId,
              notes: '',
            ),
          ],
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'معرف عملية التسليم مستخدم لبيانات مختلفة',
            ),
          ),
        ),
      );

      expect(await deliveryMutationState(value.id), beforeRetry);
      final db = await FurnexaDatabase.instance.database;
      expect(
        (await db.query(
          'sales_delivery_items',
          where: 'salesDeliveryId = ?',
          whereArgs: [first.id],
        )).single['notes'],
        isNull,
      );
    },
  );

  test(
    'delivery rejects duplicate order-line IDs with different quantities',
    () async {
      final value = order('duplicate-line-quantities-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final before = await deliveryMutationState(value.id);

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: 'duplicate-line-quantities-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 3,
              unitId: unitId,
              notes: 'First quantity',
            ),
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 4,
              unitId: unitId,
              notes: 'Second quantity',
            ),
          ],
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا يمكن تكرار بند أمر البيع في طلب التسليم',
            ),
          ),
        ),
      );

      expect(await deliveryMutationState(value.id), before);
    },
  );

  test(
    'delivery rejects duplicate order-line IDs with different notes',
    () async {
      final value = order('duplicate-line-notes-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final before = await deliveryMutationState(value.id);

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: 'duplicate-line-notes-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 3,
              unitId: unitId,
              notes: 'First note',
            ),
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 3,
              unitId: unitId,
              notes: 'Second note',
            ),
          ],
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا يمكن تكرار بند أمر البيع في طلب التسليم',
            ),
          ),
        ),
      );

      expect(await deliveryMutationState(value.id), before);
    },
  );

  test(
    'delivery rejects duplicate order-line IDs with identical payloads',
    () async {
      final value = order('duplicate-line-identical-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final before = await deliveryMutationState(value.id);
      final duplicateItem = SalesItem(
        id: value.items.single.id,
        itemId: productId,
        itemType: SalesItemType.product,
        quantity: 3,
        unitId: unitId,
        notes: 'Same note',
      );

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: 'duplicate-line-identical-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [duplicateItem, duplicateItem],
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا يمكن تكرار بند أمر البيع في طلب التسليم',
            ),
          ),
        ),
      );

      expect(await deliveryMutationState(value.id), before);
    },
  );

  test(
    'delivery rejects duplicate order-line IDs before operation replay',
    () async {
      final value = order('duplicate-line-replay-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final operationId = 'duplicate-line-replay-$suffix';
      final first = await dataSource.postDelivery(
        order: value,
        operationId: operationId,
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 6,
            unitId: unitId,
            notes: 'Same note',
          ),
        ],
      );
      final beforeDuplicateReplay = await deliveryMutationState(value.id);

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: operationId,
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 3,
              unitId: unitId,
              notes: 'Same note',
            ),
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 3,
              unitId: unitId,
              notes: 'Same note',
            ),
          ],
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'لا يمكن تكرار بند أمر البيع في طلب التسليم',
            ),
          ),
        ),
      );

      expect(await deliveryMutationState(value.id), beforeDuplicateReplay);
      expect((await dataSource.deliveries(value.id)).single.id, first.id);
    },
  );

  test(
    'delivery operation ID replays and distinguishes whitespace-only notes',
    () async {
      final value = order('operation-whitespace-notes-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      const whitespaceNotes = ' \t ';
      final requestItem = SalesItem(
        id: value.items.single.id,
        itemId: productId,
        itemType: SalesItemType.product,
        quantity: 10,
        unitId: unitId,
        notes: whitespaceNotes,
      );
      final operationId = 'delivery-operation-whitespace-notes-$suffix';
      final first = await dataSource.postDelivery(
        order: value,
        operationId: operationId,
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [requestItem],
      );
      final db = await FurnexaDatabase.instance.database;
      expect(
        (await db.query(
          'sales_delivery_items',
          where: 'salesDeliveryId = ?',
          whereArgs: [first.id],
        )).single['notes'],
        whitespaceNotes,
      );
      final beforeReplay = await deliveryMutationState(value.id);

      final replay = await dataSource.postDelivery(
        order: value,
        operationId: operationId,
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [requestItem],
      );

      expect(replay.id, first.id);
      expect(await deliveryMutationState(value.id), beforeReplay);

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: operationId,
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 10,
              unitId: unitId,
              notes: '',
            ),
          ],
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains(
              'معرف عملية التسليم مستخدم لبيانات مختلفة',
            ),
          ),
        ),
      );

      expect(await deliveryMutationState(value.id), beforeReplay);
    },
  );

  test(
    'delivery journal failure rolls back stock valuation and order updates',
    () async {
      final value = order('journal-failure-delivery-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final beforeDelivery = await deliveryMutationState(value.id);
      final db = await FurnexaDatabase.instance.database;
      await db.execute('''
      CREATE TRIGGER fail_sales_delivery_journal_insert
      BEFORE INSERT ON journal_entries
      WHEN NEW.referenceType = 'SALES_DELIVERY'
      BEGIN
        SELECT RAISE(ABORT, 'injected sales delivery journal failure');
      END
    ''');
      try {
        await expectLater(
          dataSource.postDelivery(
            order: value,
            operationId: 'journal-failure-operation-$suffix',
            warehouseId: warehouseId,
            deliveryDate: now,
            items: [
              SalesItem(
                id: value.items.single.id,
                itemId: productId,
                itemType: SalesItemType.product,
                quantity: 10,
                unitId: unitId,
              ),
            ],
          ),
          throwsA(
            predicate(
              (error) => error.toString().contains(
                'injected sales delivery journal failure',
              ),
            ),
          ),
        );
      } finally {
        await db.execute(
          'DROP TRIGGER IF EXISTS fail_sales_delivery_journal_insert',
        );
      }

      expect(await deliveryMutationState(value.id), beforeDelivery);
    },
  );

  test('delivery rolls back when valuation quantity is insufficient', () async {
    final value = order('valuation-insufficient-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation(quantity: 5);
    final beforeDelivery = await deliveryMutationState(value.id);

    await expectLater(
      dataSource.postDelivery(
        order: value,
        operationId: 'valuation-insufficient-operation-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 10,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );

    expect(await deliveryMutationState(value.id), beforeDelivery);
  });

  test('delivery rolls back when stock balance is insufficient', () async {
    final value = order('stock-insufficient-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation(quantity: 100);
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'stock_balances',
      {'quantity': 5},
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    );
    final beforeDelivery = await deliveryMutationState(value.id);

    await expectLater(
      dataSource.postDelivery(
        order: value,
        operationId: 'stock-insufficient-operation-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 10,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );

    expect(await deliveryMutationState(value.id), beforeDelivery);
  });

  test(
    'sales delivery rejects a restricted warehouse without mutations',
    () async {
      final value = order('restricted-delivery-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'warehouses',
        {'purpose': 'QUARANTINE'},
        where: 'id = ?',
        whereArgs: [warehouseId],
      );
      final before = await deliveryMutationState(value.id);

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: 'restricted-delivery-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 5,
              unitId: unitId,
            ),
          ],
        ),
        throwsA(predicate((error) => error.toString().contains('QUARANTINE'))),
      );

      expect(await deliveryMutationState(value.id), before);
    },
  );

  test('delivery posts persisted balanced revenue and COGS lines', () async {
    final value = order('accounting-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation();
    await dataSource.postDelivery(
      order: value,
      operationId: 'accounting-delivery-$suffix',
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: value.items.single.id,
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 10,
          unitId: unitId,
        ),
      ],
    );

    final db = await FurnexaDatabase.instance.database;
    final delivery = (await dataSource.deliveries(value.id)).single;
    final journals = await db.query(
      'journal_entries',
      where: 'referenceType = ? AND referenceId = ?',
      whereArgs: ['SALES_DELIVERY', delivery.id],
    );
    expect(journals, hasLength(1));
    final journalParties = await db.query(
      'journal_parties',
      where: 'journalEntryId = ?',
      whereArgs: [journals.single['id']],
    );
    expect(journalParties, hasLength(1));
    expect(journalParties.single['partyType'], 'CUSTOMER');
    expect(journalParties.single['partyId'], customerId);
    final persistedLines = await db.rawQuery(
      '''
      SELECT a.code AS accountCode, jl.debit, jl.credit
      FROM journal_lines jl
      JOIN accounts a ON a.id = jl.accountId
      WHERE jl.journalEntryId = ?
      ''',
      [journals.single['id']],
    );
    expect(persistedLines, hasLength(4));

    final receivable = persistedLines.singleWhere(
      (line) => line['accountCode'] == '1200',
    );
    final revenue = persistedLines.singleWhere(
      (line) => line['accountCode'] == '4000',
    );
    final cogs = persistedLines.singleWhere(
      (line) => line['accountCode'] == '5000',
    );
    final inventory = persistedLines.singleWhere(
      (line) => line['accountCode'] == '1100',
    );
    expect((receivable['debit'] as num).toDouble(), closeTo(10, 0.000001));
    expect((revenue['credit'] as num).toDouble(), closeTo(10, 0.000001));
    expect((cogs['debit'] as num).toDouble(), closeTo(50, 0.000001));
    expect((inventory['credit'] as num).toDouble(), closeTo(50, 0.000001));
    final totalDebits = persistedLines.fold<double>(
      0,
      (sum, line) => sum + (line['debit'] as num).toDouble(),
    );
    final totalCredits = persistedLines.fold<double>(
      0,
      (sum, line) => sum + (line['credit'] as num).toDouble(),
    );
    expect(totalDebits, closeTo(60, 0.000001));
    expect(totalCredits, closeTo(60, 0.000001));
    expect(totalDebits, closeTo(totalCredits, 0.000001));
    final stock = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    );
    final valuation = await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    );
    expect((stock.single['quantity'] as num).toDouble(), 90);
    expect((valuation.single['quantity'] as num).toDouble(), 90);
    expect((valuation.single['averageCost'] as num).toDouble(), 5);
  });

  test('delivery consumes only the requested variant identity', () async {
    final db = await FurnexaDatabase.instance.database;
    final variantA = 'sales-variant-a-$suffix';
    final variantB = 'sales-variant-b-$suffix';
    for (final variant in [variantA, variantB]) {
      await db.insert('product_variants', {
        'id': variant,
        'productId': productId,
        'name': variant,
        'code': 'SV-$variant',
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
    }
    await seedVariantInventory(
      variantId: variantA,
      quantity: 20,
      averageCost: 4,
    );
    await seedVariantInventory(
      variantId: variantB,
      quantity: 30,
      averageCost: 9,
    );
    final inventoryIdA = inventoryItemKey(
      productId: productId,
      type: StockItemType.product,
      variantId: variantA,
      identityKind: InventoryIdentityKind.variant,
    );
    final inventoryIdB = inventoryItemKey(
      productId: productId,
      type: StockItemType.product,
      variantId: variantB,
      identityKind: InventoryIdentityKind.variant,
    );
    final value = orderWithItems('variant-isolation-$suffix', [
      SalesItem(
        id: 'variant-isolation-a-$suffix',
        itemId: productId,
        itemType: SalesItemType.product,
        quantity: 10,
        unitId: unitId,
        baseUnitId: unitId,
        baseQuantity: 10,
        variantId: variantA,
        inventoryIdentityKind: 'VARIANT',
        unitPrice: 5,
        lineTotal: 50,
      ),
      SalesItem(
        id: 'variant-isolation-b-$suffix',
        itemId: productId,
        itemType: SalesItemType.product,
        quantity: 10,
        unitId: unitId,
        baseUnitId: unitId,
        baseQuantity: 10,
        variantId: variantB,
        inventoryIdentityKind: 'VARIANT',
        unitPrice: 5,
        lineTotal: 50,
      ),
    ]);
    await dataSource.saveOrder(value);
    final variantABalanceBefore = (await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, inventoryIdA, 'PRODUCT'],
    )).single;
    final variantAValuationBefore = (await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, inventoryIdA, 'PRODUCT'],
    )).single;
    final variantBBalanceBefore = (await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, inventoryIdB, 'PRODUCT'],
    )).single;
    final variantBValuationBefore = (await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, inventoryIdB, 'PRODUCT'],
    )).single;
    final baseBalanceBefore = (await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    )).single;
    final orderLinesBefore = await db.query(
      'sales_order_items',
      where: 'salesOrderId = ?',
      whereArgs: [value.id],
    );
    final deliveryJournalCountBefore = await db.query(
      'journal_entries',
      where: 'referenceType = ?',
      whereArgs: ['SALES_DELIVERY'],
    );

    await dataSource.postDelivery(
      order: value,
      operationId: 'variant-isolation-delivery-$suffix',
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: 'variant-isolation-a-$suffix',
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 4,
          unitId: unitId,
          baseUnitId: unitId,
          baseQuantity: 4,
          variantId: variantA,
          inventoryIdentityKind: 'VARIANT',
        ),
      ],
    );

    final variantABalance = (await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, inventoryIdA, 'PRODUCT'],
    )).single;
    final variantAValuation = (await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, inventoryIdA, 'PRODUCT'],
    )).single;
    expect((variantABalanceBefore['quantity'] as num).toDouble(), 20);
    expect((variantAValuationBefore['quantity'] as num).toDouble(), 20);
    expect(
      (variantAValuationBefore['quantity'] as num).toDouble() *
          (variantAValuationBefore['averageCost'] as num).toDouble(),
      80,
    );
    expect((variantABalance['quantity'] as num).toDouble(), 16);
    expect((variantAValuation['quantity'] as num).toDouble(), 16);
    expect((variantAValuation['averageCost'] as num).toDouble(), 4);
    expect(
      (variantAValuation['quantity'] as num).toDouble() *
          (variantAValuation['averageCost'] as num).toDouble(),
      64,
    );
    expect(
      (await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, inventoryIdB, 'PRODUCT'],
      )).single,
      variantBBalanceBefore,
    );
    expect(
      (await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, inventoryIdB, 'PRODUCT'],
      )).single,
      variantBValuationBefore,
    );
    expect(
      (await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      )).single,
      baseBalanceBefore,
    );

    final delivery = (await db.query(
      'sales_deliveries',
      where: 'salesOrderId = ?',
      whereArgs: [value.id],
    )).single;
    expect(delivery['warehouseId'], warehouseId);
    expect(
      await db.query(
        'sales_deliveries',
        where: 'salesOrderId = ?',
        whereArgs: [value.id],
      ),
      hasLength(1),
    );
    final deliveryLine = (await db.query(
      'sales_delivery_items',
      where: 'salesDeliveryId = ?',
      whereArgs: [delivery['id']],
    )).single;
    expect(deliveryLine['salesOrderItemId'], 'variant-isolation-a-$suffix');
    expect(deliveryLine['productId'], productId);
    expect(deliveryLine['variantId'], variantA);
    expect(deliveryLine['inventoryIdentityKind'], 'VARIANT');
    expect((deliveryLine['baseQuantity'] as num).toDouble(), 4);
    final stockTransactions = await db.query(
      'stock_transactions',
      where: 'reference = ?',
      whereArgs: [delivery['deliveryNumber']],
    );
    expect(stockTransactions, hasLength(1));
    expect(stockTransactions.single['warehouseId'], warehouseId);
    expect(stockTransactions.single['itemId'], inventoryIdA);
    expect(stockTransactions.single['productId'], productId);
    expect(stockTransactions.single['variantId'], variantA);
    expect(stockTransactions.single['inventoryIdentityKind'], 'VARIANT');
    expect(stockTransactions.single['transactionType'], 'STOCK_OUT');
    expect((stockTransactions.single['quantity'] as num).toDouble(), 4);

    final orderLines = await db.query(
      'sales_order_items',
      where: 'salesOrderId = ?',
      whereArgs: [value.id],
    );
    expect(orderLinesBefore, hasLength(2));
    final persistedLineA = orderLines.singleWhere(
      (line) => line['id'] == 'variant-isolation-a-$suffix',
    );
    final persistedLineB = orderLines.singleWhere(
      (line) => line['id'] == 'variant-isolation-b-$suffix',
    );
    expect((persistedLineA['deliveredQuantity'] as num).toDouble(), 4);
    expect((persistedLineB['deliveredQuantity'] as num).toDouble(), 0);
    expect(
      (await db.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [value.id],
      )).single['status'],
      'PARTIALLY_DELIVERED',
    );
    final journals = await db.query(
      'journal_entries',
      where: 'referenceType = ?',
      whereArgs: ['SALES_DELIVERY'],
    );
    expect(journals, hasLength(deliveryJournalCountBefore.length + 1));
    expect(journals.single['referenceId'], delivery['id']);
    expect(
      await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['SALES_DELIVERY', delivery['id']],
      ),
      hasLength(1),
    );
    expect(
      await db.query(
        'journal_lines',
        where: 'journalEntryId = ?',
        whereArgs: [journals.single['id']],
      ),
      hasLength(4),
    );
  });

  test('delivery consumes only the selected warehouse identity', () async {
    final db = await FurnexaDatabase.instance.database;
    final warehouseB = await createSecondaryWarehouse();
    await seedBaseStock(warehouseId, 12);
    await seedBaseValuation(warehouseId, quantity: 12, averageCost: 3);
    await seedBaseStock(warehouseB, 50);
    await seedBaseValuation(warehouseB, quantity: 50, averageCost: 11);
    final value = order('warehouse-isolation-$suffix');
    await dataSource.saveOrder(value);
    final warehouseABalanceBefore = (await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    )).single;
    final warehouseAValuationBefore = (await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    )).single;
    final orderLineBefore = (await db.query(
      'sales_order_items',
      where: 'id = ?',
      whereArgs: [value.items.single.id],
    )).single;
    final warehouseBBalanceBefore = (await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseB, productId, 'PRODUCT'],
    )).single;
    final warehouseBValuationBefore = (await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseB, productId, 'PRODUCT'],
    )).single;

    await dataSource.postDelivery(
      order: value,
      operationId: 'warehouse-isolation-delivery-$suffix',
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: value.items.single.id,
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 5,
          unitId: unitId,
        ),
      ],
    );

    final warehouseABalance = (await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    )).single;
    final warehouseAValuation = (await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    )).single;
    expect((warehouseABalanceBefore['quantity'] as num).toDouble(), 12);
    expect((warehouseAValuationBefore['quantity'] as num).toDouble(), 12);
    expect(
      (warehouseAValuationBefore['quantity'] as num).toDouble() *
          (warehouseAValuationBefore['averageCost'] as num).toDouble(),
      36,
    );
    expect((orderLineBefore['deliveredQuantity'] as num).toDouble(), 0);
    expect((warehouseABalance['quantity'] as num).toDouble(), 7);
    expect((warehouseAValuation['quantity'] as num).toDouble(), 7);
    expect((warehouseAValuation['averageCost'] as num).toDouble(), 3);
    expect(
      (warehouseAValuation['quantity'] as num).toDouble() *
          (warehouseAValuation['averageCost'] as num).toDouble(),
      21,
    );
    expect(
      (await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseB, productId, 'PRODUCT'],
      )).single,
      warehouseBBalanceBefore,
    );
    expect(
      (await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseB, productId, 'PRODUCT'],
      )).single,
      warehouseBValuationBefore,
    );
    final delivery = (await db.query(
      'sales_deliveries',
      where: 'salesOrderId = ?',
      whereArgs: [value.id],
    )).single;
    expect(delivery['warehouseId'], warehouseId);
    final deliveryLine = (await db.query(
      'sales_delivery_items',
      where: 'salesDeliveryId = ?',
      whereArgs: [delivery['id']],
    )).single;
    expect(deliveryLine['productId'], productId);
    expect(deliveryLine['variantId'], isNull);
    expect(deliveryLine['inventoryIdentityKind'], 'BASE');
    final stockTransactions = await db.query(
      'stock_transactions',
      where: 'reference = ?',
      whereArgs: [delivery['deliveryNumber']],
    );
    expect(stockTransactions, hasLength(1));
    expect(stockTransactions.single['warehouseId'], warehouseId);
    expect(stockTransactions.single['itemId'], productId);
    expect(stockTransactions.single['productId'], productId);
    expect(stockTransactions.single['variantId'], isNull);
    expect(stockTransactions.single['inventoryIdentityKind'], 'BASE');
    expect((stockTransactions.single['quantity'] as num).toDouble(), 5);
    expect(
      (await db.query(
        'sales_order_items',
        where: 'id = ?',
        whereArgs: [value.items.single.id],
      )).single['deliveredQuantity'],
      5,
    );
    expect(
      await db.query(
        'stock_transactions',
        where: 'warehouseId = ?',
        whereArgs: [warehouseB],
      ),
      isEmpty,
    );
  });

  test('delivery rejects a caller-supplied sibling variant identity', () async {
    final db = await FurnexaDatabase.instance.database;
    final variantA = 'sales-reject-variant-a-$suffix';
    final variantB = 'sales-reject-variant-b-$suffix';
    for (final variant in [variantA, variantB]) {
      await db.insert('product_variants', {
        'id': variant,
        'productId': productId,
        'name': variant,
        'code': 'SR-$variant',
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await seedVariantInventory(
        variantId: variant,
        quantity: 20,
        averageCost: 6,
      );
    }
    final value = orderWithItems('variant-mismatch-$suffix', [
      SalesItem(
        id: 'variant-mismatch-line-$suffix',
        itemId: productId,
        itemType: SalesItemType.product,
        quantity: 10,
        unitId: unitId,
        baseUnitId: unitId,
        baseQuantity: 10,
        variantId: variantA,
        inventoryIdentityKind: 'VARIANT',
        unitPrice: 5,
        lineTotal: 50,
      ),
    ]);
    await dataSource.saveOrder(value);
    final before = await deliveryIdentityMutationState(value.id);

    await expectLater(
      dataSource.postDelivery(
        order: value,
        operationId: 'variant-mismatch-delivery-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: 'variant-mismatch-line-$suffix',
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 4,
            unitId: unitId,
            baseUnitId: unitId,
            baseQuantity: 4,
            variantId: variantB,
            inventoryIdentityKind: 'VARIANT',
          ),
        ],
      ),
      throwsException,
    );

    expect(await deliveryIdentityMutationState(value.id), before);
  });

  test('delivery cannot borrow valuation from another warehouse', () async {
    final warehouseB = await createSecondaryWarehouse();
    await seedBaseStock(warehouseId, 20);
    await seedBaseStock(warehouseB, 20);
    await seedBaseValuation(warehouseB, quantity: 20, averageCost: 7);
    final value = order('warehouse-valuation-mismatch-$suffix');
    await dataSource.saveOrder(value);
    final before = await deliveryIdentityMutationState(value.id);

    await expectLater(
      dataSource.postDelivery(
        order: value,
        operationId: 'warehouse-valuation-mismatch-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 5,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );

    expect(await deliveryIdentityMutationState(value.id), before);
  });

  test('delivery cannot borrow stock from another warehouse', () async {
    final warehouseB = await createSecondaryWarehouse();
    await seedBaseStock(warehouseId, 0);
    await seedBaseValuation(warehouseId, quantity: 20, averageCost: 3);
    await seedBaseStock(warehouseB, 20);
    await seedBaseValuation(warehouseB, quantity: 20, averageCost: 7);
    final value = order('warehouse-stock-mismatch-$suffix');
    await dataSource.saveOrder(value);
    final before = await deliveryIdentityMutationState(value.id);

    await expectLater(
      dataSource.postDelivery(
        order: value,
        operationId: 'warehouse-stock-mismatch-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 5,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );

    expect(await deliveryIdentityMutationState(value.id), before);
  });

  test('zero-revenue delivery still posts positive COGS', () async {
    final value = SalesOrder(
      id: 'zero-revenue-$suffix',
      orderNumber: 'SO-ZERO-$suffix',
      customerId: customerId,
      orderDate: now,
      status: SalesOrderStatus.confirmed,
      subtotal: 0,
      discount: 0,
      tax: 0,
      grandTotal: 0,
      createdAt: now,
      updatedAt: now,
      items: [
        SalesItem(
          id: 'zero-revenue-item-$suffix',
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 3,
          unitId: unitId,
          unitPrice: 0,
          lineTotal: 0,
        ),
      ],
    );
    await dataSource.saveOrder(value);
    await seedProductValuation();
    await dataSource.postDelivery(
      order: value,
      operationId: 'zero-revenue-delivery-$suffix',
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: value.items.single.id,
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 3,
          unitId: unitId,
        ),
      ],
    );

    final db = await FurnexaDatabase.instance.database;
    final delivery = (await dataSource.deliveries(value.id)).single;
    final journals = await db.query(
      'journal_entries',
      where: 'referenceType = ? AND referenceId = ?',
      whereArgs: ['SALES_DELIVERY', delivery.id],
    );
    expect(journals, hasLength(1));
    final lines = await db.rawQuery(
      '''
      SELECT a.code AS accountCode, jl.debit, jl.credit
      FROM journal_lines jl
      JOIN accounts a ON a.id = jl.accountId
      WHERE jl.journalEntryId = ?
      ''',
      [journals.single['id']],
    );
    expect(lines, hasLength(2));
    final cogs = lines.singleWhere((line) => line['accountCode'] == '5000');
    final inventory = lines.singleWhere(
      (line) => line['accountCode'] == '1100',
    );
    expect((cogs['debit'] as num).toDouble(), closeTo(15, 0.000001));
    expect((inventory['credit'] as num).toDouble(), closeTo(15, 0.000001));
    expect(
      lines.fold<double>(0, (sum, line) => sum + (line['debit'] as num)),
      closeTo(15, 0.000001),
    );
    expect(
      lines.fold<double>(0, (sum, line) => sum + (line['credit'] as num)),
      closeTo(15, 0.000001),
    );
  });

  test(
    'over-discount delivery validation leaves persisted state unchanged',
    () async {
      final value = SalesOrder(
        id: 'over-discount-$suffix',
        orderNumber: 'SO-OVER-$suffix',
        customerId: customerId,
        orderDate: now,
        status: SalesOrderStatus.confirmed,
        subtotal: 30,
        discount: 31,
        tax: 0,
        grandTotal: -1,
        createdAt: now,
        updatedAt: now,
        items: [
          SalesItem(
            id: 'over-discount-item-$suffix',
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 3,
            unitId: unitId,
            unitPrice: 10,
            discount: 31,
            lineTotal: -1,
          ),
        ],
      );
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final db = await FurnexaDatabase.instance.database;
      final stockBefore = await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );
      final valuationBefore = await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );
      final orderBefore = await db.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [value.id],
      );

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: 'discount-rejected-delivery-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 1,
              unitId: unitId,
            ),
          ],
        ),
        throwsException,
      );

      expect(
        await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        equals(stockBefore),
      );
      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        equals(valuationBefore),
      );
      expect(await dataSource.deliveries(value.id), isEmpty);
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ?',
          whereArgs: ['SALES_DELIVERY'],
        ),
        isEmpty,
      );
      expect(
        await db.query('sales_orders', where: 'id = ?', whereArgs: [value.id]),
        equals(orderBefore),
      );
    },
  );

  test('non-finite persisted money rejects delivery without writes', () async {
    final value = order('non-finite-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation();
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'sales_order_items',
      {'unitPrice': double.infinity, 'lineTotal': double.infinity},
      where: 'id = ?',
      whereArgs: [value.items.single.id],
    );
    final stockBefore = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    );
    final valuationBefore = await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    );

    await expectLater(
      dataSource.postDelivery(
        order: value,
        operationId: 'non-finite-rejected-delivery-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 1,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );

    expect(
      await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      ),
      equals(stockBefore),
    );
    expect(
      await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      ),
      equals(valuationBefore),
    );
    expect(await dataSource.deliveries(value.id), isEmpty);
    expect(
      await db.query(
        'journal_entries',
        where: 'referenceType = ?',
        whereArgs: ['SALES_DELIVERY'],
      ),
      isEmpty,
    );
    final persistedOrder = await db.query(
      'sales_orders',
      where: 'id = ?',
      whereArgs: [value.id],
    );
    expect(persistedOrder.single['status'], 'CONFIRMED');
  });

  test(
    'delivery rejects caller customer identity that differs from persisted order',
    () async {
      final value = order('customer-identity-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final otherCustomerId = 'other-customer-$suffix';
      await dataSource.saveCustomer(
        Customer(
          id: otherCustomerId,
          name: 'Other Customer',
          code: 'OTHER-$suffix',
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final suppliedOrder = SalesOrder(
        id: value.id,
        orderNumber: value.orderNumber,
        customerId: otherCustomerId,
        orderDate: value.orderDate,
        status: value.status,
        subtotal: value.subtotal,
        discount: value.discount,
        tax: value.tax,
        grandTotal: value.grandTotal,
        createdAt: value.createdAt,
        updatedAt: value.updatedAt,
        items: value.items,
      );
      final db = await FurnexaDatabase.instance.database;
      final stockBefore = await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );
      final valuationBefore = await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );

      await expectLater(
        dataSource.postDelivery(
          order: suppliedOrder,
          operationId: 'customer-identity-rejected-delivery-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 1,
              unitId: unitId,
            ),
          ],
        ),
        throwsException,
      );

      expect(await dataSource.deliveries(value.id), isEmpty);
      expect(
        await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        equals(stockBefore),
      );
      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        equals(valuationBefore),
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ?',
          whereArgs: ['SALES_DELIVERY'],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'journal_parties',
          where: 'partyType = ? AND partyId = ?',
          whereArgs: ['CUSTOMER', otherCustomerId],
        ),
        isEmpty,
      );
      final persistedOrder = await db.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [value.id],
      );
      expect(persistedOrder.single['customerId'], customerId);
      expect(persistedOrder.single['status'], 'CONFIRMED');
    },
  );

  test('customer, quotation conversion, and historical preservation', () async {
    final quotation = Quotation(
      id: 'quotation-$suffix',
      quotationNumber: 'QT-$suffix',
      customerId: customerId,
      quotationDate: now,
      status: QuotationStatus.accepted,
      subtotal: 100,
      discount: 0,
      tax: 0,
      grandTotal: 100,
      createdAt: now,
      updatedAt: now,
      items: [
        SalesItem(
          id: 'quotation-item-$suffix',
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 10,
          unitId: unitId,
          unitPrice: 10,
          lineTotal: 100,
        ),
      ],
    );
    await dataSource.saveQuotation(quotation);
    final base = order('converted-$suffix');
    final converted = SalesOrder(
      id: base.id,
      orderNumber: base.orderNumber,
      customerId: base.customerId,
      quotationId: quotation.id,
      orderDate: now,
      status: SalesOrderStatus.fullyDelivered,
      subtotal: 100,
      discount: 0,
      tax: 0,
      grandTotal: 100,
      createdAt: now,
      updatedAt: now,
      items: quotation.items,
    );
    final createdOrder = await dataSource.convertQuotationToOrder(
      quotation,
      converted,
    );
    expect(createdOrder.status, SalesOrderStatus.draft);
    expect(
      (await dataSource.quotations())
          .firstWhere((v) => v.id == quotation.id)
          .status,
      QuotationStatus.converted,
    );
    expect(
      (await dataSource.orders())
          .firstWhere((v) => v.id == converted.id)
          .quotationId,
      quotation.id,
    );
    final retry = SalesOrder(
      id: 'retry-order-$suffix',
      orderNumber: 'SO-RETRY-$suffix',
      customerId: customerId,
      quotationId: quotation.id,
      orderDate: now,
      status: SalesOrderStatus.draft,
      subtotal: quotation.subtotal,
      discount: quotation.discount,
      tax: quotation.tax,
      grandTotal: quotation.grandTotal,
      createdAt: now,
      updatedAt: now,
      items: quotation.items,
    );
    final retried = await dataSource.convertQuotationToOrder(quotation, retry);
    expect(retried.id, converted.id);
    expect(retried.status, SalesOrderStatus.draft);
    expect(
      (await dataSource.orders()).where(
        (value) => value.quotationId == quotation.id,
      ),
      hasLength(1),
    );
    final persistedBeforeRetry = await (await FurnexaDatabase.instance.database)
        .query('sales_orders', where: 'id = ?', whereArgs: [converted.id]);
    final conflictingRetry = await dataSource.convertQuotationToOrder(
      quotation,
      SalesOrder(
        id: 'unrelated-order-$suffix',
        orderNumber: 'SO-UNRELATED-$suffix',
        customerId: customerId,
        quotationId: quotation.id,
        orderDate: now,
        status: SalesOrderStatus.cancelled,
        subtotal: 100,
        discount: 0,
        tax: 0,
        grandTotal: 100,
        createdAt: now,
        updatedAt: now,
        items: [
          SalesItem(
            id: 'unrelated-item-$suffix',
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 11,
            unitId: unitId,
            unitPrice: 10,
            lineTotal: 110,
          ),
        ],
      ),
    );
    expect(conflictingRetry.id, converted.id);
    expect(conflictingRetry.status, SalesOrderStatus.draft);
    expect(
      await (await FurnexaDatabase.instance.database).query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [converted.id],
      ),
      persistedBeforeRetry,
    );
    expect(
      (await dataSource.orders()).where(
        (value) => value.quotationId == quotation.id,
      ),
      hasLength(1),
    );
  });

  test('generic order creation rejects delivery-managed values', () async {
    final deliveredStatusOrder = copyOrder(
      order('managed-status-$suffix'),
      status: SalesOrderStatus.fullyDelivered,
    );
    await expectLater(
      dataSource.saveOrder(deliveredStatusOrder),
      throwsException,
    );
    final partialStatusOrder = copyOrder(
      order('managed-partial-$suffix'),
      status: SalesOrderStatus.partiallyDelivered,
    );
    await expectLater(
      dataSource.saveOrder(partialStatusOrder),
      throwsException,
    );
    await expectLater(
      dataSource.saveOrder(order('managed-quantity-$suffix', delivered: 1)),
      throwsException,
    );
    final db = await FurnexaDatabase.instance.database;
    expect(
      await db.query(
        'sales_orders',
        where: 'id IN (?, ?, ?)',
        whereArgs: [
          deliveredStatusOrder.id,
          partialStatusOrder.id,
          'managed-quantity-$suffix',
        ],
      ),
      isEmpty,
    );
  });

  test(
    'manual transitions reject managed states and invalid partial changes',
    () async {
      final draft = copyOrder(
        order('manual-draft-$suffix'),
        status: SalesOrderStatus.draft,
      );
      await dataSource.saveOrder(draft);
      await dataSource.changeOrderStatus(draft.id, SalesOrderStatus.confirmed);
      expect(
        (await (await FurnexaDatabase.instance.database).query(
          'sales_orders',
          where: 'id = ?',
          whereArgs: [draft.id],
        )).single['status'],
        'CONFIRMED',
      );

      final value = order('manual-status-$suffix');
      await dataSource.saveOrder(value);
      await expectLater(
        dataSource.changeOrderStatus(value.id, SalesOrderStatus.fullyDelivered),
        throwsException,
      );
      var persisted = await (await FurnexaDatabase.instance.database).query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [value.id],
      );
      expect(persisted.single['status'], 'CONFIRMED');

      await seedProductValuation();
      await dataSource.postDelivery(
        order: value,
        operationId: 'manual-transition-delivery-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 10,
            unitId: unitId,
          ),
        ],
      );
      for (final requestedStatus in [
        SalesOrderStatus.draft,
        SalesOrderStatus.confirmed,
      ]) {
        await expectLater(
          dataSource.changeOrderStatus(value.id, requestedStatus),
          throwsException,
        );
      }
      final persistedLines = await (await FurnexaDatabase.instance.database)
          .query(
            'sales_order_items',
            where: 'salesOrderId = ?',
            whereArgs: [value.id],
          );
      persisted = await (await FurnexaDatabase.instance.database).query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [value.id],
      );
      expect(persisted.single['status'], 'PARTIALLY_DELIVERED');
      expect(await dataSource.deliveries(value.id), hasLength(1));
      expect(
        (await (await FurnexaDatabase.instance.database).query(
          'sales_order_items',
          where: 'salesOrderId = ?',
          whereArgs: [value.id],
        )),
        persistedLines,
      );
    },
  );

  test(
    'cancelled and fully delivered orders cannot be reopened or saved',
    () async {
      final cancelled = order('cancelled-terminal-$suffix');
      await dataSource.saveOrder(cancelled);
      await dataSource.changeOrderStatus(
        cancelled.id,
        SalesOrderStatus.cancelled,
      );
      final db = await FurnexaDatabase.instance.database;
      final cancelledItemsBefore = await db.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [cancelled.id],
      );
      await expectLater(
        dataSource.saveOrder(
          copyOrder(
            cancelled,
            status: SalesOrderStatus.confirmed,
            notes: 'attempted reopen',
          ),
        ),
        throwsException,
      );
      await expectLater(
        dataSource.changeOrderStatus(cancelled.id, SalesOrderStatus.confirmed),
        throwsException,
      );
      expect(
        (await db.query(
          'sales_orders',
          where: 'id = ?',
          whereArgs: [cancelled.id],
        )).single['status'],
        'CANCELLED',
      );
      expect(
        await db.query(
          'sales_order_items',
          where: 'salesOrderId = ?',
          whereArgs: [cancelled.id],
        ),
        cancelledItemsBefore,
      );

      final fullyDelivered = order('fully-delivered-terminal-$suffix');
      await dataSource.saveOrder(fullyDelivered);
      await seedProductValuation();
      await dataSource.postDelivery(
        order: fullyDelivered,
        operationId: 'fully-delivered-terminal-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: fullyDelivered.items.single.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 100,
            unitId: unitId,
          ),
        ],
      );
      final orderBefore = await db.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [fullyDelivered.id],
      );
      final linesBefore = await db.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [fullyDelivered.id],
      );
      await expectLater(
        dataSource.saveOrder(
          copyOrder(fullyDelivered, notes: 'attempted edit'),
        ),
        throwsException,
      );
      expect(
        await db.query(
          'sales_orders',
          where: 'id = ?',
          whereArgs: [fullyDelivered.id],
        ),
        orderBefore,
      );
      expect(
        await db.query(
          'sales_order_items',
          where: 'salesOrderId = ?',
          whereArgs: [fullyDelivered.id],
        ),
        linesBefore,
      );
    },
  );

  test('partial cancellation preserves posted delivery history', () async {
    final value = order('partial-cancel-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation();
    await dataSource.postDelivery(
      order: value,
      operationId: 'partial-cancel-delivery-$suffix',
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: value.items.single.id,
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 10,
          unitId: unitId,
        ),
      ],
    );
    final db = await FurnexaDatabase.instance.database;
    final delivery = (await db.query(
      'sales_deliveries',
      where: 'salesOrderId = ?',
      whereArgs: [value.id],
    )).single;
    final deliveryItemsBefore = await db.query(
      'sales_delivery_items',
      where: 'salesDeliveryId = ?',
      whereArgs: [delivery['id']],
    );
    final stockTransactionsBefore = await db.query(
      'stock_transactions',
      where: 'reference = ?',
      whereArgs: [delivery['deliveryNumber']],
    );
    final stockBalancesBefore = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    );
    final valuationBefore = await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, productId, 'PRODUCT'],
    );
    final journalsBefore = await db.query(
      'journal_entries',
      where: 'referenceType = ? AND referenceId = ?',
      whereArgs: ['SALES_DELIVERY', delivery['id']],
    );
    final journalLinesBefore = await db.query(
      'journal_lines',
      where:
          'journalEntryId IN (SELECT id FROM journal_entries WHERE referenceType = ? AND referenceId = ?)',
      whereArgs: ['SALES_DELIVERY', delivery['id']],
    );

    await dataSource.changeOrderStatus(value.id, SalesOrderStatus.cancelled);

    await expectLater(
      dataSource.updateDeliveryDispatch(
        deliveryId: delivery['id'] as String,
        status: DeliveryDispatchStatus.dispatched,
      ),
      throwsException,
    );

    expect(
      (await db.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [value.id],
      )).single['status'],
      'CANCELLED',
    );
    expect(
      await db.query(
        'sales_deliveries',
        where: 'salesOrderId = ?',
        whereArgs: [value.id],
      ),
      [delivery],
    );
    expect(
      await db.query(
        'sales_delivery_items',
        where: 'salesDeliveryId = ?',
        whereArgs: [delivery['id']],
      ),
      deliveryItemsBefore,
    );
    expect(
      await db.query(
        'stock_transactions',
        where: 'reference = ?',
        whereArgs: [delivery['deliveryNumber']],
      ),
      stockTransactionsBefore,
    );
    expect(
      await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      ),
      stockBalancesBefore,
    );
    expect(
      await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      ),
      valuationBefore,
    );
    expect(
      await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['SALES_DELIVERY', delivery['id']],
      ),
      journalsBefore,
    );
    expect(
      await db.query(
        'journal_lines',
        where:
            'journalEntryId IN (SELECT id FROM journal_entries WHERE referenceType = ? AND referenceId = ?)',
        whereArgs: ['SALES_DELIVERY', delivery['id']],
      ),
      journalLinesBefore,
    );
  });

  test(
    'delivery rejects order quantity drift without posting writes',
    () async {
      final value = order('delivery-drift-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'sales_order_items',
        {'deliveredQuantity': 1},
        where: 'id = ?',
        whereArgs: [value.items.single.id],
      );
      final stockBefore = await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );
      final valuationBefore = await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );
      final orderBefore = await db.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [value.id],
      );

      await expectLater(
        dataSource.postDelivery(
          order: value,
          operationId: 'quantity-drift-rejected-delivery-$suffix',
          warehouseId: warehouseId,
          deliveryDate: now,
          items: [
            SalesItem(
              id: value.items.single.id,
              itemId: productId,
              itemType: SalesItemType.product,
              quantity: 1,
              unitId: unitId,
            ),
          ],
        ),
        throwsException,
      );

      expect(await dataSource.deliveries(value.id), isEmpty);
      expect(
        await db.query(
          'sales_order_items',
          where: 'salesOrderId = ?',
          whereArgs: [value.id],
        ),
        [containsPair('deliveredQuantity', 1)],
      );
      expect(
        await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        stockBefore,
      );
      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        valuationBefore,
      );
      expect(
        await db.query('sales_orders', where: 'id = ?', whereArgs: [value.id]),
        orderBefore,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ?',
          whereArgs: ['SALES_DELIVERY'],
        ),
        isEmpty,
      );
    },
  );

  test(
    'partial and full delivery decrease stock and create stock-out history',
    () async {
      final value = order('delivery-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      await dataSource.postDelivery(
        order: value,
        operationId: 'partial-full-first-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.first.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 60,
            unitId: unitId,
          ),
        ],
      );
      await dataSource.postDelivery(
        order: value,
        operationId: 'partial-full-first-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.first.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 60,
            unitId: unitId,
          ),
        ],
      );
      expect((await dataSource.deliveries(value.id)), hasLength(1));
      final database = await FurnexaDatabase.instance.database;
      final balance = await database.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
        limit: 1,
      );
      expect((balance.single['quantity'] as num).toDouble(), 40);
      final partial = (await dataSource.orders()).firstWhere(
        (v) => v.id == value.id,
      );
      expect(partial.status, SalesOrderStatus.partiallyDelivered);
      await dataSource.postDelivery(
        order: partial,
        operationId: 'partial-full-final-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.first.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 40,
            unitId: unitId,
          ),
        ],
      );
      expect(
        (await dataSource.orders()).firstWhere((v) => v.id == value.id).status,
        SalesOrderStatus.fullyDelivered,
      );
      final db = await FurnexaDatabase.instance.database;
      final orderLine = (await db.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [value.id],
      )).single;
      final deliveredRows = await db.rawQuery(
        '''
        SELECT SUM(sdi.deliveredQuantity) AS deliveredQuantity
        FROM sales_delivery_items sdi
        JOIN sales_deliveries sd ON sd.id = sdi.salesDeliveryId
        WHERE sd.salesOrderId = ? AND sdi.salesOrderItemId = ?
        ''',
        [value.id, value.items.single.id],
      );
      expect((orderLine['deliveredQuantity'] as num).toDouble(), 100);
      expect(
        (deliveredRows.single['deliveredQuantity'] as num).toDouble(),
        100,
      );
      expect(
        (await db.query(
          'sales_orders',
          where: 'id = ?',
          whereArgs: [value.id],
        )).single['status'],
        'FULLY_DELIVERED',
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ?',
          whereArgs: [warehouseId],
        )).single['quantity'],
        0,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ?',
          whereArgs: [warehouseId],
        ),
        hasLength(2),
      );
    },
  );

  test('insufficient stock and inactive items roll back delivery', () async {
    final value = order('failed-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation();
    await (await FurnexaDatabase.instance.database).update(
      'stock_balances',
      {'quantity': 5},
      where: 'warehouseId = ?',
      whereArgs: [warehouseId],
    );
    expect(
      () => dataSource.postDelivery(
        order: value,
        operationId: 'insufficient-stock-rejected-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.first.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 6,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );
    expect(await dataSource.deliveries(value.id), isEmpty);
    await (await FurnexaDatabase.instance.database).update(
      'products',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [productId],
    );
    expect(
      () => dataSource.postDelivery(
        order: value,
        operationId: 'inactive-product-rejected-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.first.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 1,
            unitId: unitId,
          ),
        ],
      ),
      throwsException,
    );
  });

  test('delivery dispatch lifecycle persists status transitions', () async {
    final value = order('dispatch-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation();
    await dataSource.postDelivery(
      order: value,
      operationId: 'dispatch-lifecycle-delivery-$suffix',
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: value.items.first.id,
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 30,
          unitId: unitId,
        ),
      ],
    );

    final delivery = (await dataSource.deliveries(value.id)).single;
    expect(delivery.status, DeliveryDispatchStatus.pending);
    await expectLater(
      dataSource.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.cancelled,
      ),
      throwsException,
    );
    expect(
      (await dataSource.deliveries(value.id)).single.status,
      DeliveryDispatchStatus.pending,
    );

    final dispatched = await dataSource.updateDeliveryDispatch(
      deliveryId: delivery.id,
      status: DeliveryDispatchStatus.dispatched,
      dispatchDate: now,
      driverName: 'Ahmed',
      vehicleNumber: 'ABC-123',
      destination: 'Dammam',
    );
    expect(dispatched.status, DeliveryDispatchStatus.dispatched);
    expect(dispatched.driverName, 'Ahmed');

    final inTransit = await dataSource.updateDeliveryDispatch(
      deliveryId: delivery.id,
      status: DeliveryDispatchStatus.inTransit,
    );
    expect(inTransit.status, DeliveryDispatchStatus.inTransit);

    final delivered = await dataSource.updateDeliveryDispatch(
      deliveryId: delivery.id,
      status: DeliveryDispatchStatus.delivered,
    );
    expect(delivered.status, DeliveryDispatchStatus.delivered);
    expect(
      () => dataSource.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.dispatched,
      ),
      throwsException,
    );
  });

  test('same-state dispatch update is an idempotent no-op', () async {
    final value = order('dispatch-noop-$suffix');
    await dataSource.saveOrder(value);
    await seedProductValuation();
    await dataSource.postDelivery(
      order: value,
      operationId: 'dispatch-noop-delivery-$suffix',
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: value.items.first.id,
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 30,
          unitId: unitId,
        ),
      ],
    );

    final db = await FurnexaDatabase.instance.database;
    final deliveryBefore = (await db.query(
      'sales_deliveries',
      where: 'salesOrderId = ?',
      whereArgs: [value.id],
    )).single;
    final stockBefore = await db.query('stock_balances');
    final valuationBefore = await db.query('inventory_valuations');
    final transactionsBefore = await db.query('stock_transactions');
    final journalsBefore = await db.query(
      'journal_entries',
      where: 'referenceType = ?',
      whereArgs: ['SALES_DELIVERY'],
    );

    final returned = await dataSource.updateDeliveryDispatch(
      deliveryId: deliveryBefore['id'] as String,
      status: DeliveryDispatchStatus.pending,
      dispatchDate: now,
      driverName: 'Ignored on no-op',
      vehicleNumber: 'Ignored on no-op',
      destination: 'Ignored on no-op',
      notes: 'Ignored on no-op',
    );

    expect(returned.status, DeliveryDispatchStatus.pending);
    expect(
      await db.query(
        'sales_deliveries',
        where: 'id = ?',
        whereArgs: [deliveryBefore['id']],
      ),
      [deliveryBefore],
    );
    expect(await db.query('stock_balances'), stockBefore);
    expect(await db.query('inventory_valuations'), valuationBefore);
    expect(await db.query('stock_transactions'), transactionsBefore);
    expect(
      await db.query(
        'journal_entries',
        where: 'referenceType = ?',
        whereArgs: ['SALES_DELIVERY'],
      ),
      journalsBefore,
    );
  });

  test(
    'concurrent dispatch requests cannot overwrite persisted status',
    () async {
      final value = order('dispatch-concurrent-$suffix');
      await dataSource.saveOrder(value);
      await seedProductValuation();
      await dataSource.postDelivery(
        order: value,
        operationId: 'dispatch-concurrent-delivery-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: value.items.first.id,
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 30,
            unitId: unitId,
          ),
        ],
      );
      final delivery = (await dataSource.deliveries(value.id)).single;

      Future<bool> tryUpdate(DeliveryDispatchStatus status) async {
        try {
          await dataSource.updateDeliveryDispatch(
            deliveryId: delivery.id,
            status: status,
          );
          return true;
        } on Exception {
          return false;
        }
      }

      final results = await Future.wait([
        tryUpdate(DeliveryDispatchStatus.dispatched),
        tryUpdate(DeliveryDispatchStatus.delivered),
      ]);
      expect(results.where((updated) => updated), hasLength(1));
      expect(
        (await dataSource.deliveries(value.id)).single.status,
        DeliveryDispatchStatus.dispatched,
      );
      await expectLater(
        dataSource.updateDeliveryDispatch(
          deliveryId: delivery.id,
          status: DeliveryDispatchStatus.pending,
        ),
        throwsException,
      );
      expect(
        (await dataSource.deliveries(value.id)).single.status,
        DeliveryDispatchStatus.dispatched,
      );
    },
  );

  test('customer history remains queryable after deactivation', () async {
    final quotation = Quotation(
      id: 'history-quotation-$suffix',
      quotationNumber: 'QT-HISTORY-$suffix',
      customerId: customerId,
      quotationDate: now,
      status: QuotationStatus.draft,
      subtotal: 10,
      discount: 0,
      tax: 0,
      grandTotal: 10,
      createdAt: now,
      updatedAt: now,
      items: [
        SalesItem(
          id: 'history-item-$suffix',
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 1,
          unitId: unitId,
          unitPrice: 10,
          lineTotal: 10,
        ),
      ],
    );
    await dataSource.saveQuotation(quotation);
    await dataSource.setCustomerActive(customerId, false);
    final customer = (await dataSource.customers()).single;
    final history = (await dataSource.quotations()).single;
    expect(customer.active, isFalse);
    expect(history.customerId, customer.id);
  });

  test(
    'sales active items are product-only and raw materials are rejected',
    () async {
      final rawMaterialId = 'sales-raw-$suffix';
      final db = await FurnexaDatabase.instance.database;
      await db.insert('raw_materials', {
        'id': rawMaterialId,
        'name': 'خامة مبيعات $suffix',
        'code': 'SR-$suffix',
        'categoryId': 'sales-category-$suffix',
        'unitId': unitId,
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      final items = await dataSource.activeItems();
      expect(items.every((item) => item.type == StockItemType.product), isTrue);

      final invalidOrder = SalesOrder(
        id: 'raw-material-order-$suffix',
        orderNumber: 'SO-RAW-$suffix',
        customerId: customerId,
        orderDate: now,
        status: SalesOrderStatus.draft,
        subtotal: 10,
        discount: 0,
        tax: 0,
        grandTotal: 10,
        createdAt: now,
        updatedAt: now,
        items: [
          SalesItem(
            id: 'raw-order-item-$suffix',
            itemId: rawMaterialId,
            itemType: SalesItemType.rawMaterial,
            quantity: 1,
            unitId: unitId,
            unitPrice: 10,
            lineTotal: 10,
          ),
        ],
      );

      expect(() => dataSource.saveOrder(invalidOrder), throwsException);
    },
  );

  test('ineligible quotation cannot be converted', () async {
    final quotation = Quotation(
      id: 'draft-quotation-$suffix',
      quotationNumber: 'QT-DRAFT-$suffix',
      customerId: customerId,
      quotationDate: now,
      status: QuotationStatus.draft,
      subtotal: 100,
      discount: 0,
      tax: 0,
      grandTotal: 100,
      createdAt: now,
      updatedAt: now,
      items: [
        SalesItem(
          id: 'draft-item-$suffix',
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 1,
          unitId: unitId,
          unitPrice: 100,
          lineTotal: 100,
        ),
      ],
    );
    await dataSource.saveQuotation(quotation);
    expect(
      () => dataSource.convertQuotationToOrder(
        quotation,
        order('blocked-$suffix'),
      ),
      throwsException,
    );
    expect(await dataSource.orders(), isEmpty);
    expect(
      (await dataSource.quotations()).single.status,
      QuotationStatus.draft,
    );
  });
}
