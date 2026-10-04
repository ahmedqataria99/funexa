import 'package:furnexa/features/dashboard_reports/domain/entities/dashboard_report_entities.dart';

abstract class DashboardReportsRepository {
  Future<DashboardSnapshot> loadDashboard(DateRangeFilter range);
  Future<ReportResult> loadReport(
    ReportType type,
    DateRangeFilter range, {
    String? search,
  });
}
