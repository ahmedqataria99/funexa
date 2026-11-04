import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/purchasing_receiving_contract.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class PurchasingLocalDataSource {
  PurchasingLocalDataSource([
    WarehousesStockLocalDataSource? stock,
    PurchasingReceiptAccountingSink? accounting,
  ]) : _database = null,
       _stock = stock ?? WarehousesStockLocalDataSource(),
       _accounting = accounting ?? AccountingLocalDataSource();

  PurchasingLocalDataSource.withDatabase(Database database)
    : _database = database,
      _stock = WarehousesStockLocalDataSource(),
      _accounting = AccountingLocalDataSource();
  final Database? _database;
  final WarehousesStockLocalDataSource _stock;
  final PurchasingReceiptAccountingSink _accounting;
  final SecurityLocalDataSource _security = SecurityLocalDataSource();
  Future<Database> get _db async =>
      _database ?? await FurnexaDatabase.instance.database;

  Future<List<Supplier>> suppliers([String query = '']) async {
    final db = await _db;
    final q = query.trim().toLowerCase();
    final rows = await db.query(
      'suppliers',
      where: q.isEmpty ? null : 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    return rows.map(Supplier.fromMap).toList();
  }

  Future<Supplier?> supplierById(String id) async {
    final rows = await (await _db).query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Supplier.fromMap(rows.first);
  }

  Future<void> saveSupplier(Supplier value) async {
    _security.require('PURCHASING_VIEW');
    final existing = await (await _db).query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [value.id],
      limit: 1,
    );
    await _save('suppliers', value.id, value.toMap());
    await _auditSafely(
      action: existing.isEmpty ? 'CREATE' : 'UPDATE',
      entityType: 'Supplier',
      entityId: value.id,
      description: existing.isEmpty ? 'Supplier created' : 'Supplier updated',
    );
  }

  Future<void> setSupplierActive(String id, bool active) async {
    _security.require('PURCHASING_VIEW');
    final count = await (await _db).update(
      'suppliers',
      {
        'active': active ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) throw Exception('المورد غير موجود');
    await _auditSafely(
      action: active ? 'ACTIVATE' : 'DEACTIVATE',
      entityType: 'Supplier',
      entityId: id,
      description: 'Supplier status changed',
    );
  }

  Future<List<PurchaseRequest>> requests([String query = '']) async {
    final db = await _db;
    final rows = await db.query(
      'purchase_requests',
      where: query.trim().isEmpty ? null : 'LOWER(requestNumber) LIKE ?',
      whereArgs: query.trim().isEmpty
          ? null
          : ['%${query.trim().toLowerCase()}%'],
      orderBy: 'requestDate DESC',
    );
    final requests = await Future.wait(rows.map(_requestFromRow));
    await FurnexaDatabaseDiagnostics.capture(
      source: 'purchasing.requestsStages',
      purchaseRequestQuery: query,
      stageCounts: {
        'sqliteRowsAfterRequestNumberSearch': rows.length,
        'mappedAndHydratedEntities': requests.length,
        'scopeFilteredRows': null,
        'statusFilteredRows': null,
        'relatedSupplierFilteredRows': null,
        'factoryFilteredRows': null,
        'finalDataSourceRows': requests.length,
      },
    );
    return requests;
  }

  Future<PurchaseRequest> saveRequest(PurchaseRequest request) async {
    _security.require('PURCHASING_VIEW');
    final db = await _db;
    PurchaseRequestStatus? previousStatus;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'purchase_requests',
        where: 'id = ?',
        whereArgs: [request.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        previousStatus = _requestStatus(existing.first['status'] as String);
        if (!_validRequestTransition(previousStatus!, request.status)) {
          throw Exception('انتقال حالة الطلب غير مسموح');
        }
      }
      if (request.supplierId.trim().isEmpty) {
        throw Exception('يجب اختيار المورد قبل حفظ الطلب');
      }
      await _validateSupplier(txn, request.supplierId);
      await _validateRequestItems(txn, request.items);
      await _saveExecutor(
        txn,
        'purchase_requests',
        request.id,
        _requestMap(request),
      );
      await txn.delete(
        'purchase_request_items',
        where: 'purchaseRequestId = ?',
        whereArgs: [request.id],
      );
      for (final item in request.items) {
        await txn.insert(
          'purchase_request_items',
          _requestItemMap(request.id, item),
        );
      }
    });
    await _auditSafely(
      action: previousStatus == null ? 'CREATE' : 'UPDATE',
      entityType: 'PurchaseRequest',
      entityId: request.id,
      description: previousStatus == null
          ? 'Purchase request created'
          : 'Purchase request updated',
    );
    if (previousStatus != null && previousStatus != request.status) {
      await _auditSafely(
        action: 'STATUS_CHANGE',
        entityType: 'PurchaseRequest',
        entityId: request.id,
        description: 'Purchase request status changed',
      );
    }
    await FurnexaDatabaseDiagnostics.capture(
      source: 'purchaseRequest.create',
      entityType: 'purchaseRequest',
      entityId: request.id,
    );
    return request;
  }

  Future<void> changeRequestStatus(
    String id,
    PurchaseRequestStatus status,
  ) async {
    if (status == PurchaseRequestStatus.approved) {
      await approveRequest(id);
      return;
    }
    _security.require('PURCHASING_VIEW');
    final db = await _db;
    final row = await db.query(
      'purchase_requests',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (row.isEmpty) throw Exception('الطلب غير موجود');
    final current = _requestStatus(row.first['status'] as String);
    if (!_validRequestTransition(current, status)) {
      throw Exception('انتقال حالة الطلب غير مسموح');
    }
    await db.update(
      'purchase_requests',
      {
        'status': status.name.toUpperCase(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _auditSafely(
      action: 'STATUS_CHANGE',
      entityType: 'PurchaseRequest',
      entityId: id,
      description: 'Purchase request status changed',
    );
  }

  Future<PurchaseOrder> approveRequest(String requestId) async {
    _security.require('PURCHASING_VIEW');
    final db = await _db;
    String? orderId;
    var created = false;
    await db.transaction((txn) async {
      final requestRows = await txn.query(
        'purchase_requests',
        where: 'id = ?',
        whereArgs: [requestId],
        limit: 1,
      );
      if (requestRows.isEmpty) throw Exception('الطلب غير موجود');
      final requestRow = requestRows.single;
      final currentStatus = _requestStatus(requestRow['status'] as String);

      final linkedOrders = await txn.query(
        'purchase_orders',
        columns: ['id'],
        where: 'purchaseRequestId = ?',
        whereArgs: [requestId],
        limit: 1,
      );
      if (linkedOrders.isNotEmpty) {
        orderId = linkedOrders.single['id'] as String;
        if (currentStatus != PurchaseRequestStatus.converted) {
          await txn.update(
            'purchase_requests',
            {
              'status': 'CONVERTED',
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [requestId],
          );
        }
        return;
      }

      if (currentStatus != PurchaseRequestStatus.pending &&
          currentStatus != PurchaseRequestStatus.approved) {
        throw Exception('يجب إرسال الطلب قبل اعتماده');
      }
      final supplierId = requestRow['supplierId'] as String? ?? '';
      if (supplierId.trim().isEmpty) {
        throw Exception('يجب تحديد مورد صالح للطلب');
      }
      await _validateSupplier(txn, supplierId);

      final requestItemRows = await txn.query(
        'purchase_request_items',
        where: 'purchaseRequestId = ?',
        whereArgs: [requestId],
        orderBy: 'rowid ASC',
      );
      final requestItems = requestItemRows
          .map(
            (row) => PurchasingItem(
              id: row['id'] as String,
              itemId: row['productId'] as String? ?? row['itemId'] as String,
              itemType: row['itemType'] == 'PRODUCT'
                  ? PurchasingItemType.product
                  : PurchasingItemType.rawMaterial,
              quantity: (row['quantity'] as num).toDouble(),
              unitId: row['unitId'] as String,
              variantId: row['variantId'] as String?,
              baseUnitId: row['baseUnitId'] as String?,
              unitConversionFactor:
                  (row['unitConversionFactor'] as num?)?.toDouble() ?? 1,
              baseQuantity: (row['baseQuantity'] as num?)?.toDouble(),
              inventoryIdentityKind:
                  row['inventoryIdentityKind'] as String? ?? 'BASE',
              identitySnapshotStatus:
                  row['identitySnapshotStatus'] as String? ?? 'UNVERIFIED',
              notes: row['notes'] as String?,
            ),
          )
          .toList();
      await _validateOrderItems(txn, requestItems);

      final now = DateTime.now();
      orderId = 'order-$requestId';
      final order = PurchaseOrder(
        id: orderId!,
        orderNumber: 'PO-${requestRow['requestNumber']}',
        supplierId: supplierId,
        purchaseRequestId: requestId,
        orderDate: now,
        status: PurchaseOrderStatus.draft,
        subtotal: 0,
        discount: 0,
        tax: 0,
        grandTotal: 0,
        notes: requestRow['notes'] as String?,
        createdAt: now,
        updatedAt: now,
        items: [
          for (var index = 0; index < requestItems.length; index++)
            PurchasingItem(
              id: purchasingDocumentItemId(orderId!, index),
              itemId: requestItems[index].itemId,
              itemType: requestItems[index].itemType,
              quantity: requestItems[index].quantity,
              unitId: requestItems[index].unitId,
              variantId: requestItems[index].variantId,
              baseUnitId: requestItems[index].baseUnitId,
              unitConversionFactor: requestItems[index].unitConversionFactor,
              baseQuantity: requestItems[index].baseQuantity,
              inventoryIdentityKind: requestItems[index].inventoryIdentityKind,
              identitySnapshotStatus:
                  requestItems[index].identitySnapshotStatus,
              unitPrice: requestItems[index].unitPrice,
              discount: requestItems[index].discount,
              tax: requestItems[index].tax,
              lineTotal: requestItems[index].lineTotal,
              notes: requestItems[index].notes,
            ),
        ],
      );
      await _saveExecutor(txn, 'purchase_orders', order.id, _orderMap(order));
      for (final item in order.items) {
        await txn.insert('purchase_order_items', _orderItemMap(order.id, item));
      }
      await txn.update(
        'purchase_requests',
        {'status': 'CONVERTED', 'updatedAt': now.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [requestId],
      );
      created = true;
    });

    if (orderId == null) throw StateError('تعذر إنشاء أمر الشراء');
    if (created) {
      await _auditSafely(
        action: 'CONVERSION',
        entityType: 'PurchaseOrder',
        entityId: orderId!,
        description: 'Purchase request approved and purchase order created',
      );
    }
    final orderRows = await db.query(
      'purchase_orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (orderRows.isEmpty) throw Exception('أمر الشراء المرتبط غير موجود');
    return _orderFromRow(orderRows.single);
  }

  Future<List<PurchaseOrder>> orders([String query = '']) async {
    final db = await _db;
    final rows = await db.query(
      'purchase_orders',
      where: query.trim().isEmpty ? null : 'LOWER(orderNumber) LIKE ?',
      whereArgs: query.trim().isEmpty
          ? null
          : ['%${query.trim().toLowerCase()}%'],
      orderBy: 'orderDate DESC',
    );
    return Future.wait(rows.map(_orderFromRow));
  }

  Future<PurchaseOrder> saveOrder(PurchaseOrder order) async {
    _security.require('PURCHASING_VIEW');
    final db = await _db;
    final existing = await db.query(
      'purchase_orders',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [order.id],
      limit: 1,
    );
    final normalized = _recalculateOrderFinancials(order);
    _validateOrderFinancialValues(normalized);
    await db.transaction((txn) async {
      await _validateOrderEdit(txn, normalized);
      await _validateSupplier(txn, normalized.supplierId);
      await _validateOrderItems(txn, normalized.items);
      _validateOrderPriceRequirements(normalized.items, normalized.status);
      await _saveExecutor(
        txn,
        'purchase_orders',
        normalized.id,
        _orderMap(normalized),
      );
      await txn.delete(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [normalized.id],
      );
      for (final item in normalized.items) {
        await txn.insert(
          'purchase_order_items',
          _orderItemMap(normalized.id, item),
        );
      }
    });
    await _auditSafely(
      action: existing.isEmpty ? 'CREATE' : 'UPDATE',
      entityType: 'PurchaseOrder',
      entityId: normalized.id,
      description: 'Purchase order saved',
    );
    return normalized;
  }

  Future<PurchaseOrder> convertRequestToOrder(
    PurchaseRequest request,
    PurchaseOrder order,
  ) async {
    if (order.purchaseRequestId != request.id) {
      throw Exception('ارتباط طلب الشراء غير صالح');
    }
    final requestRows = await (await _db).query(
      'purchase_requests',
      columns: ['supplierId'],
      where: 'id = ?',
      whereArgs: [request.id],
      limit: 1,
    );
    if (requestRows.isEmpty ||
        requestRows.single['supplierId'] != order.supplierId) {
      throw Exception('يجب أن يرث أمر الشراء مورد الطلب نفسه');
    }
    return approveRequest(request.id);
  }

  Future<void> changeOrderStatus(String id, PurchaseOrderStatus status) async {
    _security.require('PURCHASING_VIEW');
    final db = await _db;
    final rows = await db.query(
      'purchase_orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('أمر الشراء غير موجود');
    final current = _orderStatus(rows.first['status'] as String);
    if (!_validOrderTransition(current, status)) {
      throw Exception('انتقال حالة أمر الشراء غير مسموح');
    }
    final order = await _orderFromRow(rows.first);
    final normalized = _recalculateOrderFinancials(
      order.copyWith(status: status, updatedAt: DateTime.now()),
    );
    _validateOrderFinancialValues(normalized);
    if (status == PurchaseOrderStatus.approved) {
      _validateOrderPriceRequirements(normalized.items, normalized.status);
    }
    await db.update(
      'purchase_orders',
      {
        'status': _databaseOrderStatus(status),
        'subtotal': normalized.subtotal,
        'discount': normalized.discount,
        'tax': normalized.tax,
        'grandTotal': normalized.grandTotal,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    for (final item in normalized.items) {
      await db.update(
        'purchase_order_items',
        {
          'unitPrice': item.unitPrice,
          'discount': item.discount,
          'tax': item.tax,
          'lineTotal': item.lineTotal,
        },
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
    await _auditSafely(
      action: 'STATUS_CHANGE',
      entityType: 'PurchaseOrder',
      entityId: id,
      description: 'Purchase order status changed',
    );
  }

  Future<List<PurchaseReceipt>> receipts(String orderId) async {
    final rows = await (await _db).query(
      'purchase_receipts',
      where: 'purchaseOrderId = ?',
      whereArgs: [orderId],
      orderBy: 'receiptDate DESC',
    );
    return rows
        .map(
          (m) => PurchaseReceipt(
            id: m['id'] as String,
            receiptNumber: m['receiptNumber'] as String,
            purchaseOrderId: m['purchaseOrderId'] as String,
            warehouseId: m['warehouseId'] as String,
            receiptDate: _date(m['receiptDate']),
            notes: m['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<void> postReceipt({
    required PurchaseOrder order,
    required String warehouseId,
    required DateTime receiptDate,
    required List<PurchasingItem> items,
    required String operationId,
    String? notes,
  }) async {
    _security.require('PURCHASING_RECEIVE');
    await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل');
    final db = await _db;
    String? postedReceiptId;
    await db.transaction((txn) async {
      await _validateWarehouse(txn, warehouseId);
      final stateRows = await txn.query(
        'purchase_orders',
        columns: ['status', 'supplierId', 'purchaseRequestId', 'orderNumber'],
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (stateRows.isEmpty) throw Exception('أمر الشراء غير موجود');
      final persistedStatus = _orderStatus(stateRows.first['status'] as String);
      if (persistedStatus == PurchaseOrderStatus.cancelled ||
          persistedStatus == PurchaseOrderStatus.draft ||
          persistedStatus == PurchaseOrderStatus.fullyReceived) {
        throw Exception('لا يمكن استلام أمر الشراء');
      }
      final supplierId = stateRows.first['supplierId'] as String;
      final purchaseRequestId = stateRows.first['purchaseRequestId'] as String?;
      final purchaseOrderNumber = stateRows.first['orderNumber'] as String;
      final orderRows = await txn.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [order.id],
      );
      final orderById = {for (final row in orderRows) row['id'] as String: row};
      final receiptId = _id('receipt');
      postedReceiptId = receiptId;
      if (operationId.trim().isEmpty) {
        throw Exception('معرف العملية غير صالح');
      }
      final receiptNumber = 'GR-OP-${operationId.trim()}';
      final duplicateReceipt = await txn.query(
        'purchase_receipts',
        columns: ['id'],
        where: 'receiptNumber = ?',
        whereArgs: [receiptNumber],
        limit: 1,
      );
      if (duplicateReceipt.isNotEmpty) {
        throw Exception('تم تسجيل العملية من قبل');
      }
      await txn.insert('purchase_receipts', {
        'id': receiptId,
        'receiptNumber': receiptNumber,
        'purchaseOrderId': order.id,
        'warehouseId': warehouseId,
        'receiptDate': receiptDate.millisecondsSinceEpoch,
        'notes': notes,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      var receivedAny = false;
      final accountingLines = <PurchaseReceiptAccountingLine>[];
      for (final receiptItem in items) {
        final row = orderById[receiptItem.id];
        if (row == null) throw Exception('صنف الاستلام غير موجود في الأمر');
        if ((row['productId'] as String? ?? row['itemId']) !=
                receiptItem.itemId ||
            row['itemType'] != receiptItem.itemType.value ||
            row['unitId'] != receiptItem.unitId ||
            row['variantId'] != receiptItem.variantId ||
            row['unitConversionFactor'] != receiptItem.unitConversionFactor) {
          throw Exception('بيانات صنف الاستلام غير متوافقة');
        }
        final ordered = (row['quantity'] as num).toDouble();
        final received = (row['receivedQuantity'] as num).toDouble();
        if (receiptItem.quantity <= 0 ||
            receiptItem.quantity > ordered - received) {
          throw Exception('الكمية المستلمة تتجاوز الكمية المتبقية');
        }
        final approvedUnitPrice = (row['unitPrice'] as num).toDouble();
        if (!approvedUnitPrice.isFinite || approvedUnitPrice <= 0) {
          throw Exception('لا يمكن استلام بند دون سعر شراء معتمد صالح');
        }
        final itemType = row['itemType'] == 'PRODUCT'
            ? StockItemType.product
            : StockItemType.rawMaterial;
        final factor = (row['unitConversionFactor'] as num).toDouble();
        final baseQuantity = receiptItem.quantity * factor;
        if (!factor.isFinite || factor <= 0 || !baseQuantity.isFinite) {
          throw Exception('لقطة تحويل وحدة الاستلام غير صالحة');
        }
        final item = await _resolveItem(
          txn,
          row['productId'] as String? ?? row['itemId'] as String,
          itemType,
          variantId: row['variantId'] as String?,
          baseUnitId: row['baseUnitId'] as String? ?? row['unitId'] as String,
          identityKind: row['inventoryIdentityKind'] as String? ?? 'BASE',
        );
        await _stock.applyStockInWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          item: item,
          quantity: baseQuantity,
          date: receiptDate,
          reference: receiptNumber,
          notes: notes,
        );
        await _accounting.receiveInventoryValueWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          itemId: item.inventoryId,
          itemType: itemType == StockItemType.product
              ? 'PRODUCT'
              : 'RAW_MATERIAL',
          quantity: baseQuantity,
          unitCost: approvedUnitPrice / factor,
          productId: item.baseProductId,
          variantId: item.variantId,
          identityKind: item.identityKind,
          unitId: item.unitId,
        );
        accountingLines.add(
          PurchaseReceiptAccountingLine(
            purchaseOrderItemId: row['id'] as String,
            itemId: row['itemId'] as String,
            itemType: row['itemType'] as String,
            quantity: baseQuantity,
            approvedUnitPrice: approvedUnitPrice / factor,
          ),
        );
        await txn.insert('purchase_receipt_items', {
          'id': _id('receipt-item'),
          'purchaseReceiptId': receiptId,
          'purchaseOrderItemId': receiptItem.id,
          'receivedQuantity': receiptItem.quantity,
          'unitId': row['unitId'],
          'productId': item.baseProductId,
          'variantId': item.variantId,
          'baseUnitId': item.unitId,
          'unitConversionFactor': factor,
          'baseQuantity': baseQuantity,
          'inventoryIdentityKind': item.identityKind.value,
          'identitySnapshotStatus': row['identitySnapshotStatus'],
          'notes': receiptItem.notes,
        });
        await txn.update(
          'purchase_order_items',
          {
            'receivedQuantity': received + receiptItem.quantity,
            'receivedBaseQuantity':
                (row['receivedBaseQuantity'] as num).toDouble() + baseQuantity,
          },
          where: 'id = ?',
          whereArgs: [receiptItem.id],
        );
        receivedAny = true;
      }
      if (!receivedAny) throw Exception('لم يتم استلام أي صنف');
      await _accounting.postPurchaseReceiptWithinTransaction(
        executor: txn,
        purchaseOrderId: order.id,
        purchaseOrderNumber: purchaseOrderNumber,
        purchaseRequestId: purchaseRequestId,
        receiptId: receiptId,
        receiptNumber: receiptNumber,
        supplierId: supplierId,
        date: receiptDate,
        lines: accountingLines,
      );
      final totals = await txn.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [order.id],
      );
      final complete = totals.every(
        (row) =>
            (row['receivedQuantity'] as num).toDouble() >=
            (row['quantity'] as num).toDouble(),
      );
      await txn.update(
        'purchase_orders',
        {
          'status': complete ? 'FULLY_RECEIVED' : 'PARTIALLY_RECEIVED',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );
    });
    await _auditSafely(
      action: 'POST',
      entityType: 'PurchaseReceipt',
      entityId: postedReceiptId ?? order.id,
      description: 'Purchase receipt posted',
    );
  }

  Future<List<Warehouse>> activeWarehouses() async => (await (await _db).query(
    'warehouses',
    where: 'state = ?',
    whereArgs: ['active'],
    orderBy: 'name ASC',
  )).map(Warehouse.fromMap).toList();
  Future<List<StockItemOption>> activeItems() => _stock.activeItems();

  Future<Map<String, String>> unitNames() async {
    final rows = await (await _db).query('units');
    return {
      for (final row in rows)
        row['id'] as String:
            (row['abbreviation'] as String?)?.trim().isNotEmpty == true
            ? row['abbreviation'] as String
            : row['name'] as String,
    };
  }

  Future<PurchaseRequest> _requestFromRow(Map<String, Object?> row) async {
    final items = await _items(
      'purchase_request_items',
      'purchaseRequestId',
      row['id'] as String,
    );
    return PurchaseRequest(
      id: row['id'] as String,
      requestNumber: row['requestNumber'] as String,
      requestDate: _date(row['requestDate']),
      supplierId: row['supplierId'] as String? ?? '',
      requestedBy: row['requestedBy'] as String,
      notes: row['notes'] as String?,
      status: _requestStatus(row['status'] as String),
      createdAt: _date(row['createdAt']),
      updatedAt: _date(row['updatedAt']),
      items: items,
    );
  }

  Future<PurchaseOrder> _orderFromRow(Map<String, Object?> row) async {
    final items = await _items(
      'purchase_order_items',
      'purchaseOrderId',
      row['id'] as String,
    );
    return PurchaseOrder(
      id: row['id'] as String,
      orderNumber: row['orderNumber'] as String,
      supplierId: row['supplierId'] as String,
      purchaseRequestId: row['purchaseRequestId'] as String?,
      orderDate: _date(row['orderDate']),
      expectedDeliveryDate: row['expectedDeliveryDate'] == null
          ? null
          : _date(row['expectedDeliveryDate']),
      status: _orderStatus(row['status'] as String),
      subtotal: (row['subtotal'] as num).toDouble(),
      discount: (row['discount'] as num).toDouble(),
      tax: (row['tax'] as num).toDouble(),
      grandTotal: (row['grandTotal'] as num).toDouble(),
      notes: row['notes'] as String?,
      createdAt: _date(row['createdAt']),
      updatedAt: _date(row['updatedAt']),
      items: items,
    );
  }

  Future<List<PurchasingItem>> _items(
    String table,
    String key,
    String id,
  ) async {
    final rows = await (await _db).query(
      table,
      where: '$key = ?',
      whereArgs: [id],
    );
    return rows
        .map(
          (m) => PurchasingItem(
            id: m['id'] as String,
            itemId: m['productId'] as String? ?? m['itemId'] as String,
            itemType: m['itemType'] == 'PRODUCT'
                ? PurchasingItemType.product
                : PurchasingItemType.rawMaterial,
            quantity: (m['quantity'] as num).toDouble(),
            unitId: m['unitId'] as String,
            variantId: m['variantId'] as String?,
            baseUnitId: m['baseUnitId'] as String?,
            unitConversionFactor:
                (m['unitConversionFactor'] as num?)?.toDouble() ?? 1,
            baseQuantity: (m['baseQuantity'] as num?)?.toDouble(),
            receivedBaseQuantity:
                (m['receivedBaseQuantity'] as num?)?.toDouble() ?? 0,
            inventoryIdentityKind:
                m['inventoryIdentityKind'] as String? ?? 'BASE',
            identitySnapshotStatus:
                m['identitySnapshotStatus'] as String? ?? 'UNVERIFIED',
            unitPrice: _parseStoredDouble(m['unitPrice']),
            discount: _parseStoredDouble(m['discount']),
            tax: _parseStoredDouble(m['tax']),
            lineTotal: _parseStoredDouble(m['lineTotal']),
            receivedQuantity: _parseStoredDouble(m['receivedQuantity']),
            notes: m['notes'] as String?,
          ),
        )
        .toList();
  }

  double _parseStoredDouble(Object? value) {
    if (value == null) return double.nan;
    if (value is num) {
      final parsed = value.toDouble();
      return parsed.isFinite ? parsed : double.nan;
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed != null && parsed.isFinite ? parsed : double.nan;
    }
    return double.nan;
  }

  Future<void> _validateRequestItems(
    DatabaseExecutor db,
    List<PurchasingItem> items,
  ) async {
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل');
    final ids = <String>{};
    final itemKeys = <String>{};
    for (final item in items) {
      if (item.id.trim().isEmpty || !ids.add(item.id)) {
        throw Exception('أرقام بنود الطلب غير صالحة أو مكررة');
      }
      if (item.quantity <= 0 ||
          !itemKeys.add('${item.itemType.value}:${item.itemId}')) {
        throw Exception('أصناف الطلب غير صالحة أو مكررة');
      }
      await _validateItem(db, item);
    }
  }

  Future<void> _validateOrderItems(
    DatabaseExecutor db,
    List<PurchasingItem> items,
  ) async {
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل');
    final ids = <String>{};
    final itemKeys = <String>{};
    for (final item in items) {
      if (item.id.trim().isEmpty || !ids.add(item.id)) {
        throw Exception('أرقام بنود الأمر غير صالحة أو مكررة');
      }
      if (item.quantity <= 0 ||
          !itemKeys.add('${item.itemType.value}:${item.itemId}')) {
        throw Exception('أصناف الأمر غير صالحة أو مكررة');
      }
      await _validateItem(db, item);
    }
  }

  PurchaseOrder _recalculateOrderFinancials(PurchaseOrder order) {
    final items = order.items.map((item) {
      final lineSubtotal = item.quantity * item.unitPrice;
      final lineTotal = lineSubtotal - item.discount + item.tax;
      return item.copyWith(lineTotal: lineTotal);
    }).toList();
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.unitPrice),
    );
    final discount = items.fold<double>(0, (sum, item) => sum + item.discount);
    final tax = items.fold<double>(0, (sum, item) => sum + item.tax);
    final grandTotal = subtotal - discount + tax;
    return order.copyWith(
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      grandTotal: grandTotal,
      items: items
          .map(
            (item) => item.copyWith(
              lineTotal:
                  (item.quantity * item.unitPrice) - item.discount + item.tax,
            ),
          )
          .toList(),
    );
  }

  void _validateOrderFinancialValues(PurchaseOrder order) {
    if (!order.subtotal.isFinite ||
        !order.discount.isFinite ||
        !order.tax.isFinite ||
        !order.grandTotal.isFinite) {
      throw Exception('القيم المالية لأمر الشراء غير صالحة');
    }
    for (final item in order.items) {
      if (!item.quantity.isFinite ||
          item.quantity <= 0 ||
          !item.unitPrice.isFinite ||
          item.unitPrice < 0 ||
          !item.discount.isFinite ||
          item.discount < 0 ||
          !item.tax.isFinite ||
          item.tax < 0 ||
          !item.receivedQuantity.isFinite ||
          item.receivedQuantity < 0 ||
          !item.lineTotal.isFinite) {
        throw Exception('قيم بنود أمر الشراء المالية غير صالحة');
      }
    }
  }

  void _validateOrderPriceRequirements(
    List<PurchasingItem> items,
    PurchaseOrderStatus status,
  ) {
    if (status != PurchaseOrderStatus.approved) {
      return;
    }
    for (final item in items) {
      if (item.quantity <= 0 ||
          !item.unitPrice.isFinite ||
          item.unitPrice <= 0) {
        throw Exception(
          'يجب إدخال سعر الوحدة لكل الأصناف قبل اعتماد أمر الشراء',
        );
      }
      if (!item.discount.isFinite ||
          item.discount < 0 ||
          !item.tax.isFinite ||
          item.tax < 0) {
        throw Exception(
          'يجب أن تكون الخصومات والضرائب لكل الأصناف صالحة قبل اعتماد أمر الشراء',
        );
      }
    }
  }

  Future<void> _validateSupplier(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'suppliers',
      columns: ['id'],
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('المورد غير موجود أو غير نشط');
  }

  Future<void> _validateWarehouse(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'warehouses',
      columns: ['id'],
      where: 'id = ? AND state = ?',
      whereArgs: [id, 'active'],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('المخزن غير موجود أو غير نشط');
  }

  Future<void> _validateItem(DatabaseExecutor db, PurchasingItem item) async {
    final rows = await db.query(
      item.itemType == PurchasingItemType.product
          ? 'products'
          : 'raw_materials',
      columns: ['id', 'unitId'],
      where: 'id = ? AND active = 1',
      whereArgs: [item.itemId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الصنف غير موجود أو غير نشط');
    final baseUnitId = rows.single['unitId'] as String;
    if (item.baseUnitId != null && item.baseUnitId != baseUnitId) {
      throw Exception('الوحدة الأساسية للصنف غير متوافقة');
    }
    final units = await db.query(
      'units',
      columns: ['id'],
      where: 'id IN (?, ?) AND active = 1',
      whereArgs: [baseUnitId, item.unitId],
    );
    if (units.length != (baseUnitId == item.unitId ? 1 : 2)) {
      throw Exception('وحدة الشراء أو الوحدة الأساسية غير موجودة أو غير نشطة');
    }
    if (!item.unitConversionFactor.isFinite || item.unitConversionFactor <= 0) {
      throw Exception('معامل تحويل الوحدة غير صالح');
    }
    if (item.itemType == PurchasingItemType.product) {
      final variants = await db.query(
        'product_variants',
        columns: ['id'],
        where: 'productId = ? AND active = 1',
        whereArgs: [item.itemId],
        limit: 1,
      );
      if (item.variantId == null && variants.isNotEmpty) {
        throw Exception('يجب تحديد متغير المنتج');
      }
      if (item.variantId != null &&
          (await db.query(
            'product_variants',
            columns: ['id'],
            where: 'id = ? AND productId = ? AND active = 1',
            whereArgs: [item.variantId, item.itemId],
            limit: 1,
          )).isEmpty) {
        throw Exception('متغير المنتج غير موجود أو غير نشط');
      }
      final expectedIdentityKind = item.variantId == null ? 'BASE' : 'VARIANT';
      if (item.inventoryIdentityKind != expectedIdentityKind) {
        throw Exception('هوية مخزون المنتج لا تطابق المتغير المحدد');
      }
    } else if (item.variantId != null ||
        item.inventoryIdentityKind != 'BASE') {
      throw Exception('هوية الخامة غير صالحة');
    }
    if (item.unitId == baseUnitId) {
      if (item.unitConversionFactor != 1) {
        throw Exception('معامل تحويل الوحدة الأساسية يجب أن يساوي واحداً');
      }
    } else if (item.itemType == PurchasingItemType.product) {
      final conversions = await db.query(
        'product_unit_conversions',
        columns: ['factorToBase'],
        where: 'productId = ? AND unitId = ? AND active = 1',
        whereArgs: [item.itemId, item.unitId],
        limit: 1,
      );
      if (conversions.isEmpty) {
        throw Exception('وحدة الشراء غير معتمدة للمنتج');
      }
      final factor = (conversions.single['factorToBase'] as num).toDouble();
      if (!factor.isFinite ||
          factor <= 0 ||
          (factor - item.unitConversionFactor).abs() > 0.000000001) {
        throw Exception('لقطة تحويل وحدة الشراء غير صالحة');
      }
    } else {
      throw Exception('وحدة الخامة يجب أن تطابق وحدتها الأساسية');
    }
    final expectedBaseQuantity = item.quantity * item.unitConversionFactor;
    if (item.baseQuantity != null &&
        (!expectedBaseQuantity.isFinite ||
            (expectedBaseQuantity - item.baseQuantity!).abs() > 0.000001)) {
      throw Exception('الكمية الأساسية المسجلة غير متوافقة');
    }
  }

  Future<void> _validateOrderEdit(
    DatabaseExecutor db,
    PurchaseOrder order,
  ) async {
    final existingRows = await db.query(
      'purchase_orders',
      where: 'id = ?',
      whereArgs: [order.id],
      limit: 1,
    );
    if (existingRows.isEmpty) return;
    final existingItems = await db.query(
      'purchase_order_items',
      where: 'purchaseOrderId = ?',
      whereArgs: [order.id],
    );
    final receipts = await db.rawQuery(
      'SELECT pri.purchaseOrderItemId FROM purchase_receipt_items pri '
      'JOIN purchase_receipts pr ON pr.id = pri.purchaseReceiptId '
      'WHERE pr.purchaseOrderId = ?',
      [order.id],
    );
    final hasReceiving =
        receipts.isNotEmpty ||
        existingItems.any(
          (row) => (row['receivedQuantity'] as num).toDouble() > 0,
        );
    if (!hasReceiving) return;
    if (existingRows.first['supplierId'] != order.supplierId) {
      throw Exception('لا يمكن تغيير المورد بعد الاستلام');
    }
    final incoming = {for (final item in order.items) item.id: item};
    if (incoming.length != existingItems.length) {
      throw Exception('لا يمكن تغيير بنود أمر الشراء بعد الاستلام');
    }
    for (final row in existingItems) {
      final item = incoming[row['id'] as String];
      if (item == null ||
          item.itemId != row['itemId'] ||
          item.itemType.value != row['itemType'] ||
          item.unitId != row['unitId']) {
        throw Exception('لا يمكن تغيير صنف مستلم');
      }
      final received = (row['receivedQuantity'] as num).toDouble();
      if (item.quantity < received || item.receivedQuantity != received) {
        throw Exception('لا يمكن تعديل كمية مستلمة');
      }
      if (item.quantity != (row['quantity'] as num).toDouble() ||
          item.unitPrice != (row['unitPrice'] as num).toDouble() ||
          item.discount != (row['discount'] as num).toDouble() ||
          item.tax != (row['tax'] as num).toDouble() ||
          item.lineTotal != (row['lineTotal'] as num).toDouble()) {
        throw Exception('لا يمكن تعديل بند بعد الاستلام');
      }
    }
    final currentStatus = _orderStatus(existingRows.first['status'] as String);
    if (order.status != currentStatus ||
        order.supplierId != existingRows.first['supplierId'] ||
        order.subtotal != (existingRows.first['subtotal'] as num).toDouble() ||
        order.discount != (existingRows.first['discount'] as num).toDouble() ||
        order.tax != (existingRows.first['tax'] as num).toDouble() ||
        order.grandTotal !=
            (existingRows.first['grandTotal'] as num).toDouble()) {
      throw Exception('لا يمكن تعديل أمر الشراء بعد الاستلام');
    }
  }

  Future<StockItemOption> _resolveItem(
    DatabaseExecutor db,
    String id,
    StockItemType type, {
    String? variantId,
    String? baseUnitId,
    String identityKind = 'BASE',
  }) async {
    final table = type == StockItemType.product ? 'products' : 'raw_materials';
    final rows = await db.query(
      table,
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الصنف غير موجود أو غير نشط');
    final row = rows.first;
    if (identityKind == 'LEGACY_UNASSIGNED') {
      throw Exception('لا يمكن استلام مخزون بهوية قديمة غير مخصصة');
    }
    if (type == StockItemType.product) {
      final expectedIdentityKind = variantId == null ? 'BASE' : 'VARIANT';
      if (identityKind != expectedIdentityKind) {
        throw Exception('هوية مخزون المنتج لا تطابق المتغير المحدد');
      }
      final variants = await db.query(
        'product_variants',
        columns: ['id'],
        where: 'productId = ? AND active = 1',
        whereArgs: [id],
        limit: 1,
      );
      if (variantId == null && variants.isNotEmpty) {
        throw Exception('يجب تحديد متغير المنتج للاستلام');
      }
      if (variantId != null &&
          (await db.query(
            'product_variants',
            columns: ['id'],
            where: 'id = ? AND productId = ? AND active = 1',
            whereArgs: [variantId, id],
            limit: 1,
          )).isEmpty) {
        throw Exception('متغير المنتج غير موجود أو غير نشط');
      }
    } else if (variantId != null || identityKind != 'BASE') {
      throw Exception('هوية الخامة غير صالحة');
    }
    return StockItemOption(
      id: id,
      productId: type == StockItemType.product ? id : null,
      variantId: variantId,
      name: row['name'] as String,
      code: row['code'] as String,
      unitId: baseUnitId ?? row['unitId'] as String,
      type: type,
      active: true,
      identityKind: InventoryIdentityKindValue.parse(identityKind),
    );
  }

  Map<String, Object?> _requestMap(PurchaseRequest value) => {
    'id': value.id,
    'requestNumber': value.requestNumber,
    'requestDate': value.requestDate.millisecondsSinceEpoch,
    'supplierId': value.supplierId,
    'requestedBy': value.requestedBy,
    'notes': value.notes,
    'status': value.status.name.toUpperCase(),
    'createdAt': value.createdAt.millisecondsSinceEpoch,
    'updatedAt': value.updatedAt.millisecondsSinceEpoch,
  };
  String _purchasingLineStorageId(PurchasingItem item) =>
      item.itemType == PurchasingItemType.product && item.variantId != null
      ? inventoryItemKey(
          productId: item.itemId,
          type: StockItemType.product,
          variantId: item.variantId,
          identityKind: InventoryIdentityKindValue.parse(
            item.inventoryIdentityKind,
          ),
        )
      : item.itemId;

  Map<String, Object?> _requestItemMap(
    String requestId,
    PurchasingItem value,
  ) => {
    'id': value.id,
    'purchaseRequestId': requestId,
    'itemId': _purchasingLineStorageId(value),
    'productId': value.itemId,
    'itemType': value.itemType.value,
    'quantity': value.quantity,
    'unitId': value.unitId,
    'variantId': value.variantId,
    'baseUnitId': value.baseUnitId ?? value.unitId,
    'unitConversionFactor': value.unitConversionFactor,
    'baseQuantity': value.baseQuantity ?? value.normalizedBaseQuantity,
    'inventoryIdentityKind': value.inventoryIdentityKind,
    'identitySnapshotStatus': value.identitySnapshotStatus,
    'notes': value.notes,
  };
  Map<String, Object?> _orderMap(PurchaseOrder value) => {
    'id': value.id,
    'orderNumber': value.orderNumber,
    'supplierId': value.supplierId,
    'purchaseRequestId': value.purchaseRequestId,
    'orderDate': value.orderDate.millisecondsSinceEpoch,
    'expectedDeliveryDate': value.expectedDeliveryDate?.millisecondsSinceEpoch,
    'status': _databaseOrderStatus(value.status),
    'subtotal': value.subtotal,
    'discount': value.discount,
    'tax': value.tax,
    'grandTotal': value.grandTotal,
    'notes': value.notes,
    'createdAt': value.createdAt.millisecondsSinceEpoch,
    'updatedAt': value.updatedAt.millisecondsSinceEpoch,
  };
  Map<String, Object?> _orderItemMap(String orderId, PurchasingItem value) => {
    'id': value.id,
    'purchaseOrderId': orderId,
    'itemId': _purchasingLineStorageId(value),
    'productId': value.itemId,
    'itemType': value.itemType.value,
    'quantity': value.quantity,
    'unitId': value.unitId,
    'variantId': value.variantId,
    'baseUnitId': value.baseUnitId ?? value.unitId,
    'unitConversionFactor': value.unitConversionFactor,
    'baseQuantity': value.baseQuantity ?? value.normalizedBaseQuantity,
    'inventoryIdentityKind': value.inventoryIdentityKind,
    'identitySnapshotStatus': value.identitySnapshotStatus,
    'unitPrice': value.unitPrice,
    'discount': value.discount,
    'tax': value.tax,
    'lineTotal': value.lineTotal == 0
        ? value.quantity * value.unitPrice - value.discount + value.tax
        : value.lineTotal,
    'receivedQuantity': value.receivedQuantity,
    'receivedBaseQuantity': value.receivedBaseQuantity,
    'notes': value.notes,
  };
  Future<void> _save(
    String table,
    String id,
    Map<String, Object?> values,
  ) async => _saveExecutor(await _db, table, id, values);
  Future<void> _saveExecutor(
    DatabaseExecutor db,
    String table,
    String id,
    Map<String, Object?> values,
  ) async {
    final count = await db.update(
      table,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count == 0) await db.insert(table, values);
  }

  String _databaseOrderStatus(PurchaseOrderStatus status) => switch (status) {
    PurchaseOrderStatus.draft => 'DRAFT',
    PurchaseOrderStatus.approved => 'APPROVED',
    PurchaseOrderStatus.partiallyReceived => 'PARTIALLY_RECEIVED',
    PurchaseOrderStatus.fullyReceived => 'FULLY_RECEIVED',
    PurchaseOrderStatus.cancelled => 'CANCELLED',
  };

  PurchaseRequestStatus _requestStatus(String value) => PurchaseRequestStatus
      .values
      .firstWhere((v) => v.name.toUpperCase() == value);
  PurchaseOrderStatus _orderStatus(String value) =>
      switch (value.toUpperCase()) {
        'DRAFT' => PurchaseOrderStatus.draft,
        'APPROVED' => PurchaseOrderStatus.approved,
        'CONFIRMED' => PurchaseOrderStatus.approved,
        'PARTIALLY_RECEIVED' => PurchaseOrderStatus.partiallyReceived,
        'FULLY_RECEIVED' => PurchaseOrderStatus.fullyReceived,
        'CANCELLED' => PurchaseOrderStatus.cancelled,
        _ => throw Exception('حالة أمر الشراء غير معروفة: $value'),
      };
  bool _validOrderTransition(
    PurchaseOrderStatus from,
    PurchaseOrderStatus to,
  ) =>
      from == to ||
      switch (from) {
        PurchaseOrderStatus.draft =>
          to == PurchaseOrderStatus.approved ||
              to == PurchaseOrderStatus.cancelled,
        PurchaseOrderStatus.approved =>
          to == PurchaseOrderStatus.partiallyReceived ||
              to == PurchaseOrderStatus.fullyReceived ||
              to == PurchaseOrderStatus.cancelled,
        PurchaseOrderStatus.partiallyReceived =>
          to == PurchaseOrderStatus.fullyReceived ||
              to == PurchaseOrderStatus.cancelled,
        _ => false,
      };
  bool _validRequestTransition(
    PurchaseRequestStatus from,
    PurchaseRequestStatus to,
  ) =>
      from == to ||
      switch (from) {
        PurchaseRequestStatus.draft =>
          to == PurchaseRequestStatus.pending ||
              to == PurchaseRequestStatus.cancelled,
        PurchaseRequestStatus.pending =>
          to == PurchaseRequestStatus.approved ||
              to == PurchaseRequestStatus.rejected ||
              to == PurchaseRequestStatus.cancelled,
        PurchaseRequestStatus.approved =>
          to == PurchaseRequestStatus.converted ||
              to == PurchaseRequestStatus.cancelled,
        _ => false,
      };

  Future<void> _auditSafely({
    required String action,
    required String entityType,
    required String entityId,
    required String description,
  }) async {
    try {
      await _security.audit(
        action: action,
        module: 'Purchasing',
        entityType: entityType,
        entityId: entityId,
        description: description,
      );
    } catch (_) {
      // Audit failure must not roll back a committed business mutation.
    }
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().millisecond}';
  DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
}
