import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/crm/data/datasources/crm_local_data_source.dart';
import 'package:furnexa/features/costing/data/datasources/costing_local_data_source.dart';
import 'package:furnexa/features/documents/data/datasources/documents_local_data_source.dart';
import 'package:furnexa/features/documents/domain/entities/document_definition.dart';
import 'package:furnexa/features/global_search/data/datasources/global_search_local_data_source.dart';
import 'package:furnexa/features/import_export/data/datasources/import_export_local_data_source.dart';
import 'package:furnexa/features/pricing/data/datasources/pricing_local_data_source.dart';
import 'package:furnexa/features/pricing/domain/entities/pricing_entities.dart';
import 'package:furnexa/features/production/data/datasources/production_local_data_source.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/purchasing/data/datasources/purchasing_local_data_source.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/returns_quality/data/datasources/returns_quality_local_data_source.dart';
import 'package:furnexa/features/returns_quality/domain/entities/returns_quality_entities.dart';
import 'package:furnexa/features/sales/data/datasources/sales_local_data_source.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late Database db;
  late String suffix;
  late DateTime now;

  late SecurityLocalDataSource security;
  late PurchasingLocalDataSource purchasing;
  late SalesLocalDataSource sales;
  late ProductionLocalDataSource production;
  late ReturnsQualityLocalDataSource returnsQuality;
  late PricingLocalDataSource pricing;
  late CrmLocalDataSource crm;
  late ImportExportLocalDataSource importExport;
  late GlobalSearchLocalDataSource search;
  late DocumentsLocalDataSource documents;
  late AccountingLocalDataSource accounting;
  late CostingLocalDataSource costing;

  late String factoryId;
  late String warehouseId;
  late String categoryId;
  late String unitId;
  late String materialId;
  late String productId;
  late String supplierId;
  late String customerId;
  late String leadId;
  late String stageId;

  Future<void> seedBase() async {
    db = await FurnexaDatabase.instance.database;
    await db.delete('production_batch_costs');
    await db.delete('production_other_costs');
    await db.delete('production_cost_adjustments');
    await db.delete('costing_overhead_rules');
    await db.delete('sales_return_items');
    await db.delete('sales_returns');
    await db.delete('purchase_return_items');
    await db.delete('purchase_returns');
    await db.delete('quality_inspection_items');
    await db.delete('quality_inspections');
    await db.delete('crm_activities');
    await db.delete('crm_notes');
    await db.delete('crm_follow_ups');
    await db.delete('crm_tasks');
    await db.delete('crm_leads');
    await db.delete('journal_lines');
    await db.delete('journal_entries');
    await db.delete('inventory_valuations');
    await db.delete('stock_transactions');
    await db.delete('stock_balances');
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
    await db.delete('purchase_receipt_items');
    await db.delete('purchase_receipts');
    await db.delete('purchase_order_items');
    await db.delete('purchase_orders');
    await db.delete('purchase_request_items');
    await db.delete('purchase_requests');
    await db.delete('product_bom_items');
    await db.delete('products');
    await db.delete('raw_materials');
    await db.delete('customers');
    await db.delete('suppliers');
    await db.delete('pricing_lists');
    await db.delete('product_prices');
    await db.delete('customer_price_overrides');
    await db.delete('price_tiers');
    await db.delete('discount_rules');
    await db.delete('price_history');
    await db.delete('categories');
    await db.delete('units');
    await db.delete('warehouses');
    await db.delete('factories');
    await db.delete('production_stages');

    now = DateTime(2026, 9, 17);
    factoryId = 'factory-$suffix';
    warehouseId = 'warehouse-$suffix';
    categoryId = 'category-$suffix';
    unitId = 'unit-$suffix';
    materialId = 'material-$suffix';
    productId = 'product-$suffix';
    supplierId = 'supplier-$suffix';
    customerId = 'customer-$suffix';
    leadId = 'lead-$suffix';
    stageId = 'stage-$suffix';

    final stamp = now.millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': factoryId,
      'name': 'Factory $suffix',
      'code': 'F-$suffix',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': warehouseId,
      'factoryId': factoryId,
      'name': 'Warehouse $suffix',
      'code': 'W-$suffix',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': categoryId,
      'name': 'Category $suffix',
      'code': 'CAT-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': unitId,
      'name': 'Unit $suffix',
      'abbreviation': 'U$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('raw_materials', {
      'id': materialId,
      'name': 'Raw Material $suffix',
      'code': 'RM-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('products', {
      'id': productId,
      'name': 'Finished Product $suffix',
      'code': 'P-$suffix',
      'categoryId': categoryId,
      'unitId': unitId,
      'productState': 'finished',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('product_bom_items', {
      'id': 'bom-$suffix',
      'productId': productId,
      'rawMaterialId': materialId,
      'quantity': 2,
    });
    await db.insert('suppliers', {
      'id': supplierId,
      'name': 'Supplier $suffix',
      'code': 'SUP-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('customers', {
      'id': customerId,
      'name': 'Customer $suffix',
      'code': 'CUST-$suffix',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('stock_balances', {
      'id': 'stock-material-$suffix',
      'warehouseId': warehouseId,
      'itemId': materialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 20,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('stock_balances', {
      'id': 'stock-product-$suffix',
      'warehouseId': warehouseId,
      'itemId': productId,
      'itemType': 'PRODUCT',
      'quantity': 10,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('inventory_valuations', {
      'id': 'iv-material-$suffix',
      'warehouseId': warehouseId,
      'itemId': materialId,
      'itemType': 'RAW_MATERIAL',
      'quantity': 20,
      'averageCost': 10,
      'updatedAt': stamp,
    });
    await db.insert('inventory_valuations', {
      'id': 'iv-product-$suffix',
      'warehouseId': warehouseId,
      'itemId': productId,
      'itemType': 'PRODUCT',
      'productId': productId,
      'variantId': null,
      'inventoryIdentityKind': 'BASE',
      'unitId': unitId,
      'quantity': 10,
      'averageCost': 15,
      'updatedAt': stamp,
    });
    await db.insert('production_stages', {
      'id': stageId,
      'factoryId': factoryId,
      'name': 'Cutting $suffix',
      'code': 'ST-$suffix',
      'sequence': 1,
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    final adminUser = (await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['admin'],
      limit: 1,
    )).single;
    await db.insert('crm_leads', {
      'id': leadId,
      'name': 'Lead $suffix',
      'phone': '0500000000',
      'email': 'lead$suffix@example.com',
      'company': 'Lead Co',
      'address': 'Address',
      'source': 'WEBSITE',
      'notes': 'n',
      'status': 'NEW',
      'assignedUserId': adminUser['id'],
      'createdAt': stamp,
      'updatedAt': stamp,
      'convertedAt': null,
      'convertedCustomerId': null,
    });
  }

  setUp(() async {
    await DatabaseTestHelper.reset();
    suffix = DateTime.now().microsecondsSinceEpoch.toString();
    security = SecurityLocalDataSource();
    purchasing = PurchasingLocalDataSource();
    sales = SalesLocalDataSource();
    production = ProductionLocalDataSource();
    returnsQuality = ReturnsQualityLocalDataSource();
    pricing = PricingLocalDataSource();
    crm = CrmLocalDataSource();
    importExport = ImportExportLocalDataSource();
    search = GlobalSearchLocalDataSource();
    documents = DocumentsLocalDataSource();
    accounting = AccountingLocalDataSource();
    costing = CostingLocalDataSource();
    await security.ensureInitialAdmin();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    await seedBase();
  });

  tearDown(() async {
    await DatabaseTestHelper.reset();
  });

  Future<ProductionOrder> completeProductionOrder() async {
    await production.saveRoute(productId, [stageId]);
    final order = await production.createOrder(
      productId: productId,
      plannedQuantity: 5,
    );
    await production.planOrder(order.id);
    await production.startOrder(order.id);
    await production.startStage(order.stages.first.id);
    await production.completeStage(order.stages.first.id);
    await production.consumeMaterial(
      orderId: order.id,
      rawMaterialId: materialId,
      warehouseId: warehouseId,
      quantity: 10,
      date: now,
      operationId: 'system-production-consumption-$suffix',
    );
    await production.recordOutput(
      orderId: order.id,
      warehouseId: warehouseId,
      quantity: 5,
      date: now,
      operationId: 'system-production-output-$suffix',
    );
    return order;
  }

  test('1. purchasing receipt updates stock and valuation', () async {
    final order = PurchaseOrder(
      id: 'po-$suffix',
      orderNumber: 'PO-$suffix',
      supplierId: supplierId,
      orderDate: now,
      status: PurchaseOrderStatus.approved,
      subtotal: 200,
      discount: 0,
      tax: 0,
      grandTotal: 200,
      createdAt: now,
      updatedAt: now,
      items: [
        PurchasingItem(
          id: 'po-item-$suffix',
          itemId: materialId,
          itemType: PurchasingItemType.rawMaterial,
          quantity: 10,
          unitId: unitId,
          unitPrice: 20,
          lineTotal: 200,
        ),
      ],
    );
    await purchasing.saveOrder(order);
    await purchasing.postReceipt(
      order: order,
      warehouseId: warehouseId,
      receiptDate: now,
      operationId: 'system-integration-receipt-$suffix',
      items: [
        PurchasingItem(
          id: 'po-item-$suffix',
          itemId: materialId,
          itemType: PurchasingItemType.rawMaterial,
          quantity: 10,
          unitId: unitId,
        ),
      ],
    );

    final rows = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ?',
      whereArgs: [warehouseId, materialId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    expect((rows.single['quantity'] as num).toDouble(), 30);

    final valuation = await accounting.valuation(
      warehouseId,
      materialId,
      'RAW_MATERIAL',
    );
    expect(valuation, isNotNull);
    expect(valuation!.quantity, 30);
  });

  test('2. sales delivery reduces stock and keeps ledger history', () async {
    final order = SalesOrder(
      id: 'so-$suffix',
      orderNumber: 'SO-$suffix',
      customerId: customerId,
      orderDate: now,
      status: SalesOrderStatus.confirmed,
      subtotal: 60,
      discount: 0,
      tax: 0,
      grandTotal: 60,
      createdAt: now,
      updatedAt: now,
      items: [
        SalesItem(
          id: 'so-item-$suffix',
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 3,
          unitId: unitId,
          unitPrice: 20,
          lineTotal: 60,
        ),
      ],
    );
    await sales.saveOrder(order);
    await sales.postDelivery(
      order: order,
      operationId: 'sales-integration-$suffix',
      warehouseId: warehouseId,
      deliveryDate: now,
      items: [
        SalesItem(
          id: 'so-item-$suffix',
          itemId: productId,
          itemType: SalesItemType.product,
          quantity: 3,
          unitId: unitId,
        ),
      ],
    );

    final rows = await db.query(
      'stock_balances',
      where: 'warehouseId = ? AND itemId = ?',
      whereArgs: [warehouseId, productId],
      limit: 1,
    );
    expect((rows.single['quantity'] as num).toDouble(), 7);
    expect(await accounting.customerLedger(customerId), isNotEmpty);
  });

  test(
    '3. production route and output complete the manufacturing loop',
    () async {
      final order = await completeProductionOrder();

      final updated = await production.getOrder(order.id);
      expect(updated.status, ProductionOrderStatus.completed);

      final materialRows = await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ?',
        whereArgs: [warehouseId, materialId],
        limit: 1,
      );
      expect((materialRows.single['quantity'] as num).toDouble(), 10);
      final materialValuation = await accounting.valuation(
        warehouseId,
        materialId,
        'RAW_MATERIAL',
      );
      expect(materialValuation, isNotNull);
      expect(materialValuation!.quantity, 10);
      expect(materialValuation.averageCost, 10);

      final batch = await costing.calculateBatchCost(
        productionOrderId: order.id,
      );
      expect(batch.materialCost, 100);
      expect(batch.goodFinishedQuantity, 5);
      final finalized = await costing.finalizeBatchCost(order.id, 'admin');
      expect(finalized.status.name, 'finalized');
      expect(finalized.totalCost, 100);
      expect(finalized.actualUnitCost, 20);

      final finishedRows = await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
        limit: 1,
      );
      expect((finishedRows.single['quantity'] as num).toDouble(), 15);
      final finishedValuation = await accounting.valuation(
        warehouseId,
        productId,
        'PRODUCT',
      );
      expect(finishedValuation, isNotNull);
      expect(finishedValuation!.quantity, 15);
      expect(
        finishedValuation.quantity * finishedValuation.averageCost,
        closeTo(250, 0.000001),
      );

      final referenceId = '${order.id}:$warehouseId';
      final journalRows = await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['PRODUCTION_COST', referenceId],
      );
      expect(journalRows, hasLength(1));
      final journal = journalRows.single;
      expect(journal['status'], 'POSTED');
      final persistedLines = await db.rawQuery(
        '''
        SELECT jl.accountId, a.code AS accountCode, jl.debit, jl.credit
        FROM journal_lines jl
        JOIN accounts a ON a.id = jl.accountId
        WHERE jl.journalEntryId = ?
        ORDER BY jl.rowid ASC
        ''',
        [journal['id']],
      );
      expect(persistedLines, hasLength(2));
      final inventoryLine = persistedLines.singleWhere(
        (line) => line['accountCode'] == '1100',
      );
      final productionLine = persistedLines.singleWhere(
        (line) => line['accountCode'] == '5900',
      );
      expect((inventoryLine['debit'] as num).toDouble(), finalized.totalCost);
      expect((inventoryLine['credit'] as num).toDouble(), 0);
      expect((productionLine['debit'] as num).toDouble(), 0);
      expect((productionLine['credit'] as num).toDouble(), finalized.totalCost);
      final totalDebits = persistedLines.fold<double>(
        0,
        (sum, line) => sum + (line['debit'] as num).toDouble(),
      );
      final totalCredits = persistedLines.fold<double>(
        0,
        (sum, line) => sum + (line['credit'] as num).toDouble(),
      );
      expect(totalDebits, finalized.totalCost);
      expect(totalCredits, finalized.totalCost);
      expect(totalDebits, totalCredits);

      final batchBeforeRetry = await db.query(
        'production_batch_costs',
        where: 'productionOrderId = ?',
        whereArgs: [order.id],
      );
      final journalLinesBeforeRetry = await db.query(
        'journal_lines',
        where: 'journalEntryId = ?',
        whereArgs: [journal['id']],
        orderBy: 'rowid ASC',
      );
      expect(journalLinesBeforeRetry, hasLength(2));
      final valuationBeforeRetry = await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );
      expect(valuationBeforeRetry, hasLength(1));
      await expectLater(
        costing.finalizeBatchCost(order.id, 'admin'),
        throwsException,
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ? AND referenceId = ?',
          whereArgs: ['PRODUCTION_COST', referenceId],
        ),
        equals(journalRows),
      );
      expect(
        await db.query(
          'journal_lines',
          where: 'journalEntryId = ?',
          whereArgs: [journal['id']],
          orderBy: 'rowid ASC',
        ),
        equals(journalLinesBeforeRetry),
      );
      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        equals(valuationBeforeRetry),
      );
      expect(
        await db.query(
          'production_batch_costs',
          where: 'productionOrderId = ?',
          whereArgs: [order.id],
        ),
        equals(batchBeforeRetry),
      );
    },
  );

  test(
    'production cost finalization rolls back when journal insertion fails',
    () async {
      final order = await completeProductionOrder();
      final batch = await costing.calculateBatchCost(
        productionOrderId: order.id,
      );
      final referenceId = '${order.id}:$warehouseId';
      final valuationBefore = await db.query(
        'inventory_valuations',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );
      final batchBefore = await db.query(
        'production_batch_costs',
        where: 'productionOrderId = ?',
        whereArgs: [order.id],
      );
      final stockBefore = await db.query(
        'stock_balances',
        where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [warehouseId, productId, 'PRODUCT'],
      );
      expect(batch.status.name, 'calculated');

      await db.execute('''
      CREATE TRIGGER fail_production_cost_journal_insert
      BEFORE INSERT ON journal_entries
      WHEN NEW.referenceType = 'PRODUCTION_COST'
      BEGIN
        SELECT RAISE(ABORT, 'injected production costing failure');
      END
    ''');
      try {
        await expectLater(
          costing.finalizeBatchCost(order.id, 'admin'),
          throwsA(
            predicate(
              (error) => error.toString().contains(
                'injected production costing failure',
              ),
            ),
          ),
        );
      } finally {
        await db.execute(
          'DROP TRIGGER IF EXISTS fail_production_cost_journal_insert',
        );
      }

      expect(
        await db.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        equals(valuationBefore),
      );
      final failedJournals = await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['PRODUCTION_COST', referenceId],
      );
      expect(failedJournals, isEmpty);
      expect(
        await db.rawQuery(
          '''
        SELECT jl.id
        FROM journal_lines jl
        JOIN journal_entries je ON je.id = jl.journalEntryId
        WHERE je.referenceType = ? AND je.referenceId = ?
        ''',
          ['PRODUCTION_COST', referenceId],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'production_batch_costs',
          where: 'productionOrderId = ?',
          whereArgs: [order.id],
        ),
        equals(batchBefore),
      );
      expect(
        await db.query(
          'stock_balances',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, productId, 'PRODUCT'],
        ),
        equals(stockBefore),
      );
    },
  );

  test(
    '4. pricing, returns, and global search share the same ERP data',
    () async {
      final priceList = PriceList(
        id: 'pricing-$suffix',
        code: 'STD-$suffix',
        name: 'Standard Price $suffix',
        active: true,
        createdAt: now,
        updatedAt: now,
      );
      await pricing.savePriceList(priceList);
      await pricing.saveProductPrice(
        ProductPrice(
          id: 'pp-$suffix',
          priceListId: priceList.id,
          productId: productId,
          unitPrice: 25,
          active: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final resolution = await pricing.resolvePrice(
        productId: productId,
        customerId: customerId,
        quantity: 2,
        asOf: now,
      );
      expect(resolution.unitPrice, 25);

      final salesOrder = SalesOrder(
        id: 'sr-so-$suffix',
        orderNumber: 'SR-SO-$suffix',
        customerId: customerId,
        orderDate: now,
        status: SalesOrderStatus.confirmed,
        subtotal: 50,
        discount: 0,
        tax: 0,
        grandTotal: 50,
        createdAt: now,
        updatedAt: now,
        items: [
          SalesItem(
            id: 'sr-item-$suffix',
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 2,
            unitId: unitId,
            unitPrice: 25,
            lineTotal: 50,
          ),
        ],
      );
      await sales.saveOrder(salesOrder);
      await sales.postDelivery(
        order: salesOrder,
        operationId: 'sales-return-source-$suffix',
        warehouseId: warehouseId,
        deliveryDate: now,
        items: [
          SalesItem(
            id: 'sr-item-$suffix',
            itemId: productId,
            itemType: SalesItemType.product,
            quantity: 2,
            unitId: unitId,
          ),
        ],
      );
      final delivery = (await sales.deliveries(salesOrder.id)).single;
      await sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.dispatched,
        dispatchDate: now,
      );
      await sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.inTransit,
      );
      await sales.updateDeliveryDispatch(
        deliveryId: delivery.id,
        status: DeliveryDispatchStatus.delivered,
      );
      final deliveryItemRows = await db.query(
        'sales_delivery_items',
        where: 'salesDeliveryId = ?',
        whereArgs: [delivery.id],
        limit: 1,
      );
      final salesReturn = await returnsQuality.createSalesReturn(
        id: 'sales-return-$suffix',
        returnNumber: 'SR-$suffix',
        salesOrderId: salesOrder.id,
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: now,
        salesDeliveryId: delivery.id,
        items: [
          SalesReturnItem(
            id: 'sales-return-item-$suffix',
            itemId: productId,
            itemType: 'PRODUCT',
            quantity: 1,
            unitId: unitId,
            qualityStatus: ReturnQualityStatus.approved,
            sourceDeliveryItemId: deliveryItemRows.single['id'] as String,
          ),
        ],
      );
      expect(salesReturn.id, isNotEmpty);

      final results = await search.search('Finished Product');
      expect(results, isNotEmpty);
    },
  );

  test('5. CRM conversion and document history are persisted', () async {
    final conversion = await crm.convertLead(
      leadId: leadId,
      customerData: Customer(
        id: 'converted-$suffix',
        name: 'Converted Customer $suffix',
        code: 'CV-$suffix',
        active: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(conversion.customerId, isNotEmpty);

    final document = await documents.createDraft(
      type: DocumentType.salesOrder,
      title: 'System integration document $suffix',
      metadata: {'warehouseId': warehouseId},
      sourceEntityType: 'SalesOrder',
      sourceEntityId: 'so-$suffix',
    );
    expect(document.documentNumber, isNotEmpty);

    final history = await documents.history(type: DocumentType.salesOrder);
    expect(
      history.any((item) => item.documentId == document.documentId),
      isTrue,
    );
  });

  test('6. import and export use the same ERP payload format', () async {
    final payload = jsonEncode({
      'module': 'products',
      'records': [
        {
          'table': 'products',
          'rows': [
            {
              'id': 'imported-product-$suffix',
              'name': 'Imported Product $suffix',
              'code': 'IMP-$suffix',
              'categoryId': categoryId,
              'unitId': unitId,
              'productState': 'finished',
              'active': 1,
              'createdAt': now.millisecondsSinceEpoch,
              'updatedAt': now.millisecondsSinceEpoch,
            },
          ],
        },
      ],
    });
    final summary = await importExport.importData(payload);
    expect(summary.recordsCreated, 1);

    final export = await importExport.exportData(module: 'products');
    expect(export.module, 'products');
    expect(export.records, greaterThanOrEqualTo(1));
  });
}
