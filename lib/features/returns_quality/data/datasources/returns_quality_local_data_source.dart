import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
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
    final inspections = <QualityInspection>[];
    for (final row in rows) {
      final items = await db.query(
        'quality_inspection_items',
        where: 'inspectionId = ?',
        whereArgs: [row['id']],
        orderBy: 'createdAt ASC, id ASC',
      );
      inspections.add(
        QualityInspection.fromMap(
          row,
          items: items.map(QualityInspectionItem.fromMap).toList(),
        ),
      );
    }
    return inspections;
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
      final identityStatuses = await _validateSalesReturn(txn, value);
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId,
      );
      await txn.insert('sales_returns', value.toMap());
      for (final item in value.items) {
        await txn.insert(
          'sales_return_items',
          item.toMap(
            value.id,
            identitySnapshotStatus: identityStatuses[item.id],
          ),
        );
      }
      if (_isPostedReturn(value.status)) {
        await _postSalesReturnWithinTransaction(txn, value);
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

  Future<void> updateSalesReturnStatus(
    String returnId,
    ReturnStatus status,
  ) async {
    _security.require('RETURNS_EDIT');
    if (status != ReturnStatus.approved &&
        status != ReturnStatus.rejected &&
        status != ReturnStatus.cancelled) {
      throw Exception('حالة المرتجع غير صالحة للانتقال');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sales_returns',
        where: 'id = ?',
        whereArgs: [returnId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('مرتجع المبيعات غير موجود');
      final row = rows.single;
      final current = ReturnStatus.values.firstWhere(
        (value) => value.value == row['status'],
      );
      if (current == status) return;
      if (current != ReturnStatus.pending) {
        throw Exception('لا يمكن تغيير حالة المرتجع بعد معالجته');
      }
      final itemRows = await txn.query(
        'sales_return_items',
        where: 'salesReturnId = ?',
        whereArgs: [returnId],
      );
      final stored = SalesReturn.fromMap(row);
      final value = SalesReturn(
        id: stored.id,
        returnNumber: stored.returnNumber,
        salesOrderId: stored.salesOrderId,
        customerId: stored.customerId,
        warehouseId: stored.warehouseId,
        returnDate: stored.returnDate,
        salesDeliveryId: stored.salesDeliveryId,
        reason: stored.reason,
        status: status,
        notes: stored.notes,
        createdAt: stored.createdAt,
        updatedAt: DateTime.now(),
        items: itemRows.map(SalesReturnItem.fromMap).toList(),
      );
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId,
      );
      if (status == ReturnStatus.approved) {
        await _validateSalesReturn(txn, value, excludeReturnId: returnId);
      }
      await txn.update(
        'sales_returns',
        {
          'status': status.value,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [returnId],
      );
      if (status == ReturnStatus.approved) {
        await _postSalesReturnWithinTransaction(txn, value);
        await _applyInspectionRejectionsForApprovedSource(
          txn,
          sourceType: 'SALES_RETURN',
          sourceId: returnId,
          warehouseId: value.warehouseId,
          reference: value.returnNumber,
        );
      }
    });
  }

  Future<PurchaseReturn> savePurchaseReturn(PurchaseReturn value) async {
    _security.require('RETURNS_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      if (value.items.isEmpty)
        throw Exception('يجب إدخال بنود مردود المشتريات');
      final sourceLines = await _validatePurchaseReturn(txn, value);
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId,
      );
      await txn.insert('purchase_returns', value.toMap());
      for (final item in value.items) {
        await txn.insert(
          'purchase_return_items',
          item.toMap(
            value.id,
            purchaseOrderItemId: sourceLines[item.id]?.purchaseOrderItemId,
            identitySnapshotStatus:
                sourceLines[item.id]?.identitySnapshotStatus,
            sourceReceiptId: item.sourceReceiptId ?? value.purchaseReceiptId,
          ),
        );
      }
      if (_isPostedReturn(value.status)) {
        await _postPurchaseReturnWithinTransaction(txn, value);
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

  Future<void> updatePurchaseReturnStatus(
    String returnId,
    ReturnStatus status,
  ) async {
    _security.require('RETURNS_EDIT');
    if (status != ReturnStatus.approved &&
        status != ReturnStatus.rejected &&
        status != ReturnStatus.cancelled) {
      throw Exception('حالة المرتجع غير صالحة للانتقال');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'purchase_returns',
        where: 'id = ?',
        whereArgs: [returnId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('مرتجع المشتريات غير موجود');
      final row = rows.single;
      final current = ReturnStatus.values.firstWhere(
        (value) => value.value == row['status'],
      );
      if (current == status) return;
      if (current != ReturnStatus.pending) {
        throw Exception('لا يمكن تغيير حالة المرتجع بعد معالجته');
      }
      final itemRows = await txn.query(
        'purchase_return_items',
        where: 'purchaseReturnId = ?',
        whereArgs: [returnId],
      );
      final stored = PurchaseReturn.fromMap(row);
      final value = PurchaseReturn(
        id: stored.id,
        returnNumber: stored.returnNumber,
        purchaseOrderId: stored.purchaseOrderId,
        supplierId: stored.supplierId,
        warehouseId: stored.warehouseId,
        returnDate: stored.returnDate,
        purchaseReceiptId: stored.purchaseReceiptId,
        reason: stored.reason,
        status: status,
        notes: stored.notes,
        createdAt: stored.createdAt,
        updatedAt: DateTime.now(),
        items: itemRows.map(PurchaseReturnItem.fromMap).toList(),
      );
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId,
      );
      if (status == ReturnStatus.approved) {
        await _validatePurchaseReturn(txn, value, excludeReturnId: returnId);
      }
      await txn.update(
        'purchase_returns',
        {
          'status': status.value,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [returnId],
      );
      if (status == ReturnStatus.approved) {
        await _postPurchaseReturnWithinTransaction(txn, value);
        await _applyInspectionRejectionsForApprovedSource(
          txn,
          sourceType: 'PURCHASE_RETURN',
          sourceId: returnId,
          warehouseId: value.warehouseId,
          reference: value.returnNumber,
        );
      }
    });
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
      if (value.warehouseId != null) {
        await _security.requireResourceScope(
          ScopeType.warehouse,
          value.warehouseId!,
        );
      }
      final inspectedItems = await _validateQualityInspection(txn, value);
      final primaryItem = inspectedItems.first;
      await txn.insert('quality_inspections', {
        ...value.toMap(),
        'sourceType': value.sourceType.toUpperCase(),
        'productId': primaryItem.productId,
        'variantId': primaryItem.variantId,
        'inventoryIdentityKind': primaryItem.inventoryIdentityKind,
      });
      for (final item in inspectedItems) {
        await txn.insert('quality_inspection_items', item.toMap(value.id));
      }
      final sourceTable = value.sourceType.toUpperCase() == 'SALES_RETURN'
          ? 'sales_returns'
          : 'purchase_returns';
      final sourceRows = await txn.query(
        sourceTable,
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [value.sourceId],
        limit: 1,
      );
      if (sourceRows.isEmpty) throw Exception('مصدر الفحص غير موجود');
      final sourceStatus = (sourceRows.single['status'] as String)
          .toUpperCase();
      if (_isProcessedInspection(value.status) &&
          value.warehouseId != null &&
          sourceStatus != 'PENDING' &&
          sourceStatus != 'DRAFT') {
        for (final item in inspectedItems) {
          final identityKind = InventoryIdentityKindValue.parse(
            item.inventoryIdentityKind,
          );
          final rejectedBaseQuantity = item.rejectedBaseQuantity ?? 0;
          if (rejectedBaseQuantity <= 0) continue;
          final option = await _itemOption(
            txn,
            item.productId ?? item.itemId,
            _itemType(item.itemType),
            variantId: item.variantId,
            baseUnitId: item.baseUnitId,
            identityKind: identityKind,
          );
          await _stock.applyStockOutWithinTransaction(
            executor: txn,
            warehouseId: value.warehouseId!,
            item: option,
            quantity: rejectedBaseQuantity,
            date: value.inspectionDate,
            reference: value.inspectionNumber,
            notes: value.notes,
          );
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

  Future<void> _postSalesReturnWithinTransaction(
    DatabaseExecutor txn,
    SalesReturn value,
  ) async {
    for (final item in value.items) {
      await _applySalesReturnItem(
        txn,
        warehouseId: value.warehouseId,
        itemId: item.itemId,
        itemType: _stockItemType(item.itemType),
        quantity:
            item.baseQuantity ?? item.quantity * item.unitConversionFactor,
        variantId: item.variantId,
        baseUnitId: item.baseUnitId ?? item.unitId,
        identityKind: InventoryIdentityKindValue.parse(
          item.inventoryIdentityKind,
        ),
        qualityStatus: item.qualityStatus,
        direction: 'sales',
        sourceDeliveryItemId: item.sourceDeliveryItemId,
      );
    }
    await _postSalesReturnAccounting(txn, value);
  }

  Future<void> _applyInspectionRejectionsForApprovedSource(
    DatabaseExecutor txn, {
    required String sourceType,
    required String sourceId,
    required String warehouseId,
    required String reference,
    DateTime? date,
    String? notes,
  }) async {
    final rows = await txn.query(
      'quality_inspections',
      columns: ['id'],
      where: 'sourceType = ? AND sourceId = ?',
      whereArgs: [sourceType, sourceId],
    );
    if (rows.isEmpty) return;
    for (final row in rows) {
      final itemRows = await txn.query(
        'quality_inspection_items',
        where: 'inspectionId = ?',
        whereArgs: [row['id']],
      );
      for (final itemRow in itemRows) {
        final rejectedQty = (itemRow['rejectedBaseQuantity'] as num? ?? 0)
            .toDouble();
        if (rejectedQty <= 0) continue;
        final identityKind = InventoryIdentityKindValue.parse(
          itemRow['inventoryIdentityKind'] as String? ?? 'BASE',
        );
        final option = await _itemOption(
          txn,
          itemRow['productId'] as String? ?? itemRow['itemId'] as String,
          _itemType(itemRow['itemType'] as String),
          variantId: itemRow['variantId'] as String?,
          baseUnitId: itemRow['baseUnitId'] as String?,
          identityKind: identityKind,
        );
        await _stock.applyStockOutWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          item: option,
          quantity: rejectedQty,
          date: date ?? DateTime.now(),
          reference: reference,
          notes: notes,
        );
      }
    }
  }

  Future<Map<String, String>> _validateSalesReturn(
    DatabaseExecutor txn,
    SalesReturn value, {
    String? excludeReturnId,
  }) async {
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
    final identityStatuses = <String, String>{};
    for (final item in value.items) {
      if (!item.quantity.isFinite || item.quantity <= 0) {
        throw Exception('كمية المرتجع يجب أن تكون أكبر من صفر');
      }
      final deliveryItemId = item.sourceDeliveryItemId;
      if (deliveryItemId == null || deliveryItemId.isEmpty) {
        throw Exception('يجب تحديد بند التسليم المرتبط بالمرتجع');
      }
      final deliveryItemRows = await txn.rawQuery(
        '''
         SELECT di.salesDeliveryId, di.deliveredQuantity, di.baseQuantity,
           di.unitId, di.baseUnitId, di.unitConversionFactor,
           di.variantId, di.inventoryIdentityKind,
           di.identitySnapshotStatus,
           soi.salesOrderId, soi.productId, soi.itemId, soi.itemType
        FROM sales_delivery_items di
        JOIN sales_order_items soi ON soi.id = di.salesOrderItemId
        WHERE di.id = ?
        ''',
        [deliveryItemId],
      );
      if (deliveryItemRows.isEmpty) throw Exception('بند التسليم غير موجود');
      final deliveredLine = deliveryItemRows.single;
      final identitySnapshotStatus =
          deliveredLine['identitySnapshotStatus'] as String? ?? 'UNVERIFIED';
      if (deliveredLine['salesDeliveryId'] != deliveryId ||
          deliveredLine['salesOrderId'] != value.salesOrderId ||
          (deliveredLine['productId'] ?? deliveredLine['itemId']) !=
              item.itemId ||
          deliveredLine['itemType'] != item.itemType ||
          deliveredLine['unitId'] != item.unitId ||
          deliveredLine['variantId'] != item.variantId ||
          deliveredLine['baseUnitId'] != (item.baseUnitId ?? item.unitId) ||
          deliveredLine['inventoryIdentityKind'] !=
              item.inventoryIdentityKind ||
          (item.identitySnapshotStatus != 'UNVERIFIED' &&
              item.identitySnapshotStatus != identitySnapshotStatus) ||
          (item.inventoryIdentityKind == 'VARIANT' &&
              identitySnapshotStatus != 'VERIFIED') ||
          ((deliveredLine['unitConversionFactor'] as num).toDouble() -
                      item.unitConversionFactor)
                  .abs() >
              0.000000001 ||
          ((item.baseQuantity ?? item.quantity * item.unitConversionFactor) -
                      item.quantity * item.unitConversionFactor)
                  .abs() >
              0.000001) {
        throw Exception('بند المرتجع لا يطابق بند التسليم');
      }
      if (item.inventoryIdentityKind == 'LEGACY_UNASSIGNED') {
        throw Exception('لا يمكن إنشاء مرتجع بهوية مخزون قديمة غير مخصصة');
      }
      if (identitySnapshotStatus != 'VERIFIED') {
        throw Exception('لقطة هوية بند التسليم غير مؤكدة');
      }
      final previousRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(sri.baseQuantity), 0) AS returnedQuantity
        FROM sales_return_items sri
        JOIN sales_returns sr ON sr.id = sri.salesReturnId
        WHERE sri.sourceDeliveryItemId = ?
          AND sr.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
          AND (? IS NULL OR sr.id != ?)
        ''',
        [deliveryItemId, excludeReturnId, excludeReturnId],
      );
      final previous = (previousRows.single['returnedQuantity'] as num)
          .toDouble();
      final current = requestedByDeliveryLine[deliveryItemId] ?? 0;
      final delivered = (deliveredLine['baseQuantity'] as num).toDouble();
      final baseQuantity =
          item.baseQuantity ?? item.quantity * item.unitConversionFactor;
      if (!baseQuantity.isFinite ||
          !item.unitConversionFactor.isFinite ||
          item.unitConversionFactor <= 0 ||
          previous + current + baseQuantity > delivered + 0.000001) {
        throw Exception('كمية المرتجع تتجاوز الكمية المسلمة المتبقية');
      }
      requestedByDeliveryLine[deliveryItemId] = current + baseQuantity;
      identityStatuses[item.id] = identitySnapshotStatus;
      await _ensureItemExists(txn, item.itemId, _stockItemType(item.itemType));
    }
    return identityStatuses;
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
          (item.baseQuantity ?? item.quantity * item.unitConversionFactor) *
          ((rows.single['unitCogs'] as num?) ?? 0).toDouble();
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

  Future<Map<String, _PurchaseReturnSourceLine>> _validatePurchaseReturn(
    DatabaseExecutor txn,
    PurchaseReturn value, {
    String? excludeReturnId,
  }) async {
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
    final returnedByReceiptLine = <String, double>{};
    final returnedWithoutReceiptByItem = <String, double>{};
    final receiptAssignmentsByItem = <String>{};
    final sourceLines = <String, _PurchaseReturnSourceLine>{};
    for (final item in value.items) {
      if (!item.quantity.isFinite || item.quantity <= 0) {
        throw Exception('كمية المرتجع غير صالحة');
      }
      final orderItems = await txn.query(
        'purchase_order_items',
        where:
            'purchaseOrderId = ? AND productId = ? AND itemType = ? AND unitId = ? AND variantId IS ?',
        whereArgs: [
          value.purchaseOrderId,
          item.itemId,
          item.itemType.toUpperCase(),
          item.unitId,
          item.variantId,
        ],
        limit: 1,
      );
      if (orderItems.isEmpty) {
        throw Exception('بند المرتجع لا يطابق أمر الشراء');
      }
      final persistedItem = orderItems.single;
      final orderItemId = persistedItem['id'] as String;
      final identitySnapshotStatus =
          persistedItem['identitySnapshotStatus'] as String? ?? 'UNVERIFIED';
      if (item.purchaseOrderItemId != null &&
          item.purchaseOrderItemId != orderItemId) {
        throw Exception('بند المرتجع لا يطابق بند أمر الشراء');
      }
      final factor = (persistedItem['unitConversionFactor'] as num).toDouble();
      final baseQuantity =
          item.baseQuantity ?? item.quantity * item.unitConversionFactor;
      final expectedBaseQuantity = item.quantity * factor;
      if ((persistedItem['baseUnitId'] as String? ?? persistedItem['unitId']) !=
              (item.baseUnitId ?? item.unitId) ||
          persistedItem['inventoryIdentityKind'] !=
              item.inventoryIdentityKind ||
          (factor - item.unitConversionFactor).abs() > 0.000000001 ||
          item.inventoryIdentityKind == 'LEGACY_UNASSIGNED' ||
          item.identitySnapshotStatus != 'UNVERIFIED' &&
              item.identitySnapshotStatus != identitySnapshotStatus ||
          identitySnapshotStatus != 'VERIFIED' ||
          item.inventoryIdentityKind == 'VARIANT' &&
              identitySnapshotStatus != 'VERIFIED' ||
          !factor.isFinite ||
          factor <= 0 ||
          !item.unitConversionFactor.isFinite ||
          item.unitConversionFactor <= 0 ||
          !baseQuantity.isFinite ||
          baseQuantity <= 0 ||
          !expectedBaseQuantity.isFinite ||
          (baseQuantity - expectedBaseQuantity).abs() > 0.000001) {
        throw Exception('لقطة هوية أو وحدة مرتجع الشراء غير متوافقة');
      }
      if (item.sourceReceiptId != null &&
          value.purchaseReceiptId != null &&
          item.sourceReceiptId != value.purchaseReceiptId) {
        throw Exception('إيصال مصدر بند المرتجع لا يطابق الإيصال المحدد');
      }
      final sourceReceiptId = item.sourceReceiptId ?? value.purchaseReceiptId;
      if (sourceReceiptId == null) {
        if (receiptAssignmentsByItem.contains(orderItemId)) {
          throw Exception(
            'لا يمكن الجمع بين بنود مرتبطة وغير مرتبطة بإيصال على بند أمر الشراء نفسه',
          );
        }
        returnedWithoutReceiptByItem[orderItemId] =
            (returnedWithoutReceiptByItem[orderItemId] ?? 0) + baseQuantity;
      } else {
        receiptAssignmentsByItem.add(orderItemId);
      }
      if (sourceReceiptId != null) {
        final receiptRows = await txn.query(
          'purchase_receipts',
          where: 'id = ? AND purchaseOrderId = ? AND warehouseId = ?',
          whereArgs: [
            sourceReceiptId,
            value.purchaseOrderId,
            value.warehouseId,
          ],
          limit: 1,
        );
        if (receiptRows.isEmpty) throw Exception('إيصال الشراء غير موجود');
        final receiptItems = await txn.query(
          'purchase_receipt_items',
          where: 'purchaseReceiptId = ? AND purchaseOrderItemId = ?',
          whereArgs: [sourceReceiptId, orderItemId],
          limit: 1,
        );
        if (receiptItems.isEmpty) {
          throw Exception('بند المرتجع غير موجود في إيصال الشراء');
        }
        final receiptBaseQuantity =
            (receiptItems.single['baseQuantity'] as num?)?.toDouble() ??
            (receiptItems.single['receivedQuantity'] as num).toDouble() *
                factor;
        final unresolvedReceiptRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(pri.baseQuantity), 0) quantity
          FROM purchase_return_items pri
          JOIN purchase_returns pr ON pr.id = pri.purchaseReturnId
          WHERE pr.purchaseOrderId = ?
            AND COALESCE(pri.sourceReceiptId, pr.purchaseReceiptId) IS NULL
            AND (pri.purchaseOrderItemId = ? OR (
              pri.purchaseOrderItemId IS NULL
              AND pri.productId = ?
              AND pri.itemType = ?
              AND pri.unitId = ?
              AND pri.variantId IS ?
              AND pri.inventoryIdentityKind = ?
            ))
            AND pr.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
            AND (? IS NULL OR pr.id != ?)
          ''',
          [
            value.purchaseOrderId,
            orderItemId,
            item.itemId,
            item.itemType.toUpperCase(),
            item.unitId,
            item.variantId,
            item.inventoryIdentityKind,
            excludeReturnId,
            excludeReturnId,
          ],
        );
        if ((unresolvedReceiptRows.single['quantity'] as num).toDouble() > 0) {
          throw Exception(
            'لا يمكن تحديد الإيصال لبنود مرتجع سابقة على بند أمر الشراء',
          );
        }
        final receiptReturnedRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(pri.baseQuantity), 0) quantity
          FROM purchase_return_items pri
          JOIN purchase_returns pr ON pr.id = pri.purchaseReturnId
          WHERE COALESCE(pri.sourceReceiptId, pr.purchaseReceiptId) = ?
            AND (pri.purchaseOrderItemId = ? OR (
              pri.purchaseOrderItemId IS NULL
              AND pri.productId = ?
              AND pri.itemType = ?
              AND pri.unitId = ?
              AND pri.variantId IS ?
              AND pri.inventoryIdentityKind = ?
            ))
            AND pr.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
            AND (? IS NULL OR pr.id != ?)
          ''',
          [
            sourceReceiptId,
            orderItemId,
            item.itemId,
            item.itemType.toUpperCase(),
            item.unitId,
            item.variantId,
            item.inventoryIdentityKind,
            excludeReturnId,
            excludeReturnId,
          ],
        );
        final alreadyReturnedFromReceipt =
            (receiptReturnedRows.single['quantity'] as num).toDouble();
        final receiptLineKey = '$sourceReceiptId:$orderItemId';
        final receiptRequested =
            (returnedByReceiptLine[receiptLineKey] ?? 0) +
            (returnedWithoutReceiptByItem[orderItemId] ?? 0) +
            baseQuantity;
        if (!receiptBaseQuantity.isFinite ||
            alreadyReturnedFromReceipt + receiptRequested >
                receiptBaseQuantity + 0.000001) {
          throw Exception('كمية المرتجع تتجاوز الكمية المستلمة في الإيصال');
        }
        returnedByReceiptLine[receiptLineKey] =
            (returnedByReceiptLine[receiptLineKey] ?? 0) + baseQuantity;
      }
      final returnedBeforeRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(pri.baseQuantity), 0) quantity
        FROM purchase_return_items pri
        JOIN purchase_returns pr ON pr.id = pri.purchaseReturnId
        WHERE pr.purchaseOrderId = ?
          AND (pri.purchaseOrderItemId = ? OR (
            pri.purchaseOrderItemId IS NULL AND pri.productId = ?
          ))
          AND pri.itemType = ? AND pri.unitId = ? AND pri.variantId IS ?
          AND pri.inventoryIdentityKind = ?
          AND pr.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
          AND (? IS NULL OR pr.id != ?)
        ''',
        [
          value.purchaseOrderId,
          orderItemId,
          item.itemId,
          item.itemType,
          item.unitId,
          item.variantId,
          item.inventoryIdentityKind,
          excludeReturnId,
          excludeReturnId,
        ],
      );
      final received = (persistedItem['receivedBaseQuantity'] as num)
          .toDouble();
      final returnedBefore = (returnedBeforeRows.single['quantity'] as num)
          .toDouble();
      final requested = (returnedByItem[orderItemId] ?? 0) + baseQuantity;
      if (returnedBefore + requested > received) {
        throw Exception('كمية المرتجع تتجاوز الكمية المستلمة المتبقية');
      }
      returnedByItem[orderItemId] = requested;
      sourceLines[item.id] = _PurchaseReturnSourceLine(
        purchaseOrderItemId: orderItemId,
        identitySnapshotStatus: identitySnapshotStatus,
      );
      await _ensureItemExists(txn, item.itemId, _stockItemType(item.itemType));
    }
    return sourceLines;
  }

  Future<void> _postPurchaseReturnWithinTransaction(
    DatabaseExecutor txn,
    PurchaseReturn value,
  ) async {
    var payableReversal = 0.0;
    var inventoryReversal = 0.0;
    for (final item in value.items) {
      if (item.qualityStatus != ReturnQualityStatus.approved) continue;
      final unitPrice = await _purchaseUnitPrice(txn, value, item);
      final itemKey = inventoryItemKey(
        productId: item.itemId,
        type: _stockItemType(item.itemType),
        variantId: item.variantId,
        identityKind: InventoryIdentityKindValue.parse(
          item.inventoryIdentityKind,
        ),
      );
      final baseQuantity =
          item.baseQuantity ?? item.quantity * item.unitConversionFactor;
      final valuation = await _accounting.valuationWithinTransaction(
        txn,
        value.warehouseId,
        itemKey,
        _stockItemType(item.itemType).value,
      );
      if (valuation == null ||
          valuation.quantity < baseQuantity ||
          valuation.averageCost <= 0) {
        throw Exception('تقييم المخزون غير متاح أو غير كاف للمرتجع');
      }
      payableReversal += item.quantity * unitPrice;
      inventoryReversal += baseQuantity * valuation.averageCost;
      await _applyPurchaseReturnItem(
        txn,
        warehouseId: value.warehouseId,
        itemId: item.itemId,
        itemType: _stockItemType(item.itemType),
        quantity: baseQuantity,
        qualityStatus: item.qualityStatus,
        variantId: item.variantId,
        baseUnitId: item.baseUnitId ?? item.unitId,
        identityKind: InventoryIdentityKindValue.parse(
          item.inventoryIdentityKind,
        ),
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

  Future<double> _purchaseUnitPrice(
    DatabaseExecutor txn,
    PurchaseReturn value,
    PurchaseReturnItem item,
  ) async {
    final rows = await txn.query(
      'purchase_order_items',
      columns: ['unitPrice'],
      where:
          'purchaseOrderId = ? AND productId = ? AND itemType = ? AND unitId = ? AND variantId IS ?',
      whereArgs: [
        value.purchaseOrderId,
        item.itemId,
        item.itemType.toUpperCase(),
        item.unitId,
        item.variantId,
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

  Future<List<QualityInspectionItem>> _validateQualityInspection(
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
    if ([
      'DRAFT',
      'REJECTED',
      'CANCELLED',
    ].contains(sourceRows.single['status'])) {
      throw Exception('حالة مصدر الفحص لا تسمح بالفحص');
    }
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
    final itemTable = sourceType == 'SALES_RETURN'
        ? 'sales_return_items'
        : 'purchase_return_items';
    final parentColumn = sourceType == 'SALES_RETURN'
        ? 'salesReturnId'
        : 'purchaseReturnId';
    final sourceItems = await txn.query(
      itemTable,
      where: '$parentColumn = ?',
      whereArgs: [value.sourceId],
    );
    final requestedBySourceLine = <String, double>{};
    final validatedItems = <QualityInspectionItem>[];
    for (final item in value.items) {
      if (!item.requestedQuantity.isFinite ||
          item.requestedQuantity <= 0 ||
          !item.inspectedQuantity.isFinite ||
          item.inspectedQuantity <= 0 ||
          item.inspectedQuantity > item.requestedQuantity ||
          !item.acceptedQuantity.isFinite ||
          item.acceptedQuantity < 0 ||
          !item.rejectedQuantity.isFinite ||
          item.rejectedQuantity < 0 ||
          (item.acceptedQuantity +
                      item.rejectedQuantity -
                      item.inspectedQuantity)
                  .abs() >
              0.000001) {
        throw Exception('كميات الفحص غير متوافقة');
      }
      if (item.sourceReturnItemId == null ||
          item.sourceReturnItemId!.trim().isEmpty) {
        throw Exception('يجب تحديد بند المرتجع المرتبط بالفحص');
      }
      final candidates = sourceItems.where((row) {
        final productId =
            row['productId'] as String? ?? row['itemId'] as String;
        return row['itemType'] == item.itemType.toUpperCase() &&
            productId == (item.productId ?? item.itemId) &&
            row['variantId'] == item.variantId &&
            row['id'] == item.sourceReturnItemId;
      }).toList();
      if (candidates.length != 1) {
        throw Exception('يجب تحديد بند المرتجع المطابق بدقة');
      }
      final sourceItem = candidates.single;
      final sourceItemId = sourceItem['id'] as String;
      final productId =
          sourceItem['productId'] as String? ?? sourceItem['itemId'] as String;
      final variantId = sourceItem['variantId'] as String?;
      final baseUnitId =
          sourceItem['baseUnitId'] as String? ?? sourceItem['unitId'] as String;
      final unitId = sourceItem['unitId'] as String;
      final factor =
          (sourceItem['unitConversionFactor'] as num?)?.toDouble() ?? 1;
      final identityKind =
          sourceItem['inventoryIdentityKind'] as String? ?? 'BASE';
      final identitySnapshotStatus =
          sourceItem['identitySnapshotStatus'] as String? ?? 'UNVERIFIED';
      final sourceQuantity = (sourceItem['quantity'] as num).toDouble();
      final sourceBaseQuantity =
          (sourceItem['baseQuantity'] as num?)?.toDouble() ??
          sourceQuantity * factor;
      if (item.productId != null && item.productId != productId ||
          item.variantId != null && item.variantId != variantId ||
          item.unitId != null && item.unitId != unitId ||
          item.baseUnitId != null && item.baseUnitId != baseUnitId ||
          item.unitConversionFactor != null &&
              (item.unitConversionFactor! - factor).abs() > 0.000000001 ||
          item.inventoryIdentityKind != null &&
              item.inventoryIdentityKind != identityKind ||
          item.identitySnapshotStatus != null &&
              item.identitySnapshotStatus != identitySnapshotStatus) {
        throw Exception('لقطة هوية أو وحدة الفحص لا تطابق بند المرتجع');
      }
      if (identityKind == 'LEGACY_UNASSIGNED' ||
          identitySnapshotStatus != 'VERIFIED' ||
          !factor.isFinite ||
          factor <= 0 ||
          !sourceQuantity.isFinite ||
          sourceQuantity <= 0 ||
          !sourceBaseQuantity.isFinite ||
          (sourceBaseQuantity - sourceQuantity * factor).abs() > 0.000001) {
        throw Exception('هوية أو كمية مصدر الفحص غير صالحة');
      }
      if (item.requestedQuantity >
          sourceQuantity -
              (requestedBySourceLine[sourceItemId] ?? 0) +
              0.000001) {
        throw Exception('كمية الفحص لا تطابق بند المرتجع');
      }
      final requestedBaseQuantity = item.requestedQuantity * factor;
      final inspectedBaseQuantity = item.inspectedQuantity * factor;
      final acceptedBaseQuantity = item.acceptedQuantity * factor;
      final effectiveRejectedQuantity = item.rejectedQuantity;
      final rejectedBaseQuantity = effectiveRejectedQuantity * factor;
      for (final quantity in [
        requestedBaseQuantity,
        inspectedBaseQuantity,
        acceptedBaseQuantity,
        rejectedBaseQuantity,
      ]) {
        if (!quantity.isFinite) {
          throw Exception('كمية الفحص الأساسية غير صالحة');
        }
      }
      if (_stockItemType(item.itemType) == StockItemType.product) {
        final variants = await txn.query(
          'product_variants',
          columns: ['id'],
          where: 'productId = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (variantId == null && variants.isNotEmpty) {
          throw Exception('لا يمكن فحص منتج متغير دون تحديد المتغير');
        }
        if (variantId != null &&
            (identityKind != 'VARIANT' ||
                identitySnapshotStatus != 'VERIFIED' ||
                (await txn.query(
                  'product_variants',
                  columns: ['id'],
                  where: 'id = ? AND productId = ? AND active = 1',
                  whereArgs: [variantId, productId],
                  limit: 1,
                )).isEmpty)) {
          throw Exception('هوية المتغير غير مؤكدة لمصدر الفحص');
        }
        if (variantId == null && identityKind != 'BASE') {
          throw Exception('هوية المنتج غير صالحة لمصدر الفحص');
        }
      } else if (variantId != null || identityKind != 'BASE') {
        throw Exception('هوية الخامة غير صالحة لمصدر الفحص');
      }
      if (item.requestedBaseQuantity != null &&
              (item.requestedBaseQuantity! - requestedBaseQuantity).abs() >
                  0.000001 ||
          item.inspectedBaseQuantity != null &&
              (item.inspectedBaseQuantity! - inspectedBaseQuantity).abs() >
                  0.000001 ||
          item.acceptedBaseQuantity != null &&
              (item.acceptedBaseQuantity! - acceptedBaseQuantity).abs() >
                  0.000001 ||
          item.rejectedBaseQuantity != null &&
              (item.rejectedBaseQuantity! - rejectedBaseQuantity).abs() >
                  0.000001) {
        throw Exception('كمية الفحص الأساسية لا تطابق لقطة التحويل');
      }
      requestedBySourceLine[sourceItemId] =
          (requestedBySourceLine[sourceItemId] ?? 0) + item.requestedQuantity;
      await _ensureItemExists(txn, productId, _stockItemType(item.itemType));
      validatedItems.add(
        QualityInspectionItem(
          id: item.id,
          itemId: productId,
          itemType: item.itemType,
          requestedQuantity: item.requestedQuantity,
          inspectedQuantity: item.inspectedQuantity,
          acceptedQuantity: item.acceptedQuantity,
          rejectedQuantity: item.rejectedQuantity,
          sourceReturnItemId: sourceItemId,
          productId: productId,
          variantId: variantId,
          inventoryIdentityKind: identityKind,
          identitySnapshotStatus: identitySnapshotStatus,
          unitId: unitId,
          baseUnitId: baseUnitId,
          unitConversionFactor: factor,
          requestedBaseQuantity: requestedBaseQuantity,
          inspectedBaseQuantity: inspectedBaseQuantity,
          acceptedBaseQuantity: acceptedBaseQuantity,
          rejectedBaseQuantity: rejectedBaseQuantity,
          result: item.result,
          notes: item.notes,
        ),
      );
    }
    return validatedItems;
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
    String? variantId,
    String? baseUnitId,
    InventoryIdentityKind identityKind = InventoryIdentityKind.base,
    String? sourceDeliveryItemId,
  }) async {
    if (quantity <= 0) return;
    final detail = await _itemOption(
      txn,
      itemId,
      itemType,
      variantId: variantId,
      baseUnitId: baseUnitId,
      identityKind: identityKind,
    );
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
          itemId: detail.inventoryId,
          itemType: itemType.value,
          quantity: quantity,
          unitCost: unitCost,
          productId: detail.baseProductId,
          variantId: detail.variantId,
          identityKind: detail.identityKind,
          unitId: detail.unitId,
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
    } else if (qualityStatus == ReturnQualityStatus.rejected ||
        qualityStatus == ReturnQualityStatus.quarantined) {
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
    String? variantId,
    String? baseUnitId,
    InventoryIdentityKind identityKind = InventoryIdentityKind.base,
  }) async {
    if (quantity <= 0 || qualityStatus != ReturnQualityStatus.approved) return;
    final detail = await _itemOption(
      txn,
      itemId,
      itemType,
      variantId: variantId,
      baseUnitId: baseUnitId,
      identityKind: identityKind,
    );
    await _accounting.consumeInventoryValueWithinTransaction(
      executor: txn,
      warehouseId: warehouseId,
      itemId: detail.inventoryId,
      itemType: itemType.value,
      quantity: quantity,
      productId: detail.baseProductId,
      variantId: detail.variantId,
      identityKind: detail.identityKind,
      unitId: detail.unitId,
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
    StockItemType itemType, {
    String? variantId,
    String? baseUnitId,
    InventoryIdentityKind identityKind = InventoryIdentityKind.base,
  }) async {
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
      productId: itemType == StockItemType.product ? itemId : null,
      variantId: variantId,
      name: row['name'] as String,
      code: row['code'] as String,
      unitId: baseUnitId ?? row['unitId'] as String,
      type: itemType,
      active: (row['active'] as int?) == 1,
      identityKind: identityKind,
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

class _PurchaseReturnSourceLine {
  const _PurchaseReturnSourceLine({
    required this.purchaseOrderItemId,
    required this.identitySnapshotStatus,
  });

  final String purchaseOrderItemId;
  final String identitySnapshotStatus;
}

class ReturnsQualityDataSource extends ReturnsQualityLocalDataSource {}

class ReturnsAndQualityLocalDataSource extends ReturnsQualityLocalDataSource {}
