import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
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
      where: q.isEmpty
          ? null
          : "LOWER(name) LIKE ? OR LOWER(code) LIKE ? OR LOWER(COALESCE(phone, '')) LIKE ? OR LOWER(COALESCE(email, '')) LIKE ?",
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%', '%$q%'],
      orderBy: 'name ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<void> saveCustomer(Customer value) async {
    _security.require('SALES_EDIT');
    final trimmedCode = value.code.trim();
    final trimmedName = value.name.trim();
    final phone = value.phone?.trim();
    final email = value.email?.trim();
    if (trimmedName.isEmpty || trimmedCode.isEmpty) {
      throw Exception('اسم وكود العميل مطلوبان');
    }
    if (phone != null &&
        phone.isNotEmpty &&
        !RegExp(r'^[0-9+()\-\s]{7,20}$').hasMatch(phone)) {
      throw Exception('رقم الهاتف غير صالح');
    }
    if (email != null &&
        email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw Exception('البريد الإلكتروني غير صالح');
    }
    final db = await _db;
    final duplicate = await db.query(
      'customers',
      columns: ['id'],
      where: 'LOWER(code) = ? AND id != ?',
      whereArgs: [trimmedCode.toLowerCase(), value.id],
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      throw Exception('كود العميل موجود بالفعل');
    }
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
      if (value.items.any((item) => item.deliveredQuantity != 0)) {
        throw Exception('لا يمكن تحديد كميات التسليم عند حفظ أمر البيع');
      }
      final existing = await txn.query(
        'sales_orders',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [value.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        if (value.status == SalesOrderStatus.partiallyDelivered ||
            value.status == SalesOrderStatus.fullyDelivered) {
          throw Exception('حالة التسليم تحدد عند ترحيل التسليم فقط');
        }
      } else {
        final currentStatus = _orderStatus(existing.single['status'] as String);
        if (currentStatus == SalesOrderStatus.cancelled ||
            currentStatus == SalesOrderStatus.fullyDelivered) {
          throw Exception('لا يمكن تعديل أمر بيع نهائي');
        }
        if (currentStatus == SalesOrderStatus.partiallyDelivered) {
          throw Exception('لا يمكن تعديل أمر بيع تم تسليمه');
        }
        if (value.status != currentStatus) {
          throw Exception('لا يمكن تغيير حالة أمر البيع عند حفظه');
        }
        final existingItems = await txn.query(
          'sales_order_items',
          columns: ['deliveredQuantity'],
          where: 'salesOrderId = ?',
          whereArgs: [value.id],
        );
        final existingDeliveries = await txn.query(
          'sales_deliveries',
          columns: ['id'],
          where: 'salesOrderId = ?',
          whereArgs: [value.id],
          limit: 1,
        );
        if (existingItems.any(
              (row) => (row['deliveredQuantity'] as num).toDouble() > 0,
            ) ||
            existingDeliveries.isNotEmpty) {
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
    final conversion = await db.transaction((txn) async {
      final quotationRows = await txn.query(
        'quotations',
        where: 'id = ?',
        whereArgs: [quotation.id],
        limit: 1,
      );
      if (quotationRows.isEmpty) throw Exception('عرض السعر غير موجود');
      final persistedQuotation = quotationRows.single;
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
        return {
          'created': false,
          'orderId': existingOrders.single['id'] as String,
        };
      }
      if (persistedStatus != QuotationStatus.accepted) {
        throw Exception('يجب قبول عرض السعر قبل تحويله');
      }

      final persistedItems = await txn.query(
        'quotation_items',
        where: 'quotationId = ?',
        whereArgs: [quotation.id],
      );
      final canonicalOrder = _canonicalOrderFromQuotation(
        quotation: persistedQuotation,
        sourceOrder: order,
        persistedItems: persistedItems,
      );
      await _validateCustomer(txn, canonicalOrder.customerId);
      await _validateItems(txn, canonicalOrder.items);
      final duplicateLinkedOrder = await txn.query(
        'sales_orders',
        columns: ['id'],
        where: 'quotationId = ?',
        whereArgs: [quotation.id],
        limit: 1,
      );
      if (duplicateLinkedOrder.isNotEmpty) {
        throw Exception('تم تحويل هذا العرض مسبقاً');
      }
      final changed = await txn.update(
        'quotations',
        {
          'status': 'CONVERTED',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [quotation.id, 'ACCEPTED'],
      );
      if (changed != 1) {
        throw Exception('تم تحويل عرض السعر بالفعل');
      }

      await txn.insert('sales_orders', _orderMap(canonicalOrder));
      for (final item in canonicalOrder.items) {
        await txn.insert(
          'sales_order_items',
          _itemMap(canonicalOrder.id, item, 'salesOrderId'),
        );
      }
      return {'created': true, 'orderId': canonicalOrder.id};
    });

    final rows = await db.query(
      'sales_orders',
      where: 'id = ?',
      whereArgs: [conversion['orderId'] as String],
      limit: 1,
    );
    final convertedOrder = await _order(rows.single);
    if (conversion['created'] as bool) {
      await _security.audit(
        action: 'QUOTATION_TO_ORDER_CONVERSION',
        module: 'Sales',
        entityType: 'Quotation',
        entityId: quotation.id,
        description:
            'Quotation ${quotation.quotationNumber} converted to sales order ${convertedOrder.orderNumber}',
      );
    }
    return convertedOrder;
  }

  SalesOrder _canonicalOrderFromQuotation({
    required Map<String, Object?> quotation,
    required SalesOrder sourceOrder,
    required List<Map<String, Object?>> persistedItems,
  }) {
    final items = persistedItems.map((row) {
      final itemType = row['itemType'] == 'PRODUCT'
          ? SalesItemType.product
          : SalesItemType.rawMaterial;
      final quantity = (row['quantity'] as num).toDouble();
      final unitPrice = (row['unitPrice'] as num).toDouble();
      final discount = (row['discount'] as num?)?.toDouble() ?? 0;
      final tax = (row['tax'] as num?)?.toDouble() ?? 0;
      final lineTotal =
          (row['lineTotal'] as num?)?.toDouble() ??
          quantity * unitPrice - discount + tax;
      return SalesItem(
        id: row['id'] as String,
        itemId: row['productId'] as String? ?? row['itemId'] as String,
        itemType: itemType,
        quantity: quantity,
        unitId: row['unitId'] as String,
        variantId: row['variantId'] as String?,
        baseUnitId: row['baseUnitId'] as String?,
        unitConversionFactor:
            (row['unitConversionFactor'] as num?)?.toDouble() ?? 1,
        baseQuantity: (row['baseQuantity'] as num?)?.toDouble(),
        inventoryIdentityKind:
            row['inventoryIdentityKind'] as String? ?? 'BASE',
        identitySnapshotStatus:
            row['identitySnapshotStatus'] as String? ?? 'VERIFIED',
        unitPrice: unitPrice,
        discount: discount,
        tax: tax,
        lineTotal: lineTotal,
        deliveredQuantity: (row['deliveredQuantity'] as num?)?.toDouble() ?? 0,
        deliveredBaseQuantity:
            (row['deliveredBaseQuantity'] as num?)?.toDouble() ?? 0,
        notes: row['notes'] as String?,
      );
    }).toList();

    return SalesOrder(
      id: sourceOrder.id,
      orderNumber: sourceOrder.orderNumber,
      customerId: quotation['customerId'] as String,
      quotationId: quotation['id'] as String,
      orderDate: sourceOrder.orderDate,
      expectedDeliveryDate: sourceOrder.expectedDeliveryDate,
      status: SalesOrderStatus.draft,
      subtotal: (quotation['subtotal'] as num).toDouble(),
      discount: (quotation['discount'] as num).toDouble(),
      tax: (quotation['tax'] as num).toDouble(),
      grandTotal: (quotation['grandTotal'] as num).toDouble(),
      notes: sourceOrder.notes ?? quotation['notes'] as String?,
      createdAt: sourceOrder.createdAt,
      updatedAt: sourceOrder.updatedAt,
      items: items,
    );
  }

  Future<void> changeOrderStatus(String id, SalesOrderStatus status) async {
    _security.require('SALES_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('أمر البيع غير موجود');
      final persistedStatus = rows.single['status'] as String;
      final current = _orderStatus(persistedStatus);
      if (current == SalesOrderStatus.cancelled ||
          current == SalesOrderStatus.fullyDelivered) {
        throw Exception('لا يمكن تغيير حالة أمر بيع نهائي');
      }
      if (status == SalesOrderStatus.partiallyDelivered ||
          status == SalesOrderStatus.fullyDelivered) {
        throw Exception('حالة التسليم تحدد عند ترحيل التسليم فقط');
      }
      if (!_validOrderStatusTransition(current, status)) {
        throw Exception('انتقال حالة أمر البيع غير مسموح');
      }
      final changed = await txn.update(
        'sales_orders',
        {
          'status': status.name.toUpperCase(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [id, persistedStatus],
      );
      if (changed != 1) throw Exception('تعذر تحديث حالة أمر البيع');
    });
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
    return db.transaction((txn) async {
      final rows = await txn.query(
        'sales_deliveries',
        where: 'id = ?',
        whereArgs: [deliveryId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('التسليم غير موجود');
      final current = SalesDelivery.fromMap(rows.single);
      await _security.requireResourceScope(
        ScopeType.warehouse,
        current.warehouseId,
      );

      if (current.status == status) return current;

      final orderRows = await txn.query(
        'sales_orders',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [current.salesOrderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر البيع غير موجود');
      if (orderRows.single['status'] == 'CANCELLED') {
        throw Exception('لا يمكن تحديث حالة تسليم لأمر بيع ملغى');
      }
      if (status == DeliveryDispatchStatus.cancelled) {
        throw Exception('لا يمكن إلغاء تسليم تم ترحيله للمخزون والمحاسبة');
      }
      if (!_validDeliveryDispatchTransition(current.status, status)) {
        throw Exception('انتقال حالة التسليم غير مسموح');
      }
      final changed = await txn.update(
        'sales_deliveries',
        {
          'status': status.value,
          'dispatchDate':
              dispatchDate?.millisecondsSinceEpoch ??
              current.dispatchDate?.millisecondsSinceEpoch,
          'driverName': driverName ?? current.driverName,
          'vehicleNumber': vehicleNumber ?? current.vehicleNumber,
          'destination': destination ?? current.destination,
          'notes': notes ?? current.notes,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ? AND status = ?',
        whereArgs: [deliveryId, current.status.value],
      );
      if (changed != 1) {
        throw Exception('تغيرت حالة التسليم؛ حدّث القائمة ثم أعد المحاولة');
      }
      final refreshed = await txn.query(
        'sales_deliveries',
        where: 'id = ?',
        whereArgs: [deliveryId],
        limit: 1,
      );
      return SalesDelivery.fromMap(refreshed.single);
    });
  }

  Future<SalesDelivery> postDelivery({
    required SalesOrder order,
    required String warehouseId,
    required DateTime deliveryDate,
    required List<SalesItem> items,
    String? notes,
    required String operationId,
  }) async {
    _security.require('SALES_DELIVER');
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل');
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty) {
      throw Exception('معرف عملية التسليم غير صالح');
    }
    final requestKey = 'CALLER:$normalizedOperationId';
    final db = await _db;
    final persistedDelivery = await db.transaction((txn) async {
      await _validateWarehouse(txn, warehouseId);
      await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
      final orderRows = await txn.query(
        'sales_orders',
        columns: ['status', 'customerId'],
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر البيع غير موجود');
      final persistedCustomerId = orderRows.single['customerId'] as String;
      if (order.customerId != persistedCustomerId) {
        throw Exception('العميل لا يطابق أمر البيع المحفوظ');
      }
      final itemRows = await txn.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [order.id],
      );
      final byId = {for (final row in itemRows) row['id'] as String: row};
      final canonicalLines = <Map<String, Object?>>[];
      final seenSalesOrderItemIds = <String>{};
      for (final item in items) {
        if (!seenSalesOrderItemIds.add(item.id)) {
          throw Exception('لا يمكن تكرار بند أمر البيع في طلب التسليم');
        }
        if (!item.quantity.isFinite || item.quantity <= 0) {
          throw Exception('كمية التسليم غير صالحة');
        }
        final row = byId[item.id];
        if (row == null) throw Exception('صنف التسليم غير موجود في الأمر');
        if ((row['productId'] as String? ?? row['itemId']) != item.itemId ||
            row['itemType'] != item.itemType.value ||
            row['unitId'] != item.unitId ||
            row['variantId'] != item.variantId ||
            row['inventoryIdentityKind'] != item.inventoryIdentityKind ||
            (item.baseUnitId != null && row['baseUnitId'] != item.baseUnitId) ||
            ((row['unitConversionFactor'] as num).toDouble() -
                        item.unitConversionFactor)
                    .abs() >
                0.000000001) {
          throw Exception('هوية الصنف أو الوحدة لا تطابق بند أمر البيع');
        }
        canonicalLines.add({
          'salesOrderItemId': row['id'],
          'productId': row['productId'] ?? row['itemId'],
          'variantId': row['variantId'],
          'unitId': row['unitId'],
          'baseUnitId': row['baseUnitId'],
          'unitConversionFactor': row['unitConversionFactor'],
          'inventoryIdentityKind': row['inventoryIdentityKind'],
          'quantity': item.quantity,
          'notes': item.notes,
        });
      }
      canonicalLines.sort(
        (first, second) => (first['salesOrderItemId'] as String).compareTo(
          second['salesOrderItemId'] as String,
        ),
      );
      final payloadHash = sha256
          .convert(
            utf8.encode(
              jsonEncode([
                order.id,
                warehouseId,
                deliveryDate.millisecondsSinceEpoch,
                notes,
                canonicalLines,
              ]),
            ),
          )
          .toString();
      final existingDeliveries = await txn.query(
        'sales_deliveries',
        where: 'operationId = ?',
        whereArgs: [normalizedOperationId],
        limit: 1,
      );
      if (existingDeliveries.isNotEmpty) {
        final existing = existingDeliveries.single;
        if (existing['operationPayloadHash'] != payloadHash) {
          throw Exception('معرف عملية التسليم مستخدم لبيانات مختلفة');
        }
        return SalesDelivery.fromMap(existing);
      }
      final currentStatus = _orderStatus(orderRows.first['status'] as String);
      if (currentStatus == SalesOrderStatus.cancelled ||
          currentStatus == SalesOrderStatus.fullyDelivered) {
        throw Exception('لا يمكن تسليم أمر البيع');
      }
      if (currentStatus == SalesOrderStatus.draft) {
        throw Exception('يجب تأكيد أمر البيع قبل التسليم');
      }
      final requested = <String, double>{};
      final deliveredById = <String, double>{};
      final deliveredUnitsById = <String, double>{};
      for (final row in itemRows) {
        _validatePersistedOrderLine(row);
      }
      await _validatePersistedDeliveryQuantities(txn, order.id, itemRows);
      for (final item in items) {
        if (!item.quantity.isFinite || item.quantity <= 0) {
          throw Exception('كمية التسليم غير صالحة');
        }
        requested[item.id] = (requested[item.id] ?? 0) + item.quantity;
      }
      for (final entry in requested.entries) {
        final row = byId[entry.key];
        if (row == null) throw Exception('صنف التسليم غير موجود في الأمر');
        final factor = (row['unitConversionFactor'] as num).toDouble();
        final orderedBase = (row['baseQuantity'] as num).toDouble();
        final deliveredBase = (row['deliveredBaseQuantity'] as num).toDouble();
        final requestedBase = entry.value * factor;
        if (!requestedBase.isFinite ||
            entry.value <= 0 ||
            requestedBase > orderedBase - deliveredBase + 0.000001) {
          throw Exception('الكمية المسلمة تتجاوز الكمية المتبقية');
        }
        deliveredById[entry.key] = deliveredBase;
        deliveredUnitsById[entry.key] = (row['deliveredQuantity'] as num)
            .toDouble();
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
        'operationId': normalizedOperationId,
        'operationPayloadHash': payloadHash,
      });
      for (final item in items) {
        final row = byId[item.id];
        if (row == null) throw Exception('صنف التسليم غير موجود في الأمر');
        final ordered = (row['quantity'] as num).toDouble();
        final delivered = deliveredUnitsById[item.id]!;
        if (item.quantity <= 0 || item.quantity > ordered - delivered) {
          throw Exception('الكمية المسلمة تتجاوز الكمية المتبقية');
        }
        final conversionFactor = (row['unitConversionFactor'] as num)
            .toDouble();
        final baseQuantity = item.quantity * conversionFactor;
        if (!baseQuantity.isFinite || baseQuantity <= 0) {
          throw Exception('الكمية الأساسية للتسليم غير صالحة');
        }
        final type = row['itemType'] == 'PRODUCT'
            ? StockItemType.product
            : StockItemType.rawMaterial;
        final stockItem = await _resolveItem(
          txn,
          row['productId'] as String? ?? row['itemId'] as String,
          type,
          variantId: row['variantId'] as String?,
          identityKind: InventoryIdentityKindValue.parse(
            row['inventoryIdentityKind'],
          ),
          unitId: row['baseUnitId'] as String? ?? row['unitId'] as String,
        );
        final valuationRows = await txn.query(
          'inventory_valuations',
          where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
          whereArgs: [warehouseId, stockItem.inventoryId, type.value],
          limit: 1,
        );
        if (valuationRows.isEmpty) {
          throw Exception('تقييم المخزون غير متاح لحساب تكلفة البضاعة');
        }
        final unitCogs = (valuationRows.first['averageCost'] as num).toDouble();
        if (!unitCogs.isFinite || unitCogs < 0) {
          throw Exception('تقييم تكلفة المخزون غير صالح');
        }
        if (valuationRows.single['unitId'] != stockItem.unitId ||
            valuationRows.single['variantId'] != stockItem.variantId ||
            InventoryIdentityKindValue.parse(
                  valuationRows.single['inventoryIdentityKind'],
                ) !=
                stockItem.identityKind) {
          throw Exception('هوية تقييم المخزون لا تطابق بند أمر البيع');
        }
        cogsTotal += baseQuantity * unitCogs;
        if (!cogsTotal.isFinite) {
          throw Exception('إجمالي تكلفة البضاعة غير صالح');
        }
        await _accounting.consumeInventoryValueWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          itemId: stockItem.inventoryId,
          itemType: type.value,
          quantity: baseQuantity,
          productId: stockItem.baseProductId,
          variantId: stockItem.variantId,
          identityKind: stockItem.identityKind,
          unitId: stockItem.unitId,
        );
        final lineTotal = (row['lineTotal'] as num?)?.toDouble() ?? 0;
        revenueTotal += ordered == 0
            ? 0
            : item.quantity * (lineTotal / ordered);
        if (!revenueTotal.isFinite) throw Exception('إجمالي المبيعات غير صالح');
        await _stock.applyStockOutWithinTransaction(
          executor: txn,
          warehouseId: warehouseId,
          item: stockItem,
          quantity: baseQuantity,
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
          'productId': stockItem.baseProductId,
          'variantId': stockItem.variantId,
          'baseUnitId': stockItem.unitId,
          'unitConversionFactor': conversionFactor,
          'baseQuantity': baseQuantity,
          'inventoryIdentityKind': stockItem.identityKind.value,
          'identitySnapshotStatus': row['identitySnapshotStatus'],
          'unitRevenue': ordered == 0 ? 0 : lineTotal / ordered,
          'unitCogs': unitCogs,
          'notes': item.notes,
        });
        await txn.update(
          'sales_order_items',
          {
            'deliveredQuantity': delivered + item.quantity,
            'deliveredBaseQuantity': deliveredById[item.id]! + baseQuantity,
          },
          where: 'id = ?',
          whereArgs: [item.id],
        );
        deliveredById[item.id] = deliveredById[item.id]! + baseQuantity;
        deliveredUnitsById[item.id] = delivered + item.quantity;
      }
      final journalLines = <JournalLineInput>[];
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
        journalLines.addAll([
          JournalLineInput(accountId: receivable, debit: revenueTotal),
          JournalLineInput(accountId: salesRevenue, credit: revenueTotal),
        ]);
      }
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
        journalLines.add(JournalLineInput(accountId: cogs, debit: cogsTotal));
        journalLines.add(
          JournalLineInput(accountId: inventory, credit: cogsTotal),
        );
      }
      if (journalLines.isNotEmpty) {
        await _accounting.postJournalWithinTransaction(
          executor: txn,
          date: deliveryDate,
          description: 'بيع وتسليم $deliveryNumber',
          referenceType: 'SALES_DELIVERY',
          referenceId: deliveryId,
          partyType: 'CUSTOMER',
          partyId: persistedCustomerId,
          lines: journalLines,
        );
      }
      final totals = await txn.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [order.id],
      );
      final complete = totals.every(
        (row) =>
            (row['deliveredBaseQuantity'] as num).toDouble() + 0.000001 >=
            (row['baseQuantity'] as num).toDouble(),
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
      return SalesDelivery.fromMap(
        (await txn.query(
          'sales_deliveries',
          where: 'id = ?',
          whereArgs: [deliveryId],
          limit: 1,
        )).single,
      );
    });
    return persistedDelivery;
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
    return (await _stock.activeItems())
        .where((item) => item.type == StockItemType.product)
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
            itemId: m['productId'] as String? ?? m['itemId'] as String,
            itemType: m['itemType'] == 'PRODUCT'
                ? SalesItemType.product
                : SalesItemType.rawMaterial,
            quantity: (m['quantity'] as num).toDouble(),
            unitId: m['unitId'] as String,
            variantId: m['variantId'] as String?,
            baseUnitId: m['baseUnitId'] as String?,
            unitConversionFactor:
                (m['unitConversionFactor'] as num?)?.toDouble() ?? 1,
            baseQuantity: (m['baseQuantity'] as num?)?.toDouble(),
            deliveredBaseQuantity:
                (m['deliveredBaseQuantity'] as num?)?.toDouble() ?? 0,
            inventoryIdentityKind:
                m['inventoryIdentityKind'] as String? ?? 'BASE',
            identitySnapshotStatus:
                m['identitySnapshotStatus'] as String? ?? 'VERIFIED',
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

  void _validatePersistedOrderLine(Map<String, Object?> row) {
    final quantity = _finiteOrderLineValue(row, 'quantity');
    final deliveredQuantity = _finiteOrderLineValue(row, 'deliveredQuantity');
    final conversionFactor = _finiteOrderLineValue(row, 'unitConversionFactor');
    final baseQuantity = _finiteOrderLineValue(row, 'baseQuantity');
    final deliveredBaseQuantity = _finiteOrderLineValue(
      row,
      'deliveredBaseQuantity',
    );
    final unitPrice = _finiteOrderLineValue(row, 'unitPrice');
    final discount = _finiteOrderLineValue(row, 'discount');
    final tax = _finiteOrderLineValue(row, 'tax');
    final lineTotal = _finiteOrderLineValue(row, 'lineTotal');
    final gross = quantity * unitPrice;

    if (row['identitySnapshotStatus'] != 'VERIFIED') {
      throw Exception('هوية أو وحدة بند الطلب تحتاج إلى مراجعة قبل التسليم');
    }

    if (quantity <= 0 ||
        deliveredQuantity < 0 ||
        deliveredQuantity > quantity ||
        conversionFactor <= 0 ||
        baseQuantity <= 0 ||
        deliveredBaseQuantity < 0 ||
        deliveredBaseQuantity > baseQuantity + 0.000001 ||
        (baseQuantity - quantity * conversionFactor).abs() > 0.000001 ||
        (deliveredBaseQuantity - deliveredQuantity * conversionFactor).abs() >
            0.000001 ||
        unitPrice < 0 ||
        discount < 0 ||
        tax < 0 ||
        !gross.isFinite ||
        discount > gross) {
      throw Exception('بيانات بند أمر البيع غير صالحة');
    }
    final expectedLineTotal = gross - discount + tax;
    if (!expectedLineTotal.isFinite ||
        (lineTotal - expectedLineTotal).abs() > 0.000001) {
      throw Exception('إجمالي بند أمر البيع غير متوافق');
    }
  }

  double _finiteOrderLineValue(Map<String, Object?> row, String column) {
    final value = row[column];
    if (value is! num || !value.toDouble().isFinite) {
      throw Exception('قيمة بند أمر البيع غير صالحة');
    }
    return value.toDouble();
  }

  Future<void> _validatePersistedDeliveryQuantities(
    DatabaseExecutor db,
    String orderId,
    List<Map<String, Object?>> orderItems,
  ) async {
    final deliveryRows = await db.rawQuery(
      '''
      SELECT sdi.salesOrderItemId, SUM(sdi.baseQuantity) AS deliveredQuantity
      FROM sales_delivery_items sdi
      JOIN sales_deliveries sd ON sd.id = sdi.salesDeliveryId
      WHERE sd.salesOrderId = ?
      GROUP BY sdi.salesOrderItemId
      ''',
      [orderId],
    );
    final deliveredByItemId = {
      for (final row in deliveryRows)
        row['salesOrderItemId'] as String: (row['deliveredQuantity'] as num)
            .toDouble(),
    };
    final orderItemIds = {for (final row in orderItems) row['id'] as String};
    if (deliveredByItemId.keys.any((id) => !orderItemIds.contains(id))) {
      throw Exception('سجل التسليم لا يطابق بنود أمر البيع');
    }
    for (final row in orderItems) {
      final itemId = row['id'] as String;
      final persistedQuantity = _finiteOrderLineValue(
        row,
        'deliveredBaseQuantity',
      );
      final recordedQuantity = deliveredByItemId[itemId] ?? 0;
      if (!recordedQuantity.isFinite ||
          (persistedQuantity - recordedQuantity).abs() > 0.000001) {
        throw Exception('كميات التسليم لا تطابق سجل التسليم المحفوظ');
      }
    }
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
      final key =
          '${item.itemType.value}:${item.itemId}:${item.variantId ?? ''}';
      if (!item.quantity.isFinite || item.quantity <= 0 || !keys.add(key)) {
        throw Exception('أصناف المستند غير صالحة أو مكررة');
      }
      await _validateItem(db, item);
    }
  }

  Future<void> _validateItem(DatabaseExecutor db, SalesItem item) async {
    if (item.itemType != SalesItemType.product) {
      throw Exception('مستندات المبيعات تدعم المنتجات فقط');
    }
    final rows = await db.query(
      'products',
      columns: ['id', 'unitId'],
      where: 'id = ? AND active = 1',
      whereArgs: [item.itemId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الصنف غير موجود أو غير نشط');
    final baseUnitId = rows.single['unitId'] as String;
    if (item.baseUnitId != null && item.baseUnitId != baseUnitId) {
      throw Exception('الوحدة الأساسية للطلب لا تطابق المنتج');
    }
    if (item.identitySnapshotStatus != 'VERIFIED') {
      throw Exception('هوية أو وحدة بند الطلب تحتاج إلى مراجعة قبل الحفظ');
    }
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
    final expectedIdentity = item.variantId == null ? 'BASE' : 'VARIANT';
    if (item.inventoryIdentityKind != expectedIdentity) {
      throw Exception('هوية المخزون لا تطابق المنتج المحدد');
    }
    if (!item.unitConversionFactor.isFinite || item.unitConversionFactor <= 0) {
      throw Exception('معامل تحويل الوحدة غير صالح');
    }
    if (item.unitId == baseUnitId) {
      if (item.unitConversionFactor != 1) {
        throw Exception('معامل تحويل الوحدة الأساسية يجب أن يساوي واحداً');
      }
    } else {
      final conversion = await db.query(
        'product_unit_conversions',
        columns: ['factorToBase'],
        where: 'productId = ? AND unitId = ? AND active = 1',
        whereArgs: [item.itemId, item.unitId],
        limit: 1,
      );
      if (conversion.isEmpty) throw Exception('وحدة البيع غير معتمدة للمنتج');
      final factor = (conversion.single['factorToBase'] as num).toDouble();
      if (!factor.isFinite ||
          factor <= 0 ||
          (item.unitConversionFactor - factor).abs() > 0.000000001) {
        throw Exception('لقطة تحويل وحدة البيع غير صالحة');
      }
    }
    final normalized = item.quantity * item.unitConversionFactor;
    if (!normalized.isFinite ||
        (item.baseQuantity != null &&
            (item.baseQuantity! - normalized).abs() > 0.000001)) {
      throw Exception('الكمية الأساسية المسجلة غير متوافقة');
    }
  }

  Future<StockItemOption> _resolveItem(
    DatabaseExecutor db,
    String id,
    StockItemType type, {
    String? variantId,
    InventoryIdentityKind identityKind = InventoryIdentityKind.base,
    String? unitId,
  }) async {
    final row = (await db.query(
      type == StockItemType.product ? 'products' : 'raw_materials',
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    )).firstOrNull;
    if (row == null) throw Exception('الصنف غير موجود أو غير نشط');
    if (identityKind == InventoryIdentityKind.legacyUnassigned) {
      throw Exception('لا يمكن استخدام المخزون القديم غير المخصص');
    }
    if (type == StockItemType.product) {
      final variants = await db.query(
        'product_variants',
        columns: ['id'],
        where: 'productId = ? AND active = 1',
        whereArgs: [id],
        limit: 1,
      );
      if (variantId == null && variants.isNotEmpty) {
        throw Exception('يجب تحديد متغير المنتج للتسليم');
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
    }
    return StockItemOption(
      id: id,
      productId: type == StockItemType.product ? id : null,
      variantId: variantId,
      name: row['name'] as String,
      code: row['code'] as String,
      unitId: unitId ?? row['unitId'] as String,
      type: type,
      active: true,
      identityKind: identityKind,
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
  String _salesLineStorageId(SalesItem item) => item.variantId == null
      ? item.itemId
      : inventoryItemKey(
          productId: item.itemId,
          type: StockItemType.product,
          variantId: item.variantId,
          identityKind: InventoryIdentityKindValue.parse(
            item.inventoryIdentityKind,
          ),
        );

  Map<String, Object?> _itemMap(String parentId, SalesItem v, String key) {
    final values = <String, Object?>{
      'id': v.id,
      key: parentId,
      'itemId': _salesLineStorageId(v),
      'productId': v.itemId,
      'itemType': v.itemType.value,
      'quantity': v.quantity,
      'unitId': v.unitId,
      'variantId': v.variantId,
      'baseUnitId': v.baseUnitId ?? v.unitId,
      'unitConversionFactor': v.unitConversionFactor,
      'baseQuantity': v.baseQuantity ?? v.quantity * v.unitConversionFactor,
      'inventoryIdentityKind': v.inventoryIdentityKind,
      'identitySnapshotStatus': v.identitySnapshotStatus,
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
      values['deliveredBaseQuantity'] = v.deliveredBaseQuantity;
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
  bool _validOrderStatusTransition(
    SalesOrderStatus from,
    SalesOrderStatus to,
  ) => switch (from) {
    SalesOrderStatus.draft =>
      to == SalesOrderStatus.confirmed || to == SalesOrderStatus.cancelled,
    SalesOrderStatus.confirmed => to == SalesOrderStatus.cancelled,
    SalesOrderStatus.partiallyDelivered => to == SalesOrderStatus.cancelled,
    SalesOrderStatus.fullyDelivered || SalesOrderStatus.cancelled => false,
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
