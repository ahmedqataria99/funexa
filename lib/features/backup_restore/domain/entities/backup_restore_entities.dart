class BackupMetadata {
  const BackupMetadata({
    required this.backupId,
    required this.createdAt,
    required this.appVersion,
    required this.databaseVersion,
    required this.factoryName,
    required this.factoryCode,
    required this.recordCount,
    required this.checksum,
    required this.backupFormatVersion,
    required this.fileName,
    required this.location,
    required this.database,
  });

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    final database = json['database'];
    return BackupMetadata(
      backupId: (json['backupId'] ?? '').toString(),
      createdAt: DateTime.parse(
        (json['createdAt'] ?? DateTime.now().toUtc().toIso8601String())
            .toString(),
      ),
      appVersion: (json['appVersion'] ?? '').toString(),
      databaseVersion:
          int.tryParse((json['databaseVersion'] ?? '0').toString()) ?? 0,
      factoryName: (json['factoryName'] ?? '').toString(),
      factoryCode: (json['factoryCode'] ?? '').toString(),
      recordCount: int.tryParse((json['recordCount'] ?? '0').toString()) ?? 0,
      checksum: (json['checksum'] ?? '').toString(),
      backupFormatVersion:
          int.tryParse((json['backupFormatVersion'] ?? '0').toString()) ?? 0,
      fileName: (json['fileName'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      database: database is Map
          ? Map<String, dynamic>.from(database)
          : const {},
    );
  }

  final String backupId;
  final DateTime createdAt;
  final String appVersion;
  final int databaseVersion;
  final String factoryName;
  final String factoryCode;
  final int recordCount;
  final String checksum;
  final int backupFormatVersion;
  final String fileName;
  final String location;
  final Map<String, dynamic> database;

  Map<String, dynamic> toJson() => {
    'backupId': backupId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'appVersion': appVersion,
    'databaseVersion': databaseVersion,
    'factoryName': factoryName,
    'factoryCode': factoryCode,
    'recordCount': recordCount,
    'checksum': checksum,
    'backupFormatVersion': backupFormatVersion,
    'fileName': fileName,
    'location': location,
    'database': database,
  };
}

class BackupHistoryEntry {
  const BackupHistoryEntry({
    required this.id,
    required this.backupId,
    required this.createdAt,
    required this.factoryName,
    required this.factoryCode,
    required this.databaseVersion,
    required this.fileName,
    required this.sizeBytes,
    required this.status,
    required this.checksum,
    required this.filePath,
  });

  factory BackupHistoryEntry.fromMap(Map<String, dynamic> row) {
    return BackupHistoryEntry(
      id: row['id']?.toString() ?? '',
      backupId: row['backupId']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      factoryName: row['factoryName']?.toString() ?? '',
      factoryCode: row['factoryCode']?.toString() ?? '',
      databaseVersion:
          int.tryParse((row['databaseVersion'] ?? '0').toString()) ?? 0,
      fileName: row['fileName']?.toString() ?? '',
      sizeBytes: int.tryParse((row['sizeBytes'] ?? '0').toString()) ?? 0,
      status: row['status']?.toString() ?? 'VALID',
      checksum: row['checksum']?.toString() ?? '',
      filePath: row['filePath']?.toString() ?? '',
    );
  }

  final String id;
  final String backupId;
  final DateTime createdAt;
  final String factoryName;
  final String factoryCode;
  final int databaseVersion;
  final String fileName;
  final int sizeBytes;
  final String status;
  final String checksum;
  final String filePath;
}
