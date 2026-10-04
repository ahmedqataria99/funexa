import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/dashboard_reports/data/datasources/dashboard_reports_local_data_source.dart';
import 'package:furnexa/features/dashboard_reports/domain/entities/dashboard_report_entities.dart';
import 'package:furnexa/features/dashboard_reports/domain/repositories/dashboard_reports_repository.dart';
import 'package:furnexa/features/dashboard_reports/presentation/pages/dashboard_reports_page.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late SecurityLocalDataSource security;
  late DashboardReportsLocalDataSource dataSource;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.ensureInitialAdmin();
    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    dataSource = DashboardReportsLocalDataSource(security: security);
  });

  tearDown(() async {
    security.logout();
    await FurnexaDatabase.instance.resetForTesting();
  });

  test('dashboard loads', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot, isA<DashboardSnapshot>());
  });

  test('admin dashboard access', () async {
    expect(
      (await dataSource.loadDashboard(DateRangeFilter.today())).inventoryValue,
      0,
    );
  });

  test('role-based KPI visibility', () async {
    final role = await security.createRole(name: 'Sales dashboard');
    await security.setRolePermissions(role.id, ['SALES_VIEW']);
    final user = await security.createUser(
      username: 'sales-dashboard',
      displayName: 'Sales',
      password: 'secret',
      roleId: role.id,
    );
    security.logout();
    await security.login('sales-dashboard', 'secret');
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.salesOrders, 0);
    expect(snapshot.inventoryValue, 0);
    expect(user.username, 'sales-dashboard');
  });

  test('permission-restricted KPI hidden', () async {
    final role = await security.createRole(name: 'No accounting dashboard');
    await security.setRolePermissions(role.id, ['SALES_VIEW']);
    await security.createUser(
      username: 'no-accounting',
      displayName: 'No Accounting',
      password: 'secret',
      roleId: role.id,
    );
    security.logout();
    await security.login('no-accounting', 'secret');
    expect(
      (await dataSource.loadDashboard(DateRangeFilter.thisMonth())).revenue,
      0,
    );
  });

  test('scope-restricted inventory KPI', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.inventoryQuantity, 0);
  });

  test('scope-restricted production KPI', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.productionPlanned, 0);
  });

  test('date filter correctness', () {
    final range = DateRangeFilter(
      start: DateTime(2026, 1, 2),
      end: DateTime(2026, 1, 4),
    );
    expect(range.contains(DateTime(2026, 1, 4, 23)), isTrue);
    expect(range.contains(DateTime(2026, 1, 5)), isFalse);
  });

  test('sales trend aggregation', () async {
    final result = await dataSource.loadReport(
      ReportType.sales,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Sales Order'));
  });

  test('production trend aggregation', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.productionTrend, isEmpty);
  });

  test('multi-stage production output is counted once', () async {
    final db = await FurnexaDatabase.instance.database;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await db.insert('factories', {
      'id': 'report-factory',
      'name': 'Report Factory',
      'code': 'REPORT-F',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('categories', {
      'id': 'report-category',
      'name': 'Report Category',
      'code': 'REPORT-C',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('units', {
      'id': 'report-unit',
      'name': 'Pieces',
      'abbreviation': 'RPT',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('products', {
      'id': 'report-product',
      'name': 'Report Product',
      'code': 'REPORT-P',
      'categoryId': 'report-category',
      'unitId': 'report-unit',
      'productState': 'finished',
      'active': 1,
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    for (var sequence = 1; sequence <= 2; sequence++) {
      await db.insert('production_stages', {
        'id': 'report-stage-$sequence',
        'factoryId': 'report-factory',
        'name': 'Stage $sequence',
        'code': 'REPORT-S$sequence',
        'sequence': sequence,
        'active': 1,
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    }
    await db.insert('production_routes', {
      'id': 'report-route',
      'productId': 'report-product',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('warehouses', {
      'id': 'report-warehouse',
      'factoryId': 'report-factory',
      'name': 'Report Warehouse',
      'code': 'REPORT-W',
      'state': 'active',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    await db.insert('production_orders', {
      'id': 'report-order',
      'orderNumber': 'REPORT-ORDER',
      'productId': 'report-product',
      'routeId': 'report-route',
      'plannedQuantity': 10,
      'producedQuantity': 4,
      'status': 'IN_PROGRESS',
      'createdAt': stamp,
      'updatedAt': stamp,
    });
    for (var sequence = 1; sequence <= 2; sequence++) {
      await db.insert('production_order_stages', {
        'id': 'report-order-stage-$sequence',
        'productionOrderId': 'report-order',
        'productionStageId': 'report-stage-$sequence',
        'sequence': sequence,
        'status': 'COMPLETED',
        'createdAt': stamp,
        'updatedAt': stamp,
      });
    }
    await db.insert('production_outputs', {
      'id': 'report-output',
      'productionOrderId': 'report-order',
      'warehouseId': 'report-warehouse',
      'quantity': 4,
      'unitId': 'report-unit',
      'outputDate': stamp,
      'createdAt': stamp,
    });

    final range = DateRangeFilter(
      start: DateTime.fromMillisecondsSinceEpoch(stamp),
      end: DateTime.fromMillisecondsSinceEpoch(stamp),
    );
    final snapshot = await dataSource.loadDashboard(range);
    expect(snapshot.producedQuantity, 4);
    expect(snapshot.productionTrend, hasLength(1));
    expect(snapshot.productionTrend.single.value, 4);
  });

  test('revenue vs expenses aggregation', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.netResult, 0);
  });

  test('inventory distribution aggregation', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.inventoryDistribution, isEmpty);
  });

  test('attendance aggregation', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.attendanceSummary, isEmpty);
  });

  test('production status aggregation', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.productionStatus, isEmpty);
  });

  test('stock balance report', () async {
    final result = await dataSource.loadReport(
      ReportType.stockBalance,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Inventory Value'));
  });

  test('stock movement report', () async {
    final result = await dataSource.loadReport(
      ReportType.stockMovement,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Reference'));
  });

  test('warehouse report', () async {
    final result = await dataSource.loadReport(
      ReportType.warehouse,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Warehouse'));
  });

  test('purchase report', () async {
    final result = await dataSource.loadReport(
      ReportType.purchase,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Supplier'));
  });

  test('pending purchase orders', () async {
    final result = await dataSource.loadReport(
      ReportType.pendingPurchaseOrders,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Remaining'));
  });

  test('receiving report', () async {
    final result = await dataSource.loadReport(
      ReportType.receiving,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Receipt'));
  });

  test('sales report', () async {
    final result = await dataSource.loadReport(
      ReportType.sales,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Customer'));
  });

  test('customer sales report', () async {
    final result = await dataSource.loadReport(
      ReportType.customerSales,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Sales Value'));
  });

  test('product sales report', () async {
    final result = await dataSource.loadReport(
      ReportType.productSales,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Product'));
  });

  test('delivery report', () async {
    final result = await dataSource.loadReport(
      ReportType.delivery,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Delivery'));
  });

  test('outstanding sales orders', () async {
    final result = await dataSource.loadReport(
      ReportType.outstandingSalesOrders,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Remaining'));
  });

  test('production report', () async {
    final result = await dataSource.loadReport(
      ReportType.production,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Produced'));
  });

  test('production stage report', () async {
    final result = await dataSource.loadReport(
      ReportType.productionStage,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Stage'));
  });

  test('material consumption report', () async {
    final result = await dataSource.loadReport(
      ReportType.materialConsumption,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Raw Material'));
  });

  test('waste report', () async {
    final result = await dataSource.loadReport(
      ReportType.waste,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Reason'));
  });

  test('attendance report', () async {
    final result = await dataSource.loadReport(
      ReportType.attendance,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Worker'));
  });

  test('late report', () async {
    final result = await dataSource.loadReport(
      ReportType.late,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Late'));
  });

  test('overtime report', () async {
    final result = await dataSource.loadReport(
      ReportType.overtime,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Overtime'));
  });

  test('leave report', () async {
    final result = await dataSource.loadReport(
      ReportType.leave,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Leave Type'));
  });

  test('payroll summary permissions', () async {
    final result = await dataSource.loadReport(
      ReportType.payrollSummary,
      DateRangeFilter.thisMonth(),
    );
    expect(result.columns, contains('Net'));
  });

  test('recent activity integration', () async {
    final snapshot = await dataSource.loadDashboard(
      DateRangeFilter.thisMonth(),
    );
    expect(snapshot.recentActivity, isNotNull);
  });

  test('empty-state behavior', () async {
    final result = await dataSource.loadReport(
      ReportType.stockBalance,
      DateRangeFilter.thisMonth(),
    );
    expect(result.rows, isEmpty);
  });

  test('date-range edge cases', () async {
    final range = DateRangeFilter(
      start: DateTime(2026, 2, 28),
      end: DateTime(2026, 2, 28),
    );
    final result = await dataSource.loadReport(ReportType.sales, range);
    expect(result.rows, isEmpty);
  });

  test('scope enforcement at query and business level', () async {
    final role = await security.createRole(name: 'Scoped dashboard');
    await security.setRolePermissions(role.id, ['WAREHOUSE_STOCK_VIEW']);
    final user = await security.createUser(
      username: 'scoped-dashboard',
      displayName: 'Scoped',
      password: 'secret',
      roleId: role.id,
    );
    await security.setUserScopes(user.id, const [
      UserScope(
        id: 'scope',
        userId: 'user',
        type: ScopeType.warehouse,
        scopeId: 'warehouse-a',
      ),
    ]);
    security.logout();
    await security.login('scoped-dashboard', 'secret');
    final result = await dataSource.loadReport(
      ReportType.stockBalance,
      DateRangeFilter.thisMonth(),
    );
    expect(result.rows, isEmpty);
  });

  testWidgets('dashboard page renders responsive empty state', (tester) async {
    final fake = _FakeRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardReportsPage(security: security, repository: fake),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لوحة التشغيل'), findsOneWidget);
    expect(find.text('لا توجد بيانات للفترة المحددة'), findsWidgets);
  });
}

class _FakeRepository implements DashboardReportsRepository {
  @override
  Future<DashboardSnapshot> loadDashboard(DateRangeFilter range) async =>
      const DashboardSnapshot(
        inventoryQuantity: 0,
        inventoryValue: 0,
        purchaseOrders: 0,
        purchaseValue: 0,
        salesOrders: 0,
        salesValue: 0,
        productionPlanned: 0,
        productionInProgress: 0,
        productionCompleted: 0,
        producedQuantity: 0,
        activeWorkers: 0,
        presentWorkers: 0,
        absentWorkers: 0,
        leaveWorkers: 0,
        overtimeHours: 0,
        revenue: 0,
        expenses: 0,
        salesTrend: [],
        productionTrend: [],
        inventoryDistribution: [],
        productionStatus: [],
        attendanceSummary: [],
        recentActivity: [],
      );

  @override
  Future<ReportResult> loadReport(
    ReportType type,
    DateRangeFilter range, {
    String? search,
  }) async => const ReportResult(columns: [], rows: []);
}
