import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/returns_quality/data/datasources/returns_quality_local_data_source.dart';
import 'package:furnexa/features/returns_quality/domain/entities/returns_quality_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late ReturnsQualityLocalDataSource dataSource;
  late String suffix;
  late DateTime now;
  late String productId;
  late String variantProductId;
  late String variantId;
  late String secondVariantId;
  late String rawMaterialId;
  late String warehouseId;
  late String unitId;
  late String purchaseUnitId;
  late String customerId;
  late String supplierId;
  late String factoryId;
  late String categoryId;

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login('admin', 'Furnexa-Test-Admin-2026!');
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    now = DateTime(2026, 9, 17);
    dataSource = ReturnsQualityLocalDataSource();
    final db = await FurnexaDatabase.instance.database;
    factoryId = 'returns-factory-$suffix';
    categoryId = 'returns-category-$suffix';
    warehouseId = 'returns-warehouse-$suffix';
    unitId = 'returns-unit-$suffix';
    purchaseUnitId = 'returns-purchase-unit-$suffix';
    productId = 'returns-product-$suffix';
    variantProductId = 'returns-variant-product-$suffix';
    variantId = 'returns-variant-$suffix';
    secondVariantId = 'returns-second-variant-$suffix';
    rawMaterialId = 'returns-material-$suffix';
    customerId = 'returns-customer-$suffix';
    supplierId = 'returns-supplier-$suffix';
    final timestamp = now.millisecondsSinceEpoch;

    await db.insert('factories', {
      'id': factoryId,
      'name': 'مصنع المرتجعات $suffix',
      'code': 'RT-$suffix',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'مخزن المرتجعات $suffix',
      'code': 'RW-$suffix',
      'state': 'active',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'تصنيف المرتجعات $suffix',
      'code': 'RC-$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'وحدة المرتجعات $suffix',
      'abbreviation': 'RU$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('units', {
      'id': purchaseUnitId,
      'name': 'وحدة شراء المرتجعات $suffix',
      'abbreviation': 'RPU$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'منتج المرتجعات $suffix',
      'code': 'RP-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('products', {
      'id': variantProductId,
      'name': 'منتج متغير للمرتجعات $suffix',
      'code': 'RVP-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    for (final variant in [
      (variantId, 'اللون الأول', 'RV1-$suffix'),
      (secondVariantId, 'اللون الثاني', 'RV2-$suffix'),
    ]) {
      await db.insert('product_variants', {
        'id': variant.$1,
        'productId': variantProductId,
        'name': variant.$2,
        'code': variant.$3,
        'active': 1,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });
    }
    for (final conversionProductId in [productId, variantProductId]) {
      await db.insert('product_unit_conversions', {
        'id': 'conversion-$conversionProductId-$suffix',
        'productId': conversionProductId,
        'unitId': purchaseUnitId,
        'factorToBase': 12,
        'active': 1,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      });
    }
    await db.insert('raw_materials', {
      'id': rawMaterialId,
      'name': 'خامة المرتجعات $suffix',
      'code': 'RM-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('customers', {
      'id': customerId,
      'name': 'عميل المرتجعات $suffix',
      'code': 'CR-$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('suppliers', {
      'id': supplierId,
      'name': 'مورد المرتجعات $suffix',
      'code': 'SR-$suffix',
      'active': 1,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('sales_orders', {
      'id': 'sales-order-$suffix',
      'orderNumber': 'SO-$suffix',
      'customerId': customerId,
      'orderDate': now.millisecondsSinceEpoch,
      'status': 'CONFIRMED',
      'subtotal': 100,
      'discount': 0,
      'tax': 0,
      'grandTotal': 100,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('purchase_orders', {
      'id': 'purchase-order-$suffix',
      'orderNumber': 'PO-$suffix',
      'supplierId': supplierId,
      'orderDate': now.millisecondsSinceEpoch,
      'status': 'APPROVED',
      'subtotal': 100,
      'discount': 0,
      'tax': 0,
      'grandTotal': 100,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('purchase_order_items', {
      'id': 'purchase-order-item-$suffix',
      'purchaseOrderId': 'purchase-order-$suffix',
      'itemId': rawMaterialId,
      'productId': rawMaterialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 20,
      'unitId': unitId,
      'baseUnitId': unitId,
      'unitConversionFactor': 1,
      'baseQuantity': 20,
      'receivedBaseQuantity': 20,
      'inventoryIdentityKind': 'BASE',
      'identitySnapshotStatus': 'VERIFIED',
      'unitPrice': 8,
      'discount': 0,
      'tax': 0,
      'lineTotal': 160,
      'receivedQuantity': 20,
    });
    for (final orderLine in [
      (
        id: 'purchase-order-product-item-$suffix',
        productId: productId,
        itemId: productId,
        variantId: null,
        identityKind: 'BASE',
        unitPrice: 24.0,
      ),
      (
        id: 'purchase-order-variant-item-$suffix',
        productId: variantProductId,
        itemId: '__FURNEXA_VARIANT__:$variantId',
        variantId: variantId,
        identityKind: 'VARIANT',
        unitPrice: 24.0,
      ),
      (
        id: 'purchase-order-second-variant-item-$suffix',
        productId: variantProductId,
        itemId: '__FURNEXA_VARIANT__:$secondVariantId',
        variantId: secondVariantId,
        identityKind: 'VARIANT',
        unitPrice: 24.0,
      ),
    ]) {
      await db.insert('purchase_order_items', {
        'id': orderLine.id,
        'purchaseOrderId': 'purchase-order-$suffix',
        'itemId': orderLine.itemId,
        'productId': orderLine.productId,
        'variantId': orderLine.variantId,
        'inventoryIdentityKind': orderLine.identityKind,
        'itemType': 'PRODUCT',
        'quantity': 10,
        'unitId': purchaseUnitId,
        'baseUnitId': unitId,
        'unitConversionFactor': 12,
        'baseQuantity': 120,
        'receivedQuantity': 10,
        'receivedBaseQuantity': 120,
        'identitySnapshotStatus': 'VERIFIED',
        'unitPrice': orderLine.unitPrice,
        'discount': 0,
        'tax': 0,
        'lineTotal': 240,
      });
    }
    await db.insert('stock_balances', {
      'id': 'returns-stock-product-$suffix',
      'warehouseId': warehouseId,
      'itemId': productId,
      'itemType': 'PRODUCT',
      'quantity': 50,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('stock_balances', {
      'id': 'returns-stock-material-$suffix',
      'warehouseId': warehouseId,
      'itemId': rawMaterialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 20,
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });
    await db.insert('inventory_valuations', {
      'id': 'returns-valuation-material-$suffix',
      'warehouseId': warehouseId,
      'itemId': rawMaterialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 20,
      'averageCost': 8,
      'updatedAt': timestamp,
    });
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  Future<String> seedDeliveredSalesLine({
    required String id,
    required String sourceProductId,
    String? sourceVariantId,
    required String salesUnitId,
    required double quantity,
    required double deliveredQuantity,
    required double factor,
    required double unitRevenue,
    required double unitCogs,
  }) async {
    final db = await FurnexaDatabase.instance.database;
    final orderItemId = 'sales-order-item-$id';
    final deliveryId = 'sales-delivery-$id';
    final deliveryItemId = 'sales-delivery-item-$id';
    final identityKind = sourceVariantId == null ? 'BASE' : 'VARIANT';
    final inventoryId = sourceVariantId == null
        ? sourceProductId
        : '__FURNEXA_VARIANT__:$sourceVariantId';
    final baseQuantity = quantity * factor;
    final deliveredBaseQuantity = deliveredQuantity * factor;
    await db.insert('sales_order_items', {
      'id': orderItemId,
      'salesOrderId': 'sales-order-$suffix',
      'itemId': inventoryId,
      'productId': sourceProductId,
      'variantId': sourceVariantId,
      'itemType': 'PRODUCT',
      'quantity': quantity,
      'unitId': salesUnitId,
      'baseUnitId': unitId,
      'unitConversionFactor': factor,
      'baseQuantity': baseQuantity,
      'deliveredQuantity': deliveredQuantity,
      'deliveredBaseQuantity': deliveredBaseQuantity,
      'inventoryIdentityKind': identityKind,
      'identitySnapshotStatus': 'VERIFIED',
      'unitPrice': unitRevenue,
      'discount': 0,
      'tax': 0,
      'lineTotal': quantity * unitRevenue,
    });
    await db.insert('sales_deliveries', {
      'id': deliveryId,
      'deliveryNumber': 'DL-$id',
      'salesOrderId': 'sales-order-$suffix',
      'warehouseId': warehouseId,
      'deliveryDate': now.millisecondsSinceEpoch,
      'status': 'DELIVERED',
      'createdAt': now.millisecondsSinceEpoch,
    });
    await db.insert('sales_delivery_items', {
      'id': deliveryItemId,
      'salesDeliveryId': deliveryId,
      'salesOrderItemId': orderItemId,
      'deliveredQuantity': deliveredQuantity,
      'unitId': salesUnitId,
      'productId': sourceProductId,
      'variantId': sourceVariantId,
      'baseUnitId': unitId,
      'unitConversionFactor': factor,
      'baseQuantity': deliveredBaseQuantity,
      'inventoryIdentityKind': identityKind,
      'identitySnapshotStatus': 'VERIFIED',
      'unitRevenue': unitRevenue,
      'unitCogs': unitCogs,
    });
    return deliveryItemId;
  }

  Future<String> seedPurchaseReceiptLine({
    required String id,
    required String purchaseOrderItemId,
    required String sourceProductId,
    String? sourceVariantId,
    required String salesUnitId,
    required double receivedQuantity,
    required double factor,
    required String identityKind,
  }) async {
    final db = await FurnexaDatabase.instance.database;
    final receiptId = 'purchase-receipt-$id';
    await db.insert('purchase_receipts', {
      'id': receiptId,
      'receiptNumber': 'GR-$id',
      'purchaseOrderId': 'purchase-order-$suffix',
      'warehouseId': warehouseId,
      'receiptDate': now.millisecondsSinceEpoch,
      'createdAt': now.millisecondsSinceEpoch,
    });
    await db.insert('purchase_receipt_items', {
      'id': 'purchase-receipt-item-$id',
      'purchaseReceiptId': receiptId,
      'purchaseOrderItemId': purchaseOrderItemId,
      'receivedQuantity': receivedQuantity,
      'productId': sourceProductId,
      'variantId': sourceVariantId,
      'unitId': salesUnitId,
      'baseUnitId': unitId,
      'unitConversionFactor': factor,
      'baseQuantity': receivedQuantity * factor,
      'inventoryIdentityKind': identityKind,
      'identitySnapshotStatus': 'VERIFIED',
    });
    return receiptId;
  }

  test(
    'approved sales return increases warehouse stock and stores return record',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final salesOrderItemId = 'sales-order-item-$suffix';
      final salesDeliveryId = 'sales-delivery-$suffix';
      final salesDeliveryItemId = 'sales-delivery-item-$suffix';
      await db.insert('sales_order_items', {
        'id': salesOrderItemId,
        'salesOrderId': 'sales-order-$suffix',
        'itemId': productId,
        'itemType': 'PRODUCT',
        'quantity': 10,
        'unitId': unitId,
        'unitPrice': 5,
        'discount': 0,
        'tax': 0,
        'lineTotal': 50,
        'deliveredQuantity': 10,
      });
      await db.insert('sales_deliveries', {
        'id': salesDeliveryId,
        'deliveryNumber': 'DL-$suffix',
        'salesOrderId': 'sales-order-$suffix',
        'warehouseId': warehouseId,
        'deliveryDate': now.millisecondsSinceEpoch,
        'status': 'DELIVERED',
        'createdAt': now.millisecondsSinceEpoch,
      });
      await db.insert('sales_delivery_items', {
        'id': salesDeliveryItemId,
        'salesDeliveryId': salesDeliveryId,
        'salesOrderItemId': salesOrderItemId,
        'deliveredQuantity': 10,
        'unitId': unitId,
        'productId': productId,
        'baseUnitId': unitId,
        'unitConversionFactor': 1,
        'baseQuantity': 10,
        'inventoryIdentityKind': 'BASE',
        'identitySnapshotStatus': 'VERIFIED',
        'unitRevenue': 5,
        'unitCogs': 2,
      });
      await db.insert('inventory_valuations', {
        'id': 'sales-return-valuation-$suffix',
        'warehouseId': warehouseId,
        'itemId': productId,
        'itemType': 'PRODUCT',
        'quantity': 10,
        'averageCost': 2,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      final saved = await dataSource.saveSalesReturn(
        SalesReturn(
          id: 'sr-$suffix',
          returnNumber: 'SR-$suffix',
          salesOrderId: 'sales-order-$suffix',
          customerId: customerId,
          warehouseId: warehouseId,
          returnDate: now,
          salesDeliveryId: salesDeliveryId,
          status: ReturnStatus.approved,
          createdAt: now,
          updatedAt: now,
          items: [
            SalesReturnItem(
              id: 'sr-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 10,
              unitId: unitId,
              unitPrice: 5,
              qualityStatus: ReturnQualityStatus.approved,
              sourceDeliveryItemId: salesDeliveryItemId,
            ),
          ],
        ),
      );

      expect(saved.items.single.qualityStatus, ReturnQualityStatus.approved);
      final rows = await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
        limit: 1,
      );
      expect((rows.single['quantity'] as num).toDouble(), 60);
      final valuationRows = await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
        limit: 1,
      );
      expect((valuationRows.single['quantity'] as num).toDouble(), 20);
      expect((valuationRows.single['averageCost'] as num).toDouble(), 2);
      expect((await dataSource.salesReturns()).length, 1);
      final journals = await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['SALES_RETURN', saved.id],
      );
      expect(journals, hasLength(1));
      final journalLines = await db.query(
        'journal_lines',
        where: 'journalEntryId = ?',
        whereArgs: [journals.single['id']],
      );
      expect(
        journalLines.fold<double>(
          0,
          (sum, line) => sum + (line['debit'] as num).toDouble(),
        ),
        70,
      );
      expect(
        journalLines.fold<double>(
          0,
          (sum, line) => sum + (line['credit'] as num).toDouble(),
        ),
        70,
      );
      await expectLater(dataSource.saveSalesReturn(saved), throwsException);
      await expectLater(
        dataSource.createSalesReturn(
          id: 'sr-over-$suffix',
          returnNumber: 'SR-OVER-$suffix',
          salesOrderId: 'sales-order-$suffix',
          customerId: customerId,
          warehouseId: warehouseId,
          returnDate: now,
          salesDeliveryId: salesDeliveryId,
          status: ReturnStatus.approved,
          items: [
            SalesReturnItem(
              id: 'sr-over-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 1,
              unitId: unitId,
              qualityStatus: ReturnQualityStatus.approved,
              sourceDeliveryItemId: salesDeliveryItemId,
            ),
          ],
        ),
        throwsException,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['SALES_RETURN', saved.id],
        ),
        hasLength(1),
      );
    },
  );

  test(
    'approved purchase return reduces warehouse stock and records supplier return',
    () async {
      await dataSource.savePurchaseReturn(
        PurchaseReturn(
          id: 'pr-$suffix',
          returnNumber: 'PR-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          status: ReturnStatus.approved,
          createdAt: now,
          updatedAt: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-item-$suffix',
              itemId: rawMaterialId,
              itemType: 'RAW_MATERIAL',
              quantity: 5,
              unitId: unitId,
              unitPrice: 8,
              qualityStatus: ReturnQualityStatus.approved,
            ),
          ],
        ),
      );

      final rows = await (await FurnexaDatabase.instance.database).query(
        'purchase_returns',
        where: 'supplierId = ?',
        whereArgs: [supplierId],
      );
      expect(rows, hasLength(1));
      expect((await dataSource.purchaseReturns()).length, 1);
      final stockRows = await (await FurnexaDatabase.instance.database).query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, rawMaterialId],
        limit: 1,
      );
      expect((stockRows.single['quantity'] as num).toDouble(), 15);
      final valuationRows = await (await FurnexaDatabase.instance.database)
          .query(
            'inventory_valuations',
            where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
            whereArgs: [warehouseId, rawMaterialId, 'RAW_MATERIAL'],
            limit: 1,
          );
      expect((valuationRows.single['quantity'] as num).toDouble(), 15);
      expect((valuationRows.single['averageCost'] as num).toDouble(), 8);
      final db = await FurnexaDatabase.instance.database;
      final journal = await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['PURCHASE_RETURN', 'pr-$suffix'],
        limit: 1,
      );
      expect(journal, hasLength(1));
      final apLines = await db.query(
        'journal_lines',
        where: 'journalEntryId = ?',
        whereArgs: [journal.single['id']],
      );
      expect(
        apLines.fold<double>(
          0,
          (sum, line) => sum + (line['debit'] as num).toDouble(),
        ),
        40,
      );
    },
  );

  test(
    'alternative-unit sales return reverses revenue in sales units and COGS in base units',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'factor-sales-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        quantity: 10,
        deliveredQuantity: 4,
        factor: 12,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await db.insert('inventory_valuations', {
        'id': 'returns-valuation-factor-sales-$suffix',
        'warehouseId': warehouseId,
        'itemId': productId,
        'itemType': 'PRODUCT',
        'productId': productId,
        'inventoryIdentityKind': 'BASE',
        'unitId': unitId,
        'quantity': 50,
        'averageCost': 2,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await dataSource.createSalesReturn(
        id: 'sr-factor-$suffix',
        returnNumber: 'SR-FACTOR-$suffix',
        salesOrderId: 'sales-order-$suffix',
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: 'sales-delivery-factor-sales-$suffix',
        status: ReturnStatus.approved,
        items: [
          SalesReturnItem(
            id: 'sr-factor-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 4,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 48,
            inventoryIdentityKind: 'BASE',
            qualityStatus: ReturnQualityStatus.approved,
            sourceDeliveryItemId: deliveryItemId,
          ),
        ],
      );

      final returnItem = (await db.query(
        'sales_return_items',
        where: 'sourceDeliveryItemId = ?',
        whereArgs: [deliveryItemId],
      )).single;
      final reloadedReturnItem = SalesReturnItem.fromMap(returnItem);
      expect(reloadedReturnItem.itemId, productId);
      expect(reloadedReturnItem.unitConversionFactor, 12);
      expect(reloadedReturnItem.baseQuantity, 48);
      expect(returnItem['productId'], productId);
      expect(returnItem['unitId'], purchaseUnitId);
      expect(returnItem['baseUnitId'], unitId);
      expect(returnItem['unitConversionFactor'], 12);
      expect(returnItem['baseQuantity'], 48);
      expect(returnItem['inventoryIdentityKind'], 'BASE');
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        98,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        )).single['quantity'],
        98,
      );
      final journal = (await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['SALES_RETURN', 'sr-factor-$suffix'],
      )).single;
      final lines = await db.rawQuery(
        '''
        SELECT a.code, jl.debit, jl.credit
        FROM journal_lines jl JOIN accounts a ON a.id = jl.accountId
        WHERE jl.journalEntryId = ?
        ''',
        [journal['id']],
      );
      final byAccount = {for (final line in lines) line['code']: line};
      expect(byAccount['4000']!['debit'], 20);
      expect(byAccount['1200']!['credit'], 20);
      expect(byAccount['1100']!['debit'], 96);
      expect(byAccount['5000']!['credit'], 96);
      expect(
        lines.fold<double>(
          0,
          (sum, line) => sum + (line['debit'] as num).toDouble(),
        ),
        116,
      );
      expect(
        lines.fold<double>(
          0,
          (sum, line) => sum + (line['credit'] as num).toDouble(),
        ),
        116,
      );
    },
  );

  test(
    'sales return rejects non-finite quantities before any writes',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'sales-invalid-quantity-$suffix',
        sourceProductId: productId,
        salesUnitId: unitId,
        quantity: 5,
        deliveredQuantity: 5,
        factor: 1,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await expectLater(
        dataSource.createSalesReturn(
          id: 'sr-nan-quantity-$suffix',
          returnNumber: 'SR-NAN-QUANTITY-$suffix',
          salesOrderId: 'sales-order-$suffix',
          customerId: customerId,
          warehouseId: warehouseId,
          returnDate: now,
          salesDeliveryId: 'sales-delivery-sales-invalid-quantity-$suffix',
          status: ReturnStatus.approved,
          items: [
            SalesReturnItem(
              id: 'sr-nan-quantity-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: double.nan,
              unitId: unitId,
              baseUnitId: unitId,
              unitConversionFactor: 1,
              baseQuantity: 1,
              inventoryIdentityKind: 'BASE',
              identitySnapshotStatus: 'VERIFIED',
              sourceDeliveryItemId: deliveryItemId,
            ),
          ],
        ),
        throwsException,
      );
      expect(await db.query('sales_returns'), isEmpty);
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
      expect(await db.query('journal_entries'), isEmpty);
    },
  );

  test(
    'pending purchase return reserves received quantity and approval consumes it once',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'stock_balances',
        {'quantity': 150},
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
      );
      await db.insert('inventory_valuations', {
        'id': 'returns-product-valuation-$suffix',
        'warehouseId': warehouseId,
        'itemId': productId,
        'itemType': 'PRODUCT',
        'productId': productId,
        'inventoryIdentityKind': 'BASE',
        'unitId': unitId,
        'quantity': 120,
        'averageCost': 2,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.update(
        'product_unit_conversions',
        {'factorToBase': 24},
        where: 'productId = ? AND unitId = ?',
        whereArgs: [productId, purchaseUnitId],
      );
      final firstReturn = await dataSource.createPurchaseReturn(
        id: 'pr-reserved-$suffix',
        returnNumber: 'PR-RESERVED-$suffix',
        purchaseOrderId: 'purchase-order-$suffix',
        supplierId: supplierId,
        warehouseId: warehouseId,
        returnDate: now,
        items: [
          PurchaseReturnItem(
            id: 'pr-reserved-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 6,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 72,
            inventoryIdentityKind: 'BASE',
            qualityStatus: ReturnQualityStatus.approved,
          ),
        ],
      );
      final storedItem = (await db.query(
        'purchase_return_items',
        where: 'purchaseReturnId = ?',
        whereArgs: [firstReturn.id],
      )).single;
      final reloadedItem = PurchaseReturnItem.fromMap(storedItem);
      expect(reloadedItem.itemId, productId);
      expect(
        reloadedItem.purchaseOrderItemId,
        'purchase-order-product-item-$suffix',
      );
      expect(reloadedItem.unitConversionFactor, 12);
      expect(reloadedItem.baseQuantity, 72);
      expect(storedItem['productId'], productId);
      expect(
        storedItem['purchaseOrderItemId'],
        'purchase-order-product-item-$suffix',
      );
      expect(storedItem['baseQuantity'], 72);
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        150,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        120,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['PURCHASE_RETURN', firstReturn.id],
        ),
        isEmpty,
      );
      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-over-reservation-$suffix',
          returnNumber: 'PR-OVER-RESERVATION-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-over-reservation-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 5,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 60,
              inventoryIdentityKind: 'BASE',
            ),
          ],
        ),
        throwsException,
      );

      await dataSource.updatePurchaseReturnStatus(
        firstReturn.id,
        ReturnStatus.approved,
      );
      await dataSource.updatePurchaseReturnStatus(
        firstReturn.id,
        ReturnStatus.approved,
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        78,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        48,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['PURCHASE_RETURN', firstReturn.id],
        ),
        hasLength(1),
      );
      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-over-posted-$suffix',
          returnNumber: 'PR-OVER-POSTED-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-over-posted-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 5,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 60,
              inventoryIdentityKind: 'BASE',
            ),
          ],
        ),
        throwsException,
      );
    },
  );

  test(
    'failed sales return journal posting rolls back the complete return',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'sales-rollback-$suffix',
        sourceProductId: productId,
        salesUnitId: unitId,
        quantity: 5,
        deliveredQuantity: 5,
        factor: 1,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await db.insert('inventory_valuations', {
        'id': 'sales-rollback-valuation-$suffix',
        'warehouseId': warehouseId,
        'itemId': productId,
        'itemType': 'PRODUCT',
        'productId': productId,
        'inventoryIdentityKind': 'BASE',
        'unitId': unitId,
        'quantity': 50,
        'averageCost': 2,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.execute('''
      CREATE TRIGGER fail_sales_return_journal
      BEFORE INSERT ON journal_entries
      WHEN NEW.referenceType = 'SALES_RETURN'
      BEGIN
        SELECT RAISE(ABORT, 'injected sales return journal failure');
      END
    ''');
      try {
        await expectLater(
          dataSource.createSalesReturn(
            id: 'sr-rollback-$suffix',
            returnNumber: 'SR-ROLLBACK-$suffix',
            salesOrderId: 'sales-order-$suffix',
            customerId: customerId,
            warehouseId: warehouseId,
            returnDate: now,
            salesDeliveryId: 'sales-delivery-sales-rollback-$suffix',
            status: ReturnStatus.approved,
            items: [
              SalesReturnItem(
                id: 'sr-rollback-item-$suffix',
                itemId: productId,
                itemType: 'PRODUCT',
                quantity: 1,
                unitId: unitId,
                baseUnitId: unitId,
                unitConversionFactor: 1,
                baseQuantity: 1,
                qualityStatus: ReturnQualityStatus.approved,
                sourceDeliveryItemId: deliveryItemId,
              ),
            ],
          ),
          throwsException,
        );
      } finally {
        await db.execute('DROP TRIGGER IF EXISTS fail_sales_return_journal');
      }
      expect(
        await db.query(
          'sales_returns',
          where: 'id = ?',
          whereArgs: ['sr-rollback-$suffix'],
        ),
        isEmpty,
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        50,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        50,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['SALES_RETURN', 'sr-rollback-$suffix'],
        ),
        isEmpty,
      );
    },
  );

  test(
    'pending sales returns reserve quantity until rejected or approved',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'sales-reservation-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        quantity: 10,
        deliveredQuantity: 10,
        factor: 12,
        unitRevenue: 5,
        unitCogs: 2,
      );

      Future<SalesReturn> reserveSalesReturn(String id, double quantity) =>
          dataSource.createSalesReturn(
            id: id,
            returnNumber: 'SR-$id',
            salesOrderId: 'sales-order-$suffix',
            customerId: customerId,
            warehouseId: warehouseId,
            returnDate: now,
            salesDeliveryId: 'sales-delivery-sales-reservation-$suffix',
            items: [
              SalesReturnItem(
                id: '$id-item',
                itemId: productId,
                itemType: 'PRODUCT',
                quantity: quantity,
                unitId: purchaseUnitId,
                baseUnitId: unitId,
                unitConversionFactor: 12,
                baseQuantity: quantity * 12,
                inventoryIdentityKind: 'BASE',
                qualityStatus: ReturnQualityStatus.approved,
                sourceDeliveryItemId: deliveryItemId,
              ),
            ],
          );

      final rejectedReservation = await reserveSalesReturn(
        'sr-pending-release-$suffix',
        6,
      );
      await expectLater(
        reserveSalesReturn('sr-pending-overflow-$suffix', 5),
        throwsException,
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        50,
      );
      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
      expect(await db.query('journal_entries'), isEmpty);
      await dataSource.updateSalesReturnStatus(
        rejectedReservation.id,
        ReturnStatus.rejected,
      );

      Future<bool> tryReserveConcurrent(String id) async {
        try {
          await reserveSalesReturn(id, 6);
          return true;
        } on Exception {
          return false;
        }
      }

      final concurrent = await Future.wait([
        tryReserveConcurrent('sr-concurrent-a-$suffix'),
        tryReserveConcurrent('sr-concurrent-b-$suffix'),
      ]);
      expect(concurrent.where((accepted) => accepted), hasLength(1));
      final acceptedId = concurrent.first
          ? 'sr-concurrent-a-$suffix'
          : 'sr-concurrent-b-$suffix';
      await dataSource.updateSalesReturnStatus(
        acceptedId,
        ReturnStatus.cancelled,
      );
      final finalReturn = await reserveSalesReturn(
        'sr-pending-approved-$suffix',
        10,
      );
      await dataSource.updateSalesReturnStatus(
        finalReturn.id,
        ReturnStatus.approved,
      );
      await dataSource.updateSalesReturnStatus(
        finalReturn.id,
        ReturnStatus.approved,
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        170,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['SALES_RETURN', finalReturn.id],
        ),
        hasLength(1),
      );
    },
  );

  test(
    'rejected and cancelled purchase reservations release received quantity',
    () async {
      Future<PurchaseReturn> reserveRawMaterialReturn(
        String id,
        double quantity,
      ) => dataSource.createPurchaseReturn(
        id: id,
        returnNumber: 'PR-$id',
        purchaseOrderId: 'purchase-order-$suffix',
        supplierId: supplierId,
        warehouseId: warehouseId,
        returnDate: now,
        items: [
          PurchaseReturnItem(
            id: '$id-item',
            itemId: rawMaterialId,
            itemType: 'RAW_MATERIAL',
            quantity: quantity,
            unitId: unitId,
            baseUnitId: unitId,
            unitConversionFactor: 1,
            baseQuantity: quantity,
            inventoryIdentityKind: 'BASE',
          ),
        ],
      );

      final rejected = await reserveRawMaterialReturn(
        'pr-release-rejected-$suffix',
        12,
      );
      await dataSource.updatePurchaseReturnStatus(
        rejected.id,
        ReturnStatus.rejected,
      );
      final cancelled = await reserveRawMaterialReturn(
        'pr-release-cancelled-$suffix',
        20,
      );
      await dataSource.updatePurchaseReturnStatus(
        cancelled.id,
        ReturnStatus.cancelled,
      );
      await expectLater(
        reserveRawMaterialReturn('pr-after-release-$suffix', 20),
        completes,
      );
      final db = await FurnexaDatabase.instance.database;
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, rawMaterialId],
        )).single['quantity'],
        20,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, rawMaterialId],
        )).single['quantity'],
        20,
      );
      expect(await db.query('journal_entries'), isEmpty);
    },
  );

  test(
    'purchase return reservations honor the selected receipt quantity',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final firstReceiptId = 'purchase-receipt-first-$suffix';
      final secondReceiptId = 'purchase-receipt-second-$suffix';
      for (final receipt in [
        (id: firstReceiptId, number: 'GR-FIRST-$suffix', quantity: 4.0),
        (id: secondReceiptId, number: 'GR-SECOND-$suffix', quantity: 6.0),
      ]) {
        await db.insert('purchase_receipts', {
          'id': receipt.id,
          'receiptNumber': receipt.number,
          'purchaseOrderId': 'purchase-order-$suffix',
          'warehouseId': warehouseId,
          'receiptDate': now.millisecondsSinceEpoch,
          'createdAt': now.millisecondsSinceEpoch,
        });
        await db.insert('purchase_receipt_items', {
          'id': 'receipt-line-${receipt.id}',
          'purchaseReceiptId': receipt.id,
          'purchaseOrderItemId': 'purchase-order-product-item-$suffix',
          'receivedQuantity': receipt.quantity,
          'productId': productId,
          'unitId': purchaseUnitId,
          'baseUnitId': unitId,
          'unitConversionFactor': 12,
          'baseQuantity': receipt.quantity * 12,
          'inventoryIdentityKind': 'BASE',
          'identitySnapshotStatus': 'VERIFIED',
        });
      }
      await dataSource.createPurchaseReturn(
        id: 'pr-first-receipt-$suffix',
        returnNumber: 'PR-FIRST-RECEIPT-$suffix',
        purchaseOrderId: 'purchase-order-$suffix',
        purchaseReceiptId: firstReceiptId,
        supplierId: supplierId,
        warehouseId: warehouseId,
        returnDate: now,
        items: [
          PurchaseReturnItem(
            id: 'pr-first-receipt-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 4,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 48,
            inventoryIdentityKind: 'BASE',
          ),
        ],
      );
      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-first-receipt-over-$suffix',
          returnNumber: 'PR-FIRST-RECEIPT-OVER-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          purchaseReceiptId: firstReceiptId,
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-first-receipt-over-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 1,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 12,
              inventoryIdentityKind: 'BASE',
            ),
          ],
        ),
        throwsException,
      );
      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-second-receipt-$suffix',
          returnNumber: 'PR-SECOND-RECEIPT-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          purchaseReceiptId: secondReceiptId,
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-second-receipt-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 6,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 72,
              inventoryIdentityKind: 'BASE',
            ),
          ],
        ),
        completes,
      );
      final savedSource = await db.query(
        'purchase_return_items',
        where: 'purchaseReturnId = ?',
        whereArgs: ['pr-first-receipt-$suffix'],
      );
      expect(savedSource.single['sourceReceiptId'], firstReceiptId);
    },
  );

  test(
    'unknown historical receipt reservations block only their source line',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final baseReceiptId = await seedPurchaseReceiptLine(
        id: 'legacy-base-$suffix',
        purchaseOrderItemId: 'purchase-order-product-item-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        receivedQuantity: 4,
        factor: 12,
        identityKind: 'BASE',
      );
      final siblingVariantReceiptId = await seedPurchaseReceiptLine(
        id: 'sibling-variant-$suffix',
        purchaseOrderItemId: 'purchase-order-second-variant-item-$suffix',
        sourceProductId: variantProductId,
        sourceVariantId: secondVariantId,
        salesUnitId: purchaseUnitId,
        receivedQuantity: 10,
        factor: 12,
        identityKind: 'VARIANT',
      );
      for (final legacy in [
        (
          id: 'legacy-return-base-$suffix',
          itemId: productId,
          product: productId,
          variant: null,
          unit: purchaseUnitId,
          baseUnit: unitId,
          factor: 12,
          baseQuantity: 24,
          identityKind: 'BASE',
        ),
        (
          id: 'legacy-return-variant-$suffix',
          itemId: variantProductId,
          product: variantProductId,
          variant: variantId,
          unit: purchaseUnitId,
          baseUnit: unitId,
          factor: 12,
          baseQuantity: 12,
          identityKind: 'VARIANT',
        ),
      ]) {
        await db.insert('purchase_returns', {
          'id': legacy.id,
          'returnNumber': 'PR-${legacy.id}',
          'purchaseOrderId': 'purchase-order-$suffix',
          'supplierId': supplierId,
          'warehouseId': warehouseId,
          'returnDate': now.millisecondsSinceEpoch,
          'status': 'PENDING',
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        });
        await db.insert('purchase_return_items', {
          'id': '${legacy.id}-item',
          'purchaseReturnId': legacy.id,
          'itemId': legacy.itemId,
          'productId': legacy.product,
          'variantId': legacy.variant,
          'itemType': 'PRODUCT',
          'quantity': legacy.baseQuantity / legacy.factor,
          'unitId': legacy.unit,
          'baseUnitId': legacy.baseUnit,
          'unitConversionFactor': legacy.factor,
          'baseQuantity': legacy.baseQuantity,
          'inventoryIdentityKind': legacy.identityKind,
          'identitySnapshotStatus': 'VERIFIED',
          'unitPrice': 24,
          'qualityStatus': 'PENDING',
          'createdAt': now.millisecondsSinceEpoch,
        });
      }

      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-after-unknown-base-$suffix',
          returnNumber: 'PR-AFTER-UNKNOWN-BASE-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-after-unknown-base-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 3,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 36,
              inventoryIdentityKind: 'BASE',
              sourceReceiptId: baseReceiptId,
            ),
          ],
        ),
        throwsException,
      );

      final legacyBaseItem = (await db.query(
        'purchase_return_items',
        where: 'purchaseReturnId = ?',
        whereArgs: ['legacy-return-base-$suffix'],
      )).single;
      expect(legacyBaseItem['purchaseOrderItemId'], isNull);
      expect(legacyBaseItem['sourceReceiptId'], isNull);
      expect(
        (await db.query(
          'purchase_returns',
          columns: ['purchaseReceiptId'],
          where: 'id = ?',
          whereArgs: ['legacy-return-base-$suffix'],
        )).single['purchaseReceiptId'],
        isNull,
      );

      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-sibling-variant-$suffix',
          returnNumber: 'PR-SIBLING-VARIANT-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-sibling-variant-item-$suffix',
              itemId: variantProductId,
              itemType: 'PRODUCT',
              quantity: 1,
              unitId: purchaseUnitId,
              variantId: secondVariantId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 12,
              inventoryIdentityKind: 'VARIANT',
              identitySnapshotStatus: 'VERIFIED',
              sourceReceiptId: siblingVariantReceiptId,
            ),
          ],
        ),
        completes,
      );
    },
  );

  test(
    'purchase return tracks multiple receipts independently within one document',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final firstReceiptId = await seedPurchaseReceiptLine(
        id: 'mixed-first-$suffix',
        purchaseOrderItemId: 'purchase-order-product-item-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        receivedQuantity: 4,
        factor: 12,
        identityKind: 'BASE',
      );
      final secondReceiptId = await seedPurchaseReceiptLine(
        id: 'mixed-second-$suffix',
        purchaseOrderItemId: 'purchase-order-product-item-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        receivedQuantity: 6,
        factor: 12,
        identityKind: 'BASE',
      );

      final mixedReturn = await dataSource.createPurchaseReturn(
        id: 'pr-mixed-receipts-$suffix',
        returnNumber: 'PR-MIXED-RECEIPTS-$suffix',
        purchaseOrderId: 'purchase-order-$suffix',
        supplierId: supplierId,
        warehouseId: warehouseId,
        returnDate: now,
        items: [
          PurchaseReturnItem(
            id: 'pr-mixed-first-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 3,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 36,
            inventoryIdentityKind: 'BASE',
            sourceReceiptId: firstReceiptId,
          ),
          PurchaseReturnItem(
            id: 'pr-mixed-second-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 5,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 60,
            inventoryIdentityKind: 'BASE',
            sourceReceiptId: secondReceiptId,
          ),
        ],
      );
      expect(mixedReturn.purchaseReceiptId, isNull);
      final mixedItems = await db.query(
        'purchase_return_items',
        where: 'purchaseReturnId = ?',
        whereArgs: [mixedReturn.id],
        orderBy: 'id',
      );
      expect(mixedItems.map((item) => item['sourceReceiptId']).toSet(), {
        firstReceiptId,
        secondReceiptId,
      });

      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-mixed-first-over-$suffix',
          returnNumber: 'PR-MIXED-FIRST-OVER-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-mixed-first-over-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 2,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 24,
              inventoryIdentityKind: 'BASE',
              sourceReceiptId: firstReceiptId,
            ),
          ],
        ),
        throwsException,
      );
      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-mixed-second-final-$suffix',
          returnNumber: 'PR-MIXED-SECOND-FINAL-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-mixed-second-final-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              quantity: 1,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 12,
              inventoryIdentityKind: 'BASE',
              sourceReceiptId: secondReceiptId,
            ),
          ],
        ),
        completes,
      );
    },
  );

  test(
    'failed purchase return journal posting rolls back stock and valuation',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.execute('''
      CREATE TRIGGER fail_purchase_return_journal
      BEFORE INSERT ON journal_entries
      WHEN NEW.referenceType = 'PURCHASE_RETURN'
      BEGIN
        SELECT RAISE(ABORT, 'injected purchase return journal failure');
      END
    ''');
      try {
        await expectLater(
          dataSource.createPurchaseReturn(
            id: 'pr-rollback-$suffix',
            returnNumber: 'PR-ROLLBACK-$suffix',
            purchaseOrderId: 'purchase-order-$suffix',
            supplierId: supplierId,
            warehouseId: warehouseId,
            returnDate: now,
            status: ReturnStatus.approved,
            items: [
              PurchaseReturnItem(
                id: 'pr-rollback-item-$suffix',
                itemId: rawMaterialId,
                itemType: 'RAW_MATERIAL',
                quantity: 5,
                unitId: unitId,
                baseUnitId: unitId,
                unitConversionFactor: 1,
                baseQuantity: 5,
                inventoryIdentityKind: 'BASE',
                identitySnapshotStatus: 'VERIFIED',
                qualityStatus: ReturnQualityStatus.approved,
              ),
            ],
          ),
          throwsException,
        );
      } finally {
        await db.execute('DROP TRIGGER IF EXISTS fail_purchase_return_journal');
      }
      expect(
        await db.query(
          'purchase_returns',
          where: 'id = ?',
          whereArgs: ['pr-rollback-$suffix'],
        ),
        isEmpty,
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, rawMaterialId],
        )).single['quantity'],
        20,
      );
      expect(
        (await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, rawMaterialId],
        )).single['quantity'],
        20,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['PURCHASE_RETURN', 'pr-rollback-$suffix'],
        ),
        isEmpty,
      );
    },
  );

  test(
    'purchase return reservations isolate variants and stable PO lines',
    () async {
      final db = await FurnexaDatabase.instance.database;
      for (final variant in [variantId, secondVariantId]) {
        await db.insert('stock_balances', {
          'id': 'purchase-variant-stock-$variant-$suffix',
          'warehouseId': warehouseId,
          'itemId': '__FURNEXA_VARIANT__:$variant',
          'itemType': 'PRODUCT',
          'productId': variantProductId,
          'variantId': variant,
          'inventoryIdentityKind': 'VARIANT',
          'unitId': unitId,
          'quantity': 120,
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        });
        await db.insert('inventory_valuations', {
          'id': 'purchase-variant-value-$variant-$suffix',
          'warehouseId': warehouseId,
          'itemId': '__FURNEXA_VARIANT__:$variant',
          'itemType': 'PRODUCT',
          'productId': variantProductId,
          'variantId': variant,
          'inventoryIdentityKind': 'VARIANT',
          'unitId': unitId,
          'quantity': 120,
          'averageCost': 2,
          'updatedAt': now.millisecondsSinceEpoch,
        });
      }
      for (final variant in [variantId, secondVariantId]) {
        await dataSource.createPurchaseReturn(
          id: 'pr-variant-$variant-$suffix',
          returnNumber: 'PR-VARIANT-$variant-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-variant-item-$variant-$suffix',
              itemId: variantProductId,
              itemType: 'PRODUCT',
              quantity: 10,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 120,
              variantId: variant,
              inventoryIdentityKind: 'VARIANT',
              identitySnapshotStatus: 'VERIFIED',
              qualityStatus: ReturnQualityStatus.approved,
            ),
          ],
        );
      }
      final storedItems = await db.query(
        'purchase_return_items',
        where: 'itemType = ? AND productId = ?',
        whereArgs: ['PRODUCT', variantProductId],
      );
      expect(storedItems, hasLength(2));
      expect(storedItems.map((row) => row['variantId']).toSet(), {
        variantId,
        secondVariantId,
      });
      expect(storedItems.map((row) => row['purchaseOrderItemId']).toSet(), {
        'purchase-order-variant-item-$suffix',
        'purchase-order-second-variant-item-$suffix',
      });
      await dataSource.updatePurchaseReturnStatus(
        'pr-variant-$variantId-$suffix',
        ReturnStatus.approved,
      );
      for (final variant in [variantId, secondVariantId]) {
        expect(
          (await db.query(
            'stock_balances',
            where: 'warehouseId = ? AND itemId = ?',
            whereArgs: [warehouseId, '__FURNEXA_VARIANT__:$variant'],
          )).single['quantity'],
          variant == variantId ? 0 : 120,
        );
        expect(
          (await db.query(
            'inventory_valuations',
            where: 'warehouseId = ? AND itemId = ?',
            whereArgs: [warehouseId, '__FURNEXA_VARIANT__:$variant'],
          )).single['quantity'],
          variant == variantId ? 0 : 120,
        );
      }
      await expectLater(
        dataSource.createPurchaseReturn(
          id: 'pr-variant-over-$suffix',
          returnNumber: 'PR-VARIANT-OVER-$suffix',
          purchaseOrderId: 'purchase-order-$suffix',
          supplierId: supplierId,
          warehouseId: warehouseId,
          returnDate: now,
          items: [
            PurchaseReturnItem(
              id: 'pr-variant-over-item-$suffix',
              itemId: variantProductId,
              itemType: 'PRODUCT',
              quantity: 1,
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              baseQuantity: 12,
              variantId: variantId,
              inventoryIdentityKind: 'LEGACY_UNASSIGNED',
            ),
          ],
        ),
        throwsException,
      );
    },
  );

  test(
    'purchase return rejects inconsistent or invalid unit snapshots',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final invalidItems = [
        (
          id: 'quantity-zero',
          quantity: 0.0,
          factor: 12.0,
          base: 0.0,
          unit: purchaseUnitId,
        ),
        (
          id: 'quantity-negative',
          quantity: -1.0,
          factor: 12.0,
          base: -12.0,
          unit: purchaseUnitId,
        ),
        (
          id: 'quantity-infinite',
          quantity: double.infinity,
          factor: 12.0,
          base: double.infinity,
          unit: purchaseUnitId,
        ),
        (
          id: 'factor-zero',
          quantity: 1.0,
          factor: 0.0,
          base: 0.0,
          unit: purchaseUnitId,
        ),
        (
          id: 'factor-negative',
          quantity: 1.0,
          factor: -1.0,
          base: -1.0,
          unit: purchaseUnitId,
        ),
        (
          id: 'factor-nan',
          quantity: 1.0,
          factor: double.nan,
          base: double.nan,
          unit: purchaseUnitId,
        ),
        (
          id: 'factor-infinite',
          quantity: 1.0,
          factor: double.infinity,
          base: double.infinity,
          unit: purchaseUnitId,
        ),
        (
          id: 'quantity-nan',
          quantity: double.nan,
          factor: 12.0,
          base: double.nan,
          unit: purchaseUnitId,
        ),
        (
          id: 'base-mismatch',
          quantity: 1.0,
          factor: 12.0,
          base: 13.0,
          unit: purchaseUnitId,
        ),
        (
          id: 'unsupported-unit',
          quantity: 1.0,
          factor: 1.0,
          base: 1.0,
          unit: unitId,
        ),
      ];
      for (final invalid in invalidItems) {
        await expectLater(
          dataSource.createPurchaseReturn(
            id: 'pr-${invalid.id}-$suffix',
            returnNumber: 'PR-${invalid.id}-$suffix',
            purchaseOrderId: 'purchase-order-$suffix',
            supplierId: supplierId,
            warehouseId: warehouseId,
            returnDate: now,
            items: [
              PurchaseReturnItem(
                id: 'pr-item-${invalid.id}-$suffix',
                itemId: productId,
                itemType: 'PRODUCT',
                quantity: invalid.quantity,
                unitId: invalid.unit,
                baseUnitId: unitId,
                unitConversionFactor: invalid.factor,
                baseQuantity: invalid.base,
                inventoryIdentityKind: 'BASE',
              ),
            ],
          ),
          throwsException,
          reason: invalid.id,
        );
      }
      expect(await db.query('purchase_returns'), isEmpty);
    },
  );

  test(
    'quality inspection on a pending return does not post stock until approval',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final returnId = 'sr-$suffix';
      final returnItemId = 'sr-item-qc-$suffix';
      final returnNumber = 'SR-QC-$suffix';
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'quality-inspection-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        quantity: 1,
        deliveredQuantity: 1,
        factor: 12,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await dataSource.createSalesReturn(
        id: returnId,
        returnNumber: returnNumber,
        salesOrderId: 'sales-order-$suffix',
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: 'sales-delivery-quality-inspection-$suffix',
        items: [
          SalesReturnItem(
            id: returnItemId,
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 1,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 12,
            inventoryIdentityKind: 'BASE',
            identitySnapshotStatus: 'VERIFIED',
            unitPrice: 5,
            sourceDeliveryItemId: deliveryItemId,
          ),
        ],
      );
      await dataSource.saveQualityInspection(
        QualityInspection(
          id: 'qi-$suffix',
          inspectionNumber: 'QI-$suffix',
          sourceType: 'SALES_RETURN',
          sourceId: returnId,
          warehouseId: warehouseId,
          itemId: productId,
          itemType: 'PRODUCT',
          inspectedBy: 'admin',
          inspectionDate: now,
          status: QualityInspectionStatus.completed,
          result: QualityInspectionResult.quarantined,
          createdAt: now,
          updatedAt: now,
          items: [
            QualityInspectionItem(
              id: 'qi-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              requestedQuantity: 1,
              inspectedQuantity: 1,
              acceptedQuantity: 0,
              rejectedQuantity: 1,
              sourceReturnItemId: returnItemId,
              productId: productId,
              inventoryIdentityKind: 'BASE',
              identitySnapshotStatus: 'VERIFIED',
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
              result: QualityInspectionResult.quarantined,
            ),
          ],
        ),
      );
      final stockRows = await (await FurnexaDatabase.instance.database).query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
        limit: 1,
      );
      expect((stockRows.single['quantity'] as num).toDouble(), 50);
      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
      final journalRows = await (await FurnexaDatabase.instance.database).query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['SALES_RETURN', returnId],
      );
      expect(journalRows, isEmpty);
      expect(
        (await db.query(
          'sales_returns',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [returnId],
        )).single['status'],
        'PENDING',
      );
      final pendingPostedReturnTotal = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(sri.baseQuantity), 0) AS total
        FROM sales_return_items sri
        JOIN sales_returns sr ON sr.id = sri.salesReturnId
        WHERE sr.id = ? AND sr.status = 'APPROVED'
        ''',
        [returnId],
      );
      expect((pendingPostedReturnTotal.single['total'] as num).toDouble(), 0);
      final inspectionItem = (await db.query(
        'quality_inspection_items',
        where: 'inspectionId = ? AND sourceReturnItemId = ?',
        whereArgs: ['qi-$suffix', returnItemId],
      )).single;
      expect(inspectionItem['acceptedBaseQuantity'], 0);
      expect(inspectionItem['rejectedBaseQuantity'], 12);

      await dataSource.updateSalesReturnStatus(returnId, ReturnStatus.approved);
      final approvedStock = await (await FurnexaDatabase.instance.database)
          .query(
            'stock_balances',
            where: 'warehouseId = ? AND itemId = ?',
            whereArgs: [warehouseId, productId],
            limit: 1,
          );
      expect((approvedStock.single['quantity'] as num).toDouble(), 38);
      final postedMovements = await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND itemId = ? AND reference = ?',
        whereArgs: [warehouseId, productId, returnNumber],
      );
      expect(postedMovements, hasLength(1));
      expect(postedMovements.single['transactionType'], 'STOCK_OUT');
      expect((postedMovements.single['quantity'] as num).toDouble(), 12);
      final approvedPostedReturnTotal = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(sri.baseQuantity), 0) AS total
        FROM sales_return_items sri
        JOIN sales_returns sr ON sr.id = sri.salesReturnId
        WHERE sr.id = ? AND sr.status = 'APPROVED'
        ''',
        [returnId],
      );
      expect((approvedPostedReturnTotal.single['total'] as num).toDouble(), 12);
      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['SALES_RETURN', returnId],
        ),
        isEmpty,
      );

      await dataSource.updateSalesReturnStatus(returnId, ReturnStatus.approved);
      final finalStock = await (await FurnexaDatabase.instance.database).query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
        limit: 1,
      );
      expect((finalStock.single['quantity'] as num).toDouble(), 38);
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ? AND reference = ?',
          whereArgs: [warehouseId, productId, returnNumber],
        ),
        hasLength(1),
      );
      final finalPostedReturnTotal = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(sri.baseQuantity), 0) AS total
        FROM sales_return_items sri
        JOIN sales_returns sr ON sr.id = sri.salesReturnId
        WHERE sr.id = ? AND sr.status = 'APPROVED'
        ''',
        [returnId],
      );
      expect((finalPostedReturnTotal.single['total'] as num).toDouble(), 12);
    },
  );

  test(
    'accepted-only quality inspection does not post rejected stock',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final returnId = 'sr-quality-accepted-only-$suffix';
      final returnItemId = 'sr-quality-accepted-only-item-$suffix';
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'quality-accepted-only-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        quantity: 4,
        deliveredQuantity: 4,
        factor: 12,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await dataSource.createSalesReturn(
        id: returnId,
        returnNumber: 'SR-QC-ACCEPTED-ONLY-$suffix',
        salesOrderId: 'sales-order-$suffix',
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: 'sales-delivery-quality-accepted-only-$suffix',
        items: [
          SalesReturnItem(
            id: returnItemId,
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 4,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 48,
            inventoryIdentityKind: 'BASE',
            identitySnapshotStatus: 'VERIFIED',
            sourceDeliveryItemId: deliveryItemId,
          ),
        ],
      );
      await dataSource.createQualityInspection(
        id: 'qi-quality-accepted-only-$suffix',
        inspectionNumber: 'QI-QC-ACCEPTED-ONLY-$suffix',
        sourceType: 'SALES_RETURN',
        sourceId: returnId,
        warehouseId: warehouseId,
        itemId: productId,
        itemType: 'PRODUCT',
        inspectionDate: now,
        status: QualityInspectionStatus.completed,
        result: QualityInspectionResult.passed,
        items: [
          QualityInspectionItem(
            id: 'qi-quality-accepted-only-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            requestedQuantity: 4,
            inspectedQuantity: 3,
            acceptedQuantity: 3,
            rejectedQuantity: 0,
            sourceReturnItemId: returnItemId,
            productId: productId,
            inventoryIdentityKind: 'BASE',
            identitySnapshotStatus: 'VERIFIED',
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
          ),
        ],
      );

      final inspectionItem = (await db.query(
        'quality_inspection_items',
        where: 'inspectionId = ?',
        whereArgs: ['qi-quality-accepted-only-$suffix'],
      )).single;
      expect(inspectionItem['acceptedBaseQuantity'], 36);
      expect(inspectionItem['rejectedBaseQuantity'], 0);
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        50,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );

      await dataSource.updateSalesReturnStatus(returnId, ReturnStatus.approved);
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        50,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
    },
  );

  test(
    'quality inspection rejects negative non-finite and inconsistent quantities',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final returnId = 'sr-quality-invalid-quantities-$suffix';
      final returnItemId = 'sr-quality-invalid-quantities-item-$suffix';
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'quality-invalid-quantities-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        quantity: 10,
        deliveredQuantity: 10,
        factor: 12,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await dataSource.createSalesReturn(
        id: returnId,
        returnNumber: 'SR-QC-INVALID-QUANTITIES-$suffix',
        salesOrderId: 'sales-order-$suffix',
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: 'sales-delivery-quality-invalid-quantities-$suffix',
        items: [
          SalesReturnItem(
            id: returnItemId,
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 10,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 120,
            inventoryIdentityKind: 'BASE',
            identitySnapshotStatus: 'VERIFIED',
            sourceDeliveryItemId: deliveryItemId,
          ),
        ],
      );

      final invalidCases = [
        (
          id: 'negative-requested',
          requested: -1.0,
          inspected: 1.0,
          accepted: 1.0,
          rejected: 0.0,
        ),
        (
          id: 'negative-inspected',
          requested: 1.0,
          inspected: -1.0,
          accepted: 0.0,
          rejected: 0.0,
        ),
        (
          id: 'negative-accepted',
          requested: 1.0,
          inspected: 1.0,
          accepted: -1.0,
          rejected: 2.0,
        ),
        (
          id: 'negative-rejected',
          requested: 1.0,
          inspected: 1.0,
          accepted: 2.0,
          rejected: -1.0,
        ),
        (
          id: 'nan-requested',
          requested: double.nan,
          inspected: 1.0,
          accepted: 1.0,
          rejected: 0.0,
        ),
        (
          id: 'infinite-inspected',
          requested: 1.0,
          inspected: double.infinity,
          accepted: 1.0,
          rejected: 0.0,
        ),
        (
          id: 'nan-accepted',
          requested: 1.0,
          inspected: 1.0,
          accepted: double.nan,
          rejected: 0.0,
        ),
        (
          id: 'infinite-rejected',
          requested: 1.0,
          inspected: 1.0,
          accepted: 0.0,
          rejected: double.infinity,
        ),
        (
          id: 'inconsistent-total',
          requested: 1.0,
          inspected: 1.0,
          accepted: 0.0,
          rejected: 0.0,
        ),
      ];
      for (final invalid in invalidCases) {
        await expectLater(
          dataSource.createQualityInspection(
            id: 'qi-${invalid.id}-$suffix',
            inspectionNumber: 'QI-${invalid.id}-$suffix',
            sourceType: 'SALES_RETURN',
            sourceId: returnId,
            warehouseId: warehouseId,
            itemId: productId,
            itemType: 'PRODUCT',
            inspectionDate: now,
            status: QualityInspectionStatus.completed,
            items: [
              QualityInspectionItem(
                id: 'qi-item-${invalid.id}-$suffix',
                itemId: productId,
                itemType: 'PRODUCT',
                requestedQuantity: invalid.requested,
                inspectedQuantity: invalid.inspected,
                acceptedQuantity: invalid.accepted,
                rejectedQuantity: invalid.rejected,
                sourceReturnItemId: returnItemId,
                productId: productId,
                inventoryIdentityKind: 'BASE',
                identitySnapshotStatus: 'VERIFIED',
                unitId: purchaseUnitId,
                baseUnitId: unitId,
                unitConversionFactor: 12,
              ),
            ],
          ),
          throwsException,
          reason: invalid.id,
        );
      }
      expect(await db.query('quality_inspections'), isEmpty);
      expect(await db.query('quality_inspection_items'), isEmpty);
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
    },
  );

  test(
    'quality inspection converts rejected alternative units to base stock',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final returnId = 'sr-quality-conversion-$suffix';
      final returnItemId = 'sr-quality-conversion-item-$suffix';
      final returnNumber = 'SR-QC-CONVERSION-$suffix';
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'quality-conversion-$suffix',
        sourceProductId: productId,
        salesUnitId: purchaseUnitId,
        quantity: 10,
        deliveredQuantity: 10,
        factor: 12,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await dataSource.createSalesReturn(
        id: returnId,
        returnNumber: returnNumber,
        salesOrderId: 'sales-order-$suffix',
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: 'sales-delivery-quality-conversion-$suffix',
        items: [
          SalesReturnItem(
            id: returnItemId,
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 10,
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            baseQuantity: 120,
            inventoryIdentityKind: 'BASE',
            identitySnapshotStatus: 'VERIFIED',
            sourceDeliveryItemId: deliveryItemId,
          ),
        ],
      );

      await dataSource.createQualityInspection(
        id: 'qi-quality-conversion-$suffix',
        inspectionNumber: 'QI-QC-CONVERSION-$suffix',
        sourceType: 'SALES_RETURN',
        sourceId: returnId,
        warehouseId: warehouseId,
        itemId: productId,
        itemType: 'PRODUCT',
        inspectionDate: now,
        status: QualityInspectionStatus.completed,
        result: QualityInspectionResult.passed,
        items: [
          QualityInspectionItem(
            id: 'qi-quality-conversion-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            requestedQuantity: 10,
            inspectedQuantity: 5,
            acceptedQuantity: 3,
            rejectedQuantity: 2,
            sourceReturnItemId: returnItemId,
            productId: productId,
            inventoryIdentityKind: 'BASE',
            identitySnapshotStatus: 'VERIFIED',
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            result: QualityInspectionResult.quarantined,
          ),
        ],
      );

      final stock = (await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
      )).single;
      expect(stock['quantity'], 50);
      final inspectionItem = (await db.query(
        'quality_inspection_items',
        where: 'sourceReturnItemId = ?',
        whereArgs: [returnItemId],
      )).single;
      expect(inspectionItem['productId'], productId);
      expect(inspectionItem['unitId'], purchaseUnitId);
      expect(inspectionItem['baseUnitId'], unitId);
      expect(inspectionItem['unitConversionFactor'], 12);
      expect(inspectionItem['requestedBaseQuantity'], 120);
      expect(inspectionItem['inspectedBaseQuantity'], 60);
      expect(inspectionItem['rejectedBaseQuantity'], 24);
      final reloadedInspection = (await dataSource.qualityInspections(
        sourceType: 'SALES_RETURN',
      )).single;
      expect(reloadedInspection.items, hasLength(1));
      expect(reloadedInspection.items.single.sourceReturnItemId, returnItemId);
      expect(reloadedInspection.items.single.variantId, isNull);
      expect(reloadedInspection.items.single.unitConversionFactor, 12);
      expect(reloadedInspection.items.single.rejectedBaseQuantity, 24);
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
      await dataSource.updateSalesReturnStatus(returnId, ReturnStatus.approved);
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        26,
      );
      final postedMovements = await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND itemId = ? AND reference = ?',
        whereArgs: [warehouseId, productId, returnNumber],
      );
      expect(postedMovements, hasLength(1));
      expect(postedMovements.single['transactionType'], 'STOCK_OUT');
      expect((postedMovements.single['quantity'] as num).toDouble(), 24);
      await expectLater(
        dataSource.createQualityInspection(
          id: 'qi-quality-conversion-retry-$suffix',
          inspectionNumber: 'QI-QC-CONVERSION-RETRY-$suffix',
          sourceType: 'SALES_RETURN',
          sourceId: returnId,
          warehouseId: warehouseId,
          itemId: productId,
          itemType: 'PRODUCT',
          inspectionDate: now,
          status: QualityInspectionStatus.completed,
          result: QualityInspectionResult.quarantined,
          items: [
            QualityInspectionItem(
              id: 'qi-quality-conversion-retry-item-$suffix',
              itemId: productId,
              itemType: 'PRODUCT',
              requestedQuantity: 10,
              inspectedQuantity: 5,
              acceptedQuantity: 3,
              rejectedQuantity: 2,
              sourceReturnItemId: returnItemId,
            ),
          ],
        ),
        throwsException,
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        26,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ? AND reference = ?',
          whereArgs: [warehouseId, productId, returnNumber],
        ),
        hasLength(1),
      );
    },
  );

  test(
    'quality inspection binds processing to the exact variant return line',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final returnId = 'sr-quality-variant-$suffix';
      final returnNumber = 'SR-QC-VARIANT-$suffix';
      final salesDeliveryId = 'sales-delivery-quality-variant-$suffix';
      final firstSourceLine = 'sr-quality-variant-first-$suffix';
      final secondSourceLine = 'sr-quality-variant-second-$suffix';
      final sourceLines = [
        (
          id: firstSourceLine,
          variant: variantId,
          orderItemId: 'sales-order-item-quality-variant-first-$suffix',
          deliveryItemId: 'sales-delivery-item-quality-variant-first-$suffix',
        ),
        (
          id: secondSourceLine,
          variant: secondVariantId,
          orderItemId: 'sales-order-item-quality-variant-second-$suffix',
          deliveryItemId: 'sales-delivery-item-quality-variant-second-$suffix',
        ),
      ];
      await db.insert('sales_deliveries', {
        'id': salesDeliveryId,
        'deliveryNumber': 'DL-QC-VARIANT-$suffix',
        'salesOrderId': 'sales-order-$suffix',
        'warehouseId': warehouseId,
        'deliveryDate': now.millisecondsSinceEpoch,
        'status': 'DELIVERED',
        'createdAt': now.millisecondsSinceEpoch,
      });
      for (final source in sourceLines) {
        await db.insert('sales_order_items', {
          'id': source.orderItemId,
          'salesOrderId': 'sales-order-$suffix',
          'itemId': '__FURNEXA_VARIANT__:${source.variant}',
          'productId': variantProductId,
          'variantId': source.variant,
          'itemType': 'PRODUCT',
          'quantity': 10,
          'unitId': purchaseUnitId,
          'baseUnitId': unitId,
          'unitConversionFactor': 12,
          'baseQuantity': 120,
          'deliveredQuantity': 10,
          'deliveredBaseQuantity': 120,
          'inventoryIdentityKind': 'VARIANT',
          'identitySnapshotStatus': 'VERIFIED',
          'unitPrice': 5,
          'discount': 0,
          'tax': 0,
          'lineTotal': 50,
        });
        await db.insert('sales_delivery_items', {
          'id': source.deliveryItemId,
          'salesDeliveryId': salesDeliveryId,
          'salesOrderItemId': source.orderItemId,
          'deliveredQuantity': 10,
          'unitId': purchaseUnitId,
          'productId': variantProductId,
          'variantId': source.variant,
          'baseUnitId': unitId,
          'unitConversionFactor': 12,
          'baseQuantity': 120,
          'inventoryIdentityKind': 'VARIANT',
          'identitySnapshotStatus': 'VERIFIED',
          'unitRevenue': 5,
          'unitCogs': 2,
        });
      }
      await dataSource.createSalesReturn(
        id: returnId,
        returnNumber: returnNumber,
        salesOrderId: 'sales-order-$suffix',
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: salesDeliveryId,
        items: sourceLines
            .map(
              (source) => SalesReturnItem(
                id: source.id,
                itemId: variantProductId,
                itemType: 'PRODUCT',
                quantity: 10,
                unitId: purchaseUnitId,
                variantId: source.variant,
                baseUnitId: unitId,
                unitConversionFactor: 12,
                baseQuantity: 120,
                inventoryIdentityKind: 'VARIANT',
                identitySnapshotStatus: 'VERIFIED',
                sourceDeliveryItemId: source.deliveryItemId,
              ),
            )
            .toList(),
      );
      for (final variant in [variantId, secondVariantId]) {
        await db.insert('stock_balances', {
          'id': 'quality-variant-stock-$variant-$suffix',
          'warehouseId': warehouseId,
          'itemId': '__FURNEXA_VARIANT__:$variant',
          'itemType': 'PRODUCT',
          'productId': variantProductId,
          'variantId': variant,
          'inventoryIdentityKind': 'VARIANT',
          'unitId': unitId,
          'quantity': 100,
          'createdAt': now.millisecondsSinceEpoch,
          'updatedAt': now.millisecondsSinceEpoch,
        });
      }

      await expectLater(
        dataSource.createQualityInspection(
          id: 'qi-quality-wrong-source-$suffix',
          inspectionNumber: 'QI-QC-WRONG-SOURCE-$suffix',
          sourceType: 'SALES_RETURN',
          sourceId: returnId,
          warehouseId: warehouseId,
          itemId: variantProductId,
          itemType: 'PRODUCT',
          inspectionDate: now,
          status: QualityInspectionStatus.completed,
          result: QualityInspectionResult.quarantined,
          items: [
            QualityInspectionItem(
              id: 'qi-quality-wrong-source-item-$suffix',
              itemId: variantProductId,
              itemType: 'PRODUCT',
              requestedQuantity: 10,
              inspectedQuantity: 2,
              acceptedQuantity: 0,
              rejectedQuantity: 2,
              sourceReturnItemId: secondSourceLine,
              productId: variantProductId,
              variantId: variantId,
              inventoryIdentityKind: 'VARIANT',
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
            ),
          ],
        ),
        throwsException,
      );

      await expectLater(
        dataSource.createQualityInspection(
          id: 'qi-quality-wrong-unit-$suffix',
          inspectionNumber: 'QI-QC-WRONG-UNIT-$suffix',
          sourceType: 'SALES_RETURN',
          sourceId: returnId,
          warehouseId: warehouseId,
          itemId: variantProductId,
          itemType: 'PRODUCT',
          inspectionDate: now,
          status: QualityInspectionStatus.completed,
          result: QualityInspectionResult.quarantined,
          items: [
            QualityInspectionItem(
              id: 'qi-quality-wrong-unit-item-$suffix',
              itemId: variantProductId,
              itemType: 'PRODUCT',
              requestedQuantity: 10,
              inspectedQuantity: 2,
              acceptedQuantity: 0,
              rejectedQuantity: 2,
              sourceReturnItemId: firstSourceLine,
              productId: variantProductId,
              variantId: variantId,
              inventoryIdentityKind: 'VARIANT',
              unitId: unitId,
              baseUnitId: unitId,
              unitConversionFactor: 1,
            ),
          ],
        ),
        throwsException,
      );
      await expectLater(
        dataSource.createQualityInspection(
          id: 'qi-quality-unverified-variant-$suffix',
          inspectionNumber: 'QI-QC-UNVERIFIED-VARIANT-$suffix',
          sourceType: 'SALES_RETURN',
          sourceId: returnId,
          warehouseId: warehouseId,
          itemId: variantProductId,
          itemType: 'PRODUCT',
          inspectionDate: now,
          status: QualityInspectionStatus.completed,
          result: QualityInspectionResult.quarantined,
          items: [
            QualityInspectionItem(
              id: 'qi-quality-unverified-variant-item-$suffix',
              itemId: variantProductId,
              itemType: 'PRODUCT',
              requestedQuantity: 10,
              inspectedQuantity: 2,
              acceptedQuantity: 0,
              rejectedQuantity: 2,
              sourceReturnItemId: firstSourceLine,
              productId: variantProductId,
              variantId: variantId,
              inventoryIdentityKind: 'VARIANT',
              identitySnapshotStatus: 'UNVERIFIED',
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
            ),
          ],
        ),
        throwsException,
      );
      await expectLater(
        dataSource.createQualityInspection(
          id: 'qi-quality-over-inspection-$suffix',
          inspectionNumber: 'QI-QC-OVER-INSPECTION-$suffix',
          sourceType: 'SALES_RETURN',
          sourceId: returnId,
          warehouseId: warehouseId,
          itemId: variantProductId,
          itemType: 'PRODUCT',
          inspectionDate: now,
          status: QualityInspectionStatus.completed,
          result: QualityInspectionResult.quarantined,
          items: [
            QualityInspectionItem(
              id: 'qi-quality-over-inspection-item-$suffix',
              itemId: variantProductId,
              itemType: 'PRODUCT',
              requestedQuantity: 11,
              inspectedQuantity: 1,
              acceptedQuantity: 0,
              rejectedQuantity: 0,
              sourceReturnItemId: firstSourceLine,
              productId: variantProductId,
              variantId: variantId,
              inventoryIdentityKind: 'VARIANT',
              unitId: purchaseUnitId,
              baseUnitId: unitId,
              unitConversionFactor: 12,
            ),
          ],
        ),
        throwsException,
      );

      await dataSource.createQualityInspection(
        id: 'qi-quality-variant-$suffix',
        inspectionNumber: 'QI-QC-VARIANT-OK-$suffix',
        sourceType: 'SALES_RETURN',
        sourceId: returnId,
        warehouseId: warehouseId,
        itemId: variantProductId,
        itemType: 'PRODUCT',
        inspectionDate: now,
        status: QualityInspectionStatus.completed,
        result: QualityInspectionResult.quarantined,
        items: [
          QualityInspectionItem(
            id: 'qi-quality-variant-item-$suffix',
            itemId: variantProductId,
            itemType: 'PRODUCT',
            requestedQuantity: 10,
            inspectedQuantity: 3,
            acceptedQuantity: 1,
            rejectedQuantity: 2,
            sourceReturnItemId: firstSourceLine,
            productId: variantProductId,
            variantId: variantId,
            inventoryIdentityKind: 'VARIANT',
            identitySnapshotStatus: 'VERIFIED',
            unitId: purchaseUnitId,
            baseUnitId: unitId,
            unitConversionFactor: 12,
            result: QualityInspectionResult.quarantined,
          ),
        ],
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, '__FURNEXA_VARIANT__:$variantId'],
        )).single['quantity'],
        100,
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, '__FURNEXA_VARIANT__:$secondVariantId'],
        )).single['quantity'],
        100,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId LIKE ?',
          whereArgs: [warehouseId, '__FURNEXA_VARIANT__:%'],
        ),
        isEmpty,
      );
      await dataSource.updateSalesReturnStatus(returnId, ReturnStatus.approved);
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, '__FURNEXA_VARIANT__:$variantId'],
        )).single['quantity'],
        76,
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, '__FURNEXA_VARIANT__:$secondVariantId'],
        )).single['quantity'],
        100,
      );
      final variantMovements = await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND reference = ?',
        whereArgs: [warehouseId, returnNumber],
      );
      expect(variantMovements, hasLength(1));
      expect(
        variantMovements.single['itemId'],
        '__FURNEXA_VARIANT__:$variantId',
      );
      expect((variantMovements.single['quantity'] as num).toDouble(), 24);
    },
  );

  test(
    'quality inspection requires an exact source line and matching snapshot',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final firstReturnId = 'sr-quality-exact-first-$suffix';
      final firstReturnItemId = 'sr-quality-exact-first-item-$suffix';
      final secondReturnId = 'sr-quality-exact-second-$suffix';
      final secondReturnItemId = 'sr-quality-exact-second-item-$suffix';
      final firstDeliveryItemId = await seedDeliveredSalesLine(
        id: 'quality-exact-first-$suffix',
        sourceProductId: productId,
        salesUnitId: unitId,
        quantity: 2,
        deliveredQuantity: 2,
        factor: 1,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await dataSource.createSalesReturn(
        id: firstReturnId,
        returnNumber: 'SR-QC-EXACT-FIRST-$suffix',
        salesOrderId: 'sales-order-$suffix',
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: 'sales-delivery-quality-exact-first-$suffix',
        items: [
          SalesReturnItem(
            id: firstReturnItemId,
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 2,
            unitId: unitId,
            baseUnitId: unitId,
            baseQuantity: 2,
            inventoryIdentityKind: 'BASE',
            identitySnapshotStatus: 'VERIFIED',
            sourceDeliveryItemId: firstDeliveryItemId,
          ),
        ],
      );
      await db.insert('sales_returns', {
        'id': secondReturnId,
        'returnNumber': 'SR-QC-EXACT-SECOND-$suffix',
        'salesOrderId': 'sales-order-$suffix',
        'customerId': customerId,
        'warehouseId': warehouseId,
        'returnDate': now.millisecondsSinceEpoch,
        'status': 'PENDING',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.insert('sales_return_items', {
        'id': secondReturnItemId,
        'salesReturnId': secondReturnId,
        'itemId': productId,
        'productId': productId,
        'itemType': 'PRODUCT',
        'quantity': 2,
        'unitId': unitId,
        'baseUnitId': unitId,
        'unitConversionFactor': 1,
        'baseQuantity': 2,
        'inventoryIdentityKind': 'BASE',
        'identitySnapshotStatus': 'VERIFIED',
        'createdAt': now.millisecondsSinceEpoch,
      });

      Future<void> expectInvalidInspection(
        String id, {
        required String? sourceReturnItemId,
        String identityKind = 'BASE',
        double factor = 1,
      }) async {
        await expectLater(
          dataSource.createQualityInspection(
            id: 'qi-$id-$suffix',
            inspectionNumber: 'QI-$id-$suffix',
            sourceType: 'SALES_RETURN',
            sourceId: firstReturnId,
            warehouseId: warehouseId,
            itemId: productId,
            itemType: 'PRODUCT',
            inspectionDate: now,
            status: QualityInspectionStatus.completed,
            items: [
              QualityInspectionItem(
                id: 'qi-item-$id-$suffix',
                itemId: productId,
                itemType: 'PRODUCT',
                requestedQuantity: 1,
                inspectedQuantity: 1,
                acceptedQuantity: 0,
                rejectedQuantity: 1,
                sourceReturnItemId: sourceReturnItemId,
                productId: productId,
                inventoryIdentityKind: identityKind,
                identitySnapshotStatus: 'VERIFIED',
                unitId: unitId,
                baseUnitId: unitId,
                unitConversionFactor: factor,
              ),
            ],
          ),
          throwsException,
          reason: id,
        );
      }

      await expectInvalidInspection(
        'quality-missing-line',
        sourceReturnItemId: null,
      );
      await expectInvalidInspection(
        'quality-blank-line',
        sourceReturnItemId: '  ',
      );
      await expectInvalidInspection(
        'quality-foreign-line',
        sourceReturnItemId: secondReturnItemId,
      );
      await expectInvalidInspection(
        'quality-wrong-identity',
        sourceReturnItemId: firstReturnItemId,
        identityKind: 'VARIANT',
      );
      await expectInvalidInspection(
        'quality-wrong-factor',
        sourceReturnItemId: firstReturnItemId,
        factor: 2,
      );
      expect(await db.query('quality_inspections'), isEmpty);
      expect(await db.query('quality_inspection_items'), isEmpty);
    },
  );

  test(
    'quality inspection read preserves a historical null source line',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.insert('quality_inspections', {
        'id': 'qi-legacy-source-line-$suffix',
        'inspectionNumber': 'QI-LEGACY-SOURCE-LINE-$suffix',
        'sourceType': 'SALES_RETURN',
        'sourceId': 'sr-legacy-source-line-$suffix',
        'warehouseId': warehouseId,
        'itemId': productId,
        'itemType': 'PRODUCT',
        'inspectionDate': now.millisecondsSinceEpoch,
        'status': 'COMPLETED',
        'result': 'QUARANTINED',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.insert('quality_inspection_items', {
        'id': 'qi-item-legacy-source-line-$suffix',
        'inspectionId': 'qi-legacy-source-line-$suffix',
        'itemId': productId,
        'productId': productId,
        'itemType': 'PRODUCT',
        'requestedQuantity': 2,
        'inspectedQuantity': 2,
        'acceptedQuantity': 0,
        'rejectedQuantity': 2,
        'result': 'QUARANTINED',
        'createdAt': now.millisecondsSinceEpoch,
      });

      final loaded = (await dataSource.qualityInspections(
        sourceType: 'SALES_RETURN',
      )).single;
      expect(loaded.id, 'qi-legacy-source-line-$suffix');
      expect(loaded.items, hasLength(1));
      expect(loaded.items.single.sourceReturnItemId, isNull);
    },
  );

  test(
    'quality approval stock failure rolls back and remains retryable',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'stock_balances',
        {'quantity': 1},
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
      );
      final returnId = 'sr-quality-failure-$suffix';
      final returnItemId = 'sr-quality-failure-item-$suffix';
      final returnNumber = 'SR-QC-FAILURE-$suffix';
      final deliveryItemId = await seedDeliveredSalesLine(
        id: 'quality-failure-$suffix',
        sourceProductId: productId,
        salesUnitId: unitId,
        quantity: 2,
        deliveredQuantity: 2,
        factor: 1,
        unitRevenue: 5,
        unitCogs: 2,
      );
      await dataSource.createSalesReturn(
        id: returnId,
        returnNumber: returnNumber,
        salesOrderId: 'sales-order-$suffix',
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: 'sales-delivery-quality-failure-$suffix',
        items: [
          SalesReturnItem(
            id: returnItemId,
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 2,
            unitId: unitId,
            baseUnitId: unitId,
            baseQuantity: 2,
            inventoryIdentityKind: 'BASE',
            identitySnapshotStatus: 'VERIFIED',
            sourceDeliveryItemId: deliveryItemId,
          ),
        ],
      );

      await dataSource.createQualityInspection(
        id: 'qi-quality-failure-$suffix',
        inspectionNumber: 'QI-QC-FAILURE-$suffix',
        sourceType: 'SALES_RETURN',
        sourceId: returnId,
        warehouseId: warehouseId,
        itemId: productId,
        itemType: 'PRODUCT',
        inspectionDate: now,
        status: QualityInspectionStatus.completed,
        result: QualityInspectionResult.rejected,
        items: [
          QualityInspectionItem(
            id: 'qi-quality-failure-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            requestedQuantity: 2,
            inspectedQuantity: 2,
            acceptedQuantity: 0,
            rejectedQuantity: 2,
            sourceReturnItemId: returnItemId,
            productId: productId,
            identitySnapshotStatus: 'VERIFIED',
            unitId: unitId,
            baseUnitId: unitId,
            unitConversionFactor: 1,
          ),
        ],
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        1,
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );

      await expectLater(
        dataSource.updateSalesReturnStatus(returnId, ReturnStatus.approved),
        throwsException,
      );
      expect(
        await db.query(
          'quality_inspections',
          where: 'id = ?',
          whereArgs: ['qi-quality-failure-$suffix'],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'quality_inspection_items',
          where: 'inspectionId = ?',
          whereArgs: ['qi-quality-failure-$suffix'],
        ),
        hasLength(1),
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        1,
      );
      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['SALES_RETURN', returnId],
        ),
        isEmpty,
      );
      expect(
        (await db.query(
          'sales_returns',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [returnId],
        )).single['status'],
        'PENDING',
      );
      expect(
        await db.query(
          'stock_transactions',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        ),
        isEmpty,
      );

      await db.update(
        'stock_balances',
        {'quantity': 3},
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
      );
      await dataSource.updateSalesReturnStatus(returnId, ReturnStatus.approved);
      expect(
        (await db.query(
          'sales_returns',
          columns: ['status'],
          where: 'id = ?',
          whereArgs: [returnId],
        )).single['status'],
        'APPROVED',
      );
      expect(
        (await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ?',
          whereArgs: [warehouseId, productId],
        )).single['quantity'],
        1,
      );
      final retriedMovements = await db.query(
        'stock_transactions',
        where: 'warehouseId = ? AND itemId = ? AND reference = ?',
        whereArgs: [warehouseId, productId, returnNumber],
      );
      expect(retriedMovements, hasLength(1));
      expect((retriedMovements.single['quantity'] as num).toDouble(), 2);
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['SALES_RETURN', returnId],
        ),
        isEmpty,
      );
    },
  );
}
