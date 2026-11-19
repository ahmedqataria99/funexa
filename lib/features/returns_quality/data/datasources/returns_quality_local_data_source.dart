import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
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
    final session = _security.session;
    return rows
        .where(
          (row) =>
              session == null ||
              session.canAccess(
                ScopeType.warehouse,
                row['warehouseId'] as String,
              ),
        )
        .map(SalesReturn.fromMap)
        .toList();
  }

  Future<List<SalesReturnSourceDelivery>> salesReturnSourceDeliveries({
    String query = '',
  }) async {
    _security.require('RETURNS_VIEW');
    final normalized = query.trim().toLowerCase();
    final rows = await (await _db).rawQuery(
      '''
      SELECT sd.id, sd.deliveryNumber, sd.salesOrderId, sd.warehouseId,
        so.orderNumber AS salesOrderNumber, so.customerId,
        c.name AS customerName, sd.deliveryDate
      FROM sales_deliveries sd
      JOIN sales_orders so ON so.id = sd.salesOrderId
      JOIN customers c ON c.id = so.customerId
      WHERE sd.status = 'DELIVERED'
        AND (? = '' OR LOWER(sd.deliveryNumber) LIKE ?
          OR LOWER(so.orderNumber) LIKE ? OR LOWER(c.name) LIKE ?)
      ORDER BY sd.deliveryDate DESC
      LIMIT 100
      ''',
      [normalized, '%$normalized%', '%$normalized%', '%$normalized%'],
    );
    final session = _security.session;
    return rows
        .where(
          (row) =>
              session == null ||
              session.canAccess(
                ScopeType.warehouse,
                row['warehouseId'] as String,
              ),
        )
        .map(
          (row) => SalesReturnSourceDelivery(
            id: row['id'] as String,
            deliveryNumber: row['deliveryNumber'] as String,
            salesOrderId: row['salesOrderId'] as String,
            salesOrderNumber: row['salesOrderNumber'] as String,
            customerId: row['customerId'] as String,
            customerName: row['customerName'] as String,
            warehouseId: row['warehouseId'] as String,
            deliveryDate: DateTime.fromMillisecondsSinceEpoch(
              row['deliveryDate'] as int,
            ),
          ),
        )
        .toList();
  }

  Future<List<SalesReturnSourceLine>> salesReturnSourceLines(
    String deliveryId,
  ) async {
    _security.require('RETURNS_VIEW');
    final db = await _db;
    final deliveryRows = await db.query(
      'sales_deliveries',
      columns: ['warehouseId'],
      where: 'id = ? AND status = ?',
      whereArgs: [deliveryId, 'DELIVERED'],
      limit: 1,
    );
    if (deliveryRows.isEmpty) throw Exception('التسليم غير موجود أو غير مكتمل');
    await _security.requireResourceScope(
      ScopeType.warehouse,
      deliveryRows.single['warehouseId'] as String,
    );
    final rows = await db.rawQuery(
      '''
      SELECT di.id AS deliveryItemId,
        COALESCE(soi.productId, soi.itemId) AS itemId,
        soi.itemType, p.name AS productName, rm.name AS materialName,
        di.deliveredQuantity,
        COALESCE(di.baseQuantity,
          di.deliveredQuantity * COALESCE(di.unitConversionFactor, 1))
          AS deliveredBaseQuantity,
        COALESCE((
          SELECT SUM(sri.baseQuantity)
          FROM sales_return_items sri
          JOIN sales_returns sr ON sr.id = sri.salesReturnId
          WHERE sri.sourceDeliveryItemId = di.id
            AND sr.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
        ), 0) AS previouslyReturnedBaseQuantity,
        di.unitId, u.name AS unitName,
        COALESCE(di.baseUnitId, di.unitId) AS baseUnitId,
        bu.name AS baseUnitName,
        COALESCE(di.unitConversionFactor, 1) AS unitConversionFactor,
        di.variantId, v.name AS variantName,
        COALESCE(di.inventoryIdentityKind, 'BASE') AS inventoryIdentityKind,
        COALESCE(di.identitySnapshotStatus, 'UNVERIFIED')
          AS identitySnapshotStatus
      FROM sales_delivery_items di
      JOIN sales_order_items soi ON soi.id = di.salesOrderItemId
      LEFT JOIN products p ON p.id = COALESCE(soi.productId, soi.itemId)
        AND soi.itemType = 'PRODUCT'
      LEFT JOIN raw_materials rm ON rm.id = COALESCE(soi.productId, soi.itemId)
        AND soi.itemType = 'RAW_MATERIAL'
      LEFT JOIN product_variants v ON v.id = di.variantId
      LEFT JOIN units u ON u.id = di.unitId
      LEFT JOIN units bu ON bu.id = COALESCE(di.baseUnitId, di.unitId)
      WHERE di.salesDeliveryId = ?
      ORDER BY di.id ASC
      ''',
      [deliveryId],
    );
    return rows.map((row) {
      final itemId = row['itemId'] as String;
      return SalesReturnSourceLine(
        deliveryItemId: row['deliveryItemId'] as String,
        itemId: itemId,
        itemType: row['itemType'] as String,
        itemName:
            (row['productName'] ?? row['materialName'] ?? itemId) as String,
        deliveredQuantity: (row['deliveredQuantity'] as num).toDouble(),
        deliveredBaseQuantity: (row['deliveredBaseQuantity'] as num).toDouble(),
        previouslyReturnedBaseQuantity:
            (row['previouslyReturnedBaseQuantity'] as num).toDouble(),
        unitId: row['unitId'] as String,
        unitName: row['unitName'] as String? ?? row['unitId'] as String,
        baseUnitId: row['baseUnitId'] as String,
        baseUnitName:
            row['baseUnitName'] as String? ?? row['baseUnitId'] as String,
        unitConversionFactor: (row['unitConversionFactor'] as num).toDouble(),
        variantId: row['variantId'] as String?,
        variantName: row['variantName'] as String?,
        inventoryIdentityKind: row['inventoryIdentityKind'] as String,
        identitySnapshotStatus: row['identitySnapshotStatus'] as String,
      );
    }).toList();
  }

  Future<List<Warehouse>> salesReturnWarehouses(
    WarehousePurpose purpose,
  ) async {
    _security.require('RETURNS_EDIT');
    final rows = await (await _db).query(
      'warehouses',
      where: 'state = ? AND purpose = ?',
      whereArgs: ['active', purpose.value],
      orderBy: 'name ASC',
    );
    final session = _security.session;
    return rows
        .where(
          (row) =>
              session == null ||
              session.canAccess(ScopeType.warehouse, row['id'] as String),
        )
        .map(Warehouse.fromMap)
        .toList();
  }

  Future<SalesReturnWorkflowDetails> salesReturnDetails(String returnId) async {
    _security.require('RETURNS_VIEW');
    final db = await _db;
    final returnRows = await db.query(
      'sales_returns',
      where: 'id = ?',
      whereArgs: [returnId],
      limit: 1,
    );
    if (returnRows.isEmpty) throw Exception('مرتجع المبيعات غير موجود');
    final row = returnRows.single;
    await _security.requireResourceScope(
      ScopeType.warehouse,
      row['warehouseId'] as String,
    );
    final itemRows = await db.query(
      'sales_return_items',
      where: 'salesReturnId = ?',
      whereArgs: [returnId],
      orderBy: 'createdAt ASC, id ASC',
    );
    final items = itemRows.map(SalesReturnItem.fromMap).toList();
    final receipts = <SalesReturnReceiptRecord>[];
    final receivedByItem = <String, (double, double)>{};
    final receiptRows = await db.query(
      'sales_return_receipts',
      where: 'salesReturnId = ?',
      whereArgs: [returnId],
      orderBy: 'receiptDate ASC',
    );
    for (final receipt in receiptRows) {
      await _security.requireResourceScope(
        ScopeType.warehouse,
        receipt['warehouseId'] as String,
      );
      final receiptItems = await db.query(
        'sales_return_receipt_items',
        where: 'receiptId = ?',
        whereArgs: [receipt['id']],
      );
      final mappedReceiptItems = receiptItems.map((receiptItem) {
        final itemId = receiptItem['salesReturnItemId'] as String;
        final quantity = (receiptItem['quantity'] as num).toDouble();
        final baseQuantity = (receiptItem['baseQuantity'] as num).toDouble();
        final previous = receivedByItem[itemId] ?? (0.0, 0.0);
        receivedByItem[itemId] = (
          previous.$1 + quantity,
          previous.$2 + baseQuantity,
        );
        return SalesReturnReceiptItem(
          salesReturnItemId: itemId,
          quantity: quantity,
          baseQuantity: baseQuantity,
        );
      }).toList();
      final warehouseRows = await db.query(
        'warehouses',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [receipt['warehouseId']],
        limit: 1,
      );
      receipts.add(
        SalesReturnReceiptRecord(
          id: receipt['id'] as String,
          receiptNumber: receipt['receiptNumber'] as String,
          warehouseId: receipt['warehouseId'] as String,
          warehouseName: warehouseRows.isEmpty
              ? receipt['warehouseId'] as String
              : warehouseRows.single['name'] as String,
          receiptDate: DateTime.fromMillisecondsSinceEpoch(
            receipt['receiptDate'] as int,
          ),
          items: mappedReceiptItems,
        ),
      );
    }

    QualityInspection? inspection;
    final canViewQuality =
        _security.can('QUALITY_VIEW') || _security.can('QUALITY_EDIT');
    if (canViewQuality) {
      final inspectionRows = await db.query(
        'quality_inspections',
        where: 'sourceType = ? AND sourceId = ?',
        whereArgs: ['SALES_RETURN', returnId],
        limit: 1,
      );
      if (inspectionRows.isNotEmpty) {
        final inspectionItemRows = await db.query(
          'quality_inspection_items',
          where: 'inspectionId = ?',
          whereArgs: [inspectionRows.single['id']],
          orderBy: 'createdAt ASC, id ASC',
        );
        inspection = QualityInspection.fromMap(
          inspectionRows.single,
          items: inspectionItemRows.map(QualityInspectionItem.fromMap).toList(),
        );
      }
    }
    final inspectionItems =
        inspection?.items ?? const <QualityInspectionItem>[];
    final inspectionByItem = <String, List<QualityInspectionItem>>{};
    for (final inspectionItem in inspectionItems) {
      final sourceItemId = inspectionItem.sourceReturnItemId;
      if (sourceItemId != null) {
        inspectionByItem
            .putIfAbsent(sourceItemId, () => [])
            .add(inspectionItem);
      }
    }
    final lines = <SalesReturnWorkflowLine>[];
    for (final item in items) {
      final sourceRows = await db.rawQuery(
        '''
        SELECT di.deliveredQuantity, u.name AS unitName,
          p.name AS productName, rm.name AS materialName
        FROM sales_delivery_items di
        JOIN sales_order_items soi ON soi.id = di.salesOrderItemId
        LEFT JOIN units u ON u.id = di.unitId
        LEFT JOIN products p ON p.id = COALESCE(soi.productId, soi.itemId)
          AND soi.itemType = 'PRODUCT'
        LEFT JOIN raw_materials rm ON rm.id = COALESCE(soi.productId, soi.itemId)
          AND soi.itemType = 'RAW_MATERIAL'
        WHERE di.id = ?
        LIMIT 1
        ''',
        [item.sourceDeliveryItemId],
      );
      final source = sourceRows.isEmpty
          ? <String, Object?>{}
          : sourceRows.single;
      final received = receivedByItem[item.id] ?? (0.0, 0.0);
      final itemInspection = inspectionByItem[item.id] ?? const [];
      lines.add(
        SalesReturnWorkflowLine(
          item: item,
          itemName:
              (source['productName'] ?? source['materialName'] ?? item.itemId)
                  as String,
          unitName: source['unitName'] as String? ?? item.unitId,
          deliveredQuantity:
              (source['deliveredQuantity'] as num?)?.toDouble() ?? 0,
          receivedQuantity: received.$1,
          receivedBaseQuantity: received.$2,
          acceptedQuantity: itemInspection.fold<double>(
            0,
            (sum, line) => sum + line.acceptedQuantity,
          ),
          acceptedBaseQuantity: itemInspection.fold<double>(
            0,
            (sum, line) => sum + (line.acceptedBaseQuantity ?? 0),
          ),
          rejectedQuantity: itemInspection.fold<double>(
            0,
            (sum, line) => sum + line.rejectedQuantity,
          ),
          rejectedBaseQuantity: itemInspection.fold<double>(
            0,
            (sum, line) => sum + (line.rejectedBaseQuantity ?? 0),
          ),
        ),
      );
    }

    final customerRows = await db.query(
      'customers',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [row['customerId']],
      limit: 1,
    );
    final orderRows = await db.query(
      'sales_orders',
      columns: ['orderNumber'],
      where: 'id = ?',
      whereArgs: [row['salesOrderId']],
      limit: 1,
    );
    final deliveryRows = await db.query(
      'sales_deliveries',
      columns: ['deliveryNumber'],
      where: 'id = ?',
      whereArgs: [row['salesDeliveryId']],
      limit: 1,
    );
    final destinationRows = await db.query(
      'warehouses',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [row['warehouseId']],
      limit: 1,
    );
    final movementRows = await db.query(
      'stock_transactions',
      columns: ['id'],
      where: 'transactionType = ? AND reference LIKE ?',
      whereArgs: ['TRANSFER_IN', 'SALES_RETURN_ACCEPTED:$returnId:%'],
    );
    final journalRows = await db.query(
      'journal_entries',
      columns: ['entryNumber'],
      where: 'referenceType = ? AND referenceId = ?',
      whereArgs: ['SALES_RETURN', returnId],
      limit: 1,
    );
    return SalesReturnWorkflowDetails(
      salesReturn: SalesReturn.fromMap({...row, 'items': items}),
      customerName: customerRows.isEmpty
          ? row['customerId'] as String
          : customerRows.single['name'] as String,
      salesOrderNumber: orderRows.isEmpty
          ? row['salesOrderId'] as String
          : orderRows.single['orderNumber'] as String,
      deliveryNumber: deliveryRows.isEmpty
          ? row['salesDeliveryId'] as String? ?? ''
          : deliveryRows.single['deliveryNumber'] as String,
      destinationWarehouseName: destinationRows.isEmpty
          ? row['warehouseId'] as String
          : destinationRows.single['name'] as String,
      lines: lines,
      receipts: receipts,
      inspection: inspection,
      acceptedTransferCount: movementRows.length,
      journalNumber: journalRows.isEmpty
          ? null
          : journalRows.single['entryNumber'] as String,
    );
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
    final session = _security.session;
    return rows
        .where(
          (row) =>
              session == null ||
              session.canAccess(
                ScopeType.warehouse,
                row['warehouseId'] as String,
              ),
        )
        .map(PurchaseReturn.fromMap)
        .toList();
  }

  Future<List<Map<String, Object?>>> purchaseReturnSuppliers({
    String query = '',
  }) async {
    _security.require('RETURNS_VIEW');
    final normalized = query.trim().toLowerCase();
    return (await _db).query(
      'suppliers',
      where:
          "active = 1 AND (? = '' OR LOWER(name) LIKE ? OR LOWER(code) LIKE ?)",
      whereArgs: [normalized, '%$normalized%', '%$normalized%'],
      orderBy: 'name ASC',
      limit: 100,
    );
  }

  Future<List<PurchaseReturnSourceOrder>> purchaseReturnSourceOrders({
    required String supplierId,
    String query = '',
  }) async {
    _security.require('RETURNS_VIEW');
    final normalized = query.trim().toLowerCase();
    final rows = await (await _db).rawQuery(
      '''
      SELECT DISTINCT po.id, po.orderNumber, po.supplierId, s.name supplierName,
        po.orderDate, pr.warehouseId
      FROM purchase_orders po
      JOIN suppliers s ON s.id = po.supplierId
      JOIN purchase_receipts pr ON pr.purchaseOrderId = po.id
      JOIN purchase_receipt_items pri ON pri.purchaseReceiptId = pr.id
      WHERE po.supplierId = ? AND s.active = 1
        AND po.status NOT IN ('DRAFT', 'CANCELLED')
        AND (? = '' OR LOWER(po.orderNumber) LIKE ?)
      ORDER BY po.orderDate DESC
      LIMIT 100
      ''',
      [supplierId, normalized, '%$normalized%'],
    );
    final session = _security.session;
    final scopedRows = rows.where(
      (row) =>
          session != null &&
          session.canAccess(ScopeType.warehouse, row['warehouseId'] as String),
    );
    final seenOrders = <String>{};
    return scopedRows
        .where((row) => seenOrders.add(row['id'] as String))
        .map(
          (row) => PurchaseReturnSourceOrder(
            id: row['id'] as String,
            orderNumber: row['orderNumber'] as String,
            supplierId: row['supplierId'] as String,
            supplierName: row['supplierName'] as String,
            orderDate: DateTime.fromMillisecondsSinceEpoch(
              row['orderDate'] as int,
            ),
          ),
        )
        .toList();
  }

  Future<List<Map<String, Object?>>>
  purchaseReturnQuarantineWarehouses() async {
    _security.require('RETURNS_VIEW');
    final rows = await (await _db).query(
      'warehouses',
      where: 'state = ? AND purpose = ?',
      whereArgs: ['active', WarehousePurpose.quarantine.value],
      orderBy: 'name ASC',
    );
    final session = _security.session;
    return rows
        .where(
          (row) =>
              session != null &&
              session.canAccess(ScopeType.warehouse, row['id'] as String),
        )
        .toList();
  }

  Future<List<PurchaseReturnSourceLine>> purchaseReturnSourceLines(
    String purchaseOrderId, {
    String? receiptId,
  }) async {
    _security.require('RETURNS_VIEW');
    final rows = await (await _db).rawQuery(
      '''
      SELECT poi.id purchaseOrderItemId, pr.id receiptId,
        pr.receiptNumber, pr.warehouseId,
        COALESCE(pri.productId, poi.productId, poi.itemId) itemId,
        poi.itemType, COALESCE(p.name, rm.name, poi.productId, poi.itemId) itemName,
        poi.quantity, pri.receivedQuantity,
        COALESCE(pri.baseQuantity,
          pri.receivedQuantity * COALESCE(poi.unitConversionFactor, 1))
          receivedBaseQuantity,
        COALESCE(poi.receivedBaseQuantity,
          poi.receivedQuantity * COALESCE(poi.unitConversionFactor, 1))
          purchaseOrderReceivedBaseQuantity,
        COALESCE((
          SELECT SUM(pri2.baseQuantity)
          FROM purchase_return_items pri2
          JOIN purchase_returns pr2 ON pr2.id = pri2.purchaseReturnId
          WHERE pr2.purchaseOrderId = poi.purchaseOrderId
            AND (pri2.purchaseOrderItemId = poi.id OR
              (pri2.purchaseOrderItemId IS NULL AND pri2.productId = poi.productId
                AND pri2.variantId IS poi.variantId))
            AND pr2.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
        ), 0) returnedBaseQuantity,
        COALESCE((
          SELECT SUM(pri2.baseQuantity)
          FROM purchase_return_items pri2
          JOIN purchase_returns pr2 ON pr2.id = pri2.purchaseReturnId
          WHERE COALESCE(pri2.sourceReceiptId, pr2.purchaseReceiptId) = pr.id
            AND (pri2.purchaseOrderItemId = poi.id OR
              (pri2.purchaseOrderItemId IS NULL AND pri2.productId = poi.productId
                AND pri2.variantId IS poi.variantId))
            AND pr2.status NOT IN ('DRAFT', 'REJECTED', 'CANCELLED')
        ), 0) receiptReturnedBaseQuantity,
        poi.unitPrice,
        COALESCE(poi.unitId, pri.unitId) unitId,
        COALESCE(u.name, poi.unitId, pri.unitId) unitName,
        COALESCE(poi.baseUnitId, poi.unitId) baseUnitId,
        COALESCE(poi.unitConversionFactor, 1) unitConversionFactor,
        poi.variantId, v.name variantName,
        COALESCE(poi.inventoryIdentityKind, 'BASE') inventoryIdentityKind,
        COALESCE(poi.identitySnapshotStatus, 'UNVERIFIED') identitySnapshotStatus
      FROM purchase_receipt_items pri
      JOIN purchase_receipts pr ON pr.id = pri.purchaseReceiptId
      JOIN purchase_order_items poi ON poi.id = pri.purchaseOrderItemId
      LEFT JOIN products p ON p.id = COALESCE(poi.productId, poi.itemId)
        AND poi.itemType = 'PRODUCT'
      LEFT JOIN raw_materials rm ON rm.id = COALESCE(poi.productId, poi.itemId)
        AND poi.itemType = 'RAW_MATERIAL'
      LEFT JOIN units u ON u.id = COALESCE(poi.unitId, pri.unitId)
      LEFT JOIN product_variants v ON v.id = poi.variantId
      WHERE pr.purchaseOrderId = ? AND (? IS NULL OR pr.id = ?)
      ORDER BY pr.receiptDate ASC, poi.id ASC
      ''',
      [purchaseOrderId, receiptId, receiptId],
    );
    final lines = <PurchaseReturnSourceLine>[];
    for (final row in rows) {
      await _security.requireResourceScope(
        ScopeType.warehouse,
        row['warehouseId'] as String,
      );
      lines.add(
        PurchaseReturnSourceLine(
          purchaseOrderItemId: row['purchaseOrderItemId'] as String,
          receiptId: row['receiptId'] as String,
          receiptNumber: row['receiptNumber'] as String,
          sourceWarehouseId: row['warehouseId'] as String,
          itemId: row['itemId'] as String,
          itemType: row['itemType'] as String,
          itemName: row['itemName'] as String,
          quantity: (row['quantity'] as num).toDouble(),
          receivedQuantity: (row['receivedQuantity'] as num).toDouble(),
          receivedBaseQuantity: (row['receivedBaseQuantity'] as num).toDouble(),
          purchaseOrderReceivedBaseQuantity:
              (row['purchaseOrderReceivedBaseQuantity'] as num).toDouble(),
          returnedBaseQuantity: (row['returnedBaseQuantity'] as num).toDouble(),
          receiptReturnedBaseQuantity:
              (row['receiptReturnedBaseQuantity'] as num).toDouble(),
          unitPrice: (row['unitPrice'] as num).toDouble(),
          unitId: row['unitId'] as String,
          unitName: row['unitName'] as String,
          baseUnitId: row['baseUnitId'] as String,
          unitConversionFactor: (row['unitConversionFactor'] as num).toDouble(),
          variantId: row['variantId'] as String?,
          variantName: row['variantName'] as String?,
          inventoryIdentityKind: row['inventoryIdentityKind'] as String,
          identitySnapshotStatus: row['identitySnapshotStatus'] as String,
        ),
      );
    }
    return lines;
  }

  Future<PurchaseReturnWorkflowDetails> purchaseReturnDetails(
    String returnId,
  ) async {
    _security.require('RETURNS_VIEW');
    final db = await _db;
    final returnRows = await db.query(
      'purchase_returns',
      where: 'id = ?',
      whereArgs: [returnId],
      limit: 1,
    );
    if (returnRows.isEmpty) throw Exception('مرتجع المشتريات غير موجود');
    final row = returnRows.single;
    await _security.requireResourceScope(
      ScopeType.warehouse,
      row['warehouseId'] as String,
    );
    final itemRows = await db.query(
      'purchase_return_items',
      where: 'purchaseReturnId = ?',
      whereArgs: [returnId],
      orderBy: 'createdAt ASC, id ASC',
    );
    final items = itemRows.map(PurchaseReturnItem.fromMap).toList();
    final receiptRows = await db.query(
      'purchase_return_receipts',
      where: 'purchaseReturnId = ?',
      whereArgs: [returnId],
      orderBy: 'receiptDate ASC, id ASC',
    );
    final allInspectionRows = await db.query(
      'quality_inspections',
      where: 'sourceType = ? AND sourceId = ?',
      whereArgs: ['PURCHASE_RETURN', returnId],
      orderBy: 'inspectionDate ASC, id ASC',
    );
    final canViewQuality =
        _security.can('QUALITY_VIEW') || _security.can('QUALITY_EDIT');
    final receiptRecords = <PurchaseReturnReceiptRecord>[];
    for (final receipt in receiptRows) {
      final receiptItems = await db.query(
        'purchase_return_receipt_items',
        where: 'receiptId = ?',
        whereArgs: [receipt['id']],
        orderBy: 'id ASC',
      );
      final mappedReceiptItems = <PurchaseReturnReceiptItem>[];
      for (final receiptItem in receiptItems) {
        final inspectionItemRows = await db.rawQuery(
          '''
          SELECT COALESCE(SUM(qii.inspectedQuantity), 0) inspectedQuantity,
            COALESCE(SUM(qii.acceptedQuantity), 0) acceptedQuantity,
            COALESCE(SUM(qii.rejectedQuantity), 0) rejectedQuantity,
            COALESCE(SUM(qii.quarantinedQuantity), 0) quarantinedQuantity
          FROM quality_inspection_items qii
          JOIN quality_inspections qi ON qi.id = qii.inspectionId
          WHERE qi.sourceType = 'PURCHASE_RETURN' AND qi.sourceId = ?
            AND qi.purchaseReturnReceiptId = ?
            AND qii.purchaseReturnReceiptItemId = ?
          ''',
          [returnId, receipt['id'], receiptItem['id']],
        );
        final handoverItemRows = await db.rawQuery(
          '''
          SELECT COALESCE(SUM(baseQuantity), 0) quantity
          FROM purchase_return_handover_items
          WHERE purchaseReturnReceiptItemId = ?
          ''',
          [receiptItem['id']],
        );
        final inspectionHeaders = allInspectionRows
            .where(
              (inspection) =>
                  inspection['purchaseReturnReceiptId'] == receipt['id'],
            )
            .toList();
        final inspectionTotals = inspectionItemRows.single;
        mappedReceiptItems.add(
          PurchaseReturnReceiptItem(
            id: receiptItem['id'] as String,
            purchaseReturnItemId: receiptItem['purchaseReturnItemId'] as String,
            quantity: (receiptItem['quantity'] as num).toDouble(),
            baseQuantity: (receiptItem['baseQuantity'] as num).toDouble(),
            movementReference: receiptItem['movementReference'] as String?,
            inspectionStatus: inspectionHeaders.isEmpty
                ? null
                : inspectionHeaders.last['status'] as String,
            inspectedQuantity: (inspectionTotals['inspectedQuantity'] as num)
                .toDouble(),
            acceptedQuantity: (inspectionTotals['acceptedQuantity'] as num)
                .toDouble(),
            rejectedQuantity: (inspectionTotals['rejectedQuantity'] as num)
                .toDouble(),
            quarantinedQuantity:
                (inspectionTotals['quarantinedQuantity'] as num).toDouble(),
            handedOverQuantity: (handoverItemRows.single['quantity'] as num)
                .toDouble(),
          ),
        );
      }
      final warehouseRows = await db.query(
        'warehouses',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [receipt['warehouseId']],
        limit: 1,
      );
      receiptRecords.add(
        PurchaseReturnReceiptRecord(
          id: receipt['id'] as String,
          receiptNumber: receipt['receiptNumber'] as String,
          warehouseId: receipt['warehouseId'] as String,
          warehouseName: warehouseRows.isEmpty
              ? receipt['warehouseId'] as String
              : warehouseRows.single['name'] as String,
          receiptDate: DateTime.fromMillisecondsSinceEpoch(
            receipt['receiptDate'] as int,
          ),
          receivedBy: receipt['receivedBy'] as String?,
          notes: receipt['notes'] as String?,
          items: mappedReceiptItems,
        ),
      );
    }

    final inspections = <QualityInspection>[];
    final inspectionItems = <Map<String, Object?>>[];
    final allInspectionItems = <Map<String, Object?>>[];
    for (final inspection in allInspectionRows) {
      final inspectionItemRows = await db.query(
        'quality_inspection_items',
        where: 'inspectionId = ?',
        whereArgs: [inspection['id']],
        orderBy: 'createdAt ASC, id ASC',
      );
      allInspectionItems.addAll(inspectionItemRows);
      if (canViewQuality) {
        inspectionItems.addAll(inspectionItemRows);
        inspections.add(
          QualityInspection.fromMap(
            inspection,
            items: inspectionItemRows
                .map(QualityInspectionItem.fromMap)
                .toList(),
          ),
        );
      }
    }
    var receiptQcComplete = receiptRows.isNotEmpty;
    for (final receipt in receiptRows) {
      final receiptInspections = allInspectionRows.where(
        (inspection) => inspection['purchaseReturnReceiptId'] == receipt['id'],
      );
      if (receiptInspections.isEmpty ||
          receiptInspections.any(
            (inspection) =>
                inspection['status'] != QualityInspectionStatus.completed.value,
          )) {
        receiptQcComplete = false;
        continue;
      }
      final receiptItems = await db.query(
        'purchase_return_receipt_items',
        columns: ['id', 'baseQuantity'],
        where: 'receiptId = ?',
        whereArgs: [receipt['id']],
      );
      for (final receiptItem in receiptItems) {
        final inspectedBase = allInspectionItems
            .where(
              (item) =>
                  item['purchaseReturnReceiptItemId'] == receiptItem['id'],
            )
            .fold<double>(
              0,
              (sum, item) =>
                  sum + (item['inspectedBaseQuantity'] as num).toDouble(),
            );
        if ((inspectedBase - (receiptItem['baseQuantity'] as num).toDouble())
                .abs() >
            0.000001) {
          receiptQcComplete = false;
          break;
        }
      }
    }

    final handoverRows = await db.query(
      'purchase_return_handovers',
      where: 'purchaseReturnId = ?',
      whereArgs: [returnId],
      orderBy: 'handoverDate ASC, id ASC',
    );
    final handovers = <PurchaseReturnHandoverRecord>[];
    for (final handover in handoverRows) {
      final handoverItems = await db.query(
        'purchase_return_handover_items',
        where: 'handoverId = ?',
        whereArgs: [handover['id']],
        orderBy: 'id ASC',
      );
      final journalRows = handover['journalEntryId'] == null
          ? <Map<String, Object?>>[]
          : await db.query(
              'journal_entries',
              columns: ['entryNumber'],
              where: 'id = ?',
              whereArgs: [handover['journalEntryId']],
              limit: 1,
            );
      handovers.add(
        PurchaseReturnHandoverRecord(
          id: handover['id'] as String,
          handoverNumber: handover['handoverNumber'] as String,
          warehouseId: handover['warehouseId'] as String,
          handoverDate: DateTime.fromMillisecondsSinceEpoch(
            handover['handoverDate'] as int,
          ),
          performedBy: handover['performedBy'] as String?,
          notes: handover['notes'] as String?,
          journalEntryId: handover['journalEntryId'] as String?,
          journalNumber: journalRows.isEmpty
              ? null
              : journalRows.single['entryNumber'] as String,
          items: handoverItems
              .map(
                (handoverItem) => PurchaseReturnHandoverItem(
                  purchaseReturnItemId:
                      handoverItem['purchaseReturnItemId'] as String,
                  purchaseReturnReceiptItemId:
                      handoverItem['purchaseReturnReceiptItemId'] as String,
                  quantity: (handoverItem['quantity'] as num).toDouble(),
                  baseQuantity: (handoverItem['baseQuantity'] as num)
                      .toDouble(),
                  movementReference:
                      handoverItem['movementReference'] as String?,
                ),
              )
              .toList(),
        ),
      );
    }

    final handedOverByLine = <String, double>{};
    for (final handover in handoverRows) {
      final lines = await db.query(
        'purchase_return_handover_items',
        columns: ['purchaseReturnItemId', 'quantity'],
        where: 'handoverId = ?',
        whereArgs: [handover['id']],
      );
      for (final line in lines) {
        final itemId = line['purchaseReturnItemId'] as String;
        handedOverByLine[itemId] =
            (handedOverByLine[itemId] ?? 0) +
            (line['quantity'] as num).toDouble();
      }
    }
    final lines = <PurchaseReturnWorkflowLine>[];
    for (final item in items) {
      final sourceRows = await db.rawQuery(
        '''
        SELECT COALESCE(p.name, rm.name, poi.productId, poi.itemId) itemName,
          COALESCE(u.name, poi.unitId) unitName
        FROM purchase_order_items poi
        LEFT JOIN products p ON p.id = COALESCE(poi.productId, poi.itemId)
          AND poi.itemType = 'PRODUCT'
        LEFT JOIN raw_materials rm ON rm.id = COALESCE(poi.productId, poi.itemId)
          AND poi.itemType = 'RAW_MATERIAL'
        LEFT JOIN units u ON u.id = poi.unitId
        WHERE poi.id = ? LIMIT 1
        ''',
        [item.purchaseOrderItemId],
      );
      final source = sourceRows.isEmpty
          ? <String, Object?>{}
          : sourceRows.single;
      final allLineInspections = allInspectionItems.where(
        (inspectionItem) => inspectionItem['sourceReturnItemId'] == item.id,
      );
      final received = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(pri.quantity), 0) quantity
        FROM purchase_return_receipt_items pri
        JOIN purchase_return_receipts pr ON pr.id = pri.receiptId
        WHERE pr.purchaseReturnId = ? AND pri.purchaseReturnItemId = ?
        ''',
        [returnId, item.id],
      );
      lines.add(
        PurchaseReturnWorkflowLine(
          item: item,
          itemName: source['itemName'] as String? ?? item.itemId,
          unitName: source['unitName'] as String? ?? item.unitId,
          requestedQuantity: item.quantity,
          receivedQuantity: (received.single['quantity'] as num).toDouble(),
          inspectedQuantity: allLineInspections.fold<double>(
            0,
            (sum, line) => sum + (line['inspectedQuantity'] as num).toDouble(),
          ),
          acceptedQuantity: allLineInspections.fold<double>(
            0,
            (sum, line) => sum + (line['acceptedQuantity'] as num).toDouble(),
          ),
          rejectedQuantity: allLineInspections.fold<double>(
            0,
            (sum, line) => sum + (line['rejectedQuantity'] as num).toDouble(),
          ),
          quarantinedQuantity: allLineInspections.fold<double>(
            0,
            (sum, line) =>
                sum + (line['quarantinedQuantity'] as num? ?? 0).toDouble(),
          ),
          handedOverQuantity: handedOverByLine[item.id] ?? 0,
        ),
      );
    }
    final supplierRows = await db.query(
      'suppliers',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [row['supplierId']],
      limit: 1,
    );
    final orderRows = await db.query(
      'purchase_orders',
      columns: ['orderNumber'],
      where: 'id = ?',
      whereArgs: [row['purchaseOrderId']],
      limit: 1,
    );
    final warehouseRows = await db.query(
      'warehouses',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [row['warehouseId']],
      limit: 1,
    );
    return PurchaseReturnWorkflowDetails(
      purchaseReturn: PurchaseReturn.fromMap({...row, 'items': items}),
      supplierName: supplierRows.isEmpty
          ? row['supplierId'] as String
          : supplierRows.single['name'] as String,
      purchaseOrderNumber: orderRows.isEmpty
          ? row['purchaseOrderId'] as String
          : orderRows.single['orderNumber'] as String,
      warehouseName: warehouseRows.isEmpty
          ? row['warehouseId'] as String
          : warehouseRows.single['name'] as String,
      lines: lines,
      receipts: receiptRecords,
      inspections: inspections,
      handovers: handovers,
      hasInspectionRecords: allInspectionRows.isNotEmpty,
      receiptQcComplete: receiptQcComplete,
    );
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
    if (value.status != ReturnStatus.pending) {
      throw Exception('Sales returns must be created with PENDING status');
    }
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

  Future<void> receiveSalesReturn({
    required String returnId,
    required String receiptId,
    required String receiptNumber,
    required String quarantineWarehouseId,
    required DateTime receiptDate,
    required List<SalesReturnReceiptItem> items,
  }) async {
    _security.require('RETURNS_EDIT');
    if (items.isEmpty) throw Exception('يجب إدخال بنود استلام المرتجع');
    if (receiptId.trim().isEmpty || receiptNumber.trim().isEmpty) {
      throw Exception('رقم استلام المرتجع غير صالح');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final duplicateRows = await txn.query(
        'sales_return_receipts',
        where: 'id = ? OR receiptNumber = ?',
        whereArgs: [receiptId, receiptNumber.trim()],
        limit: 1,
      );
      if (duplicateRows.isNotEmpty) {
        final duplicate = duplicateRows.single;
        final storedItems = await txn.query(
          'sales_return_receipt_items',
          where: 'receiptId = ?',
          whereArgs: [duplicate['id']],
        );
        final matches =
            duplicate['id'] == receiptId &&
            duplicate['receiptNumber'] == receiptNumber.trim() &&
            duplicate['salesReturnId'] == returnId &&
            duplicate['warehouseId'] == quarantineWarehouseId &&
            storedItems.length == items.length &&
            items.every((item) {
              final matches = storedItems.where(
                (row) => row['salesReturnItemId'] == item.salesReturnItemId,
              );
              return matches.length == 1 &&
                  (matches.single['quantity'] as num).toDouble() ==
                      item.quantity;
            });
        if (matches) return;
        throw Exception('رقم استلام المرتجع مستخدم في عملية أخرى');
      }

      final returnRows = await txn.query(
        'sales_returns',
        where: 'id = ?',
        whereArgs: [returnId],
        limit: 1,
      );
      if (returnRows.isEmpty) throw Exception('مرتجع المبيعات غير موجود');
      final returnRow = returnRows.single;
      if (returnRow['status'] != ReturnStatus.pending.value) {
        throw Exception('لا يمكن استلام مرتجع بعد معالجته');
      }
      await _security.requireResourceScope(
        ScopeType.warehouse,
        returnRow['warehouseId'] as String,
      );
      await _security.requireResourceScope(
        ScopeType.warehouse,
        quarantineWarehouseId,
      );
      await _requireWarehousePurpose(
        txn,
        quarantineWarehouseId,
        WarehousePurpose.quarantine,
      );
      await _requireWarehousePurpose(
        txn,
        returnRow['warehouseId'] as String,
        WarehousePurpose.sellable,
      );
      final existingReceipts = await txn.query(
        'sales_return_receipts',
        columns: ['warehouseId'],
        where: 'salesReturnId = ?',
        whereArgs: [returnId],
      );
      if (existingReceipts.any(
        (row) => row['warehouseId'] != quarantineWarehouseId,
      )) {
        throw Exception('يجب استلام بنود المرتجع في مخزن الحجر نفسه');
      }
      if ((await txn.query(
        'quality_inspections',
        columns: ['id'],
        where: 'sourceType = ? AND sourceId = ?',
        whereArgs: ['SALES_RETURN', returnId],
        limit: 1,
      )).isNotEmpty) {
        throw Exception('لا يمكن استلام مرتجع بعد بدء فحص الجودة');
      }

      final seenLineIds = <String>{};
      final receiptLines = <_SalesReturnReceiptLine>[];
      for (final item in items) {
        if (!seenLineIds.add(item.salesReturnItemId) ||
            !item.quantity.isFinite ||
            item.quantity <= 0) {
          throw Exception('كمية أو بند استلام المرتجع غير صالح');
        }
        final returnItemRows = await txn.query(
          'sales_return_items',
          where: 'id = ? AND salesReturnId = ?',
          whereArgs: [item.salesReturnItemId, returnId],
          limit: 1,
        );
        if (returnItemRows.isEmpty) {
          throw Exception('بند الاستلام لا يخص مرتجع المبيعات');
        }
        final returnItem = returnItemRows.single;
        final factor = (returnItem['unitConversionFactor'] as num).toDouble();
        final baseQuantity = item.quantity * factor;
        final requestedBase = (returnItem['baseQuantity'] as num).toDouble();
        if (!factor.isFinite || factor <= 0 || !baseQuantity.isFinite) {
          throw Exception('لقطة تحويل وحدة الاستلام غير صالحة');
        }
        final receivedRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(sri.baseQuantity), 0) AS quantity
          FROM sales_return_receipt_items sri
          JOIN sales_return_receipts sr ON sr.id = sri.receiptId
          WHERE sr.salesReturnId = ? AND sri.salesReturnItemId = ?
          ''',
          [returnId, item.salesReturnItemId],
        );
        final received = (receivedRows.single['quantity'] as num).toDouble();
        if (received + baseQuantity > requestedBase) {
          throw Exception('كمية الاستلام تتجاوز كمية بند المرتجع');
        }
        final deliveryRows = await txn.query(
          'sales_delivery_items',
          columns: ['unitCogs'],
          where: 'id = ?',
          whereArgs: [returnItem['sourceDeliveryItemId']],
          limit: 1,
        );
        if (deliveryRows.isEmpty) throw Exception('بند التسليم غير موجود');
        final unitCost = (deliveryRows.single['unitCogs'] as num? ?? 0)
            .toDouble();
        if (!unitCost.isFinite || unitCost < 0) {
          throw Exception('تقييم بند التسليم غير صالح');
        }
        final itemOption = await _itemOption(
          txn,
          returnItem['productId'] as String? ?? returnItem['itemId'] as String,
          _itemType(returnItem['itemType'] as String),
          variantId: returnItem['variantId'] as String?,
          baseUnitId: returnItem['baseUnitId'] as String?,
          identityKind: InventoryIdentityKindValue.parse(
            returnItem['inventoryIdentityKind'],
          ),
        );
        receiptLines.add(
          _SalesReturnReceiptLine(
            item: item,
            baseQuantity: baseQuantity,
            itemOption: itemOption,
            unitCost: unitCost,
          ),
        );
      }

      await txn.insert('sales_return_receipts', {
        'id': receiptId,
        'receiptNumber': receiptNumber.trim(),
        'salesReturnId': returnId,
        'warehouseId': quarantineWarehouseId,
        'receiptDate': receiptDate.millisecondsSinceEpoch,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      for (final line in receiptLines) {
        await _stock.applyStockInWithinTransaction(
          executor: txn,
          warehouseId: quarantineWarehouseId,
          item: line.itemOption,
          quantity: line.baseQuantity,
          date: receiptDate,
          reference: 'SALES_RETURN_RECEIPT:$receiptId',
        );
        await _accounting.receiveInventoryValueWithinTransaction(
          executor: txn,
          warehouseId: quarantineWarehouseId,
          itemId: line.itemOption.inventoryId,
          itemType: line.itemOption.type.value,
          quantity: line.baseQuantity,
          unitCost: line.unitCost,
          productId: line.itemOption.baseProductId,
          variantId: line.itemOption.variantId,
          identityKind: line.itemOption.identityKind,
          unitId: line.itemOption.unitId,
        );
        await txn.insert('sales_return_receipt_items', {
          'id': '${receiptId}:${line.item.salesReturnItemId}',
          'receiptId': receiptId,
          'salesReturnItemId': line.item.salesReturnItemId,
          'quantity': line.item.quantity,
          'baseQuantity': line.baseQuantity,
        });
      }
    });
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
      if (status != ReturnStatus.approved &&
          (await txn.query(
            'sales_return_receipts',
            columns: ['id'],
            where: 'salesReturnId = ?',
            whereArgs: [returnId],
            limit: 1,
          )).isNotEmpty) {
        throw Exception('لا يمكن رفض أو إلغاء مرتجع بعد استلامه فعلياً');
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
      _SalesReturnPostingData? postingData;
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId,
      );
      if (status == ReturnStatus.approved) {
        await _validateSalesReturn(txn, value, excludeReturnId: returnId);
        postingData = await _salesReturnPostingData(txn, returnId);
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
        await _postSalesReturnWithinTransaction(txn, value, postingData!);
      }
    });
  }

  Future<PurchaseReturn> savePurchaseReturn(PurchaseReturn value) async {
    _security.require('RETURNS_EDIT');
    if (value.status != ReturnStatus.pending) {
      throw Exception('Purchase returns must be created with PENDING status');
    }
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
    ReturnStatus status, {
    String? decisionNotes,
  }) async {
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
        await _validatePurchaseReturnReadyForApproval(txn, returnId);
      }
      final now = DateTime.now();
      final session = _security.session;
      await txn.update(
        'purchase_returns',
        {
          'status': status.value,
          'updatedAt': now.millisecondsSinceEpoch,
          if (status == ReturnStatus.approved) ...{
            'approvedBy': session?.user.id,
            'approvedAt': now.millisecondsSinceEpoch,
            'approvalNotes': decisionNotes?.trim(),
          },
        },
        where: 'id = ?',
        whereArgs: [returnId],
      );
    });
    await _auditPurchaseReturn(
      action: status == ReturnStatus.approved ? 'APPROVE' : status.value,
      returnId: returnId,
      description: decisionNotes,
    );
  }

  Future<void> receivePurchaseReturn({
    required String returnId,
    required String receiptId,
    required String receiptNumber,
    required String quarantineWarehouseId,
    required DateTime receiptDate,
    required List<PurchaseReturnReceiptItem> items,
    String? notes,
  }) async {
    _security.require('RETURNS_EDIT');
    if (items.isEmpty ||
        receiptId.trim().isEmpty ||
        receiptNumber.trim().isEmpty) {
      throw Exception('Purchase return receipt details are incomplete');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final duplicateRows = await txn.query(
        'purchase_return_receipts',
        where: 'id = ? OR receiptNumber = ?',
        whereArgs: [receiptId, receiptNumber.trim()],
        limit: 1,
      );
      if (duplicateRows.isNotEmpty) {
        final duplicate = duplicateRows.single;
        final storedItems = await txn.query(
          'purchase_return_receipt_items',
          where: 'receiptId = ?',
          whereArgs: [duplicate['id']],
        );
        var matches =
            duplicate['id'] == receiptId &&
            duplicate['receiptNumber'] == receiptNumber.trim() &&
            duplicate['purchaseReturnId'] == returnId &&
            duplicate['warehouseId'] == quarantineWarehouseId &&
            duplicate['receiptDate'] == receiptDate.millisecondsSinceEpoch &&
            duplicate['notes'] == notes?.trim() &&
            storedItems.length == items.length;
        for (final item in items) {
          if (!matches) break;
          final storedMatches = storedItems.where(
            (stored) =>
                stored['purchaseReturnItemId'] == item.purchaseReturnItemId,
          );
          final sourceRows = await txn.query(
            'purchase_return_items',
            columns: ['unitConversionFactor'],
            where: 'id = ? AND purchaseReturnId = ?',
            whereArgs: [item.purchaseReturnItemId, returnId],
            limit: 1,
          );
          if (storedMatches.length != 1 || sourceRows.isEmpty) {
            matches = false;
            break;
          }
          final factor = (sourceRows.single['unitConversionFactor'] as num)
              .toDouble();
          final expectedBase = item.baseQuantity ?? item.quantity * factor;
          matches =
              (storedMatches.single['quantity'] as num).toDouble() ==
                  item.quantity &&
              (storedMatches.single['baseQuantity'] as num).toDouble() ==
                  expectedBase;
        }
        if (matches) return;
        throw Exception('Purchase return receipt reference is already used');
      }

      final returnRows = await txn.query(
        'purchase_returns',
        where: 'id = ? AND status = ?',
        whereArgs: [returnId, ReturnStatus.pending.value],
        limit: 1,
      );
      if (returnRows.isEmpty) {
        throw Exception('Only pending Purchase Returns can be received');
      }
      final value = PurchaseReturn.fromMap(returnRows.single);
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId,
      );
      await _security.requireResourceScope(
        ScopeType.warehouse,
        quarantineWarehouseId,
      );
      await _requireWarehousePurpose(
        txn,
        value.warehouseId,
        WarehousePurpose.sellable,
      );
      await _requireWarehousePurpose(
        txn,
        quarantineWarehouseId,
        WarehousePurpose.quarantine,
      );
      final existingReceipts = await txn.query(
        'purchase_return_receipts',
        columns: ['warehouseId'],
        where: 'purchaseReturnId = ?',
        whereArgs: [returnId],
      );
      if (existingReceipts.any(
        (receipt) => receipt['warehouseId'] != quarantineWarehouseId,
      )) {
        throw Exception('يجب استلام بنود المرتجع في مخزن الحجر نفسه');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('purchase_return_receipts', {
        'id': receiptId,
        'receiptNumber': receiptNumber.trim(),
        'purchaseReturnId': returnId,
        'warehouseId': quarantineWarehouseId,
        'receiptDate': receiptDate.millisecondsSinceEpoch,
        'receivedBy': _security.session?.user.id,
        'notes': notes?.trim(),
        'createdAt': now,
      });
      final seenLineIds = <String>{};
      for (final item in items) {
        if (!seenLineIds.add(item.purchaseReturnItemId) ||
            !item.quantity.isFinite ||
            item.quantity <= 0) {
          throw Exception('Purchase return receipt quantity is invalid');
        }
        final sourceRows = await txn.query(
          'purchase_return_items',
          where: 'id = ? AND purchaseReturnId = ?',
          whereArgs: [item.purchaseReturnItemId, returnId],
          limit: 1,
        );
        if (sourceRows.isEmpty) {
          throw Exception('Receipt line does not belong to this return');
        }
        final source = PurchaseReturnItem.fromMap(sourceRows.single);
        final baseQuantity = item.quantity * source.unitConversionFactor;
        final expectedBase = item.baseQuantity ?? baseQuantity;
        if (!baseQuantity.isFinite ||
            !expectedBase.isFinite ||
            (baseQuantity - expectedBase).abs() > 0.000001) {
          throw Exception('Purchase return receipt unit snapshot is invalid');
        }
        final receivedRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(pri.baseQuantity), 0) quantity
          FROM purchase_return_receipt_items pri
          JOIN purchase_return_receipts pr ON pr.id = pri.receiptId
          WHERE pr.purchaseReturnId = ? AND pri.purchaseReturnItemId = ?
          ''',
          [returnId, source.id],
        );
        final received = (receivedRows.single['quantity'] as num).toDouble();
        final requested =
            source.baseQuantity ??
            source.quantity * source.unitConversionFactor;
        if (received + baseQuantity > requested + 0.000001) {
          throw Exception('Received quantity exceeds the requested quantity');
        }
        final itemOption = await _itemOption(
          txn,
          source.itemId,
          _stockItemType(source.itemType),
          variantId: source.variantId,
          baseUnitId: source.baseUnitId ?? source.unitId,
          identityKind: InventoryIdentityKindValue.parse(
            source.inventoryIdentityKind,
          ),
        );
        final movementReference =
            'PURCHASE_RETURN_RECEIPT:$receiptId:${source.id}';
        await _stock.transferPurchaseReturnToQuarantineWithinTransaction(
          executor: txn,
          sourceWarehouseId: value.warehouseId,
          quarantineWarehouseId: quarantineWarehouseId,
          item: itemOption,
          quantity: baseQuantity,
          date: receiptDate,
          reference: movementReference,
        );
        await txn.insert('purchase_return_receipt_items', {
          'id': '$receiptId:${source.id}',
          'receiptId': receiptId,
          'purchaseReturnItemId': source.id,
          'quantity': item.quantity,
          'baseQuantity': baseQuantity,
          'movementReference': movementReference,
        });
      }
    });
    await _auditPurchaseReturn(
      action: 'PHYSICAL_RECEIPT',
      returnId: returnId,
      description: receiptNumber.trim(),
    );
  }

  Future<void> recordPurchaseReturnHandover({
    required String handoverId,
    required String handoverNumber,
    required String returnId,
    required String supplierId,
    required String quarantineWarehouseId,
    required DateTime handoverDate,
    required List<PurchaseReturnHandoverItem> items,
    String? notes,
  }) async {
    _security.require('RETURNS_EDIT');
    if (handoverId.trim().isEmpty ||
        handoverNumber.trim().isEmpty ||
        items.isEmpty) {
      throw Exception('بيانات تسليم المورد غير مكتملة');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final duplicateRows = await txn.query(
        'purchase_return_handovers',
        where: 'id = ? OR handoverNumber = ?',
        whereArgs: [handoverId, handoverNumber.trim()],
        limit: 1,
      );
      if (duplicateRows.isNotEmpty) {
        final duplicate = duplicateRows.single;
        final storedItems = await txn.query(
          'purchase_return_handover_items',
          where: 'handoverId = ?',
          whereArgs: [duplicate['id']],
        );
        var sameRequest =
            duplicate['id'] == handoverId &&
            duplicate['handoverNumber'] == handoverNumber.trim() &&
            duplicate['purchaseReturnId'] == returnId &&
            duplicate['supplierId'] == supplierId &&
            duplicate['warehouseId'] == quarantineWarehouseId &&
            duplicate['handoverDate'] == handoverDate.millisecondsSinceEpoch &&
            duplicate['notes'] == notes?.trim() &&
            storedItems.length == items.length &&
            true;
        for (final item in items) {
          if (!sameRequest) break;
          final matches = storedItems.where(
            (stored) =>
                stored['purchaseReturnItemId'] == item.purchaseReturnItemId &&
                stored['purchaseReturnReceiptItemId'] ==
                    item.purchaseReturnReceiptItemId,
          );
          final sourceRows = await txn.query(
            'purchase_return_items',
            columns: ['unitConversionFactor'],
            where: 'id = ? AND purchaseReturnId = ?',
            whereArgs: [item.purchaseReturnItemId, returnId],
            limit: 1,
          );
          if (matches.length != 1 || sourceRows.isEmpty) {
            sameRequest = false;
            break;
          }
          final factor = (sourceRows.single['unitConversionFactor'] as num)
              .toDouble();
          final expectedBase = item.baseQuantity ?? item.quantity * factor;
          sameRequest =
              (matches.single['quantity'] as num).toDouble() == item.quantity &&
              (matches.single['baseQuantity'] as num).toDouble() ==
                  expectedBase;
        }
        if (sameRequest) return;
        throw Exception('مرجع تسليم المورد مستخدم في عملية أخرى');
      }

      final returnRows = await txn.query(
        'purchase_returns',
        where: 'id = ? AND status = ?',
        whereArgs: [returnId, ReturnStatus.approved.value],
        limit: 1,
      );
      if (returnRows.isEmpty) {
        throw Exception('يجب اعتماد المرتجع قبل تسليمه للمورد');
      }
      final returnValue = PurchaseReturn.fromMap(returnRows.single);
      if (returnValue.supplierId != supplierId) {
        throw Exception('المورد لا يطابق مرتجع المشتريات');
      }
      await _security.requireResourceScope(
        ScopeType.warehouse,
        returnValue.warehouseId,
      );
      await _security.requireResourceScope(
        ScopeType.warehouse,
        quarantineWarehouseId,
      );
      await _requireWarehousePurpose(
        txn,
        quarantineWarehouseId,
        WarehousePurpose.quarantine,
      );
      await _validatePurchaseReturnReadyForApproval(txn, returnId);

      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('purchase_return_handovers', {
        'id': handoverId,
        'handoverNumber': handoverNumber.trim(),
        'purchaseReturnId': returnId,
        'supplierId': supplierId,
        'warehouseId': quarantineWarehouseId,
        'handoverDate': handoverDate.millisecondsSinceEpoch,
        'performedBy': _security.session?.user.id,
        'notes': notes?.trim(),
        'createdAt': now,
      });

      final seenReceiptLines = <String>{};
      var payableReversal = 0.0;
      var inventoryReversal = 0.0;
      for (final item in items) {
        if (!seenReceiptLines.add(item.purchaseReturnReceiptItemId) ||
            !item.quantity.isFinite ||
            item.quantity <= 0) {
          throw Exception('كمية أو بند تسليم المورد غير صالح');
        }
        final returnItemRows = await txn.query(
          'purchase_return_items',
          where: 'id = ? AND purchaseReturnId = ?',
          whereArgs: [item.purchaseReturnItemId, returnId],
          limit: 1,
        );
        if (returnItemRows.isEmpty) {
          throw Exception('بند التسليم لا يخص مرتجع المشتريات');
        }
        final returnItem = PurchaseReturnItem.fromMap(returnItemRows.single);
        final receiptItemRows = await txn.rawQuery(
          '''
          SELECT pri.*, pr.warehouseId, pr.purchaseReturnId
          FROM purchase_return_receipt_items pri
          JOIN purchase_return_receipts pr ON pr.id = pri.receiptId
          WHERE pri.id = ? AND pri.purchaseReturnItemId = ?
            AND pr.purchaseReturnId = ?
          LIMIT 1
          ''',
          [
            item.purchaseReturnReceiptItemId,
            item.purchaseReturnItemId,
            returnId,
          ],
        );
        if (receiptItemRows.isEmpty ||
            receiptItemRows.single['warehouseId'] != quarantineWarehouseId) {
          throw Exception('بند التسليم لا يطابق إيصال الحجر');
        }
        final receiptItem = receiptItemRows.single;
        final receiptId = receiptItem['receiptId'] as String;
        final inspectedRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(qii.acceptedBaseQuantity), 0) acceptedBase,
            COUNT(qii.id) lineCount
          FROM quality_inspection_items qii
          JOIN quality_inspections qi ON qi.id = qii.inspectionId
          WHERE qi.sourceType = 'PURCHASE_RETURN' AND qi.sourceId = ?
            AND qi.purchaseReturnReceiptId = ?
            AND qi.status = 'COMPLETED'
            AND qii.purchaseReturnReceiptItemId = ?
            AND qii.sourceReturnItemId = ?
          ''',
          [
            returnId,
            receiptId,
            item.purchaseReturnReceiptItemId,
            item.purchaseReturnItemId,
          ],
        );
        if ((inspectedRows.single['lineCount'] as int) == 0) {
          throw Exception('يجب إكمال فحص الجودة قبل تسليم البضاعة');
        }
        final acceptedBase = (inspectedRows.single['acceptedBase'] as num)
            .toDouble();
        final receivedBase = (receiptItem['baseQuantity'] as num).toDouble();
        final baseQuantity = item.quantity * returnItem.unitConversionFactor;
        final expectedBase = item.baseQuantity ?? baseQuantity;
        if (!baseQuantity.isFinite ||
            !expectedBase.isFinite ||
            (baseQuantity - expectedBase).abs() > 0.000001) {
          throw Exception('لقطة وحدة كمية التسليم غير صالحة');
        }
        final handedRows = await txn.rawQuery(
          '''
          SELECT COALESCE(SUM(baseQuantity), 0) quantity
          FROM purchase_return_handover_items
          WHERE purchaseReturnReceiptItemId = ?
          ''',
          [item.purchaseReturnReceiptItemId],
        );
        final previouslyHanded = (handedRows.single['quantity'] as num)
            .toDouble();
        if (acceptedBase > receivedBase + 0.000001 ||
            previouslyHanded + baseQuantity > acceptedBase + 0.000001) {
          throw Exception('كمية التسليم تتجاوز الكمية المقبولة المتبقية');
        }
        final option = await _itemOption(
          txn,
          returnItem.itemId,
          _stockItemType(returnItem.itemType),
          variantId: returnItem.variantId,
          baseUnitId: returnItem.baseUnitId ?? returnItem.unitId,
          identityKind: InventoryIdentityKindValue.parse(
            returnItem.inventoryIdentityKind,
          ),
        );
        final movementReference =
            'PURCHASE_RETURN_HANDOVER:$handoverId:${item.purchaseReturnReceiptItemId}';
        final valuation = await _accounting.valuationWithinTransaction(
          txn,
          quarantineWarehouseId,
          option.inventoryId,
          option.type.value,
        );
        if (valuation == null || valuation.averageCost <= 0) {
          throw Exception('تقييم مخزون الحجر غير متاح للتسليم');
        }
        final unitPrice = await _purchaseUnitPrice(
          txn,
          returnValue,
          returnItem,
        );
        payableReversal += item.quantity * unitPrice;
        inventoryReversal += baseQuantity * valuation.averageCost;
        await _stock.applyPurchaseReturnHandoverWithinTransaction(
          executor: txn,
          quarantineWarehouseId: quarantineWarehouseId,
          item: option,
          quantity: baseQuantity,
          date: handoverDate,
          reference: movementReference,
        );
        await txn.insert('purchase_return_handover_items', {
          'id': '$handoverId:${item.purchaseReturnReceiptItemId}',
          'handoverId': handoverId,
          'purchaseReturnItemId': item.purchaseReturnItemId,
          'purchaseReturnReceiptItemId': item.purchaseReturnReceiptItemId,
          'quantity': item.quantity,
          'baseQuantity': baseQuantity,
          'movementReference': movementReference,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      final journalEntryId = await _postPurchaseReturnAccounting(
        txn,
        returnValue,
        payableReversal: payableReversal,
        inventoryReversal: inventoryReversal,
        date: handoverDate,
        referenceType: 'PURCHASE_RETURN_HANDOVER',
        referenceId: handoverId,
      );
      await txn.update(
        'purchase_return_handovers',
        {'journalEntryId': journalEntryId},
        where: 'id = ?',
        whereArgs: [handoverId],
      );
      final acceptedRows = await txn.rawQuery(
        '''
        SELECT pri.purchaseReturnItemId, SUM(qii.acceptedBaseQuantity) accepted
        FROM quality_inspection_items qii
        JOIN quality_inspections qi ON qi.id = qii.inspectionId
        JOIN purchase_return_receipt_items pri
          ON pri.id = qii.purchaseReturnReceiptItemId
        JOIN purchase_return_receipts pr ON pr.id = pri.receiptId
        WHERE pr.purchaseReturnId = ? AND qi.status = 'COMPLETED'
        GROUP BY pri.purchaseReturnItemId
        ''',
        [returnId],
      );
      final handedRows = await txn.rawQuery(
        '''
        SELECT purchaseReturnItemId, SUM(baseQuantity) handed
        FROM purchase_return_handover_items
        WHERE purchaseReturnItemId IN (
          SELECT id FROM purchase_return_items WHERE purchaseReturnId = ?
        )
        GROUP BY purchaseReturnItemId
        ''',
        [returnId],
      );
      final handedByLine = {
        for (final row in handedRows)
          row['purchaseReturnItemId'] as String: (row['handed'] as num)
              .toDouble(),
      };
      final isComplete =
          acceptedRows.isNotEmpty &&
          acceptedRows.every((row) {
            final itemId = row['purchaseReturnItemId'] as String;
            return ((row['accepted'] as num).toDouble() -
                        (handedByLine[itemId] ?? 0))
                    .abs() <=
                0.000001;
          });
      if (isComplete) {
        await txn.update(
          'purchase_returns',
          {
            'status': ReturnStatus.completed.value,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [returnId],
        );
      } else {
        await txn.update(
          'purchase_returns',
          {'updatedAt': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [returnId],
        );
      }
    });
    await _auditPurchaseReturn(
      action: 'SUPPLIER_HANDOVER',
      returnId: returnId,
      description: handoverNumber.trim(),
    );
  }

  Future<QualityInspection> saveQualityInspection(
    QualityInspection value,
  ) async {
    _security.require('QUALITY_EDIT');
    final db = await _db;
    await db.transaction((txn) async {
      if (value.items.isEmpty) throw Exception('يجب إدخال بنود الفحص');
      final sourceType = value.sourceType.toUpperCase();
      if (sourceType == 'PURCHASE_RETURN' &&
          value.purchaseReturnReceiptId == null) {
        throw Exception('يجب ربط فحص الشراء بإيصال فعلي');
      }
      final duplicateInspections = sourceType == 'PURCHASE_RETURN'
          ? <Map<String, Object?>>[]
          : await txn.query(
              'quality_inspections',
              columns: ['id'],
              where: 'sourceType = ? AND sourceId = ?',
              whereArgs: [sourceType, value.sourceId],
              limit: 1,
            );
      if (duplicateInspections.isNotEmpty) {
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
        'sourceType': sourceType,
        'productId': primaryItem.productId,
        'variantId': primaryItem.variantId,
        'inventoryIdentityKind': primaryItem.inventoryIdentityKind,
      });
      for (final item in inspectedItems) {
        await txn.insert('quality_inspection_items', item.toMap(value.id));
      }
      if (value.sourceType.toUpperCase() == 'SALES_RETURN' &&
          value.status == QualityInspectionStatus.completed) {
        await _salesReturnPostingData(txn, value.sourceId);
      }
      if (sourceType == 'PURCHASE_RETURN' &&
          value.status == QualityInspectionStatus.completed) {
        await _validatePurchaseReturnReceiptInspection(
          txn,
          value.id,
          value.purchaseReturnReceiptId!,
        );
      }
    });
    return value;
  }

  Future<void> updateQualityInspectionStatus(
    String inspectionId,
    QualityInspectionStatus status,
  ) async {
    _security.require('QUALITY_EDIT');
    if (status != QualityInspectionStatus.inProgress &&
        status != QualityInspectionStatus.completed &&
        status != QualityInspectionStatus.rejected &&
        status != QualityInspectionStatus.quarantined) {
      throw Exception('حالة فحص الجودة غير صالحة للانتقال');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'quality_inspections',
        where: 'id = ?',
        whereArgs: [inspectionId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('فحص الجودة غير موجود');
      final row = rows.single;
      final sourceType = row['sourceType'] as String;
      if (sourceType != 'SALES_RETURN' && sourceType != 'PURCHASE_RETURN') {
        throw Exception('نوع مصدر الفحص غير مدعوم');
      }
      final warehouseId = row['warehouseId'] as String?;
      if (warehouseId == null) {
        throw Exception('مخزن فحص المرتجع غير محدد');
      }
      await _security.requireResourceScope(ScopeType.warehouse, warehouseId);
      final current = QualityInspectionStatus.values.firstWhere(
        (value) => value.value == row['status'],
      );
      if (current == status) return;
      if (current != QualityInspectionStatus.pending &&
          current != QualityInspectionStatus.inProgress) {
        throw Exception('لا يمكن تغيير حالة فحص الجودة بعد إغلاقه');
      }
      await txn.update(
        'quality_inspections',
        {
          'status': status.value,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [inspectionId],
      );
      if (status == QualityInspectionStatus.completed) {
        if (sourceType == 'SALES_RETURN') {
          await _salesReturnPostingData(txn, row['sourceId'] as String);
        } else {
          final receiptId = row['purchaseReturnReceiptId'] as String?;
          if (receiptId == null) {
            throw Exception('فحص مرتجع الشراء غير مربوط بإيصال فعلي');
          }
          await _validatePurchaseReturnReceiptInspection(
            txn,
            inspectionId,
            receiptId,
          );
        }
      }
    });
  }

  Future<QualityInspection> createQualityInspection({
    required String id,
    required String inspectionNumber,
    required String sourceType,
    required String sourceId,
    String? warehouseId,
    String? purchaseReturnReceiptId,
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
        purchaseReturnReceiptId: purchaseReturnReceiptId,
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
    _SalesReturnPostingData postingData,
  ) async {
    for (final item in value.items) {
      final accepted = postingData.acceptedByReturnItem[item.id];
      if (accepted == null || accepted.baseQuantity <= 0) continue;
      final detail = await _itemOption(
        txn,
        item.itemId,
        _stockItemType(item.itemType),
        variantId: item.variantId,
        baseUnitId: item.baseUnitId ?? item.unitId,
        identityKind: InventoryIdentityKindValue.parse(
          item.inventoryIdentityKind,
        ),
      );
      await _stock.transferQuarantinedSalesReturnWithinTransaction(
        executor: txn,
        sourceWarehouseId: postingData.quarantineWarehouseId,
        destinationWarehouseId: value.warehouseId,
        item: detail,
        quantity: accepted.baseQuantity,
        date: value.returnDate,
        reference: 'SALES_RETURN_ACCEPTED:${value.id}:${item.id}',
      );
    }
    await _postSalesReturnAccounting(
      txn,
      value,
      postingData.acceptedByReturnItem,
    );
  }

  Future<_SalesReturnPostingData> _salesReturnPostingData(
    DatabaseExecutor txn,
    String returnId,
  ) async {
    final returnRows = await txn.query(
      'sales_returns',
      columns: ['status', 'warehouseId'],
      where: 'id = ?',
      whereArgs: [returnId],
      limit: 1,
    );
    if (returnRows.isEmpty ||
        returnRows.single['status'] != ReturnStatus.pending.value) {
      throw Exception('مرتجع المبيعات غير موجود أو غير معلق');
    }
    final inspectionRows = await txn.query(
      'quality_inspections',
      where: 'sourceType = ? AND sourceId = ?',
      whereArgs: ['SALES_RETURN', returnId],
      limit: 2,
    );
    if (inspectionRows.length != 1 ||
        inspectionRows.single['status'] !=
            QualityInspectionStatus.completed.value) {
      throw Exception('يجب إكمال فحص الجودة قبل اعتماد المرتجع');
    }
    final receiptRows = await txn.query(
      'sales_return_receipts',
      where: 'salesReturnId = ?',
      whereArgs: [returnId],
    );
    if (receiptRows.isEmpty) {
      throw Exception('يجب استلام المرتجع فعلياً قبل اعتماد الفحص');
    }
    final quarantineWarehouseIds = receiptRows
        .map((row) => row['warehouseId'] as String)
        .toSet();
    if (quarantineWarehouseIds.length != 1) {
      throw Exception('استلام المرتجع موزع على مخازن حجر مختلفة');
    }
    final quarantineWarehouseId = quarantineWarehouseIds.single;
    if (inspectionRows.single['warehouseId'] != quarantineWarehouseId) {
      throw Exception('مخزن الفحص لا يطابق مخزن استلام المرتجع');
    }
    await _requireWarehousePurpose(
      txn,
      quarantineWarehouseId,
      WarehousePurpose.quarantine,
    );
    await _requireWarehousePurpose(
      txn,
      returnRows.single['warehouseId'] as String,
      WarehousePurpose.sellable,
    );

    final returnItems = await txn.query(
      'sales_return_items',
      where: 'salesReturnId = ?',
      whereArgs: [returnId],
    );
    final receiptItemRows = await txn.rawQuery(
      '''
      SELECT salesReturnItemId, SUM(quantity) AS quantity,
        SUM(baseQuantity) AS baseQuantity
      FROM sales_return_receipt_items sri
      JOIN sales_return_receipts sr ON sr.id = sri.receiptId
      WHERE sr.salesReturnId = ?
      GROUP BY salesReturnItemId
      ''',
      [returnId],
    );
    final receivedByReturnItem = {
      for (final row in receiptItemRows)
        row['salesReturnItemId'] as String: (
          quantity: (row['quantity'] as num).toDouble(),
          baseQuantity: (row['baseQuantity'] as num).toDouble(),
        ),
    };
    final inspectionItems = await txn.query(
      'quality_inspection_items',
      where: 'inspectionId = ?',
      whereArgs: [inspectionRows.single['id']],
    );
    final returnItemIds = returnItems.map((row) => row['id'] as String).toSet();
    if (inspectionItems.any(
      (row) =>
          row['sourceReturnItemId'] == null ||
          !returnItemIds.contains(row['sourceReturnItemId']),
    )) {
      throw Exception('فحص الجودة يحتوي على بند من مرتجع آخر');
    }
    final acceptedByReturnItem = <String, _SalesReturnAcceptedQuantity>{};
    for (final returnItem in returnItems) {
      final itemId = returnItem['id'] as String;
      final received = receivedByReturnItem[itemId];
      final lineInspections = inspectionItems
          .where((row) => row['sourceReturnItemId'] == itemId)
          .toList();
      if (received == null) {
        throw Exception('يجب استلام كل بند مرتجع قبل اعتماده');
      }
      final returnLineBaseQuantity = (returnItem['baseQuantity'] as num)
          .toDouble();
      if ((received.baseQuantity - returnLineBaseQuantity).abs() > 0.000001) {
        throw Exception('يجب استلام كامل كمية بند المرتجع قبل اعتماده');
      }
      if (lineInspections.isEmpty) {
        throw Exception('لم يتم فحص كامل الكمية المستلمة');
      }
      var requestedBaseQuantity = 0.0;
      var inspectedBaseQuantity = 0.0;
      var acceptedQuantity = 0.0;
      var acceptedBaseQuantity = 0.0;
      var rejectedBaseQuantity = 0.0;
      for (final inspectionItem in lineInspections) {
        requestedBaseQuantity +=
            (inspectionItem['requestedBaseQuantity'] as num).toDouble();
        inspectedBaseQuantity +=
            (inspectionItem['inspectedBaseQuantity'] as num).toDouble();
        acceptedQuantity += (inspectionItem['acceptedQuantity'] as num)
            .toDouble();
        acceptedBaseQuantity += (inspectionItem['acceptedBaseQuantity'] as num)
            .toDouble();
        rejectedBaseQuantity += (inspectionItem['rejectedBaseQuantity'] as num)
            .toDouble();
      }
      if ((requestedBaseQuantity - received.baseQuantity).abs() > 0.000001 ||
          (inspectedBaseQuantity - received.baseQuantity).abs() > 0.000001 ||
          acceptedBaseQuantity < 0 ||
          rejectedBaseQuantity < 0 ||
          acceptedBaseQuantity + rejectedBaseQuantity >
              received.baseQuantity + 0.000001 ||
          (acceptedBaseQuantity + rejectedBaseQuantity - inspectedBaseQuantity)
                  .abs() >
              0.000001) {
        throw Exception('كميات الفحص لا تطابق الكمية المستلمة');
      }
      acceptedByReturnItem[itemId] = _SalesReturnAcceptedQuantity(
        quantity: acceptedQuantity,
        baseQuantity: acceptedBaseQuantity,
      );
    }
    return _SalesReturnPostingData(
      quarantineWarehouseId: quarantineWarehouseId,
      acceptedByReturnItem: acceptedByReturnItem,
    );
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
    if (WarehousePurpose.fromStorage(warehouseRows.single['purpose']) !=
        WarehousePurpose.sellable) {
      throw Exception('يجب أن يكون مخزن إرجاع المبيعات متاحاً للبيع');
    }
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
    Map<String, _SalesReturnAcceptedQuantity> acceptedByReturnItem,
  ) async {
    var revenueReversal = 0.0;
    var cogsReversal = 0.0;
    for (final item in value.items) {
      final accepted = acceptedByReturnItem[item.id];
      if (accepted == null || accepted.quantity <= 0) continue;
      final rows = await txn.query(
        'sales_delivery_items',
        columns: ['unitRevenue', 'unitCogs'],
        where: 'id = ?',
        whereArgs: [item.sourceDeliveryItemId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('بند التسليم غير موجود');
      revenueReversal +=
          accepted.quantity *
          ((rows.single['unitRevenue'] as num?) ?? 0).toDouble();
      cogsReversal +=
          accepted.baseQuantity *
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
    await _requireWarehousePurpose(
      txn,
      value.warehouseId,
      WarehousePurpose.sellable,
    );
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

  Future<void> _validatePurchaseReturnReadyForApproval(
    DatabaseExecutor txn,
    String returnId,
  ) async {
    final returnItems = await txn.query(
      'purchase_return_items',
      where: 'purchaseReturnId = ?',
      whereArgs: [returnId],
    );
    if (returnItems.isEmpty) throw Exception('مرتجع المشتريات بلا بنود');
    final receiptRows = await txn.query(
      'purchase_return_receipts',
      where: 'purchaseReturnId = ?',
      whereArgs: [returnId],
    );
    if (receiptRows.isEmpty) {
      throw Exception('يجب تسجيل الاستلام الفعلي قبل الاعتماد');
    }
    for (final item in returnItems) {
      final expected = (item['baseQuantity'] as num).toDouble();
      final receivedRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(pri.baseQuantity), 0) quantity
        FROM purchase_return_receipt_items pri
        JOIN purchase_return_receipts pr ON pr.id = pri.receiptId
        WHERE pr.purchaseReturnId = ? AND pri.purchaseReturnItemId = ?
        ''',
        [returnId, item['id']],
      );
      final received = (receivedRows.single['quantity'] as num).toDouble();
      if ((received - expected).abs() > 0.000001) {
        throw Exception('يجب استلام كامل كمية كل بند قبل الاعتماد');
      }
    }
    for (final receipt in receiptRows) {
      final inspections = await txn.query(
        'quality_inspections',
        where:
            'sourceType = ? AND sourceId = ? AND purchaseReturnReceiptId = ?',
        whereArgs: ['PURCHASE_RETURN', returnId, receipt['id']],
      );
      if (inspections.isEmpty ||
          inspections.any(
            (inspection) =>
                inspection['status'] != QualityInspectionStatus.completed.value,
          )) {
        throw Exception('يجب إكمال فحص الجودة لكل إيصال قبل الاعتماد');
      }
      final receiptItems = await txn.query(
        'purchase_return_receipt_items',
        where: 'receiptId = ?',
        whereArgs: [receipt['id']],
      );
      final inspectionItems = await txn.rawQuery(
        '''
        SELECT qii.*
        FROM quality_inspection_items qii
        JOIN quality_inspections qi ON qi.id = qii.inspectionId
        WHERE qi.sourceType = 'PURCHASE_RETURN' AND qi.sourceId = ?
          AND qi.purchaseReturnReceiptId = ?
        ''',
        [returnId, receipt['id']],
      );
      for (final receiptItem in receiptItems) {
        final matching = inspectionItems.where(
          (inspectionItem) =>
              inspectionItem['purchaseReturnReceiptItemId'] ==
              receiptItem['id'],
        );
        if (matching.isEmpty) {
          throw Exception('لم يتم فحص كامل كمية بند الإيصال');
        }
        final receivedBase = (receiptItem['baseQuantity'] as num).toDouble();
        final inspectedBase = matching.fold<double>(
          0,
          (sum, line) =>
              sum + (line['inspectedBaseQuantity'] as num).toDouble(),
        );
        final acceptedBase = matching.fold<double>(
          0,
          (sum, line) => sum + (line['acceptedBaseQuantity'] as num).toDouble(),
        );
        final rejectedBase = matching.fold<double>(
          0,
          (sum, line) => sum + (line['rejectedBaseQuantity'] as num).toDouble(),
        );
        final quarantinedBase = matching.fold<double>(
          0,
          (sum, line) =>
              sum + (line['quarantinedBaseQuantity'] as num? ?? 0).toDouble(),
        );
        if ((inspectedBase - receivedBase).abs() > 0.000001 ||
            acceptedBase < 0 ||
            rejectedBase < 0 ||
            quarantinedBase < 0 ||
            (acceptedBase + rejectedBase + quarantinedBase - inspectedBase)
                    .abs() >
                0.000001) {
          throw Exception('كميات الفحص لا تطابق الكمية المستلمة');
        }
      }
    }
  }

  Future<void> _auditPurchaseReturn({
    required String action,
    required String returnId,
    String? description,
  }) async {
    try {
      await _security.audit(
        action: action,
        module: 'Returns',
        entityType: 'PurchaseReturn',
        entityId: returnId,
        description: description,
      );
    } on Object {
      // Audit logging must not make a committed inventory operation look failed.
    }
  }

  Future<double> _purchaseUnitPrice(
    DatabaseExecutor txn,
    PurchaseReturn value,
    PurchaseReturnItem item,
  ) async {
    final orderItemId = item.purchaseOrderItemId;
    final rows = orderItemId == null
        ? await txn.query(
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
          )
        : await txn.query(
            'purchase_order_items',
            columns: ['unitPrice'],
            where: 'id = ? AND purchaseOrderId = ?',
            whereArgs: [orderItemId, value.purchaseOrderId],
            limit: 1,
          );
    if (rows.isEmpty) throw Exception('بند أمر الشراء غير موجود');
    return (rows.single['unitPrice'] as num).toDouble();
  }

  Future<String> _postPurchaseReturnAccounting(
    DatabaseExecutor txn,
    PurchaseReturn value, {
    required double payableReversal,
    required double inventoryReversal,
    required DateTime date,
    required String referenceType,
    required String referenceId,
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
    return _accounting.postJournalWithinTransaction(
      executor: txn,
      date: date,
      description: 'عكس مرتجع المشتريات ${value.returnNumber}',
      referenceType: referenceType,
      referenceId: referenceId,
      partyType: 'SUPPLIER',
      partyId: value.supplierId,
      lines: lines,
    );
  }

  Future<void> _validatePurchaseReturnReceiptInspection(
    DatabaseExecutor txn,
    String inspectionId,
    String receiptId,
  ) async {
    final inspectionRows = await txn.query(
      'quality_inspections',
      where: 'id = ? AND sourceType = ? AND purchaseReturnReceiptId = ?',
      whereArgs: [inspectionId, 'PURCHASE_RETURN', receiptId],
      limit: 1,
    );
    if (inspectionRows.isEmpty ||
        inspectionRows.single['status'] !=
            QualityInspectionStatus.completed.value) {
      throw Exception('Purchase Return inspection is not completed');
    }
    final receiptRows = await txn.query(
      'purchase_return_receipts',
      where: 'id = ? AND purchaseReturnId = ?',
      whereArgs: [receiptId, inspectionRows.single['sourceId']],
      limit: 1,
    );
    if (receiptRows.isEmpty ||
        receiptRows.single['warehouseId'] !=
            inspectionRows.single['warehouseId']) {
      throw Exception('Inspection receipt or warehouse does not match');
    }
    final receiptItems = await txn.query(
      'purchase_return_receipt_items',
      where: 'receiptId = ?',
      whereArgs: [receiptId],
    );
    final inspectionItems = await txn.query(
      'quality_inspection_items',
      where: 'inspectionId = ?',
      whereArgs: [inspectionId],
    );
    if (receiptItems.isEmpty || inspectionItems.isEmpty) {
      throw Exception('Inspection must contain a received receipt line');
    }
    final seenReceiptLines = <String>{};
    for (final inspectionItem in inspectionItems) {
      final itemId = inspectionItem['purchaseReturnReceiptItemId'] as String?;
      final receiptLine = receiptItems.where((item) => item['id'] == itemId);
      if (itemId == null ||
          !seenReceiptLines.add(itemId) ||
          receiptLine.length != 1) {
        throw Exception('Inspection line does not match one receipt line');
      }
      final receiptItem = receiptLine.single;
      final received = (receiptItem['baseQuantity'] as num).toDouble();
      final requested = (inspectionItem['requestedBaseQuantity'] as num)
          .toDouble();
      final inspected = (inspectionItem['inspectedBaseQuantity'] as num)
          .toDouble();
      final accepted = (inspectionItem['acceptedBaseQuantity'] as num)
          .toDouble();
      final rejected = (inspectionItem['rejectedBaseQuantity'] as num)
          .toDouble();
      final quarantined =
          (inspectionItem['quarantinedBaseQuantity'] as num? ?? 0).toDouble();
      if (inspectionItem['sourceReturnItemId'] !=
              receiptItem['purchaseReturnItemId'] ||
          !requested.isFinite ||
          requested <= 0 ||
          !inspected.isFinite ||
          inspected <= 0 ||
          inspected > requested + 0.000001 ||
          accepted < 0 ||
          rejected < 0 ||
          quarantined < 0 ||
          (accepted + rejected + quarantined - inspected).abs() > 0.000001) {
        throw Exception('Inspection quantities do not match physical receipt');
      }
      final cumulativeRows = await txn.rawQuery(
        '''
        SELECT COALESCE(SUM(qii.inspectedBaseQuantity), 0) quantity
        FROM quality_inspection_items qii
        JOIN quality_inspections qi ON qi.id = qii.inspectionId
        WHERE qi.sourceType = 'PURCHASE_RETURN' AND qi.sourceId = ?
          AND qi.purchaseReturnReceiptId = ?
          AND qii.purchaseReturnReceiptItemId = ?
        ''',
        [inspectionRows.single['sourceId'], receiptId, itemId],
      );
      final cumulativeInspected = (cumulativeRows.single['quantity'] as num)
          .toDouble();
      if (cumulativeInspected > received + 0.000001) {
        throw Exception('Cumulative inspection exceeds physical receipt');
      }
    }
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
    if (sourceType == 'SALES_RETURN' &&
        sourceRows.single['status'] != ReturnStatus.pending.value) {
      throw Exception('لا يمكن فحص مرتجع مبيعات بعد معالجته');
    }
    if (sourceType == 'PURCHASE_RETURN' &&
        sourceRows.single['status'] != ReturnStatus.pending.value) {
      throw Exception('لا يمكن فحص مرتجع مشتريات بعد اعتماده');
    }
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
    final receivedBaseBySourceLine = <String, double>{};
    final purchaseReceiptLines = <String, Map<String, Object?>>{};
    if (sourceType == 'SALES_RETURN') {
      if (value.warehouseId == null) {
        throw Exception('يجب تحديد مخزن استلام المرتجع للفحص');
      }
      final receipts = await txn.query(
        'sales_return_receipts',
        columns: ['warehouseId'],
        where: 'salesReturnId = ?',
        whereArgs: [value.sourceId],
      );
      final quarantineWarehouseIds = receipts
          .map((row) => row['warehouseId'] as String)
          .toSet();
      if (quarantineWarehouseIds.length != 1 ||
          quarantineWarehouseIds.single != value.warehouseId) {
        throw Exception('مخزن الفحص لا يطابق مخزن استلام المرتجع');
      }
      await _requireWarehousePurpose(
        txn,
        value.warehouseId!,
        WarehousePurpose.quarantine,
      );
      final receivedRows = await txn.rawQuery(
        '''
        SELECT sri.salesReturnItemId, SUM(sri.baseQuantity) baseQuantity
        FROM sales_return_receipt_items sri
        JOIN sales_return_receipts sr ON sr.id = sri.receiptId
        WHERE sr.salesReturnId = ?
        GROUP BY sri.salesReturnItemId
        ''',
        [value.sourceId],
      );
      for (final row in receivedRows) {
        receivedBaseBySourceLine[row['salesReturnItemId'] as String] =
            (row['baseQuantity'] as num).toDouble();
      }
    } else {
      final receiptId = value.purchaseReturnReceiptId;
      if (receiptId == null || value.warehouseId == null) {
        throw Exception('يجب ربط فحص الشراء بإيصال ومخزن فعليين');
      }
      final receiptRows = await txn.query(
        'purchase_return_receipts',
        where: 'id = ? AND purchaseReturnId = ?',
        whereArgs: [receiptId, value.sourceId],
        limit: 1,
      );
      if (receiptRows.isEmpty ||
          receiptRows.single['warehouseId'] != value.warehouseId) {
        throw Exception('إيصال الفحص لا يخص مرتجع المشتريات أو مخزنه');
      }
      await _security.requireResourceScope(
        ScopeType.warehouse,
        value.warehouseId!,
      );
      await _requireWarehousePurpose(
        txn,
        value.warehouseId!,
        WarehousePurpose.quarantine,
      );
      final receiptItems = await txn.query(
        'purchase_return_receipt_items',
        where: 'receiptId = ?',
        whereArgs: [receiptId],
      );
      for (final receiptItem in receiptItems) {
        purchaseReceiptLines[receiptItem['id'] as String] = receiptItem;
      }
    }
    final previouslyInspectedBaseByReceiptLine = <String, double>{};
    if (sourceType == 'PURCHASE_RETURN' &&
        value.purchaseReturnReceiptId != null) {
      final previousInspectionRows = await txn.rawQuery(
        '''
        SELECT qii.purchaseReturnReceiptItemId,
          COALESCE(SUM(qii.inspectedBaseQuantity), 0) inspectedBaseQuantity
        FROM quality_inspection_items qii
        JOIN quality_inspections qi ON qi.id = qii.inspectionId
        WHERE qi.sourceType = 'PURCHASE_RETURN' AND qi.sourceId = ?
          AND qi.purchaseReturnReceiptId = ?
        GROUP BY qii.purchaseReturnReceiptItemId
        ''',
        [value.sourceId, value.purchaseReturnReceiptId],
      );
      for (final row in previousInspectionRows) {
        final receiptLineId = row['purchaseReturnReceiptItemId'] as String?;
        if (receiptLineId != null) {
          previouslyInspectedBaseByReceiptLine[receiptLineId] =
              (row['inspectedBaseQuantity'] as num).toDouble();
        }
      }
    }
    final requestedBySourceLine = <String, double>{};
    final seenReceiptLineIds = <String>{};
    final validatedItems = <QualityInspectionItem>[];
    for (final item in value.items) {
      final qualityTotal =
          item.acceptedQuantity +
          item.rejectedQuantity +
          item.quarantinedQuantity;
      final qualityTotalInvalid = sourceType == 'PURCHASE_RETURN'
          ? qualityTotal > item.inspectedQuantity + 0.000001
          : (qualityTotal - item.inspectedQuantity).abs() > 0.000001;
      if (!item.requestedQuantity.isFinite ||
          item.requestedQuantity <= 0 ||
          !item.inspectedQuantity.isFinite ||
          item.inspectedQuantity <= 0 ||
          item.inspectedQuantity > item.requestedQuantity ||
          !item.acceptedQuantity.isFinite ||
          item.acceptedQuantity < 0 ||
          !item.rejectedQuantity.isFinite ||
          item.rejectedQuantity < 0 ||
          !item.quarantinedQuantity.isFinite ||
          item.quarantinedQuantity < 0 ||
          qualityTotalInvalid) {
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
      final requestedBaseQuantity = item.requestedQuantity * factor;
      final inspectedBaseQuantity = item.inspectedQuantity * factor;
      final acceptedBaseQuantity = item.acceptedQuantity * factor;
      final effectiveRejectedQuantity = item.rejectedQuantity;
      final rejectedBaseQuantity = effectiveRejectedQuantity * factor;
      final quarantinedBaseQuantity = item.quarantinedQuantity * factor;
      final receiptLineId = item.purchaseReturnReceiptItemId;
      final receiptLine = receiptLineId == null
          ? null
          : purchaseReceiptLines[receiptLineId];
      if (sourceType == 'PURCHASE_RETURN' &&
          (receiptLine == null ||
              !seenReceiptLineIds.add(receiptLineId!) ||
              receiptLine['purchaseReturnItemId'] != sourceItemId)) {
        throw Exception('بند الفحص لا يطابق إيصال المرتجع المحدد');
      }
      final requestedBefore = sourceType == 'SALES_RETURN'
          ? requestedBySourceLine[sourceItemId] ?? 0
          : 0.0;
      final receivedBaseQuantity = receivedBaseBySourceLine[sourceItemId];
      final purchaseReceiptBaseQuantity = (receiptLine?['baseQuantity'] as num?)
          ?.toDouble();
      final previouslyInspectedBase = receiptLineId == null
          ? 0.0
          : previouslyInspectedBaseByReceiptLine[receiptLineId] ?? 0;
      final requestedLimit = sourceType == 'PURCHASE_RETURN'
          ? purchaseReceiptBaseQuantity == null
                ? 0
                : (purchaseReceiptBaseQuantity - previouslyInspectedBase) /
                      factor
          : sourceType == 'SALES_RETURN'
          ? (receivedBaseQuantity ?? 0) / factor
          : sourceQuantity;
      if (item.requestedQuantity >
              requestedLimit - requestedBefore + 0.000001 ||
          sourceType == 'SALES_RETURN' &&
              (receivedBaseQuantity == null ||
                  requestedBaseQuantity > receivedBaseQuantity + 0.000001 ||
                  inspectedBaseQuantity > receivedBaseQuantity + 0.000001)) {
        throw Exception('كمية الفحص تتجاوز الكمية المستلمة');
      }
      for (final quantity in [
        requestedBaseQuantity,
        inspectedBaseQuantity,
        acceptedBaseQuantity,
        rejectedBaseQuantity,
        quarantinedBaseQuantity,
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
                  0.000001 ||
          item.quarantinedBaseQuantity != null &&
              (item.quarantinedBaseQuantity! - quarantinedBaseQuantity).abs() >
                  0.000001) {
        throw Exception('كمية الفحص الأساسية لا تطابق لقطة التحويل');
      }
      if (sourceType == 'SALES_RETURN') {
        requestedBySourceLine[sourceItemId] =
            (requestedBySourceLine[sourceItemId] ?? 0) + item.requestedQuantity;
      }
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
          quarantinedQuantity: item.quarantinedQuantity,
          quarantinedBaseQuantity: quarantinedBaseQuantity,
          purchaseReturnReceiptItemId: receiptLineId,
          result: item.result,
          notes: item.notes,
        ),
      );
    }
    return validatedItems;
  }

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

  Future<void> _requireWarehousePurpose(
    DatabaseExecutor txn,
    String warehouseId,
    WarehousePurpose expected,
  ) async {
    final rows = await txn.query(
      'warehouses',
      columns: ['purpose'],
      where: 'id = ? AND state = ?',
      whereArgs: [warehouseId, 'active'],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('المخزن غير موجود أو غير نشط');
    if (WarehousePurpose.fromStorage(rows.single['purpose']) != expected) {
      throw Exception('غرض المخزن غير صالح لهذه العملية');
    }
  }

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

class _SalesReturnReceiptLine {
  const _SalesReturnReceiptLine({
    required this.item,
    required this.baseQuantity,
    required this.itemOption,
    required this.unitCost,
  });

  final SalesReturnReceiptItem item;
  final double baseQuantity;
  final StockItemOption itemOption;
  final double unitCost;
}

class _SalesReturnAcceptedQuantity {
  const _SalesReturnAcceptedQuantity({
    required this.quantity,
    required this.baseQuantity,
  });

  final double quantity;
  final double baseQuantity;
}

class _SalesReturnPostingData {
  const _SalesReturnPostingData({
    required this.quarantineWarehouseId,
    required this.acceptedByReturnItem,
  });

  final String quarantineWarehouseId;
  final Map<String, _SalesReturnAcceptedQuantity> acceptedByReturnItem;
}

class ReturnsQualityDataSource extends ReturnsQualityLocalDataSource {}

class ReturnsAndQualityLocalDataSource extends ReturnsQualityLocalDataSource {}
