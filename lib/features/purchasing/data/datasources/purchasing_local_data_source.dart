import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class PurchasingLocalDataSource {
  PurchasingLocalDataSource([
    WarehousesStockLocalDataSource? stock,
    AccountingLocalDataSource? accounting,
  ]) : _stock = stock ?? WarehousesStockLocalDataSource(),
       _accounting = accounting ?? AccountingLocalDataSource();
  final WarehousesStockLocalDataSource _stock;
  final AccountingLocalDataSource _accounting;
  final SecurityLocalDataSource _security = SecurityLocalDataSource();
  Future<Database> get _db async => FurnexaDatabase.instance.database;

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
    await db.transaction((txn) async {
      await _validateOrderEdit(txn, order);
      await _validateSupplier(txn, order.supplierId);
      await _validateOrderItems(txn, order.items);
      await _saveExecutor(txn, 'purchase_orders', order.id, _orderMap(order));
      await txn.delete(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [order.id],
      );
      for (final item in order.items) {
        await txn.insert('purchase_order_items', _orderItemMap(order.id, item));
      }
    });
    await _auditSafely(
      action: existing.isEmpty ? 'CREATE' : 'UPDATE',
      entityType: 'PurchaseOrder',
      entityId: order.id,
      description: 'Purchase order saved',
    );
    return order;
  }

  Future<PurchaseOrder> convertRequestToOrder(
    PurchaseRequest request,
    PurchaseOrder order,
  ) async {
    _security.require('PURCHASING_VIEW');
    final db = await _db;
    await db.transaction((txn) async {
      final requestRows = await txn.query(
        'purchase_requests',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [request.id],
        limit: 1,
      );
      if (requestRows.isEmpty ||
          _requestStatus(requestRows.first['status'] as String) !=
              PurchaseRequestStatus.approved) {
        throw Exception('يجب اعتماد الطلب قبل تحويله');
      }
      final existingOrders = await txn.query(
        'purchase_orders',
        columns: ['id'],
        where: 'purchaseRequestId = ?',
        whereArgs: [request.id],
        limit: 1,
      );
      if (existingOrders.isNotEmpty) {
        throw Exception('تم تحويل طلب الشراء من قبل');
      }
      if (order.purchaseRequestId != request.id) {
        throw Exception('ارتباط طلب الشراء غير صالح');
      }
      await _validateSupplier(txn, order.supplierId);
      await _validateOrderItems(txn, order.items);
      await _saveExecutor(txn, 'purchase_orders', order.id, _orderMap(order));
      for (final item in order.items) {
        await txn.insert('purchase_order_items', _orderItemMap(order.id, item));
      }
      await txn.update(
        'purchase_requests',
        {
          'status': 'CONVERTED',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [request.id],
      );
    });
    await _auditSafely(
      action: 'CONVERSION',
      entityType: 'PurchaseOrder',
      entityId: order.id,
      description: 'Purchase request converted to purchase order',
    );
    return order;
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
    if (current == PurchaseOrderStatus.cancelled ||
        current == PurchaseOrderStatus.fullyReceived) {
      throw Exception('لا يمكن تغيير حالة أمر الشراء');
    }
    await db.update(
      'purchase_orders',
      {
        'status': status.name.toUpperCase(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
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
    String? notes,
    String? operationId,
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
        columns: ['status', 'supplierId'],
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (stateRows.isEmpty) throw Exception('أمر الشراء غير موجود');
      final persistedStatus = _orderStatus(stateRows.first['status'] as String);
      if (persistedStatus == PurchaseOrderStatus.cancelled ||
          persistedStatus == PurchaseOrderStatus.fullyReceived) {
        throw Exception('لا يمكن استلام أمر الشراء');
      }
      final supplierId = stateRows.first['supplierId'] as String;
      final orderRows = await txn.query(
        'purchase_order_items',
        where: 'purchaseOrderId = ?',
        whereArgs: [order.id],
      );
      final orderById = {for (final row in orderRows) row['id'] as String: row};
      final receiptId = _id('receipt');
      postedReceiptId = receiptId;
      if (operationId != null && operationId.trim().isEmpty) {
        throw Exception('معرف العملية غير صالح');
      }
      final receiptNumber = operationId == null
          ? _number('GR')
          : 'GR-OP-${operationId.trim()}';
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
      var inventoryTotal = 0.0;
      for (final receiptItem in items) {
        final row = orderById[receiptItem.id];
        if (row == null) throw Exception('صنف الاستلام غير موجود في الأمر');
        if (row['itemId'] != receiptItem.itemId ||
            row['itemType'] != receiptItem.itemType.value ||
            row['unitId'] != receiptItem.unitId) {
          throw Exception('بيانات صنف الاستلام غير متوافقة');
        }
        final ordered = (row['quantity'] as num).toDouble();
        final received = (row['receivedQuantity'] as num).toDouble();
        if (receiptItem.quantity <= 0 ||
            receiptItem.quantity > ordered - received) {
          throw Exception('الكمية المستلمة تتجاوز الكمية المتبقية');
        }
        final itemType = row['itemType'] == 'PRODUCT'
            ? StockItemType.product
            : StockItemType.rawMaterial;
        final item = await _resolveItem(txn, row['itemId'] as String, itemType);
        await _stock.applyStockInWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          item: item,
          quantity: receiptItem.quantity,
          date: receiptDate,
          reference: receiptNumber,
          notes: notes,
        );
        final lineTotal = (row['lineTotal'] as num?)?.toDouble() ?? 0;
        final orderedCost = (row['quantity'] as num).toDouble();
        inventoryTotal += orderedCost == 0
            ? 0
            : receiptItem.quantity * (lineTotal / orderedCost);
        if (orderedCost > 0) {
          await _accounting.receiveInventoryValueWithinTransaction(
            executor: txn,
            warehouseId: warehouseId,
            itemId: row['itemId'] as String,
            itemType: itemType == StockItemType.product
                ? 'PRODUCT'
                : 'RAW_MATERIAL',
            quantity: receiptItem.quantity,
            unitCost: lineTotal / orderedCost,
          );
        }
        await txn.insert('purchase_receipt_items', {
          'id': _id('receipt-item'),
          'purchaseReceiptId': receiptId,
          'purchaseOrderItemId': receiptItem.id,
          'receivedQuantity': receiptItem.quantity,
          'unitId': row['unitId'],
          'notes': receiptItem.notes,
        });
        await txn.update(
          'purchase_order_items',
          {'receivedQuantity': received + receiptItem.quantity},
          where: 'id = ?',
          whereArgs: [receiptItem.id],
        );
        receivedAny = true;
      }
      if (!receivedAny) throw Exception('لم يتم استلام أي صنف');
      if (inventoryTotal > 0) {
        final inventory =
            (await txn.query(
                  'accounts',
                  columns: ['id'],
                  where: 'code = ? AND active = 1',
                  whereArgs: ['1100'],
                  limit: 1,
                )).single['id']
                as String;
        final payable =
            (await txn.query(
                  'accounts',
                  columns: ['id'],
                  where: 'code = ? AND active = 1',
                  whereArgs: ['2000'],
                  limit: 1,
                )).single['id']
                as String;
        await _accounting.postJournalWithinTransaction(
          executor: txn,
          date: receiptDate,
          description: 'استلام مشتريات $receiptNumber',
          referenceType: 'PURCHASE_RECEIPT',
          referenceId: receiptId,
          partyType: 'SUPPLIER',
          partyId: supplierId,
          lines: [
            JournalLineInput(accountId: inventory, debit: inventoryTotal),
            JournalLineInput(accountId: payable, credit: inventoryTotal),
          ],
        );
      }
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
            itemId: m['itemId'] as String,
            itemType: m['itemType'] == 'PRODUCT'
                ? PurchasingItemType.product
                : PurchasingItemType.rawMaterial,
            quantity: (m['quantity'] as num).toDouble(),
            unitId: m['unitId'] as String,
            unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
            discount: (m['discount'] as num?)?.toDouble() ?? 0,
            tax: (m['tax'] as num?)?.toDouble() ?? 0,
            lineTotal: (m['lineTotal'] as num?)?.toDouble() ?? 0,
            receivedQuantity: (m['receivedQuantity'] as num?)?.toDouble() ?? 0,
            notes: m['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<void> _validateRequestItems(
    DatabaseExecutor db,
    List<PurchasingItem> items,
  ) async {
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل');
    final keys = <String>{};
    for (final item in items) {
      if (item.quantity <= 0 ||
          !keys.add('${item.itemType.value}:${item.itemId}')) {
        throw Exception('أصناف الطلب غير صالحة أو مكررة');
      }
      await _validateItem(db, item.itemId, item.itemType, item.unitId);
    }
  }

  Future<void> _validateOrderItems(
    DatabaseExecutor db,
    List<PurchasingItem> items,
  ) async {
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل');
    for (final item in items) {
      if (item.quantity <= 0) {
        throw Exception('كمية الأمر يجب أن تكون أكبر من صفر');
      }
      await _validateItem(db, item.itemId, item.itemType, item.unitId);
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

  Future<void> _validateItem(
    DatabaseExecutor db,
    String id,
    PurchasingItemType type,
    String unitId,
  ) async {
    final rows = await db.query(
      type == PurchasingItemType.product ? 'products' : 'raw_materials',
      columns: ['id', 'unitId'],
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الصنف غير موجود أو غير نشط');
    if (rows.first['unitId'] != unitId) {
      throw Exception('وحدة الصنف غير متوافقة');
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
    StockItemType type,
  ) async {
    final table = type == StockItemType.product ? 'products' : 'raw_materials';
    final rows = await db.query(
      table,
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الصنف غير موجود أو غير نشط');
    final row = rows.first;
    return StockItemOption(
      id: id,
      name: row['name'] as String,
      code: row['code'] as String,
      unitId: row['unitId'] as String,
      type: type,
      active: true,
    );
  }

  Map<String, Object?> _requestMap(PurchaseRequest value) => {
    'id': value.id,
    'requestNumber': value.requestNumber,
    'requestDate': value.requestDate.millisecondsSinceEpoch,
    'requestedBy': value.requestedBy,
    'notes': value.notes,
    'status': value.status.name.toUpperCase(),
    'createdAt': value.createdAt.millisecondsSinceEpoch,
    'updatedAt': value.updatedAt.millisecondsSinceEpoch,
  };
  Map<String, Object?> _requestItemMap(
    String requestId,
    PurchasingItem value,
  ) => {
    'id': value.id,
    'purchaseRequestId': requestId,
    'itemId': value.itemId,
    'itemType': value.itemType.value,
    'quantity': value.quantity,
    'unitId': value.unitId,
    'notes': value.notes,
  };
  Map<String, Object?> _orderMap(PurchaseOrder value) => {
    'id': value.id,
    'orderNumber': value.orderNumber,
    'supplierId': value.supplierId,
    'purchaseRequestId': value.purchaseRequestId,
    'orderDate': value.orderDate.millisecondsSinceEpoch,
    'expectedDeliveryDate': value.expectedDeliveryDate?.millisecondsSinceEpoch,
    'status': value.status.name
        .replaceAll('partiallyReceived', 'PARTIALLY_RECEIVED')
        .replaceAll('fullyReceived', 'FULLY_RECEIVED')
        .toUpperCase(),
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
    'itemId': value.itemId,
    'itemType': value.itemType.value,
    'quantity': value.quantity,
    'unitId': value.unitId,
    'unitPrice': value.unitPrice,
    'discount': value.discount,
    'tax': value.tax,
    'lineTotal': value.lineTotal == 0
        ? value.quantity * value.unitPrice - value.discount + value.tax
        : value.lineTotal,
    'receivedQuantity': value.receivedQuantity,
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

  PurchaseRequestStatus _requestStatus(String value) => PurchaseRequestStatus
      .values
      .firstWhere((v) => v.name.toUpperCase() == value);
  PurchaseOrderStatus _orderStatus(String value) =>
      PurchaseOrderStatus.values.firstWhere(
        (v) =>
            v.name
                .replaceAll('partiallyReceived', 'PARTIALLY_RECEIVED')
                .replaceAll('fullyReceived', 'FULLY_RECEIVED')
                .toUpperCase() ==
            value,
      );
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
  String _number(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';
  DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
}
