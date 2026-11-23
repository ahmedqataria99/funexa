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
      if (value.items.any((item) => item.invoicedQuantity != 0)) {
        throw Exception('لا يمكن تحديد كميات الفوترة عند حفظ أمر البيع');
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
          columns: ['deliveredQuantity', 'invoicedQuantity'],
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
            existingItems.any(
              (row) => (row['invoicedQuantity'] as num? ?? 0).toDouble() > 0,
            ) ||
            existingDeliveries.isNotEmpty) {
          throw Exception('لا يمكن تعديل أمر بيع تم تسليمه');
        }
        final existingInvoices = await txn.query(
          'sales_invoices',
          columns: ['id'],
          where: 'salesOrderId = ?',
          whereArgs: [value.id],
          limit: 1,
        );
        if (existingInvoices.isNotEmpty) {
          throw Exception('لا يمكن تعديل أمر بيع تمت فوترته');
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

  Future<SalesInvoice> issueInvoice({
    required String salesOrderId,
    required DateTime invoiceDate,
    required List<SalesInvoiceLineRequest> items,
    required String operationId,
    double invoiceDiscount = 0,
  }) async {
    _security.require('SALES_EDIT');
    _security.require('ACCOUNTING_POST');
    if (items.isEmpty) throw Exception('أضف صنفاً واحداً على الأقل للفاتورة');
    final normalizedOperationId = operationId.trim();
    if (normalizedOperationId.isEmpty) {
      throw Exception('معرف عملية الفاتورة غير صالح');
    }
    if (!invoiceDiscount.isFinite || invoiceDiscount < 0) {
      throw Exception('خصم الفاتورة غير صالح');
    }
    final requests = [...items]
      ..sort(
        (first, second) =>
            first.salesOrderItemId.compareTo(second.salesOrderItemId),
      );
    final seenItemIds = <String>{};
    for (final item in requests) {
      if (!seenItemIds.add(item.salesOrderItemId) ||
          !item.quantity.isFinite ||
          item.quantity <= 0) {
        throw Exception('كمية بند الفاتورة غير صالحة');
      }
    }
    final payloadHash = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              salesOrderId,
              invoiceDate.millisecondsSinceEpoch,
              invoiceDiscount,
              [
                for (final item in requests)
                  [item.salesOrderItemId, item.quantity],
              ],
            ]),
          ),
        )
        .toString();
    final db = await _db;
    return db.transaction((txn) async {
      final existingInvoices = await txn.query(
        'sales_invoices',
        where: 'operationId = ?',
        whereArgs: [normalizedOperationId],
        limit: 1,
      );
      if (existingInvoices.isNotEmpty) {
        final existing = existingInvoices.single;
        if (existing['operationPayloadHash'] != payloadHash) {
          throw Exception('معرف عملية الفاتورة مستخدم لبيانات مختلفة');
        }
        return SalesInvoice.fromMap(existing);
      }

      final orderRows = await txn.query(
        'sales_orders',
        columns: ['customerId', 'status'],
        where: 'id = ?',
        whereArgs: [salesOrderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر البيع غير موجود');
      final orderStatus = _orderStatus(orderRows.single['status'] as String);
      if (orderStatus == SalesOrderStatus.draft ||
          orderStatus == SalesOrderStatus.cancelled) {
        throw Exception('يجب تأكيد أمر البيع قبل إصدار الفاتورة');
      }
      final customerId = orderRows.single['customerId'] as String;
      await _validateCustomer(txn, customerId);
      final orderRowsItems = await txn.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [salesOrderId],
      );
      final orderItems = {
        for (final row in orderRowsItems) row['id'] as String: row,
      };
      final calculations = <Map<String, Object?>>[];
      var subtotal = 0.0;
      var orderDiscountTotal = 0.0;
      var taxTotal = 0.0;
      var invoiceDiscountBasis = 0.0;
      for (final request in requests) {
        final row = orderItems[request.salesOrderItemId];
        if (row == null) throw Exception('بند الفاتورة غير موجود في أمر البيع');
        _validatePersistedOrderLine(row);
        final orderedQuantity = (row['quantity'] as num).toDouble();
        final alreadyInvoiced =
            (row['invoicedQuantity'] as num?)?.toDouble() ?? 0;
        if (request.quantity > orderedQuantity - alreadyInvoiced + 0.000001) {
          throw Exception('كمية الفاتورة تتجاوز الكمية غير المفوترة');
        }
        final factor = request.quantity / orderedQuantity;
        final unitPrice = (row['unitPrice'] as num).toDouble();
        final gross = unitPrice * request.quantity;
        final orderDiscount = (row['discount'] as num).toDouble() * factor;
        final tax = (row['tax'] as num).toDouble() * factor;
        final discountBasis = gross - orderDiscount;
        if (![
          gross,
          orderDiscount,
          tax,
          discountBasis,
        ].every((value) => value.isFinite && value >= 0)) {
          throw Exception('إجمالي بند الفاتورة غير صالح');
        }
        calculations.add({
          'request': request,
          'row': row,
          'gross': gross,
          'orderDiscount': orderDiscount,
          'invoiceDiscount': 0.0,
          'tax': tax,
        });
        subtotal += gross;
        orderDiscountTotal += orderDiscount;
        taxTotal += tax;
        invoiceDiscountBasis += discountBasis;
      }
      if (invoiceDiscount > invoiceDiscountBasis + 0.000001) {
        throw Exception('خصم الفاتورة يتجاوز قيمة البنود');
      }
      var remainingInvoiceDiscount = invoiceDiscount;
      for (var index = 0; index < calculations.length; index++) {
        final line = calculations[index];
        final basis =
            (line['gross'] as double) - (line['orderDiscount'] as double);
        final allocation = index == calculations.length - 1
            ? remainingInvoiceDiscount
            : invoiceDiscountBasis == 0
            ? 0.0
            : invoiceDiscount * basis / invoiceDiscountBasis;
        line['invoiceDiscount'] = allocation;
        remainingInvoiceDiscount -= allocation;
      }
      final totalDiscount = orderDiscountTotal + invoiceDiscount;
      final grandTotal = subtotal - totalDiscount + taxTotal;
      if (!grandTotal.isFinite || grandTotal < -0.000001) {
        throw Exception('إجمالي الفاتورة غير صالح');
      }

      final invoiceId = _id('sales-invoice');
      final invoiceNumber = _id('INV');
      final createdAt = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('sales_invoices', {
        'id': invoiceId,
        'invoiceNumber': invoiceNumber,
        'salesOrderId': salesOrderId,
        'customerId': customerId,
        'invoiceDate': invoiceDate.millisecondsSinceEpoch,
        'subtotal': subtotal,
        'discount': totalDiscount,
        'tax': taxTotal,
        'grandTotal': grandTotal < 0 ? 0 : grandTotal,
        'status': 'POSTED',
        'operationId': normalizedOperationId,
        'operationPayloadHash': payloadHash,
        'createdAt': createdAt,
        'updatedAt': createdAt,
      });
      for (final line in calculations) {
        final request = line['request'] as SalesInvoiceLineRequest;
        final row = line['row'] as Map<String, Object?>;
        final lineGross = line['gross'] as double;
        final orderDiscount = line['orderDiscount'] as double;
        final lineInvoiceDiscount = line['invoiceDiscount'] as double;
        final tax = line['tax'] as double;
        await txn.insert('sales_invoice_items', {
          'id': _id('sales-invoice-item'),
          'salesInvoiceId': invoiceId,
          'salesOrderItemId': request.salesOrderItemId,
          'quantity': request.quantity,
          'unitId': row['unitId'],
          'unitPrice': row['unitPrice'],
          'orderDiscount': orderDiscount,
          'invoiceDiscount': lineInvoiceDiscount,
          'tax': tax,
          'lineTotal': lineGross - orderDiscount - lineInvoiceDiscount + tax,
        });
        final priorQuantity =
            (row['invoicedQuantity'] as num?)?.toDouble() ?? 0;
        final changed = await txn.update(
          'sales_order_items',
          {'invoicedQuantity': priorQuantity + request.quantity},
          where: 'id = ? AND invoicedQuantity = ?',
          whereArgs: [request.salesOrderItemId, priorQuantity],
        );
        if (changed != 1) {
          throw Exception('تغيرت كمية الفوترة؛ حدّث القائمة ثم أعد المحاولة');
        }
      }
      if (grandTotal > 0) {
        Future<String> accountId(String code) async {
          final rows = await txn.query(
            'accounts',
            columns: ['id'],
            where: 'code = ? AND active = 1',
            whereArgs: [code],
            limit: 1,
          );
          if (rows.isEmpty) throw Exception('حساب الفاتورة غير متاح');
          return rows.single['id'] as String;
        }

        await _accounting.postJournalWithinTransaction(
          executor: txn,
          date: invoiceDate,
          description: 'فاتورة مبيعات $invoiceNumber',
          referenceType: 'SALES_INVOICE',
          referenceId: invoiceId,
          partyType: 'CUSTOMER',
          partyId: customerId,
          lines: [
            JournalLineInput(
              accountId: await accountId('1200'),
              debit: grandTotal,
            ),
            JournalLineInput(
              accountId: await accountId('4000'),
              credit: grandTotal,
            ),
          ],
        );
      }
      await _recordSalesInvoiceAudit(txn, invoiceId, invoiceNumber);
      final invoiceRows = await txn.query(
        'sales_invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      return SalesInvoice.fromMap(invoiceRows.single);
    });
  }

  Future<SalesOrder> updateSalesOrderItemPrice({
    required String salesOrderId,
    required String salesOrderItemId,
    required double unitPrice,
  }) async {
    _security.require('SALES_EDIT');
    if (!unitPrice.isFinite || unitPrice < 0) {
      throw Exception('سعر البيع غير صالح');
    }
    final db = await _db;
    return db.transaction((txn) async {
      final orderRows = await txn.query(
        'sales_orders',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [salesOrderId],
        limit: 1,
      );
      if (orderRows.isEmpty) throw Exception('أمر البيع غير موجود');
      final status = _orderStatus(orderRows.single['status'] as String);
      if (status != SalesOrderStatus.draft &&
          status != SalesOrderStatus.confirmed) {
        throw Exception('لا يمكن تعديل سعر أمر بيع نهائي');
      }
      final deliveryRows = await txn.query(
        'sales_deliveries',
        columns: ['id'],
        where: 'salesOrderId = ?',
        whereArgs: [salesOrderId],
        limit: 1,
      );
      final invoiceRows = await txn.query(
        'sales_invoices',
        columns: ['id'],
        where: 'salesOrderId = ?',
        whereArgs: [salesOrderId],
        limit: 1,
      );
      if (deliveryRows.isNotEmpty || invoiceRows.isNotEmpty) {
        throw Exception('لا يمكن تعديل سعر أمر بيع له تسليم أو فاتورة');
      }
      final itemRows = await txn.query(
        'sales_order_items',
        where: 'id = ? AND salesOrderId = ?',
        whereArgs: [salesOrderItemId, salesOrderId],
        limit: 1,
      );
      if (itemRows.isEmpty) throw Exception('بند أمر البيع غير موجود');
      final item = itemRows.single;
      _validatePersistedOrderLine(item);
      final quantity = (item['quantity'] as num).toDouble();
      final discount = (item['discount'] as num).toDouble();
      final tax = (item['tax'] as num).toDouble();
      final lineTotal = quantity * unitPrice - discount + tax;
      if (!lineTotal.isFinite || lineTotal < 0) {
        throw Exception('السعر الجديد لا يغطي خصم البند');
      }
      final oldPrice = (item['unitPrice'] as num).toDouble();
      final changed = await txn.update(
        'sales_order_items',
        {'unitPrice': unitPrice, 'lineTotal': lineTotal},
        where: 'id = ? AND salesOrderId = ? AND unitPrice = ?',
        whereArgs: [salesOrderItemId, salesOrderId, oldPrice],
      );
      if (changed != 1) throw Exception('تغير سعر البند؛ حدّث القائمة');

      final orderItems = await txn.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [salesOrderId],
      );
      final subtotal = orderItems.fold<double>(
        0,
        (sum, row) =>
            sum +
            (row['quantity'] as num).toDouble() *
                (row['unitPrice'] as num).toDouble(),
      );
      final totalDiscount = orderItems.fold<double>(
        0,
        (sum, row) => sum + (row['discount'] as num).toDouble(),
      );
      final totalTax = orderItems.fold<double>(
        0,
        (sum, row) => sum + (row['tax'] as num).toDouble(),
      );
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      await txn.update(
        'sales_orders',
        {
          'subtotal': subtotal,
          'discount': totalDiscount,
          'tax': totalTax,
          'grandTotal': subtotal - totalDiscount + totalTax,
          'updatedAt': updatedAt,
        },
        where: 'id = ?',
        whereArgs: [salesOrderId],
      );
      final session = _security.session;
      await txn.insert('audit_logs', {
        'id': _id('audit'),
        'userId': session?.user.id,
        'usernameSnapshot': session?.user.username ?? 'SYSTEM',
        'action': 'SALES_ORDER_PRICE_CHANGED',
        'module': 'SALES',
        'entityType': 'SALES_ORDER_ITEM',
        'entityId': salesOrderItemId,
        'timestamp': updatedAt,
        'oldValue': oldPrice.toStringAsFixed(2),
        'newValue': unitPrice.toStringAsFixed(2),
        'description': 'Sales order item selling price changed',
      });
      final refreshed = await txn.query(
        'sales_orders',
        where: 'id = ?',
        whereArgs: [salesOrderId],
        limit: 1,
      );
      return _order(refreshed.single);
    });
  }

  Future<void> _recordSalesInvoiceAudit(
    DatabaseExecutor txn,
    String invoiceId,
    String invoiceNumber,
  ) async {
    final session = _security.session;
    await txn.insert('audit_logs', {
      'id': _id('audit'),
      'userId': session?.user.id,
      'usernameSnapshot': session?.user.username ?? 'SYSTEM',
      'action': 'SALES_INVOICE_POSTED',
      'module': 'SALES',
      'entityType': 'SALES_INVOICE',
      'entityId': invoiceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'oldValue': null,
      'newValue': 'POSTED',
      'description': 'Sales invoice $invoiceNumber posted',
    });
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
      if (status == SalesOrderStatus.cancelled) {
        final activeDeliveries = await txn.query(
          'sales_deliveries',
          where:
              'salesOrderId = ? AND inventoryPosted = 0 AND status IN (?, ?, ?)',
          whereArgs: [
            id,
            DeliveryDispatchStatus.pending.value,
            DeliveryDispatchStatus.dispatched.value,
            DeliveryDispatchStatus.inTransit.value,
          ],
        );
        if (activeDeliveries.any(
          (delivery) =>
              delivery['status'] != DeliveryDispatchStatus.pending.value,
        )) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.cancellationAfterDispatch,
          );
        }
        for (final delivery in activeDeliveries) {
          await txn.update(
            'sales_deliveries',
            {
              'status': DeliveryDispatchStatus.cancelled.value,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ? AND status = ? AND inventoryPosted = 0',
            whereArgs: [delivery['id'], DeliveryDispatchStatus.pending.value],
          );
          await _recordDeliveryAudit(
            txn,
            deliveryId: delivery['id'] as String,
            oldStatus: DeliveryDispatchStatus.pending,
            newStatus: DeliveryDispatchStatus.cancelled,
          );
        }
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
    final warehouseIds = _security.authorizedWarehouseIds.toList()..sort();
    if (!_security.hasUnrestrictedWarehouseAccess && warehouseIds.isEmpty) {
      return [];
    }
    final whereArgs = <Object?>[orderId];
    final warehousePredicate = _security.hasUnrestrictedWarehouseAccess
        ? '1 = 1'
        : 'deliveryWarehouse.id IN (${List.filled(warehouseIds.length, '?').join(', ')})';
    if (!_security.hasUnrestrictedWarehouseAccess) {
      whereArgs.addAll(warehouseIds);
    }
    final rows = await (await _db).rawQuery('''
      SELECT sd.*
      FROM sales_deliveries sd
      JOIN warehouses deliveryWarehouse ON deliveryWarehouse.id = sd.warehouseId
      JOIN factories deliveryFactory ON deliveryFactory.id = deliveryWarehouse.factoryId
      WHERE sd.salesOrderId = ? AND $warehousePredicate
      ORDER BY sd.deliveryDate DESC
      ''', whereArgs);
    return rows.map(SalesDelivery.fromMap).toList();
  }

  Future<DeliveryStockAvailability> deliveryAvailability({
    required String warehouseId,
    required SalesItem orderItem,
  }) async {
    _security.require('SALES_VIEW');
    final db = await _db;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'sales_order_items',
        where: 'id = ?',
        whereArgs: [orderItem.id],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('صنف أمر البيع غير موجود');
      final row = rows.single;
      if ((row['productId'] as String? ?? row['itemId']) != orderItem.itemId ||
          row['itemType'] != orderItem.itemType.value ||
          row['variantId'] != orderItem.variantId) {
        throw Exception('هوية صنف أمر البيع تغيرت؛ حدّث القائمة');
      }
      final type = row['itemType'] == 'PRODUCT'
          ? StockItemType.product
          : StockItemType.rawMaterial;
      final item = await _resolveItem(
        txn,
        row['productId'] as String? ?? row['itemId'] as String,
        type,
        variantId: row['variantId'] as String?,
        identityKind: InventoryIdentityKindValue.parse(
          row['inventoryIdentityKind'],
        ),
        unitId: row['baseUnitId'] as String? ?? row['unitId'] as String,
      );
      final stock = await _deliveryStockAvailability(
        txn,
        warehouseId: warehouseId,
        item: item,
        salesOrderItemId: orderItem.id,
      );
      return stock;
    });
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
      final inventoryPosted = (rows.single['inventoryPosted'] as int?) ?? 1;
      await _security.requireResourceScope(
        ScopeType.warehouse,
        current.warehouseId,
      );

      if (current.status == status) return current;

      if (status == DeliveryDispatchStatus.cancelled) {
        if (current.status != DeliveryDispatchStatus.pending ||
            inventoryPosted != 0) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.cancellationAfterDispatch,
          );
        }
        final changed = await txn.update(
          'sales_deliveries',
          {
            'status': DeliveryDispatchStatus.cancelled.value,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ? AND status = ? AND inventoryPosted = 0',
          whereArgs: [deliveryId, current.status.value],
        );
        if (changed != 1) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.invalidTransition,
          );
        }
        await _recordDeliveryAudit(
          txn,
          deliveryId: deliveryId,
          oldStatus: current.status,
          newStatus: status,
        );
        final refreshed = await txn.query(
          'sales_deliveries',
          where: 'id = ?',
          whereArgs: [deliveryId],
          limit: 1,
        );
        return SalesDelivery.fromMap(refreshed.single);
      }

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
      if (!_validDeliveryDispatchTransition(current.status, status)) {
        throw const SalesDeliveryException(
          SalesDeliveryFailure.invalidTransition,
        );
      }
      if (status == DeliveryDispatchStatus.delivered) {
        await _completeDeliveryWithinTransaction(
          txn,
          delivery: current,
          currentInventoryPosted: inventoryPosted,
        );
      } else {
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
          where: 'id = ? AND status = ? AND inventoryPosted = ?',
          whereArgs: [deliveryId, current.status.value, inventoryPosted],
        );
        if (changed != 1) {
          throw Exception('تغيرت حالة التسليم؛ حدّث القائمة ثم أعد المحاولة');
        }
        await _recordDeliveryAudit(
          txn,
          deliveryId: deliveryId,
          oldStatus: current.status,
          newStatus: status,
        );
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

  Future<void> _completeDeliveryWithinTransaction(
    DatabaseExecutor txn, {
    required SalesDelivery delivery,
    required int currentInventoryPosted,
  }) async {
    if (currentInventoryPosted == 0) {
      final lines = await txn.query(
        'sales_delivery_items',
        where: 'salesDeliveryId = ?',
        whereArgs: [delivery.id],
        orderBy: 'id ASC',
      );
      if (lines.isEmpty) {
        throw const SalesDeliveryException(
          SalesDeliveryFailure.reservationMissing,
        );
      }
      for (final line in lines) {
        final orderRows = await txn.query(
          'sales_order_items',
          where: 'id = ? AND salesOrderId = ?',
          whereArgs: [line['salesOrderItemId'], delivery.salesOrderId],
          limit: 1,
        );
        if (orderRows.isEmpty) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.reservationMissing,
          );
        }
        final orderLine = orderRows.single;
        final itemType = orderLine['itemType'] == 'PRODUCT'
            ? StockItemType.product
            : StockItemType.rawMaterial;
        final inventoryItem = await _resolveItem(
          txn,
          orderLine['productId'] as String? ?? orderLine['itemId'] as String,
          itemType,
          variantId: orderLine['variantId'] as String?,
          identityKind: InventoryIdentityKindValue.parse(
            orderLine['inventoryIdentityKind'],
          ),
          unitId:
              orderLine['baseUnitId'] as String? ??
              orderLine['unitId'] as String,
        );
        if (line['productId'] != inventoryItem.baseProductId ||
            line['variantId'] != inventoryItem.variantId ||
            line['baseUnitId'] != inventoryItem.unitId ||
            InventoryIdentityKindValue.parse(line['inventoryIdentityKind']) !=
                inventoryItem.identityKind) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.reservationMissing,
          );
        }
        final quantity = (line['baseQuantity'] as num).toDouble();
        final deliveredQuantity = (line['deliveredQuantity'] as num).toDouble();
        final conversionFactor = (line['unitConversionFactor'] as num)
            .toDouble();
        if (!quantity.isFinite ||
            quantity <= 0 ||
            !deliveredQuantity.isFinite ||
            deliveredQuantity <= 0 ||
            !conversionFactor.isFinite ||
            conversionFactor <= 0 ||
            (quantity - deliveredQuantity * conversionFactor).abs() >
                0.000001) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.reservationMissing,
          );
        }
        final availability = await _deliveryStockAvailability(
          txn,
          warehouseId: delivery.warehouseId,
          item: inventoryItem,
          salesOrderItemId: line['salesOrderItemId'] as String,
        );
        if (availability.orderReservedBaseQuantity + 0.000001 < quantity) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.reservationMissing,
          );
        }
        if (availability.physicalBaseQuantity + 0.000001 < quantity) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.physicalStockInsufficient,
          );
        }

        await _stock.applyStockOutWithinTransaction(
          executor: txn,
          warehouseId: delivery.warehouseId,
          item: inventoryItem,
          quantity: quantity,
          date: delivery.deliveryDate,
          reference: delivery.deliveryNumber,
          notes: delivery.notes,
        );
        final deliveredBaseBefore = (orderLine['deliveredBaseQuantity'] as num)
            .toDouble();
        final deliveredBefore = (orderLine['deliveredQuantity'] as num)
            .toDouble();
        final changedLine = await txn.update(
          'sales_order_items',
          {
            'deliveredBaseQuantity': deliveredBaseBefore + quantity,
            'deliveredQuantity': deliveredBefore + deliveredQuantity,
          },
          where: 'id = ? AND salesOrderId = ?',
          whereArgs: [line['salesOrderItemId'], delivery.salesOrderId],
        );
        if (changedLine != 1) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.reservationMissing,
          );
        }
      }
    }

    final changedDelivery = await txn.update(
      'sales_deliveries',
      {
        'status': DeliveryDispatchStatus.delivered.value,
        'inventoryPosted': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND status = ? AND inventoryPosted = ?',
      whereArgs: [delivery.id, delivery.status.value, currentInventoryPosted],
    );
    if (changedDelivery != 1) {
      throw const SalesDeliveryException(
        SalesDeliveryFailure.invalidTransition,
      );
    }
    if (currentInventoryPosted == 0) {
      final totals = await txn.query(
        'sales_order_items',
        where: 'salesOrderId = ?',
        whereArgs: [delivery.salesOrderId],
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
        whereArgs: [delivery.salesOrderId],
      );
    }
    await _recordDeliveryAudit(
      txn,
      deliveryId: delivery.id,
      oldStatus: delivery.status,
      newStatus: DeliveryDispatchStatus.delivered,
    );
  }

  Future<void> _recordDeliveryAudit(
    DatabaseExecutor txn, {
    required String deliveryId,
    required DeliveryDispatchStatus oldStatus,
    required DeliveryDispatchStatus newStatus,
  }) async {
    final session = _security.session;
    await txn.insert('audit_logs', {
      'id': _id('audit'),
      'userId': session?.user.id,
      'usernameSnapshot': session?.user.username ?? 'SYSTEM',
      'action': 'DELIVERY_STATUS_CHANGED',
      'module': 'SALES',
      'entityType': 'SALES_DELIVERY',
      'entityId': deliveryId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'oldValue': oldStatus.value,
      'newValue': newStatus.value,
      'description': 'Sales delivery status changed',
    });
  }

  Future<void> _recordDeliveryReservationAudit(
    DatabaseExecutor txn,
    String deliveryId,
  ) async {
    final session = _security.session;
    await txn.insert('audit_logs', {
      'id': _id('audit'),
      'userId': session?.user.id,
      'usernameSnapshot': session?.user.username ?? 'SYSTEM',
      'action': 'DELIVERY_RESERVED',
      'module': 'SALES',
      'entityType': 'SALES_DELIVERY',
      'entityId': deliveryId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'oldValue': null,
      'newValue': DeliveryDispatchStatus.pending.value,
      'description': 'Sales delivery stock reserved',
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
      await _validateWarehouse(txn, warehouseId);
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
      final resolvedItemsById = <String, StockItemOption>{};
      final requestedByStockIdentity =
          <(String, String, String, String), double>{};
      final availableByStockIdentity =
          <(String, String, String, String), double>{};
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
        if (!requestedBase.isFinite || entry.value <= 0) {
          throw Exception('الكمية الأساسية للتسليم غير صالحة');
        }
        final itemType = row['itemType'] == 'PRODUCT'
            ? StockItemType.product
            : StockItemType.rawMaterial;
        final stockItem = await _resolveItem(
          txn,
          row['productId'] as String? ?? row['itemId'] as String,
          itemType,
          variantId: row['variantId'] as String?,
          identityKind: InventoryIdentityKindValue.parse(
            row['inventoryIdentityKind'],
          ),
          unitId: row['baseUnitId'] as String? ?? row['unitId'] as String,
        );
        final availability = await _deliveryStockAvailability(
          txn,
          warehouseId: warehouseId,
          item: stockItem,
          salesOrderItemId: entry.key,
        );
        if (requestedBase >
                orderedBase -
                    deliveredBase -
                    availability.orderReservedBaseQuantity +
                    0.000001 ||
            requestedBase > availability.availableBaseQuantity + 0.000001) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.insufficientAvailableStock,
          );
        }
        if (requestedBase > orderedBase - deliveredBase + 0.000001) {
          throw Exception('الكمية المسلمة تتجاوز الكمية المتبقية');
        }
        final stockIdentity = (
          stockItem.inventoryId,
          itemType.value,
          stockItem.unitId,
          stockItem.identityKind.value,
        );
        requestedByStockIdentity.update(
          stockIdentity,
          (quantity) => quantity + requestedBase,
          ifAbsent: () => requestedBase,
        );
        availableByStockIdentity[stockIdentity] =
            availability.availableBaseQuantity;
        resolvedItemsById[entry.key] = stockItem;
        deliveredById[entry.key] = deliveredBase;
        deliveredUnitsById[entry.key] = (row['deliveredQuantity'] as num)
            .toDouble();
      }
      for (final entry in requestedByStockIdentity.entries) {
        if (entry.value > availableByStockIdentity[entry.key]! + 0.000001) {
          throw const SalesDeliveryException(
            SalesDeliveryFailure.insufficientAvailableStock,
          );
        }
      }
      final deliveryId = _id('delivery');
      final deliveryNumber = _number('DL');
      await txn.insert('sales_deliveries', {
        'id': deliveryId,
        'deliveryNumber': deliveryNumber,
        'salesOrderId': order.id,
        'warehouseId': warehouseId,
        'deliveryDate': deliveryDate.millisecondsSinceEpoch,
        'status': DeliveryDispatchStatus.pending.value,
        'inventoryPosted': 0,
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
        final conversionFactor = (row['unitConversionFactor'] as num)
            .toDouble();
        final baseQuantity = requested[item.id]! * conversionFactor;
        if (!baseQuantity.isFinite || baseQuantity <= 0) {
          throw Exception('الكمية الأساسية للتسليم غير صالحة');
        }
        final stockItem = resolvedItemsById[item.id]!;
        final lineTotal = (row['lineTotal'] as num?)?.toDouble() ?? 0;
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
          'unitRevenue': lineTotal / (row['quantity'] as num).toDouble(),
          'notes': item.notes,
        });
      }
      await _recordDeliveryReservationAudit(txn, deliveryId);
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
    final warehouseIds = _security.authorizedWarehouseIds.toList()..sort();
    if (!_security.hasUnrestrictedWarehouseAccess && warehouseIds.isEmpty) {
      return [];
    }
    final whereArgs = <Object?>['active', WarehousePurpose.sellable.value];
    final warehousePredicate = _security.hasUnrestrictedWarehouseAccess
        ? '1 = 1'
        : 'w.id IN (${List.filled(warehouseIds.length, '?').join(', ')})';
    if (!_security.hasUnrestrictedWarehouseAccess) {
      whereArgs.addAll(warehouseIds);
    }
    final rows = await (await _db).rawQuery('''
      SELECT w.*
      FROM warehouses w
      JOIN factories f ON f.id = w.factoryId
      WHERE w.state = ? AND w.purpose = ? AND $warehousePredicate
      ORDER BY w.name ASC
      ''', whereArgs);
    return rows.map(Warehouse.fromMap).toList();
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
            invoicedQuantity: (m['invoicedQuantity'] as num?)?.toDouble() ?? 0,
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

  Future<DeliveryStockAvailability> _deliveryStockAvailability(
    DatabaseExecutor db, {
    required String warehouseId,
    required StockItemOption item,
    String? salesOrderItemId,
  }) async {
    await _validateWarehouse(db, warehouseId);

    final balanceRows = await db.query(
      'stock_balances',
      columns: ['quantity', 'unitId'],
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, item.inventoryId, item.type.value],
      limit: 1,
    );
    var physicalQuantity = 0.0;
    if (balanceRows.isNotEmpty) {
      if (balanceRows.single['unitId'] != item.unitId) {
        throw const SalesDeliveryException(
          SalesDeliveryFailure.stockUnitMismatch,
        );
      }
      physicalQuantity = (balanceRows.single['quantity'] as num).toDouble();
    }
    final reservedQuantity = await _activeReservedQuantity(
      db,
      warehouseId: warehouseId,
      item: item,
    );
    final orderReservedQuantity = salesOrderItemId == null
        ? 0.0
        : await _activeReservedQuantity(
            db,
            item: item,
            salesOrderItemId: salesOrderItemId,
          );
    return DeliveryStockAvailability(
      physicalBaseQuantity: physicalQuantity,
      reservedBaseQuantity: reservedQuantity,
      orderReservedBaseQuantity: orderReservedQuantity,
    );
  }

  Future<double> _activeReservedQuantity(
    DatabaseExecutor db, {
    required StockItemOption item,
    String? warehouseId,
    String? salesOrderItemId,
  }) async {
    final conditions = <String>[
      'sd.inventoryPosted = 0',
      "sd.status IN ('PENDING', 'DISPATCHED', 'IN_TRANSIT')",
      'sdi.productId = ?',
      'sdi.variantId IS ?',
      'sdi.inventoryIdentityKind = ?',
      'sdi.baseUnitId = ?',
      'soi.itemType = ?',
    ];
    final arguments = <Object?>[
      item.baseProductId,
      item.variantId,
      item.identityKind.value,
      item.unitId,
      item.type.value,
    ];
    if (warehouseId != null) {
      conditions.add('sd.warehouseId = ?');
      arguments.add(warehouseId);
    }
    if (salesOrderItemId != null) {
      conditions.add('sdi.salesOrderItemId = ?');
      arguments.add(salesOrderItemId);
    }
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(sdi.baseQuantity), 0) AS reservedQuantity
      FROM sales_delivery_items sdi
      JOIN sales_deliveries sd ON sd.id = sdi.salesDeliveryId
      JOIN sales_order_items soi ON soi.id = sdi.salesOrderItemId
      WHERE ${conditions.join(' AND ')}
    ''', arguments);
    return (rows.single['reservedQuantity'] as num).toDouble();
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
        AND sd.inventoryPosted = 1
        AND sd.status != 'CANCELLED'
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
    await _security.requireResourceScope(ScopeType.warehouse, id);
    if ((await db.query(
      'warehouses',
      columns: ['id'],
      where: 'id = ? AND state = ? AND purpose = ?',
      whereArgs: [id, 'active', WarehousePurpose.sellable.value],
      limit: 1,
    )).isEmpty) {
      throw const SalesDeliveryException(
        SalesDeliveryFailure.warehouseUnavailable,
      );
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
      values['invoicedQuantity'] = v.invoicedQuantity;
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
