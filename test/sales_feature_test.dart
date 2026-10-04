import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
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
      status: SalesOrderStatus.draft,
      subtotal: 100,
      discount: 0,
      tax: 0,
      grandTotal: 100,
      createdAt: now,
      updatedAt: now,
      items: quotation.items,
    );
    await dataSource.convertQuotationToOrder(quotation, converted);
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
    expect(
      (await dataSource.orders()).where(
        (value) => value.quotationId == quotation.id,
      ),
      hasLength(1),
    );
    await expectLater(
      dataSource.convertQuotationToOrder(
        quotation,
        SalesOrder(
          id: 'unrelated-order-$suffix',
          orderNumber: 'SO-UNRELATED-$suffix',
          customerId: customerId,
          quotationId: quotation.id,
          orderDate: now,
          status: SalesOrderStatus.draft,
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
      ),
      throwsException,
    );
  });

  test(
    'partial and full delivery decrease stock and create stock-out history',
    () async {
      final value = order('delivery-$suffix');
      await dataSource.saveOrder(value);
      await dataSource.postDelivery(
        order: value,
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
    await (await FurnexaDatabase.instance.database).update(
      'stock_balances',
      {'quantity': 5},
      where: 'warehouseId = ?',
      whereArgs: [warehouseId],
    );
    expect(
      () => dataSource.postDelivery(
        order: value,
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
    await dataSource.postDelivery(
      order: value,
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
