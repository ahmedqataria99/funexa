import 'package:furnexa/features/import_export/domain/entities/import_export_entities.dart';

abstract class ImportExportRepository {
  Future<ImportExportExport> exportData({required String module});
  Future<ImportExportImportSummary> importData(String payload);
  Future<List<ImportExportHistoryEntry>> history({String? module});
}
