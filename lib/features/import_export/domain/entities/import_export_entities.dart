class ImportExportExport {
  const ImportExportExport({
    required this.module,
    required this.payload,
    required this.records,
    required this.exportedAt,
  });

  final String module;
  final String payload;
  final int records;
  final DateTime exportedAt;
}

class ImportExportImportSummary {
  const ImportExportImportSummary({
    required this.module,
    required this.recordsCreated,
    required this.recordsUpdated,
    required this.importedAt,
  });

  final String module;
  final int recordsCreated;
  final int recordsUpdated;
  final DateTime importedAt;
}

class ImportExportHistoryEntry {
  const ImportExportHistoryEntry({
    required this.id,
    required this.module,
    required this.type,
    required this.entityType,
    required this.description,
    required this.timestamp,
  });

  factory ImportExportHistoryEntry.fromMap(Map<String, dynamic> row) {
    return ImportExportHistoryEntry(
      id: row['id']?.toString() ?? '',
      module: row['module']?.toString() ?? 'ImportExport',
      type: row['action']?.toString() ?? 'EXPORT',
      entityType: row['entityType']?.toString() ?? 'ImportExport',
      description: row['description']?.toString() ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (row['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  final String id;
  final String module;
  final String type;
  final String entityType;
  final String description;
  final DateTime timestamp;
}
