import 'package:furnexa/features/backup_restore/data/datasources/backup_restore_local_data_source.dart';
import 'package:furnexa/features/backup_restore/domain/entities/backup_restore_entities.dart';
import 'package:furnexa/features/backup_restore/domain/repositories/backup_restore_repository.dart';

class BackupRestoreRepositoryImpl implements BackupRestoreRepository {
  BackupRestoreRepositoryImpl({BackupRestoreLocalDataSource? dataSource})
    : _dataSource = dataSource ?? BackupRestoreLocalDataSource();

  final BackupRestoreLocalDataSource _dataSource;

  @override
  Future<BackupMetadata> createBackup({required String destination}) =>
      _dataSource.createBackup(destination: destination);

  @override
  Future<BackupMetadata> validateBackupFile(String path) =>
      _dataSource.validateBackupFile(path);

  @override
  Future<void> restoreBackup(String path) => _dataSource.restoreBackup(path);

  @override
  Future<List<BackupHistoryEntry>> getHistory() => _dataSource.getHistory();

  @override
  Future<String> createSafetyBackup() => _dataSource.createSafetyBackup();
}
