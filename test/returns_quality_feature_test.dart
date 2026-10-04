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
  late String rawMaterialId;
  late String warehouseId;
  late String unitId;
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
    productId = 'returns-product-$suffix';
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
      'status': 'CONFIRMED',
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
      'itemType': 'RAW_MATERIAL',
      'quantity': 20,
      'unitId': unitId,
      'unitPrice': 8,
      'discount': 0,
      'tax': 0,
      'lineTotal': 160,
      'receivedQuantity': 20,
    });
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
    'quality inspection quarantine result is persisted and stock is reduced',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.insert('sales_returns', {
        'id': 'sr-$suffix',
        'returnNumber': 'SR-QC-$suffix',
        'salesOrderId': 'sales-order-$suffix',
        'customerId': customerId,
        'warehouseId': warehouseId,
        'returnDate': now.millisecondsSinceEpoch,
        'status': 'PENDING',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await db.insert('sales_return_items', {
        'id': 'sr-item-qc-$suffix',
        'salesReturnId': 'sr-$suffix',
        'itemId': productId,
        'itemType': 'PRODUCT',
        'quantity': 12,
        'unitId': unitId,
        'unitPrice': 5,
        'createdAt': now.millisecondsSinceEpoch,
      });
      await dataSource.saveQualityInspection(
        QualityInspection(
          id: 'qi-$suffix',
          inspectionNumber: 'QI-$suffix',
          sourceType: 'SALES_RETURN',
          sourceId: 'sr-$suffix',
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
              requestedQuantity: 12,
              inspectedQuantity: 12,
              acceptedQuantity: 0,
              rejectedQuantity: 12,
              result: QualityInspectionResult.quarantined,
            ),
          ],
        ),
      );

      final rows = await (await FurnexaDatabase.instance.database).query(
        'quality_inspections',
        where: 'sourceType = ?',
        whereArgs: ['SALES_RETURN'],
      );
      expect(rows, hasLength(1));
      final stockRows = await (await FurnexaDatabase.instance.database).query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, productId],
        limit: 1,
      );
      expect((stockRows.single['quantity'] as num).toDouble(), 38);
    },
  );
}
