import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class SalesLocalDataSource {
  SalesLocalDataSource([
    WarehousesStockLocalDataSource? stock,
    AccountingLocalDataSource? accounting,
    SecurityLocalDataSource? security,
  ]) : _stock = stock ?? WarehousesStockLocalDataSource(),
       _accounting = accounting ?? AccountingLocalDataSource(),
       _security = security ?? SecurityLocalDataSource();
  final WarehousesStockLocalDataSource _stock;
  final AccountingLocalDataSource _accounting;
  final SecurityLocalDataSource _security;
  Future<Database> get _db async => FurnexaDatabase.instance.database;
  static int _sequence = 0;
  String _id(String prefix) {
    _sequence++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  String _number(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';

  Future<List<Customer>> customers([String query = '']) async {
    _security.require('SALES_VIEW');
    final db = await _db;
    final q = query.trim().toLowerCase();
    final rows = await db.query(
      'customers',
      where: q.isEmpty ? null : 'LOWER(name) LIKE ? OR LOWER(code) LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<void> saveCustomer(Customer value) async {
    _security.require('SALES_EDIT');
    await _save('customers', value.id, value.toMap());
  }

  Future<void> setCustomerActive(String id, bool active) async {
    _security.require('SALES_EDIT');
    await (await _db).update(
      'customers',
      {
        'active': active ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Quotation>> quotations([String query = '']) async {
    _security.require('SALES_VIEW');
    final db = await _db;
    final q = query.trim().toLowerCase();
    final rows = await db.query(
      'quotations',
      where: q.isEmpty ? null : 'LOWER(quotationNumber) LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%'],
      orderBy: 'quotationDate DESC',
    );
    return Future.wait(rows.map(_quotation));
  }

  Future<Quotation> saveQuotation(Quotation value) async {
    _security.require('SALES_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      await _validateCustomer(txn, value.customerId);
      await _validateItems(txn, value.items);
      final existing = await txn.query(
        'quotations',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [value.id],
        limit: 1,
      );
      if (existing.isNotEmpty &&
          _quotationStatus(existing.first['status'] as String) !=
              QuotationStatus.draft) {
        throw Exception('لا يمكن تعديل عرض سعر غير مسودة');
      }
      await _saveExecutor(txn, 'quotations', value.id, _quotationMap(value));
      await txn.delete(
        'quotation_items',
        where: 'quotationId = ?',
        whereArgs: [value.id],
      );
      for (final item in value.items) {
        await txn.insert(
          'quotation_items',
          _itemMap(value.id, item, 'quotationId'),
        );
      }
    });
    return value;
  }

  Future<void> changeQuotationStatus(String id, QuotationStatus status) async {
    _security.require('SALES_EDIT');
    final db = await _db;
    final rows = await db.query(
      'quotations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('عرض السعر غير موجود');
    final current = _quotationStatus(rows.first['status'] as String);
    if (!_validQuotationTransition(current, status)) {
      throw Exception('انتقال حالة عرض السعر غير مسموح');
    }
    await db.update(
      'quotations',
      {
        'status': status.name.toUpperCase(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SalesOrder>> orders([String query = '']) async {
    _security.require('SALES_VIEW');
    final db = await _db;
    final q = query.trim().toLowerCase();
    final rows = await db.query(
      'sales_orders',
      where: q.isEmpty ? null : 'LOWER(orderNumber) LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%'],
      orderBy: 'orderDate DESC',
    );
    return Future.wait(rows.map(_order));
  }

  Future<SalesOrder> saveOrder(SalesOrder value) async {
    _security.require('SALES_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      await _validateCustomer(txn, value.customerId);
      await _validateItems(txn, value.items);
      final existing = await txn.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [value.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final existingItems = await txn.query(
          'sales_order_items',
          columns: ['deliveredQuantity'],
          where: 'salesOrderId = ?',
          whereArgs: [value.id],
        );
        if (existingItems.any(
          (row) => (row['deliveredQuantity'] as num).toDouble() > 0,
        )) {
          throw Exception('لا يمكن تعديل أمر بيع تم تسليمه');
        }
      }
      await _saveExecutor(txn, 'sales_orders', value.id, _orderMap(value));
      await txn.delete(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [value.id],
      );
      for (final item in value.items) {
        await txn.insert(
          'sales_order_items',
          _itemMap(value.id, item, 'salesOrderId'),
        );
      }
    });
    return value;
  }

  Future<SalesOrder> convertQuotationToOrder(
    Quotation quotation,
    SalesOrder order,
  ) async {
    _security.require('SALES_EDIT');
    final db = await _db;
    final convertedOrderId = await db.transaction((txn) async {
      final quotationRows = await txn.query(
        'quotations',
        where: 'id = ?',
        whereArgs: [quotation.id],
        limit: 1,
      );
      if (quotationRows.isEmpty) throw Exception('عرض السعر غير موجود');
      final persistedQuotation = quotationRows.single;
      final quotationItems = await txn.query(
        'quotation_items',
        where: 'quotationId = ?',
        whereArgs: [quotation.id],
      );
      if (!_orderMatchesQuotation(order, persistedQuotation, quotationItems)) {
        throw Exception('أمر البيع لا يطابق عرض السعر');
      }

      final persistedStatus = _quotationStatus(
        persistedQuotation['status'] as String,
      );
      if (persistedStatus == QuotationStatus.converted) {
        final existingOrders = await txn.query(
          'sales_orders',
          where: 'quotationId = ?',
          whereArgs: [quotation.id],
          limit: 2,
        );
        if (existingOrders.length != 1) {
          throw Exception('أمر التحويل المحفوظ غير صالح');
        }
        return existingOrders.single['id'] as String;
      }
      if (persistedStatus != QuotationStatus.accepted) {
        throw Exception('يجب قبول عرض السعر قبل تحويله');
      }

      await _validateCustomer(txn, order.customerId);
      await _validateItems(txn, order.items);
      final changed = await txn.update(
        'quotations',
        {
          'status': 'CONVERTED',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [quotation.id, 'ACCEPTED'],
      );
      if (changed != 1) throw Exception('تم تحويل عرض السعر بالفعل');
      await txn.insert('sales_orders', _orderMap(order));
      for (final item in order.items) {
        await txn.insert(
          'sales_order_items',
          _itemMap(order.id, item, 'salesOrderId'),
        );
      }
      return order.id;
    });
    final rows = await db.query(
      'sales_orders',
      where: 'id = ?',
      whereArgs: [convertedOrderId],
      limit: 1,
    );
    return _order(rows.single);
  }

  bool _orderMatchesQuotation(
    SalesOrder order,
    Map<String, Object?> quotation,
    List<Map<String, Object?>> quotationItems,
  ) {
    bool close(double first, double second) =>
        (first - second).abs() < 0.000001;
    if (order.quotationId != quotation['id'] ||
        order.customerId != quotation['customerId'] ||
        order.items.length != quotationItems.length ||
        !close(order.subtotal, (quotation['subtotal'] as num).toDouble()) ||
        !close(order.discount, (quotation['discount'] as num).toDouble()) ||
        !close(order.tax, (quotation['tax'] as num).toDouble()) ||
        !close(order.grandTotal, (quotation['grandTotal'] as num).toDouble())) {
      return false;
    }
    final matched = <String>{};
    for (final row in quotationItems) {
      final key = '${row['itemType']}:${row['itemId']}';
      final item = order.items.where(
        (candidate) => '${candidate.itemType.value}:${candidate.itemId}' == key,
      );
      if (item.length != 1 || !matched.add(key)) return false;
      final candidate = item.single;
      final lineTotal = candidate.lineTotal == 0
          ? candidate.quantity * candidate.unitPrice -
                candidate.discount +
                candidate.tax
          : candidate.lineTotal;
      if (!close(candidate.quantity, (row['quantity'] as num).toDouble()) ||
          candidate.unitId != row['unitId'] ||
          !close(candidate.unitPrice, (row['unitPrice'] as num).toDouble()) ||
          !close(candidate.discount, (row['discount'] as num).toDouble()) ||
          !close(candidate.tax, (row['tax'] as num).toDouble()) ||
          !close(lineTotal, (row['lineTotal'] as num).toDouble())) {
        return false;
      }
    }
    return true;
  }

  Future<void> changeOrderStatus(String id, SalesOrderStatus status) async {
    _security.require('SALES_EDIT');
    final db = await _db;
    final rows = await db.query(
      'sales_orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('أمر البيع غير موجود');
    final current = _orderStatus(rows.first['status'] as String);
    if (current == SalesOrderStatus.cancelled ||
        current == SalesOrderStatus.fullyDelivered) {
      throw Exception('لا يمكن تغيير حالة أمر البيع');
    }
    await db.update(
      'sales_orders',
      {
        'status': status.name.toUpperCase(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<SalesDelivery>> deliveries(String orderId) async {
    _security.require('SALES_VIEW');
    final rows = await (await _db).query(
      'sales_deliveries',
      where: 'salesOrderId = ?',
      whereArgs: [orderId],
      orderBy: 'deliveryDate DESC',
    );
    return rows.map(SalesDelivery.fromMap).toList();
  }

  Future<SalesDelivery> updateDeliveryDispatch({
    required String deliveryId,
    required DeliveryDispatchStatus status,
    DateTime? dispatchDate,
    String? driverName,
    String? vehicleNumber,
    String? destination,
    String? notes,
  }) async {
    _security.require('SALES_DELIVER');
    final db = await _db;
    final rows = await db.query(
      'sales_deliveries',
      where: 'id = ?',
      whereArgs: [deliveryId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('التسليم غير موجود');
    final current = SalesDelivery.fromMap(rows.first);
    await _security.requireResourceScope(
      ScopeType.warehouse,
      current.warehouseId,
    );
    if (status == DeliveryDispatchStatus.cancelled) {
      throw Exception('لا يمكن إلغاء تسليم تم ترحيله للمخزون والمحاسبة');
    }
    if (!_validDeliveryDispatchTransition(current.status, status)) {
      throw Exception('انتقال حالة التسليم غير مسموح');
    }
    final updates = <String, Object?>{
      'status': status.value,
      'dispatchDate':
          dispatchDate?.millisecondsSinceEpoch ??
          current.dispatchDate?.millisecondsSinceEpoch,
      'driverName': driverName ?? current.driverName,
      'vehicleNumber': vehicleNumber ?? current.vehicleNumber,
      'destination': destination ?? current.destination,
      'notes': notes ?? current.notes,
    };
    await db.update(
      'sales_deliveries',
      updates,
      where: 'id = ?',
      whereArgs: [deliveryId],
    );
    final refreshed = await db.query(
      'sales_deliveries',
      where: 'id = ?',
      whereArgs: [deliveryId],
      limit: 1,
    );
    return SalesDelivery.fromMap(refreshed.single);
  }

  Future<void> postDelivery({
    required SalesOrder order,
    required String warehouseId,
    required DateTime deliveryDate,
    required List<SalesItem> items,
    String? notes,
    String? operationId,
  }) async {
    _security.require('SALES_DELIVER');
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل');
    if (operationId != null && operationId.trim().isEmpty) {
      throw Exception('معرف عملية التسليم غير صالح');
    }
    final requestKey = operationId == null
        ? _deliveryRequestKey(order, warehouseId, deliveryDate, items, notes)
        : 'CALLER:${operationId.trim()}';
    final db = await _db;
    await db.transaction((txn) async {
      await _validateWarehouse(txn, warehouseId);
      await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
      final existingDeliveries = await txn.query(
        'sales_deliveries',
        where: 'requestKey = ?',
        whereArgs: [requestKey],
        limit: 1,
      );
      if (existingDeliveries.isNotEmpty) {
        final existing = existingDeliveries.single;
        final existingItems = await txn.query(
          'sales_delivery_items',
          where: 'salesDeliveryId = ?',
          whereArgs: [existing['id']],
        );
        if (existing['salesOrderId'] != order.id ||
            existing['warehouseId'] != warehouseId ||
            (existing['deliveryDate'] as num).toInt() !=
                deliveryDate.millisecondsSinceEpoch ||
            !_sameDeliveryItems(existingItems, items)) {
          throw Exception('معرف عملية التسليم مستخدم لطلب آخر');
        }
        return;
      }
      final orderRows = await txn.query(
        'sales_orders',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر البيع غير موجود');
      final currentStatus = _orderStatus(orderRows.first['status'] as String);
      if (currentStatus == SalesOrderStatus.cancelled ||
          currentStatus == SalesOrderStatus.fullyDelivered) {
        throw Exception('لا يمكن تسليم أمر البيع');
      }
      if (currentStatus == SalesOrderStatus.draft) {
        throw Exception('يجب تأكيد أمر البيع قبل التسليم');
      }
      final itemRows = await txn.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [order.id],
      );
      final byId = {for (final row in itemRows) row['id'] as String: row};
      final requested = <String, double>{};
      final deliveredById = <String, double>{};
      for (final item in items) {
        requested[item.id] = (requested[item.id] ?? 0) + item.quantity;
      }
      for (final entry in requested.entries) {
        final row = byId[entry.key];
        if (row == null) throw Exception('صنف التسليم غير موجود في الأمر');
        final remaining =
            (row['quantity'] as num).toDouble() -
            (row['deliveredQuantity'] as num).toDouble();
        if (entry.value <= 0 || entry.value > remaining) {
          throw Exception('الكمية المسلمة تتجاوز الكمية المتبقية');
        }
        deliveredById[entry.key] = (row['deliveredQuantity'] as num).toDouble();
      }
      final deliveryId = _id('delivery');
      final deliveryNumber = _number('DL');
      var revenueTotal = 0.0;
      var cogsTotal = 0.0;
      await txn.insert('sales_deliveries', {
        'id': deliveryId,
        'deliveryNumber': deliveryNumber,
        'salesOrderId': order.id,
        'warehouseId': warehouseId,
        'deliveryDate': deliveryDate.millisecondsSinceEpoch,
        'status': DeliveryDispatchStatus.pending.value,
        'dispatchDate': null,
        'driverName': null,
        'vehicleNumber': null,
        'destination': null,
        'notes': notes,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'requestKey': requestKey,
      });
      for (final item in items) {
        final row = byId[item.id];
        if (row == null) throw Exception('صنف التسليم غير موجود في الأمر');
        final ordered = (row['quantity'] as num).toDouble();
        final delivered = (row['deliveredQuantity'] as num).toDouble();
        if (item.quantity <= 0 || item.quantity > ordered - delivered) {
          throw Exception('الكمية المسلمة تتجاوز الكمية المتبقية');
        }
        final type = row['itemType'] == 'PRODUCT'
            ? StockItemType.product
            : StockItemType.rawMaterial;
        final stockItem = await _resolveItem(
          txn,
          row['itemId'] as String,
          type,
        );
        final valuationRows = await txn.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, row['itemId'], type.value],
          limit: 1,
        );
        if (valuationRows.isEmpty) {
          throw Exception('تقييم المخزون غير متاح لحساب تكلفة البضاعة');
        }
        final unitCogs = (valuationRows.first['averageCost'] as num).toDouble();
        cogsTotal += item.quantity * unitCogs;
        await _accounting.consumeInventoryValueWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          itemId: row['itemId'] as String,
          itemType: type.value,
          quantity: item.quantity,
        );
        final lineTotal = (row['lineTotal'] as num?)?.toDouble() ?? 0;
        revenueTotal += ordered == 0
            ? 0
            : item.quantity * (lineTotal / ordered);
        await _stock.applyStockOutWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          item: stockItem,
          quantity: item.quantity,
          date: deliveryDate,
          reference: deliveryNumber,
          notes: notes,
        );
        await txn.insert('sales_delivery_items', {
          'id': _id('delivery-item'),
          'salesDeliveryId': deliveryId,
          'salesOrderItemId': item.id,
          'deliveredQuantity': item.quantity,
          'unitId': row['unitId'],
          'unitRevenue': ordered == 0 ? 0 : lineTotal / ordered,
          'unitCogs': unitCogs,
          'notes': item.notes,
        });
        await txn.update(
          'sales_order_items',
          {'deliveredQuantity': deliveredById[item.id]! + item.quantity},
          where: 'id = ?',
          whereArgs: [item.id],
        );
        deliveredById[item.id] = deliveredById[item.id]! + item.quantity;
      }
      if (revenueTotal > 0) {
        final receivable =
            (await txn.query(
                  'accounts',
                  columns: ['id'],
                  where: 'code = ? AND active = 1',
                  whereArgs: ['1200'],
                  limit: 1,
                )).single['id']
                as String;
        final salesRevenue =
            (await txn.query(
                  'accounts',
                  columns: ['id'],
                  where: 'code = ? AND active = 1',
                  whereArgs: ['4000'],
                  limit: 1,
                )).single['id']
                as String;
        final lines = <JournalLineInput>[
          JournalLineInput(accountId: receivable, debit: revenueTotal),
          JournalLineInput(accountId: salesRevenue, credit: revenueTotal),
        ];
        if (cogsTotal > 0) {
          final cogs =
              (await txn.query(
                    'accounts',
                    columns: ['id'],
                    where: 'code = ? AND active = 1',
                    whereArgs: ['5000'],
                    limit: 1,
                  )).single['id']
                  as String;
          final inventory =
              (await txn.query(
                    'accounts',
                    columns: ['id'],
                    where: 'code = ? AND active = 1',
                    whereArgs: ['1100'],
                    limit: 1,
                  )).single['id']
                  as String;
          lines.add(JournalLineInput(accountId: cogs, debit: cogsTotal));
          lines.add(JournalLineInput(accountId: inventory, credit: cogsTotal));
        }
        await _accounting.postJournalWithinTransaction(
          executor: txn,
          date: deliveryDate,
          description: 'بيع وتسليم $deliveryNumber',
          referenceType: 'SALES_DELIVERY',
          referenceId: deliveryId,
          partyType: 'CUSTOMER',
          partyId: order.customerId,
          lines: lines,
        );
      }
      final totals = await txn.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [order.id],
      );
      final complete = totals.every(
        (row) =>
            (row['deliveredQuantity'] as num).toDouble() >=
            (row['quantity'] as num).toDouble(),
      );
      await txn.update(
        'sales_orders',
        {
          'status': complete ? 'FULLY_DELIVERED' : 'PARTIALLY_DELIVERED',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );
    });
  }

  String _deliveryRequestKey(
    SalesOrder order,
    String warehouseId,
    DateTime deliveryDate,
    List<SalesItem> items,
    String? notes,
  ) {
    final lines =
        items
            .map((item) => [item.id, item.itemId, item.quantity, item.unitId])
            .toList()
          ..sort(
            (first, second) =>
                (first[0] as String).compareTo(second[0] as String),
          );
    final payload = jsonEncode([
      order.id,
      warehouseId,
      deliveryDate.millisecondsSinceEpoch,
      notes,
      lines,
    ]);
    return 'AUTO:${sha256.convert(utf8.encode(payload))}';
  }

  bool _sameDeliveryItems(
    List<Map<String, Object?>> stored,
    List<SalesItem> requested,
  ) {
    if (stored.length != requested.length) return false;
    final remaining = [...stored];
    for (final item in requested) {
      final index = remaining.indexWhere(
        (row) =>
            row['salesOrderItemId'] == item.id &&
            (row['deliveredQuantity'] as num).toDouble() == item.quantity,
      );
      if (index < 0) return false;
      remaining.removeAt(index);
    }
    return remaining.isEmpty;
  }

  Future<List<Warehouse>> activeWarehouses() async {
    _security.require('SALES_VIEW');
    return (await (await _db).query(
      'warehouses',
      where: 'state = ?',
      whereArgs: ['active'],
      orderBy: 'name ASC',
    )).map(Warehouse.fromMap).toList();
  }

  Future<List<StockItemOption>> activeItems() async {
    _security.require('SALES_VIEW');
    final rows = await (await _db).query(
      'products',
      where: 'active = 1',
      orderBy: 'name ASC',
    );
    return rows
        .map(
          (row) => StockItemOption(
            id: row['id'] as String,
            name: row['name'] as String,
            code: row['code'] as String,
            unitId: row['unitId'] as String,
            type: StockItemType.product,
            active: true,
          ),
        )
        .toList();
  }

  Future<Quotation> _quotation(Map<String, Object?> row) async {
    final items = await _items(
      'quotation_items',
      'quotationId',
      row['id'] as String,
    );
    return Quotation(
      id: row['id'] as String,
      quotationNumber: row['quotationNumber'] as String,
      customerId: row['customerId'] as String,
      quotationDate: _date(row['quotationDate']),
      validUntil: row['validUntil'] == null ? null : _date(row['validUntil']),
      status: _quotationStatus(row['status'] as String),
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

  Future<SalesOrder> _order(Map<String, Object?> row) async {
    final items = await _items(
      'sales_order_items',
      'salesOrderId',
      row['id'] as String,
    );
    return SalesOrder(
      id: row['id'] as String,
      orderNumber: row['orderNumber'] as String,
      customerId: row['customerId'] as String,
      quotationId: row['quotationId'] as String?,
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

  Future<List<SalesItem>> _items(String table, String key, String id) async {
    final rows = await (await _db).query(
      table,
      where: '$key = ?',
      whereArgs: [id],
    );
    return rows
        .map(
          (m) => SalesItem(
            id: m['id'] as String,
            itemId: m['itemId'] as String,
            itemType: m['itemType'] == 'PRODUCT'
                ? SalesItemType.product
                : SalesItemType.rawMaterial,
            quantity: (m['quantity'] as num).toDouble(),
            unitId: m['unitId'] as String,
            unitPrice: (m['unitPrice'] as num?)?.toDouble() ?? 0,
            discount: (m['discount'] as num?)?.toDouble() ?? 0,
            tax: (m['tax'] as num?)?.toDouble() ?? 0,
            lineTotal: (m['lineTotal'] as num?)?.toDouble() ?? 0,
            deliveredQuantity:
                (m['deliveredQuantity'] as num?)?.toDouble() ?? 0,
            notes: m['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<void> _validateCustomer(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'customers',
      columns: ['id'],
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('العميل غير موجود أو غير نشط');
  }

  Future<void> _validateItems(
    DatabaseExecutor db,
    List<SalesItem> items,
  ) async {
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل');
    final keys = <String>{};
    for (final item in items) {
      if (item.itemType != SalesItemType.product) {
        throw Exception('مستندات المبيعات تدعم المنتجات فقط');
      }
      if (item.quantity <= 0 ||
          !keys.add('${item.itemType.value}:${item.itemId}')) {
        throw Exception('أصناف المستند غير صالحة أو مكررة');
      }
      await _validateItem(db, item.itemId, item.itemType);
    }
  }

  Future<void> _validateItem(
    DatabaseExecutor db,
    String id,
    SalesItemType type,
  ) async {
    if (type != SalesItemType.product) {
      throw Exception('مستندات المبيعات تدعم المنتجات فقط');
    }
    final rows = await db.query(
      'products',
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الصنف غير موجود أو غير نشط');
  }

  Future<StockItemOption> _resolveItem(
    DatabaseExecutor db,
    String id,
    StockItemType type,
  ) async {
    final row = (await db.query(
      type == StockItemType.product ? 'products' : 'raw_materials',
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    )).firstOrNull;
    if (row == null) throw Exception('الصنف غير موجود أو غير نشط');
    return StockItemOption(
      id: id,
      name: row['name'] as String,
      code: row['code'] as String,
      unitId: row['unitId'] as String,
      type: type,
      active: true,
    );
  }

  Future<void> _validateWarehouse(DatabaseExecutor db, String id) async {
    if ((await db.query(
      'warehouses',
      columns: ['id'],
      where: 'id = ? AND state = ?',
      whereArgs: [id, 'active'],
      limit: 1,
    )).isEmpty) {
      throw Exception('المخزن غير موجود أو غير نشط');
    }
  }

  Map<String, Object?> _quotationMap(Quotation v) => {
    'id': v.id,
    'quotationNumber': v.quotationNumber,
    'customerId': v.customerId,
    'quotationDate': v.quotationDate.millisecondsSinceEpoch,
    'validUntil': v.validUntil?.millisecondsSinceEpoch,
    'status': v.status.name.toUpperCase(),
    'subtotal': v.subtotal,
    'discount': v.discount,
    'tax': v.tax,
    'grandTotal': v.grandTotal,
    'notes': v.notes,
    'createdAt': v.createdAt.millisecondsSinceEpoch,
    'updatedAt': v.updatedAt.millisecondsSinceEpoch,
  };
  Map<String, Object?> _orderMap(SalesOrder v) => {
    'id': v.id,
    'orderNumber': v.orderNumber,
    'customerId': v.customerId,
    'quotationId': v.quotationId,
    'orderDate': v.orderDate.millisecondsSinceEpoch,
    'expectedDeliveryDate': v.expectedDeliveryDate?.millisecondsSinceEpoch,
    'status': v.status.name
        .replaceAll('partiallyDelivered', 'PARTIALLY_DELIVERED')
        .replaceAll('fullyDelivered', 'FULLY_DELIVERED')
        .toUpperCase(),
    'subtotal': v.subtotal,
    'discount': v.discount,
    'tax': v.tax,
    'grandTotal': v.grandTotal,
    'notes': v.notes,
    'createdAt': v.createdAt.millisecondsSinceEpoch,
    'updatedAt': v.updatedAt.millisecondsSinceEpoch,
  };
  Map<String, Object?> _itemMap(String parentId, SalesItem v, String key) {
    final values = <String, Object?>{
      'id': v.id,
      key: parentId,
      'itemId': v.itemId,
      'itemType': v.itemType.value,
      'quantity': v.quantity,
      'unitId': v.unitId,
      'unitPrice': v.unitPrice,
      'discount': v.discount,
      'tax': v.tax,
      'lineTotal': v.lineTotal == 0
          ? v.quantity * v.unitPrice - v.discount + v.tax
          : v.lineTotal,
      'notes': v.notes,
    };
    if (key == 'salesOrderId') {
      values['deliveredQuantity'] = v.deliveredQuantity;
    }
    return values;
  }

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

  QuotationStatus _quotationStatus(String value) =>
      QuotationStatus.values.firstWhere((v) => v.name.toUpperCase() == value);
  SalesOrderStatus _orderStatus(String value) =>
      SalesOrderStatus.values.firstWhere(
        (v) =>
            v.name
                .replaceAll('partiallyDelivered', 'PARTIALLY_DELIVERED')
                .replaceAll('fullyDelivered', 'FULLY_DELIVERED')
                .toUpperCase() ==
            value,
      );
  bool _validQuotationTransition(QuotationStatus from, QuotationStatus to) =>
      from == to ||
      switch (from) {
        QuotationStatus.draft =>
          to == QuotationStatus.sent || to == QuotationStatus.cancelled,
        QuotationStatus.sent =>
          to == QuotationStatus.accepted ||
              to == QuotationStatus.rejected ||
              to == QuotationStatus.expired ||
              to == QuotationStatus.cancelled,
        QuotationStatus.accepted =>
          to == QuotationStatus.converted || to == QuotationStatus.cancelled,
        _ => false,
      };
  bool _validDeliveryDispatchTransition(
    DeliveryDispatchStatus from,
    DeliveryDispatchStatus to,
  ) =>
      from == to ||
      switch (from) {
        DeliveryDispatchStatus.pending =>
          to == DeliveryDispatchStatus.dispatched ||
              to == DeliveryDispatchStatus.cancelled,
        DeliveryDispatchStatus.dispatched =>
          to == DeliveryDispatchStatus.inTransit ||
              to == DeliveryDispatchStatus.cancelled,
        DeliveryDispatchStatus.inTransit =>
          to == DeliveryDispatchStatus.delivered ||
              to == DeliveryDispatchStatus.cancelled,
        DeliveryDispatchStatus.delivered => false,
        DeliveryDispatchStatus.cancelled => false,
      };
  DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
}
