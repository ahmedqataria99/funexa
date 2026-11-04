import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_helpers/database_test_helper.dart';

void main() {
  late String suffix;
  late String warehouseId;
  late String supplierId;
  late String baseUnitId;
  late String purchaseUnitId;
  late String inactiveUnitId;
  late String variantProductId;
  late String variantId;
  late String plainProductId;
  late String foreignVariantId;
  late DateTime now;
  late PurchasingLocalDataSource dataSource;

  Future<PurchaseOrder> createOrder({
    required String id,
    required String productId,
    String? selectedVariantId,
    required String unitId,
    required double quantity,
    double factor = 1,
    String identityKind = 'BASE',
  }) async {
    final item = PurchasingItem(
      id: '$id-item',
      itemId: productId,
      itemType: PurchasingItemType.product,
      quantity: quantity,
      unitId: unitId,
      variantId: selectedVariantId,
      baseUnitId: baseUnitId,
      unitConversionFactor: factor,
      baseQuantity: quantity * factor,
      inventoryIdentityKind: identityKind,
      unitPrice: 60,
    );
    final order = PurchaseOrder(
      id: id,
      orderNumber: 'PO-$id',
      supplierId: supplierId,
      orderDate: now,
      status: PurchaseOrderStatus.approved,
      subtotal: quantity * 60,
      discount: 0,
      tax: 0,
      grandTotal: quantity * 60,
      createdAt: now,
      updatedAt: now,
      items: [item],
    );
    await dataSource.saveOrder(order);
    return order;
  }

  Future<void> receive(
    PurchaseOrder order, {
    required double quantity,
    required String operationId,
    PurchasingLocalDataSource? source,
  }) async {
    final item = order.items.single;
    await (source ?? dataSource).postReceipt(
      order: order,
      warehouseId: warehouseId,
      receiptDate: now,
      operationId: operationId,
      items: [
        PurchasingItem(
          id: item.id,
          itemId: item.itemId,
          itemType: item.itemType,
          quantity: quantity,
          unitId: item.unitId,
          variantId: item.variantId,
          unitConversionFactor: item.unitConversionFactor,
          inventoryIdentityKind: item.inventoryIdentityKind,
        ),
      ],
    );
  }

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login(
      'admin',
      DatabaseTestHelper.adminPassword,
    );
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime.utc(2026, 10, 9);
    warehouseId = 'receive-warehouse-$suffix';
    supplierId = 'receive-supplier-$suffix';
    baseUnitId = 'receive-base-unit-$suffix';
    purchaseUnitId = 'receive-purchase-unit-$suffix';
    inactiveUnitId = 'receive-inactive-unit-$suffix';
    variantProductId = 'receive-product-$suffix';
    variantId = 'receive-variant-$suffix';
    plainProductId = 'receive-plain-product-$suffix';
    foreignVariantId = 'receive-foreign-variant-$suffix';
    final factoryId = 'receive-factory-$suffix';
    final categoryId = 'receive-category-$suffix';
    final otherProductId = 'receive-other-product-$suffix';
    final stamp = now.millisecondsSinceEpoch;
    final db = await FurnexaDatabase.instance.database;
    await db.insert('factories', {
      'id': factoryId,
      'name': 'Receiving Factory',
      'code': 'RF-$suffix',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'Receiving Warehouse',
      'code': 'RW-$suffix',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'Receiving Category',
      'code': 'RC-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    for (final unit in [
      (baseUnitId, 'BASE-$suffix', 'RB$suffix', 1),
      (purchaseUnitId, 'PURCHASE-$suffix', 'RP$suffix', 1),
      (inactiveUnitId, 'INACTIVE-$suffix', 'RI$suffix', 0),
    ]) {
      await db.insert('units', {
        'id': unit.$1,
        'name': unit.$2,
        'abbreviation': unit.$3,
        'active': unit.$4,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    }
    for (final product in [
      (variantProductId, 'RVP-$suffix'),
      (plainProductId, 'RPL-$suffix'),
      (otherProductId, 'ROP-$suffix'),
    ]) {
      await db.insert('products', {
        'id': product.$1,
        'name': product.$1,
        'code': product.$2,
        'categoryId': categoryId,
        'unitId': baseUnitId,
        'productState': 'finished',
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    }
    for (final variant in [
      (variantId, variantProductId, 'RV-1-$suffix'),
      (foreignVariantId, otherProductId, 'RV-2-$suffix'),
    ]) {
      await db.insert('product_variants', {
        'id': variant.$1,
        'productId': variant.$2,
        'name': variant.$1,
        'code': variant.$3,
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    }
    for (final conversion in [(purchaseUnitId, 12.0), (inactiveUnitId, 6.0)]) {
      await db.insert('product_unit_conversions', {
        'id': 'conversion-${conversion.$1}-$suffix',
        'productId': variantProductId,
        'unitId': conversion.$1,
        'factorToBase': conversion.$2,
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    }
    await db.insert('suppliers', {
      'id': supplierId,
      'name': 'Receiving Supplier',
      'code': 'RS-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    dataSource = PurchasingLocalDataSource();
  });

  tearDown(() async {
    SecurityLocalDataSource().logout();
    await DatabaseTestHelper.reset();
  });

  Future<void> expectNoReceiptOrInventoryWrites(PurchaseOrder order) async {
    final db = await FurnexaDatabase.instance.database;
    final identityKey = '__FURNEXA_VARIANT__:$variantId';
    expect(
      await db.query(
        'purchase_receipts',
        where: 'purchaseOrderId = ?',
        whereArgs: [order.id],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'purchase_receipt_items',
        where: 'purchaseOrderItemId = ?',
        whereArgs: [order.items.single.id],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      ),
      isEmpty,
    );
    expect(
      await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      ),
      isEmpty,
    );
    final persistedOrderItem = (await db.query(
      'purchase_order_items',
      where: 'id = ?',
      whereArgs: [order.items.single.id],
    )).single;
    expect(persistedOrderItem['receivedQuantity'], 0);
    expect(persistedOrderItem['receivedBaseQuantity'], 0);
  }

  test(
    'full receipt posts stock and valuation to the selected variant',
    () async {
      final order = await createOrder(
        id: 'receive-full-$suffix',
        productId: variantProductId,
        selectedVariantId: variantId,
        unitId: baseUnitId,
        quantity: 5,
        identityKind: 'VARIANT',
      );
      await receive(order, quantity: 5, operationId: 'full-$suffix');

      final db = await FurnexaDatabase.instance.database;
      const identityKeyPrefix = '__FURNEXA_VARIANT__:';
      final identityKey = '$identityKeyPrefix$variantId';
      final storedOrderItem = (await db.query(
        'purchase_order_items',
        where: 'id = ?',
        whereArgs: [order.items.single.id],
      )).single;
      expect(storedOrderItem['itemId'], identityKey);
      expect(storedOrderItem['productId'], variantProductId);
      expect(storedOrderItem['variantId'], variantId);
      expect(storedOrderItem['inventoryIdentityKind'], 'VARIANT');
      expect(storedOrderItem['unitId'], baseUnitId);
      expect(storedOrderItem['unitConversionFactor'], 1);
      expect(storedOrderItem['baseQuantity'], 5);
      expect(storedOrderItem['receivedQuantity'], 5);
      expect(storedOrderItem['receivedBaseQuantity'], 5);

      final stock = (await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      )).single;
      expect(stock['productId'], variantProductId);
      expect(stock['variantId'], variantId);
      expect(stock['inventoryIdentityKind'], 'VARIANT');
      expect(stock['unitId'], baseUnitId);
      expect(stock['quantity'], 5);
      final transaction = (await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      )).single;
      expect(transaction['productId'], variantProductId);
      expect(transaction['variantId'], variantId);
      expect(transaction['inventoryIdentityKind'], 'VARIANT');
      expect(transaction['quantity'], 5);
      expect(transaction['unitId'], baseUnitId);
      final valuation = (await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      )).single;
      expect(valuation['productId'], variantProductId);
      expect(valuation['variantId'], variantId);
      expect(valuation['inventoryIdentityKind'], 'VARIANT');
      expect(valuation['unitId'], baseUnitId);
      expect(valuation['quantity'], 5);
      expect(valuation['averageCost'], 60);

      final receipt = (await db.query(
        'purchase_receipts',
        where: 'purchaseOrderId = ?',
        whereArgs: [order.id],
      )).single;
      final receiptItem = (await db.query(
        'purchase_receipt_items',
        where: 'purchaseReceiptId = ?',
        whereArgs: [receipt['id']],
      )).single;
      expect(receiptItem['productId'], variantProductId);
      expect(receiptItem['variantId'], variantId);
      expect(receiptItem['inventoryIdentityKind'], 'VARIANT');
      expect(receiptItem['unitId'], baseUnitId);
      expect(receiptItem['unitConversionFactor'], 1);
      expect(receiptItem['baseQuantity'], 5);
    },
  );

  test(
    'partial alternative-unit receipts normalize into variant base stock',
    () async {
      final order = await createOrder(
        id: 'receive-partial-$suffix',
        productId: variantProductId,
        selectedVariantId: variantId,
        unitId: purchaseUnitId,
        quantity: 10,
        factor: 12,
        identityKind: 'VARIANT',
      );
      await receive(order, quantity: 4, operationId: 'partial-one-$suffix');
      await receive(order, quantity: 6, operationId: 'partial-two-$suffix');

      final db = await FurnexaDatabase.instance.database;
      final identityKey = '__FURNEXA_VARIANT__:$variantId';
      final storedOrderItem = (await db.query(
        'purchase_order_items',
        where: 'id = ?',
        whereArgs: [order.items.single.id],
      )).single;
      expect(storedOrderItem['itemId'], identityKey);
      expect(storedOrderItem['productId'], variantProductId);
      expect(storedOrderItem['variantId'], variantId);
      expect(storedOrderItem['inventoryIdentityKind'], 'VARIANT');
      expect(storedOrderItem['unitId'], purchaseUnitId);
      expect(storedOrderItem['baseUnitId'], baseUnitId);
      expect(storedOrderItem['unitConversionFactor'], 12);
      expect(storedOrderItem['baseQuantity'], 120);
      expect(storedOrderItem['receivedQuantity'], 10);
      expect(storedOrderItem['receivedBaseQuantity'], 120);

      final receiptRows = await db.rawQuery(
        '''
      SELECT pri.productId, pri.variantId, pri.inventoryIdentityKind,
             pri.unitId, pri.unitConversionFactor, pri.baseUnitId,
             pri.baseQuantity, pri.receivedQuantity
      FROM purchase_receipt_items pri
      JOIN purchase_receipts pr ON pr.id = pri.purchaseReceiptId
      WHERE pr.purchaseOrderId = ?
      ORDER BY pr.receiptNumber
      ''',
        [order.id],
      );
      expect(receiptRows, hasLength(2));
      expect(receiptRows.map((row) => row['productId']), [
        variantProductId,
        variantProductId,
      ]);
      expect(receiptRows.map((row) => row['variantId']), [
        variantId,
        variantId,
      ]);
      expect(receiptRows.map((row) => row['inventoryIdentityKind']), [
        'VARIANT',
        'VARIANT',
      ]);
      expect(receiptRows.map((row) => row['unitId']), [
        purchaseUnitId,
        purchaseUnitId,
      ]);
      expect(receiptRows.map((row) => row['unitConversionFactor']), [12, 12]);
      expect(receiptRows.map((row) => row['baseUnitId']), [
        baseUnitId,
        baseUnitId,
      ]);
      expect(receiptRows.map((row) => row['baseQuantity']), [48, 72]);
      expect(receiptRows.map((row) => row['receivedQuantity']), [4, 6]);

      final stock = (await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      )).single;
      expect(stock['quantity'], 120);
      expect(stock['productId'], variantProductId);
      expect(stock['variantId'], variantId);
      final transactions = await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      );
      expect(transactions, hasLength(2));
      expect(transactions.map((row) => row['quantity']), [48, 72]);
      expect(transactions.every((row) => row['unitId'] == baseUnitId), isTrue);
      final valuation = (await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, identityKey],
      )).single;
      expect(valuation['quantity'], 120);
      expect(valuation['averageCost'], 5);
      expect(valuation['productId'], variantProductId);
      expect(valuation['variantId'], variantId);
      expect(valuation['inventoryIdentityKind'], 'VARIANT');
    },
  );

  test(
    'retry identities cannot duplicate receipt or inventory postings',
    () async {
      final order = await createOrder(
        id: 'receive-retry-$suffix',
        productId: variantProductId,
        selectedVariantId: variantId,
        unitId: baseUnitId,
        quantity: 5,
        identityKind: 'VARIANT',
      );
      final operationId = 'retry-$suffix';
      await receive(order, quantity: 2, operationId: operationId);
      await expectLater(
        receive(order, quantity: 2, operationId: operationId),
        throwsException,
      );
      await expectLater(
        receive(order, quantity: 3, operationId: operationId),
        throwsException,
      );

      final db = await FurnexaDatabase.instance.database;
      final identityKey = '__FURNEXA_VARIANT__:$variantId';
      expect(
        await db.query(
          'purchase_receipts',
          where: 'receiptNumber = ?',
          whereArgs: ['GR-OP-$operationId'],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'purchase_receipt_items',
          where: 'purchaseOrderItemId = ?',
          whereArgs: [order.items.single.id],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, identityKey],
        ),
        hasLength(1),
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, identityKey],
        )).single['quantity'],
        2,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, identityKey],
        )).single['quantity'],
        2,
      );
      expect(
        (await db.query(
          'purchase_order_items',
          where: 'id = ?',
          whereArgs: [order.items.single.id],
        )).single['receivedQuantity'],
        2,
      );
    },
  );

  test('products without variants continue receiving base inventory', () async {
    final order = await createOrder(
      id: 'receive-base-$suffix',
      productId: plainProductId,
      unitId: baseUnitId,
      quantity: 3,
    );
    await receive(order, quantity: 3, operationId: 'base-$suffix');

    final db = await FurnexaDatabase.instance.database;
    final stock = (await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ?',
      whereArgs: [warehouseId, plainProductId],
    )).single;
    expect(stock['productId'], plainProductId);
    expect(stock['variantId'], isNull);
    expect(stock['inventoryIdentityKind'], 'BASE');
    expect(stock['quantity'], 3);
    final valuation = (await db.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ?',
      whereArgs: [warehouseId, plainProductId],
    )).single;
    expect(valuation['quantity'], 3);
    expect(valuation['inventoryIdentityKind'], 'BASE');
  });

  test(
    'receiving rejects unsupported, inactive, and invalid unit snapshots',
    () async {
      final unsupportedUnitId = 'receive-unsupported-unit-$suffix';
      final db = await FurnexaDatabase.instance.database;
      await db.insert('units', {
        'id': unsupportedUnitId,
        'name': 'Unsupported $suffix',
        'abbreviation': 'RU$suffix',
        'active': 1,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      for (final invalid in [
        (
          id: 'unsupported',
          unit: unsupportedUnitId,
          factor: 1.0,
          message: 'unsupported unit',
        ),
        (
          id: 'inactive',
          unit: inactiveUnitId,
          factor: 6.0,
          message: 'inactive unit',
        ),
        (
          id: 'wrong-factor',
          unit: purchaseUnitId,
          factor: 11.0,
          message: 'mismatched factor',
        ),
        (
          id: 'zero-factor',
          unit: purchaseUnitId,
          factor: 0.0,
          message: 'nonpositive factor',
        ),
      ]) {
        await expectLater(
          createOrder(
            id: 'receive-invalid-${invalid.id}-$suffix',
            productId: variantProductId,
            selectedVariantId: variantId,
            unitId: invalid.unit,
            quantity: 1,
            factor: invalid.factor,
            identityKind: 'VARIANT',
          ),
          throwsException,
          reason: invalid.message,
        );
      }
    },
  );

  test('variant identity and product ownership are validated', () async {
    await expectLater(
      createOrder(
        id: 'receive-wrong-variant-$suffix',
        productId: variantProductId,
        selectedVariantId: foreignVariantId,
        unitId: baseUnitId,
        quantity: 1,
        identityKind: 'VARIANT',
      ),
      throwsException,
    );
    await expectLater(
      createOrder(
        id: 'receive-wrong-identity-kind-$suffix',
        productId: variantProductId,
        selectedVariantId: variantId,
        unitId: baseUnitId,
        quantity: 1,
      ),
      throwsException,
    );
  });

  test(
    'stock posting failure rolls back all receipt and inventory writes',
    () async {
      final order = await createOrder(
        id: 'receive-stock-rollback-$suffix',
        productId: variantProductId,
        selectedVariantId: variantId,
        unitId: baseUnitId,
        quantity: 2,
        identityKind: 'VARIANT',
      );
      final failingSource = PurchasingLocalDataSource(
        _FailAfterStockWrite(),
        AccountingLocalDataSource(),
      );
      await expectLater(
        receive(
          order,
          quantity: 2,
          operationId: 'stock-rollback-$suffix',
          source: failingSource,
        ),
        throwsStateError,
      );
      await expectNoReceiptOrInventoryWrites(order);
    },
  );

  test('valuation posting failure rolls back the prior stock write', () async {
    final order = await createOrder(
      id: 'receive-valuation-rollback-$suffix',
      productId: variantProductId,
      selectedVariantId: variantId,
      unitId: baseUnitId,
      quantity: 2,
      identityKind: 'VARIANT',
    );
    final failingSource = PurchasingLocalDataSource(
      WarehousesStockLocalDataSource(),
      _FailAfterValuationWrite(),
    );
    await expectLater(
      receive(
        order,
        quantity: 2,
        operationId: 'valuation-rollback-$suffix',
        source: failingSource,
      ),
      throwsStateError,
    );
    await expectNoReceiptOrInventoryWrites(order);
  });
}

class _FailAfterStockWrite extends WarehousesStockLocalDataSource {
  @override
  Future<void> applyStockInWithinTransaction({
    required DatabaseExecutor executor,
    required String warehouseId,
    required StockItemOption item,
    required double quantity,
    required DateTime date,
    String? reference,
    String? notes,
    String? operationId,
  }) async {
    await super.applyStockInWithinTransaction(
      executor: executor,
      warehouseId: warehouseId,
      item: item,
      quantity: quantity,
      date: date,
      reference: reference,
      notes: notes,
      operationId: operationId,
    );
    throw StateError('Injected stock posting failure');
  }
}

class _FailAfterValuationWrite extends AccountingLocalDataSource {
  @override
  Future<InventoryValuation> receiveInventoryValueWithinTransaction({
    required DatabaseExecutor executor,
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double quantity,
    required double unitCost,
    String? productId,
    String? variantId,
    InventoryIdentityKind identityKind = InventoryIdentityKind.base,
    String? unitId,
  }) async {
    await super.receiveInventoryValueWithinTransaction(
      executor: executor,
      warehouseId: warehouseId,
      itemId: itemId,
      itemType: itemType,
      quantity: quantity,
      unitCost: unitCost,
      productId: productId,
      variantId: variantId,
      identityKind: identityKind,
      unitId: unitId,
    );
    throw StateError('Injected valuation posting failure');
  }
}
