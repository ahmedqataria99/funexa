import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class DateRangeFilter {
  const DateRangeFilter({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  DateTime get startDay => DateTime(start.year, start.month, start.day);
  DateTime get endExclusive => DateTime(end.year, end.month, end.day + 1);

  bool contains(DateTime value) =>
      !value.isBefore(startDay) && value.isBefore(endExclusive);

  static DateRangeFilter today() {
    final now = DateTime.now();
    return DateRangeFilter(start: now, end: now);
  }

  static DateRangeFilter thisWeek() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final start = day.subtract(Duration(days: day.weekday - 1));
    return DateRangeFilter(
      start: start,
      end: start.add(const Duration(days: 6)),
    );
  }

  static DateRangeFilter thisMonth() {
    final now = DateTime.now();
    return DateRangeFilter(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.inventoryQuantity,
    required this.inventoryValue,
    required this.purchaseOrders,
    required this.purchaseValue,
    required this.salesOrders,
    required this.salesValue,
    required this.productionPlanned,
    required this.productionInProgress,
    required this.productionCompleted,
    required this.producedQuantity,
    required this.activeWorkers,
    required this.presentWorkers,
    required this.absentWorkers,
    required this.leaveWorkers,
    required this.overtimeHours,
    required this.revenue,
    required this.expenses,
    required this.salesTrend,
    required this.productionTrend,
    required this.inventoryDistribution,
    required this.productionStatus,
    required this.attendanceSummary,
    required this.recentActivity,
  });

  final double inventoryQuantity;
  final double inventoryValue;
  final int purchaseOrders;
  final double purchaseValue;
  final int salesOrders;
  final double salesValue;
  final int productionPlanned;
  final int productionInProgress;
  final int productionCompleted;
  final double producedQuantity;
  final int activeWorkers;
  final int presentWorkers;
  final int absentWorkers;
  final int leaveWorkers;
  final double overtimeHours;
  final double revenue;
  final double expenses;
  final List<TrendPoint> salesTrend;
  final List<TrendPoint> productionTrend;
  final List<BreakdownPoint> inventoryDistribution;
  final List<BreakdownPoint> productionStatus;
  final List<BreakdownPoint> attendanceSummary;
  final List<AuditLog> recentActivity;

  double get netResult => revenue - expenses;
}

class TrendPoint {
  const TrendPoint(this.label, this.value);
  final String label;
  final double value;
}

class BreakdownPoint {
  const BreakdownPoint(this.label, this.value);
  final String label;
  final double value;
}

enum ReportType {
  stockBalance,
  stockMovement,
  warehouse,
  purchase,
  pendingPurchaseOrders,
  receiving,
  sales,
  customerSales,
  productSales,
  delivery,
  outstandingSalesOrders,
  production,
  productionStage,
  materialConsumption,
  waste,
  attendance,
  late,
  overtime,
  leave,
  payrollSummary,
}

class ReportRow {
  const ReportRow(this.values);
  final Map<String, Object?> values;

  Object? operator [](String key) => values[key];
}

class ReportResult {
  const ReportResult({required this.columns, required this.rows});
  final List<String> columns;
  final List<ReportRow> rows;
}
