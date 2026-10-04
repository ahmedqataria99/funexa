import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/dashboard_reports/domain/entities/dashboard_report_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class DashboardReportsLocalDataSource {
  DashboardReportsLocalDataSource({SecurityLocalDataSource? security})
    : security = security ?? SecurityLocalDataSource();

  final SecurityLocalDataSource security;
  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<DashboardSnapshot> loadDashboard(DateRangeFilter range) async {
    await security.refreshSession();
    final inventory = await _inventoryTotals();
    final purchasing = await _purchaseTotals(range);
    final sales = await _salesTotals(range);
    final production = await _productionTotals(range);
    final hr = await _hrTotals(range);
    final financial = await _financialTotals(range);
    return DashboardSnapshot(
      inventoryQuantity: inventory.quantity,
      inventoryValue: inventory.value,
      purchaseOrders: purchasing.count,
      purchaseValue: purchasing.value,
      salesOrders: sales.count,
      salesValue: sales.value,
      productionPlanned: production.planned,
      productionInProgress: production.inProgress,
      productionCompleted: production.completed,
      producedQuantity: production.produced,
      activeWorkers: hr.active,
      presentWorkers: hr.present,
      absentWorkers: hr.absent,
      leaveWorkers: hr.leave,
      overtimeHours: hr.overtime,
      revenue: financial.revenue,
      expenses: financial.expenses,
      salesTrend: await _salesTrend(range),
      productionTrend: await _productionTrend(range),
      inventoryDistribution: await _inventoryDistribution(),
      productionStatus: await _productionStatus(range),
      attendanceSummary: await _attendanceSummary(range),
      recentActivity: await _recentActivity(),
    );
  }

  Future<ReportResult> loadReport(
    ReportType type,
    DateRangeFilter range, {
    String? search,
  }) async {
    await security.refreshSession();
    return switch (type) {
      ReportType.stockBalance => _stockBalance(search),
      ReportType.stockMovement => _stockMovement(range, search),
      ReportType.warehouse => _warehouseReport(search),
      ReportType.purchase => _purchaseReport(range, search),
      ReportType.pendingPurchaseOrders => _pendingPurchases(search),
      ReportType.receiving => _receivingReport(range, search),
      ReportType.sales => _salesReport(range, search),
      ReportType.customerSales => _customerSales(range, search),
      ReportType.productSales => _productSales(range, search),
      ReportType.delivery => _deliveryReport(range, search),
      ReportType.outstandingSalesOrders => _outstandingSales(search),
      ReportType.production => _productionReport(range, search),
      ReportType.productionStage => _productionStageReport(range, search),
      ReportType.materialConsumption => _materialConsumption(range, search),
      ReportType.waste => _wasteReport(range, search),
      ReportType.attendance => _attendanceReport(range, search),
      ReportType.late => _lateReport(range, search),
      ReportType.overtime => _overtimeReport(range, search),
      ReportType.leave => _leaveReport(range, search),
      ReportType.payrollSummary => _payrollReport(range, search),
    };
  }

  bool _can(String permission) => security.session?.can(permission) ?? false;

  String _scopeFilter(String column, ScopeType type, List<Object?> args) {
    final session = security.session!;
    if (session.isSystemAdmin) return '1 = 1';
    final ids = session.scopes
        .where((scope) => scope.type == type)
        .map((scope) => scope.scopeId)
        .toList();
    if (ids.isEmpty) return '1 = 0';
    args.addAll(ids);
    return '$column IN (${List.filled(ids.length, '?').join(',')})';
  }

  Future<List<Map<String, Object?>>> _query(
    String sql,
    List<Object?> args,
  ) async => (await _db).rawQuery(sql, args);

  Future<double> _sum(String sql, List<Object?> args) async {
    final rows = await _query(sql, args);
    return (rows.first['value'] as num?)?.toDouble() ?? 0;
  }

  Future<int> _count(String sql, List<Object?> args) async {
    final rows = await _query(sql, args);
    return (rows.first['value'] as num?)?.toInt() ?? 0;
  }

  Future<_Totals> _inventoryTotals() async {
    if (!_can('WAREHOUSE_STOCK_VIEW')) return const _Totals.zero();
    final args = <Object?>[];
    final scope = _scopeFilter('sb.warehouseId', ScopeType.warehouse, args);
    return _Totals(
      await _sum(
        'SELECT COALESCE(SUM(sb.quantity), 0) value FROM stock_balances sb WHERE $scope',
        args,
      ),
      await _sum(
        '''
        SELECT COALESCE(SUM(sb.quantity * COALESCE(iv.averageCost, 0)), 0) value
        FROM stock_balances sb LEFT JOIN inventory_valuations iv
          ON iv.warehouseId = sb.warehouseId AND iv.itemId = sb.itemId AND iv.itemType = sb.itemType
        WHERE $scope
      ''',
        [...args],
      ),
    );
  }

  Future<_Totals> _purchaseTotals(DateRangeFilter range) async {
    if (!_can('PURCHASING_VIEW')) return const _Totals.zero();
    final args = [_date(range.startDay), _date(range.endExclusive)];
    return _Totals(
      (await _count(
        'SELECT COUNT(*) value FROM purchase_orders WHERE orderDate >= ? AND orderDate < ?',
        args,
      )).toDouble(),
      await _sum(
        'SELECT COALESCE(SUM(grandTotal), 0) value FROM purchase_orders WHERE orderDate >= ? AND orderDate < ?',
        [...args],
      ),
    );
  }

  Future<_Totals> _salesTotals(DateRangeFilter range) async {
    if (!_can('SALES_VIEW')) return const _Totals.zero();
    final args = [_date(range.startDay), _date(range.endExclusive)];
    return _Totals(
      (await _count(
        'SELECT COUNT(*) value FROM sales_orders WHERE orderDate >= ? AND orderDate < ?',
        args,
      )).toDouble(),
      await _sum(
        'SELECT COALESCE(SUM(grandTotal), 0) value FROM sales_orders WHERE orderDate >= ? AND orderDate < ?',
        [...args],
      ),
    );
  }

  Future<_ProductionTotals> _productionTotals(DateRangeFilter range) async {
    if (!_can('PRODUCTION_VIEW')) return const _ProductionTotals.zero();
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _productionStageScope('po', args);
    final rows = await _query('''
      SELECT po.status, COUNT(*) count, COALESCE(SUM(po.producedQuantity), 0) produced
      FROM production_orders po
      WHERE po.createdAt >= ? AND po.createdAt < ? AND $scope GROUP BY po.status
    ''', args);
    var planned = 0;
    var inProgress = 0;
    var completed = 0;
    var produced = 0.0;
    for (final row in rows) {
      final count = (row['count'] as num).toInt();
      if (row['status'] == 'PLANNED') planned += count;
      if (row['status'] == 'IN_PROGRESS') inProgress += count;
      if (row['status'] == 'COMPLETED') completed += count;
      produced += (row['produced'] as num).toDouble();
    }
    return _ProductionTotals(planned, inProgress, completed, produced);
  }

  Future<_HrTotals> _hrTotals(DateRangeFilter range) async {
    if (!_can('HR_VIEW')) return const _HrTotals.zero();
    final activeArgs = <Object?>[];
    final activeScope = _workerScope('w', activeArgs);
    final activeRows = await _query(
      'SELECT COUNT(*) value FROM workers w WHERE w.active = 1 AND $activeScope',
      activeArgs,
    );
    final active = (activeRows.first['value'] as num?)?.toInt() ?? 0;
    final attendanceArgs = <Object?>[
      _date(range.startDay),
      _date(range.endExclusive),
    ];
    final attendanceScope = _workerScope('w', attendanceArgs);
    final rows = await _query('''
      SELECT ar.status, COUNT(*) count, COALESCE(SUM(ar.overtimeHours), 0) overtime
      FROM attendance_records ar JOIN workers w ON w.id = ar.workerId
      WHERE ar.workDate >= ? AND ar.workDate < ? AND $attendanceScope GROUP BY ar.status
    ''', attendanceArgs);
    var present = 0;
    var absent = 0;
    var leave = 0;
    var overtime = 0.0;
    for (final row in rows) {
      final count = (row['count'] as num).toInt();
      if (row['status'] == 'PRESENT') present += count;
      if (row['status'] == 'ABSENT') absent += count;
      if (row['status'] == 'LEAVE') leave += count;
      overtime += (row['overtime'] as num).toDouble();
    }
    return _HrTotals(active, present, absent, leave, overtime);
  }

  Future<_Totals> _financialTotals(DateRangeFilter range) async {
    if (!_can('ACCOUNTING_VIEW')) return const _Totals.zero();
    final rows = await _query(
      '''
      SELECT COALESCE(SUM(CASE WHEN a.type = 'REVENUE' THEN jl.credit - jl.debit ELSE 0 END), 0) revenue,
        COALESCE(SUM(CASE WHEN a.type = 'EXPENSE' THEN jl.debit - jl.credit ELSE 0 END), 0) expenses
      FROM journal_entries je JOIN journal_lines jl ON jl.journalEntryId = je.id JOIN accounts a ON a.id = jl.accountId
      WHERE je.status = 'POSTED' AND je.date >= ? AND je.date < ?
    ''',
      [_date(range.startDay), _date(range.endExclusive)],
    );
    return _Totals(
      (rows.first['revenue'] as num?)?.toDouble() ?? 0,
      (rows.first['expenses'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<TrendPoint>> _salesTrend(DateRangeFilter range) async {
    if (!_can('SALES_VIEW')) return const [];
    final rows = await _query(
      'SELECT orderDate day, COALESCE(SUM(grandTotal), 0) value FROM sales_orders WHERE orderDate >= ? AND orderDate < ? GROUP BY orderDate ORDER BY orderDate',
      [_date(range.startDay), _date(range.endExclusive)],
    );
    return rows
        .map(
          (row) =>
              TrendPoint(_label(row['day']), (row['value'] as num).toDouble()),
        )
        .toList();
  }

  Future<List<TrendPoint>> _productionTrend(DateRangeFilter range) async {
    if (!_can('PRODUCTION_VIEW')) return const [];
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _productionStageScope('po', args);
    final rows = await _query('''
      SELECT outputDate day, COALESCE(SUM(po2.quantity), 0) value
      FROM production_outputs po2 JOIN production_orders po ON po.id = po2.productionOrderId
      WHERE outputDate >= ? AND outputDate < ? AND $scope GROUP BY outputDate ORDER BY outputDate
    ''', args);
    return rows
        .map(
          (row) =>
              TrendPoint(_label(row['day']), (row['value'] as num).toDouble()),
        )
        .toList();
  }

  Future<List<BreakdownPoint>> _inventoryDistribution() async {
    if (!_can('WAREHOUSE_STOCK_VIEW')) return const [];
    final args = <Object?>[];
    final scope = _scopeFilter('iv.warehouseId', ScopeType.warehouse, args);
    final rows = await _query(
      'SELECT iv.itemType label, COALESCE(SUM(iv.quantity * iv.averageCost), 0) value FROM inventory_valuations iv WHERE $scope GROUP BY iv.itemType',
      args,
    );
    return rows
        .map(
          (row) => BreakdownPoint(
            row['label'] as String,
            (row['value'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<BreakdownPoint>> _productionStatus(DateRangeFilter range) async {
    if (!_can('PRODUCTION_VIEW')) return const [];
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _productionStageScope('po', args);
    final rows = await _query('''
      SELECT po.status label, COUNT(*) value FROM production_orders po
      WHERE po.createdAt >= ? AND po.createdAt < ? AND $scope GROUP BY po.status
    ''', args);
    return rows
        .map(
          (row) => BreakdownPoint(
            row['label'] as String,
            (row['value'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<BreakdownPoint>> _attendanceSummary(DateRangeFilter range) async {
    if (!_can('HR_VIEW')) return const [];
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _workerScope('w', args);
    final rows = await _query('''
      SELECT ar.status label, COUNT(*) value FROM attendance_records ar JOIN workers w ON w.id = ar.workerId
      WHERE ar.workDate >= ? AND ar.workDate < ? AND $scope GROUP BY ar.status
    ''', args);
    return rows
        .map(
          (row) => BreakdownPoint(
            row['label'] as String,
            (row['value'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<AuditLog>> _recentActivity() async {
    if (!_can('AUDIT_VIEW')) return const [];
    return (await security.auditLogs()).take(8).toList();
  }

  Future<ReportResult> _stockBalance(String? search) async {
    if (!_can('WAREHOUSE_STOCK_VIEW'))
      return _empty(['Warehouse', 'Item', 'Quantity', 'Value']);
    final args = <Object?>[];
    final scope = _scopeFilter('sb.warehouseId', ScopeType.warehouse, args);
    final searchSql = _search(['w.name', 'rm.name', 'p.name'], search, args);
    final rows = await _query('''
      SELECT w.name warehouse, COALESCE(rm.name, p.name, sb.itemId) item, sb.itemType itemType, sb.quantity quantity,
        u.abbreviation unit, COALESCE(iv.averageCost, 0) averageCost, sb.quantity * COALESCE(iv.averageCost, 0) inventoryValue
      FROM stock_balances sb JOIN warehouses w ON w.id = sb.warehouseId
      LEFT JOIN raw_materials rm ON rm.id = sb.itemId AND sb.itemType = 'RAW_MATERIAL'
      LEFT JOIN products p ON p.id = sb.itemId AND sb.itemType = 'PRODUCT'
      LEFT JOIN units u ON u.id = COALESCE(rm.unitId, p.unitId)
      LEFT JOIN inventory_valuations iv ON iv.warehouseId = sb.warehouseId AND iv.itemId = sb.itemId AND iv.itemType = sb.itemType
      WHERE $scope $searchSql ORDER BY w.name, item
    ''', args);
    return _result([
      'Warehouse',
      'Item',
      'Item Type',
      'Quantity',
      'Unit',
      'Average Cost',
      'Inventory Value',
    ], rows);
  }

  Future<ReportResult> _stockMovement(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('WAREHOUSE_STOCK_VIEW'))
      return _empty(['Date', 'Type', 'Warehouse', 'Item', 'Quantity']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _scopeFilter('st.warehouseId', ScopeType.warehouse, args);
    final searchSql = _search(
      ['w.name', 'rm.name', 'p.name', 'st.reference'],
      search,
      args,
    );
    final rows = await _query('''
      SELECT st.transactionDate date, st.transactionType type, w.name warehouse, COALESCE(rm.name, p.name, st.itemId) item, st.quantity quantity, st.reference reference
      FROM stock_transactions st JOIN warehouses w ON w.id = st.warehouseId
      LEFT JOIN raw_materials rm ON rm.id = st.itemId AND st.itemType = 'RAW_MATERIAL'
      LEFT JOIN products p ON p.id = st.itemId AND st.itemType = 'PRODUCT'
      WHERE st.transactionDate >= ? AND st.transactionDate < ? AND $scope $searchSql ORDER BY st.transactionDate DESC
    ''', args);
    return _result([
      'Date',
      'Type',
      'Warehouse',
      'Item',
      'Quantity',
      'Reference',
    ], rows);
  }

  Future<ReportResult> _warehouseReport(String? search) async {
    if (!_can('WAREHOUSE_STOCK_VIEW'))
      return _empty(['Warehouse', 'Items', 'Quantity', 'Value']);
    final args = <Object?>[];
    final scope = _scopeFilter('iv.warehouseId', ScopeType.warehouse, args);
    final searchSql = _search(['w.name'], search, args);
    final rows = await _query(
      'SELECT w.name warehouse, COUNT(DISTINCT iv.itemId) items, COALESCE(SUM(iv.quantity), 0) quantity, COALESCE(SUM(iv.quantity * iv.averageCost), 0) inventoryValue FROM inventory_valuations iv JOIN warehouses w ON w.id = iv.warehouseId WHERE $scope $searchSql GROUP BY w.id, w.name ORDER BY w.name',
      args,
    );
    return _result(['Warehouse', 'Items', 'Quantity', 'Inventory Value'], rows);
  }

  Future<ReportResult> _purchaseReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('PURCHASING_VIEW'))
      return _empty(['Date', 'Supplier', 'Order', 'Amount', 'Status']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final searchSql = _search(
      ['s.name', 'po.orderNumber', 'po.status'],
      search,
      args,
    );
    final rows = await _query(
      'SELECT po.orderDate date, s.name supplier, po.orderNumber orderNumber, po.grandTotal amount, po.status status FROM purchase_orders po JOIN suppliers s ON s.id = po.supplierId WHERE po.orderDate >= ? AND po.orderDate < ? $searchSql ORDER BY po.orderDate DESC',
      args,
    );
    return _result([
      'Date',
      'Supplier',
      'Purchase Order',
      'Amount',
      'Status',
    ], rows);
  }

  Future<ReportResult> _pendingPurchases(String? search) async {
    if (!_can('PURCHASING_VIEW'))
      return _empty([
        'Order',
        'Supplier',
        'Ordered',
        'Received',
        'Remaining',
        'Status',
      ]);
    final args = <Object?>[];
    final searchSql = _search(['s.name', 'po.orderNumber'], search, args);
    final rows = await _query(
      'SELECT po.orderNumber orderNumber, s.name supplier, SUM(poi.quantity) ordered, SUM(poi.receivedQuantity) received, SUM(poi.quantity - poi.receivedQuantity) remaining, po.status status FROM purchase_orders po JOIN suppliers s ON s.id = po.supplierId JOIN purchase_order_items poi ON poi.purchaseOrderId = po.id WHERE po.status IN (\'CONFIRMED\',\'PARTIALLY_RECEIVED\') $searchSql GROUP BY po.id, po.orderNumber, s.name, po.status ORDER BY po.orderDate',
      args,
    );
    return _result([
      'Order',
      'Supplier',
      'Ordered',
      'Received',
      'Remaining',
      'Status',
    ], rows);
  }

  Future<ReportResult> _receivingReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('PURCHASING_VIEW'))
      return _empty(['Receipt', 'Order', 'Warehouse', 'Date', 'Quantity']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _scopeFilter('pr.warehouseId', ScopeType.warehouse, args);
    final searchSql = _search(
      ['pr.receiptNumber', 'po.orderNumber', 'w.name'],
      search,
      args,
    );
    final rows = await _query('''
      SELECT pr.receiptNumber receipt, po.orderNumber orderNumber, w.name warehouse, pr.receiptDate date,
        COALESCE(SUM(pri.receivedQuantity), 0) quantity
      FROM purchase_receipts pr JOIN purchase_orders po ON po.id = pr.purchaseOrderId
      JOIN warehouses w ON w.id = pr.warehouseId LEFT JOIN purchase_receipt_items pri ON pri.purchaseReceiptId = pr.id
      WHERE pr.receiptDate >= ? AND pr.receiptDate < ? AND $scope $searchSql
      GROUP BY pr.id, pr.receiptNumber, po.orderNumber, w.name, pr.receiptDate ORDER BY pr.receiptDate DESC
    ''', args);
    return _result([
      'Receipt',
      'Purchase Order',
      'Warehouse',
      'Date',
      'Quantity',
    ], rows);
  }

  Future<ReportResult> _salesReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('SALES_VIEW'))
      return _empty(['Date', 'Customer', 'Order', 'Amount', 'Status']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final searchSql = _search(
      ['c.name', 'so.orderNumber', 'so.status'],
      search,
      args,
    );
    final rows = await _query(
      'SELECT so.orderDate date, c.name customer, so.orderNumber orderNumber, so.grandTotal amount, so.status status FROM sales_orders so JOIN customers c ON c.id = so.customerId WHERE so.orderDate >= ? AND so.orderDate < ? $searchSql ORDER BY so.orderDate DESC',
      args,
    );
    return _result([
      'Date',
      'Customer',
      'Sales Order',
      'Amount',
      'Status',
    ], rows);
  }

  Future<ReportResult> _customerSales(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('SALES_VIEW'))
      return _empty(['Customer', 'Orders', 'Sales Value']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final searchSql = _search(['c.name'], search, args);
    final rows = await _query(
      'SELECT c.name customer, COUNT(so.id) orders, COALESCE(SUM(so.grandTotal), 0) salesValue FROM sales_orders so JOIN customers c ON c.id = so.customerId WHERE so.orderDate >= ? AND so.orderDate < ? $searchSql GROUP BY c.id, c.name ORDER BY salesValue DESC',
      args,
    );
    return _result(['Customer', 'Orders', 'Sales Value'], rows);
  }

  Future<ReportResult> _productSales(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('SALES_VIEW'))
      return _empty(['Product', 'Quantity', 'Sales Value']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final searchSql = _search(['p.name'], search, args);
    final rows = await _query(
      'SELECT COALESCE(p.name, soi.itemId) product, SUM(soi.quantity) quantity, SUM(soi.lineTotal) salesValue FROM sales_order_items soi JOIN sales_orders so ON so.id = soi.salesOrderId LEFT JOIN products p ON p.id = soi.itemId AND soi.itemType = \'PRODUCT\' WHERE so.orderDate >= ? AND so.orderDate < ? $searchSql GROUP BY soi.itemId, p.name ORDER BY salesValue DESC',
      args,
    );
    return _result(['Product', 'Quantity', 'Sales Value'], rows);
  }

  Future<ReportResult> _deliveryReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('SALES_VIEW'))
      return _empty([
        'Delivery',
        'Order',
        'Customer',
        'Warehouse',
        'Date',
        'Quantity',
      ]);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _scopeFilter('sd.warehouseId', ScopeType.warehouse, args);
    final searchSql = _search(
      ['sd.deliveryNumber', 'so.orderNumber', 'c.name'],
      search,
      args,
    );
    final rows = await _query('''
      SELECT sd.deliveryNumber delivery, so.orderNumber orderNumber, c.name customer, w.name warehouse,
        sd.deliveryDate date, COALESCE(SUM(sdi.deliveredQuantity), 0) quantity
      FROM sales_deliveries sd JOIN sales_orders so ON so.id = sd.salesOrderId JOIN customers c ON c.id = so.customerId
      JOIN warehouses w ON w.id = sd.warehouseId LEFT JOIN sales_delivery_items sdi ON sdi.salesDeliveryId = sd.id
      WHERE sd.deliveryDate >= ? AND sd.deliveryDate < ? AND $scope $searchSql
      GROUP BY sd.id, sd.deliveryNumber, so.orderNumber, c.name, w.name, sd.deliveryDate ORDER BY sd.deliveryDate DESC
    ''', args);
    return _result([
      'Delivery',
      'Sales Order',
      'Customer',
      'Warehouse',
      'Date',
      'Quantity',
    ], rows);
  }

  Future<ReportResult> _outstandingSales(String? search) async {
    if (!_can('SALES_VIEW'))
      return _empty([
        'Order',
        'Customer',
        'Ordered',
        'Delivered',
        'Remaining',
        'Status',
      ]);
    final args = <Object?>[];
    final searchSql = _search(['c.name', 'so.orderNumber'], search, args);
    final rows = await _query('''
      SELECT so.orderNumber orderNumber, c.name customer, SUM(soi.quantity) ordered,
        SUM(soi.deliveredQuantity) delivered, SUM(soi.quantity - soi.deliveredQuantity) remaining, so.status status
      FROM sales_orders so JOIN customers c ON c.id = so.customerId JOIN sales_order_items soi ON soi.salesOrderId = so.id
      WHERE so.status IN ('CONFIRMED','PARTIALLY_DELIVERED') $searchSql
      GROUP BY so.id, so.orderNumber, c.name, so.status ORDER BY so.orderDate
    ''', args);
    return _result([
      'Order',
      'Customer',
      'Ordered',
      'Delivered',
      'Remaining',
      'Status',
    ], rows);
  }

  Future<ReportResult> _productionReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('PRODUCTION_VIEW'))
      return _empty([
        'Order',
        'Product',
        'Planned',
        'Produced',
        'Remaining',
        'Status',
      ]);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _scopeFilter(
      'pos.productionStageId',
      ScopeType.productionStage,
      args,
    );
    final searchSql = _search(
      ['po.orderNumber', 'p.name', 'po.status'],
      search,
      args,
    );
    final rows = await _query('''
      SELECT po.orderNumber orderNumber, p.name product, po.plannedQuantity planned, po.producedQuantity produced,
        po.plannedQuantity - po.producedQuantity remaining, po.status status, po.startDate startDate, po.completionDate completionDate
      FROM production_orders po JOIN products p ON p.id = po.productId
      LEFT JOIN production_order_stages pos ON pos.productionOrderId = po.id
      WHERE po.createdAt >= ? AND po.createdAt < ? AND $scope $searchSql GROUP BY po.id ORDER BY po.createdAt DESC
    ''', args);
    return _result([
      'Order',
      'Product',
      'Planned',
      'Produced',
      'Remaining',
      'Status',
      'Start',
      'Completion',
    ], rows);
  }

  Future<ReportResult> _productionStageReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('PRODUCTION_VIEW'))
      return _empty(['Order', 'Stage', 'Status', 'Start', 'Completion']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _scopeFilter(
      'pos.productionStageId',
      ScopeType.productionStage,
      args,
    );
    final searchSql = _search(
      ['po.orderNumber', 'ps.name', 'pos.status'],
      search,
      args,
    );
    final rows = await _query('''
      SELECT po.orderNumber orderNumber, ps.name stage, pos.status status, pos.startedAt start, pos.completedAt completion
      FROM production_order_stages pos JOIN production_orders po ON po.id = pos.productionOrderId
      JOIN production_stages ps ON ps.id = pos.productionStageId
      WHERE po.createdAt >= ? AND po.createdAt < ? AND $scope $searchSql ORDER BY po.createdAt DESC, pos.sequence
    ''', args);
    return _result(['Order', 'Stage', 'Status', 'Start', 'Completion'], rows);
  }

  Future<ReportResult> _materialConsumption(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('PRODUCTION_VIEW'))
      return _empty(['Order', 'Raw Material', 'Quantity', 'Date']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _scopeFilter('mc.warehouseId', ScopeType.warehouse, args);
    final searchSql = _search(['po.orderNumber', 'rm.name'], search, args);
    final rows = await _query('''
      SELECT po.orderNumber orderNumber, rm.name material, mc.quantity quantity, mc.consumptionDate date
      FROM production_material_consumptions mc JOIN production_orders po ON po.id = mc.productionOrderId JOIN raw_materials rm ON rm.id = mc.rawMaterialId
      WHERE mc.consumptionDate >= ? AND mc.consumptionDate < ? AND $scope $searchSql ORDER BY mc.consumptionDate DESC
    ''', args);
    return _result(['Order', 'Raw Material', 'Quantity', 'Date'], rows);
  }

  Future<ReportResult> _wasteReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('PRODUCTION_VIEW'))
      return _empty(['Order', 'Item', 'Quantity', 'Reason', 'Date']);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _scopeFilter('pw.warehouseId', ScopeType.warehouse, args);
    final searchSql = _search(
      ['po.orderNumber', 'rm.name', 'pw.reason'],
      search,
      args,
    );
    final rows = await _query('''
      SELECT po.orderNumber orderNumber, rm.name item, pw.quantity quantity, pw.reason reason, pw.wasteDate date
      FROM production_waste pw JOIN production_orders po ON po.id = pw.productionOrderId JOIN raw_materials rm ON rm.id = pw.rawMaterialId
      WHERE pw.wasteDate >= ? AND pw.wasteDate < ? AND $scope $searchSql ORDER BY pw.wasteDate DESC
    ''', args);
    return _result(['Order', 'Item', 'Quantity', 'Reason', 'Date'], rows);
  }

  Future<ReportResult> _attendanceReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('HR_VIEW'))
      return _empty([
        'Worker',
        'Date',
        'Status',
        'Regular Hours',
        'Overtime',
        'Late',
      ]);
    final args = <Object?>[_date(range.startDay), _date(range.endExclusive)];
    final scope = _workerScope('w', args);
    final searchSql = _search(['w.name', 'ar.status'], search, args);
    final rows = await _query('''
      SELECT w.name worker, ar.workDate date, ar.status status, ar.regularHours regularHours, ar.overtimeHours overtimeHours,
        ar.lateMinutes lateMinutes, ar.earlyLeaveMinutes earlyLeave
      FROM attendance_records ar JOIN workers w ON w.id = ar.workerId
      WHERE ar.workDate >= ? AND ar.workDate < ? AND $scope $searchSql ORDER BY ar.workDate DESC
    ''', args);
    return _result([
      'Worker',
      'Date',
      'Status',
      'Regular Hours',
      'Overtime',
      'Late',
      'Early Leave',
    ], rows);
  }

  Future<ReportResult> _lateReport(
    DateRangeFilter range,
    String? search,
  ) async {
    final result = await _attendanceReport(range, search);
    return ReportResult(
      columns: ['Worker', 'Date', 'Late'],
      rows: result.rows
          .where((row) => ((row['Late'] as num?) ?? 0) > 0)
          .toList(),
    );
  }

  Future<ReportResult> _overtimeReport(
    DateRangeFilter range,
    String? search,
  ) async {
    final result = await _attendanceReport(range, search);
    return ReportResult(
      columns: ['Worker', 'Date', 'Overtime'],
      rows: result.rows
          .where((row) => ((row['Overtime'] as num?) ?? 0) > 0)
          .toList(),
    );
  }

  Future<ReportResult> _leaveReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('HR_VIEW'))
      return _empty(['Worker', 'Type', 'Start', 'End', 'Days', 'Status']);
    final args = <Object?>[_date(range.endExclusive), _date(range.startDay)];
    final scope = _workerScope('w', args);
    final searchSql = _search(
      ['w.name', 'lr.leaveType', 'lr.status'],
      search,
      args,
    );
    final rows = await _query('''
      SELECT w.name worker, lr.leaveType type, lr.startDate start, lr.endDate end, lr.days days, lr.status status
      FROM leave_records lr JOIN workers w ON w.id = lr.workerId
      WHERE lr.startDate < ? AND lr.endDate >= ? AND $scope $searchSql ORDER BY lr.startDate DESC
    ''', args);
    return _result([
      'Worker',
      'Leave Type',
      'Start',
      'End',
      'Days',
      'Status',
    ], rows);
  }

  Future<ReportResult> _payrollReport(
    DateRangeFilter range,
    String? search,
  ) async {
    if (!_can('HR_PAYROLL_APPROVE'))
      return _empty(['Worker', 'Period', 'Gross', 'Net', 'Status']);
    final args = <Object?>[_date(range.endExclusive), _date(range.startDay)];
    final scope = _workerScope('w', args);
    final searchSql = _search(['w.name', 'pp.name', 'pr.status'], search, args);
    final rows = await _query('''
      SELECT w.name worker, pp.name period, pr.regularEarnings regularEarnings, pr.overtimeAmount overtime,
        pr.deductionsAmount deductions, pr.grossSalary gross, pr.netSalary net, pr.status status
      FROM payroll_records pr JOIN workers w ON w.id = pr.workerId JOIN payroll_periods pp ON pp.id = pr.payrollPeriodId
      WHERE pp.startDate < ? AND pp.endDate >= ? AND $scope $searchSql ORDER BY pp.startDate DESC, w.name
    ''', args);
    return _result([
      'Worker',
      'Period',
      'Regular Earnings',
      'Overtime',
      'Deductions',
      'Gross',
      'Net',
      'Status',
    ], rows);
  }

  String _workerScope(String alias, List<Object?> args) {
    final session = security.session!;
    if (session.isSystemAdmin) return '1 = 1';
    final clauses = <String>[];
    for (final type in [
      ScopeType.section,
      ScopeType.workshop,
      ScopeType.productionStage,
    ]) {
      final ids = session.scopes
          .where((scope) => scope.type == type)
          .map((scope) => scope.scopeId)
          .toList();
      if (ids.isEmpty) continue;
      final column = switch (type) {
        ScopeType.section => 'sectionId',
        ScopeType.workshop => 'workshopId',
        ScopeType.productionStage => 'productionStageId',
        ScopeType.warehouse => 'warehouseId',
      };
      args.addAll(ids);
      clauses.add(
        '$alias.$column IN (${List.filled(ids.length, '?').join(',')})',
      );
    }
    return clauses.isEmpty ? '1 = 0' : '(${clauses.join(' OR ')})';
  }

  String _productionStageScope(String orderAlias, List<Object?> args) {
    final session = security.session!;
    if (session.isSystemAdmin) return '1 = 1';
    final clauses = <String>[];
    for (final type in [
      ScopeType.productionStage,
      ScopeType.workshop,
      ScopeType.section,
    ]) {
      final ids = session.scopes
          .where((scope) => scope.type == type)
          .map((scope) => scope.scopeId)
          .toList();
      if (ids.isEmpty) continue;
      args.addAll(ids);
      if (type == ScopeType.productionStage) {
        clauses.add(
          'EXISTS (SELECT 1 FROM production_order_stages scoped_pos '
          'WHERE scoped_pos.productionOrderId = $orderAlias.id '
          'AND scoped_pos.productionStageId IN (${List.filled(ids.length, '?').join(',')}))',
        );
      } else {
        final column = type == ScopeType.workshop ? 'workshopId' : 'sectionId';
        clauses.add(
          'EXISTS (SELECT 1 FROM production_order_stages scoped_pos '
          'JOIN workers scoped_worker ON scoped_worker.productionStageId = scoped_pos.productionStageId '
          'WHERE scoped_pos.productionOrderId = $orderAlias.id '
          'AND scoped_worker.$column IN (${List.filled(ids.length, '?').join(',')}))',
        );
      }
    }
    final warehouseIds = session.scopes
        .where((scope) => scope.type == ScopeType.warehouse)
        .map((scope) => scope.scopeId)
        .toList();
    if (warehouseIds.isNotEmpty) {
      args.addAll(warehouseIds);
      clauses.add(
        'EXISTS (SELECT 1 FROM production_outputs scoped_output '
        'WHERE scoped_output.productionOrderId = $orderAlias.id '
        'AND scoped_output.warehouseId IN (${List.filled(warehouseIds.length, '?').join(',')}))',
      );
    }
    return clauses.isEmpty ? '1 = 0' : '(${clauses.join(' OR ')})';
  }

  String _search(List<String> columns, String? search, List<Object?> args) {
    if (search == null || search.trim().isEmpty) return '';
    args.addAll(List<Object?>.filled(columns.length, '%${search.trim()}%'));
    return 'AND (${columns.map((column) => '$column LIKE ?').join(' OR ')})';
  }

  ReportResult _result(List<String> columns, List<Map<String, Object?>> rows) =>
      ReportResult(columns: columns, rows: rows.map(ReportRow.new).toList());
  ReportResult _empty(List<String> columns) =>
      ReportResult(columns: columns, rows: const []);
  int _date(DateTime value) => value.millisecondsSinceEpoch;
  String _label(Object? value) => value is int
      ? DateTime.fromMillisecondsSinceEpoch(
          value,
        ).toIso8601String().substring(0, 10)
      : '$value';
}

class _Totals {
  const _Totals(this.countOrQuantity, this.value);
  const _Totals.zero() : countOrQuantity = 0, value = 0;
  final double countOrQuantity;
  final double value;
  int get count => countOrQuantity.toInt();
  double get quantity => countOrQuantity;
  double get revenue => countOrQuantity;
  double get expenses => value;
}

class _ProductionTotals {
  const _ProductionTotals(
    this.planned,
    this.inProgress,
    this.completed,
    this.produced,
  );
  const _ProductionTotals.zero()
    : planned = 0,
      inProgress = 0,
      completed = 0,
      produced = 0;
  final int planned;
  final int inProgress;
  final int completed;
  final double produced;
}

class _HrTotals {
  const _HrTotals(
    this.active,
    this.present,
    this.absent,
    this.leave,
    this.overtime,
  );
  const _HrTotals.zero()
    : active = 0,
      present = 0,
      absent = 0,
      leave = 0,
      overtime = 0;
  final int active;
  final int present;
  final int absent;
  final int leave;
  final double overtime;
}
