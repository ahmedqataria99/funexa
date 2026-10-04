import 'package:furnexa/features/backup_restore/domain/entities/backup_restore_entities.dart';

abstract class BackupRestoreRepository {
  Future<BackupMetadata> createBackup({required String destination});
  Future<BackupMetadata> validateBackupFile(String path);
  Future<void> restoreBackup(String path);
  Future<List<BackupHistoryEntry>> getHistory();
  Future<String> createSafetyBackup();
}
