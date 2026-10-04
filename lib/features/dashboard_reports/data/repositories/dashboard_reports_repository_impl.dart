import 'package:furnexa/features/dashboard_reports/data/datasources/dashboard_reports_local_data_source.dart';
import 'package:furnexa/features/dashboard_reports/domain/entities/dashboard_report_entities.dart';
import 'package:furnexa/features/dashboard_reports/domain/repositories/dashboard_reports_repository.dart';

class DashboardReportsRepositoryImpl implements DashboardReportsRepository {
  DashboardReportsRepositoryImpl({DashboardReportsLocalDataSource? dataSource})
    : dataSource = dataSource ?? DashboardReportsLocalDataSource();

  final DashboardReportsLocalDataSource dataSource;

  @override
  Future<DashboardSnapshot> loadDashboard(DateRangeFilter range) =>
      dataSource.loadDashboard(range);

  @override
  Future<ReportResult> loadReport(
    ReportType type,
    DateRangeFilter range, {
    String? search,
  }) => dataSource.loadReport(type, range, search: search);
}
