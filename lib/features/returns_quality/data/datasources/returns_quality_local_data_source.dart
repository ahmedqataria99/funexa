import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/returns_quality/domain/entities/returns_quality_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';

class ReturnsQualityLocalDataSource {
  ReturnsQualityLocalDataSource([
    WarehousesStockLocalDataSource? stock,
    SecurityLocalDataSource? security,
    AccountingLocalDataSource? accounting,
  ]) : _stock = stock ?? WarehousesStockLocalDataSource(),
       _security = security ?? SecurityLocalDataSource(),
       _accounting = accounting ?? AccountingLocalDataSource();

  final WarehousesStockLocalDataSource _stock;
  final SecurityLocalDataSource _security;
  final AccountingLocalDataSource _accounting;

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<List<SalesReturn>> salesReturns({String? customerId}) async {
    _security.require('RETURNS_VIEW');
    final db = await _db;
    final rows = await db.query(
      'sales_returns',
      where: customerId == null ? null : 'customerId = ?',
      whereArgs: customerId == null ? null : [customerId],
      orderBy: 'returnDate DESC',
    );
    return rows.map(SalesReturn.fromMap).toList();
  }

  Future<List<PurchaseReturn>> purchaseReturns({String? supplierId}) async {
    _security.require('RETURNS_VIEW');
    final db = await _db;
    final rows = await db.query(
      'purchase_returns',
      where: supplierId == null ? null : 'supplierId = ?',
      whereArgs: supplierId == null ? null : [supplierId],
      orderBy: 'returnDate DESC',
    );
    return rows.map(PurchaseReturn.fromMap).toList();
  }

  Future<List<QualityInspection>> qualityInspections({
    String? sourceType,
  }) async {
    _security.require('QUALITY_VIEW');
    final db = await _db;
    final rows = await db.query(
      'quality_inspections',
      where: sourceType == null ? null : 'sourceType = ?',
      whereArgs: sourceType == null ? null : [sourceType],
      orderBy: 'inspectionDate DESC',
    );
    return rows.map(QualityInspection.fromMap).toList();
  }

