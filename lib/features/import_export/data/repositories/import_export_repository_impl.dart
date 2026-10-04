import 'package:furnexa/features/import_export/data/datasources/import_export_local_data_source.dart';
import 'package:furnexa/features/import_export/domain/entities/import_export_entities.dart';
import 'package:furnexa/features/import_export/domain/repositories/import_export_repository.dart';

class ImportExportRepositoryImpl implements ImportExportRepository {
  ImportExportRepositoryImpl({ImportExportLocalDataSource? dataSource})
    : _dataSource = dataSource ?? ImportExportLocalDataSource();

  final ImportExportLocalDataSource _dataSource;

  @override
  Future<ImportExportExport> exportData({required String module}) =>
      _dataSource.exportData(module: module);

  @override
  Future<ImportExportImportSummary> importData(String payload) =>
      _dataSource.importData(payload);

  @override
  Future<List<ImportExportHistoryEntry>> history({String? module}) =>
      _dataSource.history(module: module);
}