  Future<SalesReturn> saveSalesReturn(SalesReturn value) async {
    _security.require('RETURNS_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      if (value.items.isEmpty) throw Exception('يجب إدخال بنود المرتجع');
      if ((await txn.query(
        'sales_returns',
        columns: ['id'],
        where: 'id = ? OR returnNumber = ?',
        whereArgs: [value.id, value.returnNumber],
        limit: 1,
      )).isNotEmpty) {
        throw Exception('تم تسجيل المرتجع من قبل');
      }
      await _validateSalesReturn(txn, value);
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId,
      );
      await txn.insert('sales_returns', value.toMap());
      for (final item in value.items) {
        await txn.insert('sales_return_items', item.toMap(value.id));
      }
      if (_isPostedReturn(value.status)) {
        for (final item in value.items) {
          await _applySalesReturnItem(
            txn,
            warehouseId: value.warehouseId,
            itemId: item.itemId,
            itemType: _stockItemType(item.itemType),
            quantity: item.quantity,
            qualityStatus: item.qualityStatus,
            direction: 'sales',
            sourceDeliveryItemId: item.sourceDeliveryItemId,
          );
        }
        await _postSalesReturnAccounting(txn, value);
      }
    });
    return value;
  }

  Future<SalesReturn> createSalesReturn({
    required String id,
    required String returnNumber,
    required String salesOrderId,
    required String customerId,
    required String warehouseId,
    required DateTime returnDate,
    String? salesDeliveryId,
    String? reason,
    ReturnStatus status = ReturnStatus.pending,
    String? notes,
    required List<SalesReturnItem> items,
  }) async {
    final now = DateTime.now();
    return saveSalesReturn(
      SalesReturn(
        id: id,
        returnNumber: returnNumber,
        salesOrderId: salesOrderId,
        customerId: customerId,
        warehouseId: warehouseId,
        returnDate: returnDate,
        salesDeliveryId: salesDeliveryId,
        reason: reason,
        status: status,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        items: items,
      ),
    );
  }

  Future<PurchaseReturn> savePurchaseReturn(PurchaseReturn value) async {
    _security.require('RETURNS_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      if (value.items.isEmpty)
        throw Exception('يجب إدخال بنود مردود المشتريات');
      await _validatePurchaseReturn(txn, value);
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId,
      );
      await txn.insert('purchase_returns', value.toMap());
      for (final item in value.items) {
        await txn.insert('purchase_return_items', item.toMap(value.id));
      }
      if (_isPostedReturn(value.status)) {
        var payableReversal = 0.0;
        var inventoryReversal = 0.0;
        for (final item in value.items) {
          if (item.qualityStatus != ReturnQualityStatus.approved) continue;
          final unitPrice = await _purchaseUnitPrice(txn, value, item);
          final valuation = await _accounting.valuationWithinTransaction(
            txn,
            value.warehouseId,
            item.itemId,
            _stockItemType(item.itemType).value,
          );
          if (valuation == null ||
              valuation.quantity < item.quantity ||
              valuation.averageCost <= 0) {
            throw Exception('تقييم المخزون غير متاح أو غير كاف للمرتجع');
          }
          payableReversal += item.quantity * unitPrice;
          inventoryReversal += item.quantity * valuation.averageCost;
          await _applyPurchaseReturnItem(
            txn,
            warehouseId: value.warehouseId,
            itemId: item.itemId,
            itemType: _stockItemType(item.itemType),
            quantity: item.quantity,
            qualityStatus: item.qualityStatus,
          );
        }
        if (payableReversal > 0 || inventoryReversal > 0) {
          await _postPurchaseReturnAccounting(
            txn,
            value,
            payableReversal: payableReversal,
            inventoryReversal: inventoryReversal,
          );
        }
      }
    });
    return value;
  }

  Future<PurchaseReturn> createPurchaseReturn({
    required String id,
    required String returnNumber,
    required String purchaseOrderId,
    required String supplierId,
    required String warehouseId,
    required DateTime returnDate,
    String? purchaseReceiptId,
    String? reason,
    ReturnStatus status = ReturnStatus.pending,
    String? notes,
    required List<PurchaseReturnItem> items,
  }) async {
    final now = DateTime.now();
    return savePurchaseReturn(
      PurchaseReturn(
        id: id,
        returnNumber: returnNumber,
        purchaseOrderId: purchaseOrderId,
        supplierId: supplierId,
        warehouseId: warehouseId,
        returnDate: returnDate,
        purchaseReceiptId: purchaseReceiptId,
        reason: reason,
        status: status,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        items: items,
      ),
    );
  }

  Future<QualityInspection> saveQualityInspection(
    QualityInspection value,
  ) async {
    _security.require('QUALITY_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      if (value.items.isEmpty) throw Exception('يجب إدخال بنود الفحص');
      if ((await txn.query(
        'quality_inspections',
        columns: ['id'],
        where: 'sourceType = ? AND sourceId = ?',
        whereArgs: [value.sourceType.toUpperCase(), value.sourceId],
        limit: 1,
      )).isNotEmpty) {
        throw Exception('تم فحص مصدر المرتجع من قبل');
      }
      await _validateQualityInspection(txn, value);
      if (value.warehouseId != null) {
        await _security.requireResourceScope(
          ScopeType.warehouse,
          value.warehouseId!,
        );
      }
      await txn.insert('quality_inspections', value.toMap());
      for (final item in value.items) {
        await txn.insert('quality_inspection_items', item.toMap(value.id));
      }
      if (_isProcessedInspection(value.status) &&
          (value.result == QualityInspectionResult.quarantined ||
              value.result == QualityInspectionResult.rejected)) {
        if (value.warehouseId != null) {
          for (final item in value.items) {
            final itemType = _itemType(item.itemType);
            final quantity = item.rejectedQuantity > 0
                ? item.rejectedQuantity
                : item.inspectedQuantity;
            final option = await _itemOption(txn, item.itemId, itemType);
            await _stock.applyStockOutWithinTransaction(
              executor: txn,
              warehouseId: value.warehouseId!,
              item: option,
              quantity: quantity,
              date: value.inspectionDate,
              reference: value.inspectionNumber,
              notes: value.notes,
            );
          }
        }
      }
    });
    return value;
  }

  Future<QualityInspection> createQualityInspection({
    required String id,
    required String inspectionNumber,
    required String sourceType,
    required String sourceId,
    String? warehouseId,
    required String itemId,
    required String itemType,
    String? inspectedBy,
    required DateTime inspectionDate,
    QualityInspectionStatus status = QualityInspectionStatus.pending,
    QualityInspectionResult result = QualityInspectionResult.passed,
    String? notes,
    required List<QualityInspectionItem> items,
  }) async {
    final now = DateTime.now();
    return saveQualityInspection(
      QualityInspection(
        id: id,
        inspectionNumber: inspectionNumber,
        sourceType: sourceType,
        sourceId: sourceId,
        warehouseId: warehouseId,
        itemId: itemId,
        itemType: itemType,
        inspectedBy: inspectedBy,
        inspectionDate: inspectionDate,
        status: status,
        result: result,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        items: items,
      ),
    );
  }

  Future<void> _validateSalesReturn(
    DatabaseExecutor txn,
    SalesReturn value,
  ) async {
    final orderRows = await txn.query(
      'sales_orders',
      columns: ['customerId'],
      where: 'id = ?',
      whereArgs: [value.salesOrderId],
      limit: 1,
    );
    if (orderRows.isEmpty) throw Exception('أمر البيع غير موجود');
    if (orderRows.single['customerId'] != value.customerId) {
      throw Exception('العميل لا يطابق أمر البيع');
    }
    final deliveryId = value.salesDeliveryId;
    if (deliveryId == null || deliveryId.isEmpty) {
      throw Exception('يجب ربط المرتجع بتسليم فعلي');
    }
    final deliveryRows = await txn.query(
      'sales_deliveries',
      where: 'id = ? AND salesOrderId = ? AND status = ?',
      whereArgs: [deliveryId, value.salesOrderId, 'DELIVERED'],
      limit: 1,
    );
    if (deliveryRows.isEmpty) throw Exception('التسليم غير موجود أو غير مكتمل');
    final customerRows = await txn.query(
      'customers',
      where: 'id = ? AND active = 1',
      whereArgs: [value.customerId],
      limit: 1,
    );
    if (customerRows.isEmpty) throw Exception('العميل غير موجود أو غير نشط');
    final warehouseRows = await txn.query(
      'warehouses',
      where: 'id = ? AND state = ?',
      whereArgs: [value.warehouseId, 'active'],
      limit: 1,
    );
    if (warehouseRows.isEmpty) throw Exception('المخزن غير موجود أو غير نشط');
    final requestedByDeliveryLine = <String, double>{};
    for (final item in value.items) {
      if (item.quantity <= 0)
        throw Exception('كمية المرتجع يجب أن تكون أكبر من صفر');
      final deliveryItemId = item.sourceDeliveryItemId;
      if (deliveryItemId == null || deliveryItemId.isEmpty) {
        throw Exception('يجب تحديد بند التسليم المرتبط بالمرتجع');
      }
      final deliveryItemRows = await txn.rawQuery(
        '''
        SELECT di.salesDeliveryId, di.deliveredQuantity, di.unitId,
               soi.salesOrderId, soi.itemId, soi.itemType
        FROM sales_delivery_items di
        JOIN sales_order_items soi ON soi.id = di.salesOrderItemId
        WHERE di.id = ?
        ''',
        [deliveryItemId],
      );
      if (deliveryItemRows.isEmpty) throw Exception('بند التسليم غير موجود');
      final deliveredLine = deliveryItemRows.single;
      if (deliveredLine['salesDeliveryId'] != deliveryId ||
          deliveredLine['salesOrderId'] != value.salesOrderId ||
          deliveredLine['itemId'] != item.itemId ||
          deliveredLine['itemType'] != item.itemType ||
          deliveredLine['unitId'] != item.unitId) {
        throw Exception('بند المرتجع لا يطابق بند التسليم');
      }
      final previousRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(sri.quantity), 0) AS returnedQuantity
        FROM sales_return_items sri
        JOIN sales_returns sr ON sr.id = sri.salesReturnId
        WHERE sri.sourceDeliveryItemId = ?
          AND sr.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
        ''',
        [deliveryItemId],
      );
      final previous = (previousRows.single['returnedQuantity'] as num)
          .toDouble();
      final current = requestedByDeliveryLine[deliveryItemId] ?? 0;
      final delivered = (deliveredLine['deliveredQuantity'] as num).toDouble();
      if (previous + current + item.quantity > delivered) {
        throw Exception('كمية المرتجع تتجاوز الكمية المسلمة المتبقية');
      }
      requestedByDeliveryLine[deliveryItemId] = current + item.quantity;
      await _ensureItemExists(txn, item.itemId, _stockItemType(item.itemType));
    }
  }

  Future<void> _postSalesReturnAccounting(
    DatabaseExecutor txn,
    SalesReturn value,
  ) async {
    var revenueReversal = 0.0;
    var cogsReversal = 0.0;
    for (final item in value.items) {
      if (item.qualityStatus != ReturnQualityStatus.approved) continue;
      final rows = await txn.query(
        'sales_delivery_items',
        columns: ['unitRevenue', 'unitCogs'],
        where: 'id = ?',
        whereArgs: [item.sourceDeliveryItemId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('بند التسليم غير موجود');
      revenueReversal +=
          item.quantity *
          ((rows.single['unitRevenue'] as num?) ?? 0).toDouble();
      cogsReversal +=
          item.quantity * ((rows.single['unitCogs'] as num?) ?? 0).toDouble();
    }
    if (revenueReversal <= 0 && cogsReversal <= 0) return;

    Future<String> accountId(String code) async =>
        (await txn.query(
              'accounts',
              columns: ['id'],
              where: 'code = ? AND active = 1',
              whereArgs: [code],
              limit: 1,
            )).single['id']
            as String;

    final lines = <JournalLineInput>[];
    if (revenueReversal > 0) {
      lines.add(
        JournalLineInput(
          accountId: await accountId('4000'),
          debit: revenueReversal,
        ),
      );
      lines.add(
        JournalLineInput(
          accountId: await accountId('1200'),
          credit: revenueReversal,
        ),
      );
    }
    if (cogsReversal > 0) {
      lines.add(
        JournalLineInput(
          accountId: await accountId('1100'),
          debit: cogsReversal,
        ),
      );
      lines.add(
        JournalLineInput(
          accountId: await accountId('5000'),
          credit: cogsReversal,
        ),
      );
    }
    await _accounting.postJournalWithinTransaction(
      executor: txn,
      date: value.returnDate,
      description: 'عكس مرتجع المبيعات ${value.returnNumber}',
      referenceType: 'SALES_RETURN',
      referenceId: value.id,
      partyType: 'CUSTOMER',
      partyId: value.customerId,
      lines: lines,
    );
  }

  Future<void> _validatePurchaseReturn(
    DatabaseExecutor txn,
    PurchaseReturn value,
  ) async {
    final orderRows = await txn.query(
      'purchase_orders',
      where: 'id = ?',
      whereArgs: [value.purchaseOrderId],
      limit: 1,
    );
    if (orderRows.isEmpty) throw Exception('أمر الشراء غير موجود');
    if (orderRows.single['supplierId'] != value.supplierId) {
      throw Exception('المورد لا يطابق أمر الشراء');
    }
    final supplierRows = await txn.query(
      'suppliers',
      where: 'id = ? AND active = 1',
      whereArgs: [value.supplierId],
      limit: 1,
    );
    if (supplierRows.isEmpty) throw Exception('المورد غير موجود أو غير نشط');
    final warehouseRows = await txn.query(
      'warehouses',
      where: 'id = ? AND state = ?',
      whereArgs: [value.warehouseId, 'active'],
      limit: 1,
    );
    if (warehouseRows.isEmpty) throw Exception('المخزن غير موجود أو غير نشط');
    final returnedByItem = <String, double>{};
    for (final item in value.items) {
      if (item.quantity <= 0) throw Exception('كمية المرتجع غير صالحة');
      final orderItems = await txn.query(
        'purchase_order_items',
        where:
            'purchaseOrderId = ? AND itemId = ? AND itemType = ? AND unitId = ?',
        whereArgs: [
          value.purchaseOrderId,
          item.itemId,
          item.itemType.toUpperCase(),
          item.unitId,
        ],
        limit: 1,
      );
      if (orderItems.isEmpty) {
        throw Exception('بند المرتجع لا يطابق أمر الشراء');
      }
      if (value.purchaseReceiptId != null) {
        final receiptRows = await txn.query(
          'purchase_receipts',
          where: 'id = ? AND purchaseOrderId = ?',
          whereArgs: [value.purchaseReceiptId, value.purchaseOrderId],
          limit: 1,
        );
        if (receiptRows.isEmpty) throw Exception('إيصال الشراء غير موجود');
        final receiptItems = await txn.query(
          'purchase_receipt_items',
          where: 'purchaseReceiptId = ? AND purchaseOrderItemId = ?',
          whereArgs: [value.purchaseReceiptId, orderItems.single['id']],
          limit: 1,
        );
        if (receiptItems.isEmpty) {
          throw Exception('بند المرتجع غير موجود في إيصال الشراء');
        }
      }
      final key = '${item.itemId}:${item.itemType}:${item.unitId}';
      final returnedBeforeRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(pri.quantity), 0) quantity
        FROM purchase_return_items pri
        JOIN purchase_returns pr ON pr.id = pri.purchaseReturnId
        WHERE pr.purchaseOrderId = ? AND pri.itemId = ?
          AND pri.itemType = ? AND pri.unitId = ?
          AND pr.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
        ''',
        [value.purchaseOrderId, item.itemId, item.itemType, item.unitId],
      );
      final received = (orderItems.single['receivedQuantity'] as num)
          .toDouble();
      final returnedBefore = (returnedBeforeRows.single['quantity'] as num)
          .toDouble();
      final requested = (returnedByItem[key] ?? 0) + item.quantity;
      if (returnedBefore + requested > received) {
        throw Exception('كمية المرتجع تتجاوز الكمية المستلمة المتبقية');
      }
      returnedByItem[key] = requested;
      await _ensureItemExists(txn, item.itemId, _stockItemType(item.itemType));
    }
  }

  Future<double> _purchaseUnitPrice(
    DatabaseExecutor txn,
    PurchaseReturn value,
    PurchaseReturnItem item,
  ) async {
    final rows = await txn.query(
      'purchase_order_items',
      columns: ['unitPrice'],
      where:
          'purchaseOrderId = ? AND itemId = ? AND itemType = ? AND unitId = ?',
      whereArgs: [
        value.purchaseOrderId,
        item.itemId,
        item.itemType.toUpperCase(),
        item.unitId,
      ],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('بند أمر الشراء غير موجود');
    return (rows.single['unitPrice'] as num).toDouble();
  }

  Future<void> _postPurchaseReturnAccounting(
    DatabaseExecutor txn,
    PurchaseReturn value, {
    required double payableReversal,
    required double inventoryReversal,
  }) async {
    if (payableReversal <= 0 || inventoryReversal <= 0) {
      throw Exception('قيمة مرتجع الشراء غير صالحة للمحاسبة');
    }
    Future<String> accountId(String code) async =>
        (await txn.query(
              'accounts',
              columns: ['id'],
              where: 'code = ? AND active = 1',
              whereArgs: [code],
              limit: 1,
            )).single['id']
            as String;

    final lines = <JournalLineInput>[
      JournalLineInput(
        accountId: await accountId('2000'),
        debit: payableReversal,
      ),
      JournalLineInput(
        accountId: await accountId('1100'),
        credit: inventoryReversal,
      ),
    ];
    final difference = inventoryReversal - payableReversal;
    if (difference > 0) {
      lines.add(
        JournalLineInput(accountId: await accountId('5920'), debit: difference),
      );
    } else if (difference < 0) {
      lines.add(
        JournalLineInput(
          accountId: await accountId('5910'),
          credit: -difference,
        ),
      );
    }
    await _accounting.postJournalWithinTransaction(
      executor: txn,
      date: value.returnDate,
      description: 'عكس مرتجع المشتريات ${value.returnNumber}',
      referenceType: 'PURCHASE_RETURN',
      referenceId: value.id,
      partyType: 'SUPPLIER',
      partyId: value.supplierId,
      lines: lines,
    );
  }

  Future<void> _validateQualityInspection(
    DatabaseExecutor txn,
    QualityInspection value,
  ) async {
    final sourceType = value.sourceType.toUpperCase();
    final sourceTable = switch (sourceType) {
      'SALES_RETURN' => 'sales_returns',
      'PURCHASE_RETURN' => 'purchase_returns',
      _ => throw Exception('نوع مصدر الفحص غير مدعوم'),
    };
    final sourceRows = await txn.query(
      sourceTable,
      where: 'id = ?',
      whereArgs: [value.sourceId],
      limit: 1,
    );
    if (sourceRows.isEmpty) throw Exception('مصدر الفحص غير موجود');
    if (!value.items.any(
      (item) =>
          item.itemId == value.itemId &&
          item.itemType.toUpperCase() == value.itemType.toUpperCase(),
    )) {
      throw Exception('البند الرئيسي غير موجود في تفاصيل الفحص');
    }
    if (value.warehouseId != null) {
      final warehouseRows = await txn.query(
        'warehouses',
        where: 'id = ? AND state = ?',
        whereArgs: [value.warehouseId, 'active'],
        limit: 1,
      );
      if (warehouseRows.isEmpty) throw Exception('المخزن غير موجود أو غير نشط');
    }
    for (final item in value.items) {
      if (item.requestedQuantity <= 0 ||
          item.inspectedQuantity <= 0 ||
          item.inspectedQuantity > item.requestedQuantity ||
          item.acceptedQuantity + item.rejectedQuantity >
              item.inspectedQuantity) {
        throw Exception('كميات الفحص غير متوافقة');
      }
      final returnItems = await txn.query(
        sourceType == 'SALES_RETURN'
            ? 'sales_return_items'
            : 'purchase_return_items',
        where: sourceType == 'SALES_RETURN'
            ? 'salesReturnId = ? AND itemId = ? AND itemType = ?'
            : 'purchaseReturnId = ? AND itemId = ? AND itemType = ?',
        whereArgs: [value.sourceId, item.itemId, item.itemType.toUpperCase()],
        limit: 1,
      );
      if (returnItems.isEmpty ||
          item.requestedQuantity >
              (returnItems.single['quantity'] as num).toDouble()) {
        throw Exception('كمية الفحص لا تطابق بند المرتجع');
      }
      await _ensureItemExists(txn, item.itemId, _stockItemType(item.itemType));
    }
  }

  bool _isProcessedInspection(QualityInspectionStatus status) =>
      status == QualityInspectionStatus.completed ||
      status == QualityInspectionStatus.rejected ||
      status == QualityInspectionStatus.quarantined;

  Future<void> _ensureItemExists(
    DatabaseExecutor txn,
    String itemId,
    StockItemType itemType,
  ) async {
    final table = itemType == StockItemType.rawMaterial
        ? 'raw_materials'
        : 'products';
    final rows = await txn.query(
      table,
      where: 'id = ? AND active = 1',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('البند غير موجود أو غير نشط');
  }

  Future<void> _applySalesReturnItem(
    DatabaseExecutor txn, {
    required String warehouseId,
    required String itemId,
    required StockItemType itemType,
    required double quantity,
    required ReturnQualityStatus qualityStatus,
    required String direction,
    String? sourceDeliveryItemId,
  }) async {
    if (quantity <= 0) return;
    final detail = await _itemOption(txn, itemId, itemType);
    if (qualityStatus == ReturnQualityStatus.approved) {
      if (direction == 'sales') {
        final sourceRows = await txn.query(
          'sales_delivery_items',
          columns: ['unitCogs'],
          where: 'id = ?',
          whereArgs: [sourceDeliveryItemId],
          limit: 1,
        );
        final unitCost = sourceRows.isEmpty
            ? 0.0
            : ((sourceRows.single['unitCogs'] as num?) ?? 0).toDouble();
        if (unitCost <= 0) {
          throw Exception('تكلفة بند التسليم غير متاحة لتقييم المرتجع');
        }
        await _accounting.receiveInventoryValueWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          itemId: itemId,
          itemType: itemType.value,
          quantity: quantity,
          unitCost: unitCost,
        );
      }
      await _stock.applyStockInWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        item: detail,
        quantity: quantity,
        date: DateTime.now(),
        reference: direction == 'sales' ? 'SALES_RETURN' : 'PURCHASE_RETURN',
        notes: 'مرتجع',
      );
    } else if (qualityStatus == ReturnQualityStatus.rejected) {
      await _stock.applyStockOutWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        item: detail,
        quantity: quantity,
        date: DateTime.now(),
        reference: direction == 'sales'
            ? 'SALES_RETURN_REJECTED'
            : 'PURCHASE_RETURN_REJECTED',
        notes: 'مرفوض',
      );
    }
  }

  Future<void> _applyPurchaseReturnItem(
    DatabaseExecutor txn, {
    required String warehouseId,
    required String itemId,
    required StockItemType itemType,
    required double quantity,
    required ReturnQualityStatus qualityStatus,
  }) async {
    if (quantity <= 0 || qualityStatus != ReturnQualityStatus.approved) return;
    final detail = await _itemOption(txn, itemId, itemType);
    await _accounting.consumeInventoryValueWithinTransaction(
      executor: txn,
      warehouseId: warehouseId,
      itemId: itemId,
      itemType: itemType.value,
      quantity: quantity,
    );
    await _stock.applyStockOutWithinTransaction(
      executor: txn,
      warehouseId: warehouseId,
      item: detail,
      quantity: quantity,
      date: DateTime.now(),
      reference: 'PURCHASE_RETURN',
      notes: 'مرتجع إلى المورد',
    );
  }

  bool _isPostedReturn(ReturnStatus status) =>
      status == ReturnStatus.approved || status == ReturnStatus.completed;

  Future<StockItemOption> _itemOption(
    DatabaseExecutor txn,
    String itemId,
    StockItemType itemType,
  ) async {
    final table = itemType == StockItemType.rawMaterial
        ? 'raw_materials'
        : 'products';
    final rows = await txn.query(
      table,
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('البند غير موجود');
    final row = rows.first;
    return StockItemOption(
      id: row['id'] as String,
      name: row['name'] as String,
      code: row['code'] as String,
      unitId: row['unitId'] as String,
      type: itemType,
      active: (row['active'] as int?) == 1,
    );
  }

  StockItemType _stockItemType(String itemType) =>
      itemType.toUpperCase() == 'RAW_MATERIAL'
      ? StockItemType.rawMaterial
      : StockItemType.product;

  StockItemType _itemType(String itemType) => _stockItemType(itemType);
}

class ReturnsQualityControlLocalDataSource
    extends ReturnsQualityLocalDataSource {}

class ReturnsAndQualityLocalDataSource extends ReturnsQualityLocalDataSource {}
