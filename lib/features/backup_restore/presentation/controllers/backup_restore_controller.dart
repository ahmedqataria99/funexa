import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:furnexa/features/backup_restore/domain/entities/backup_restore_entities.dart';
import 'package:furnexa/features/backup_restore/domain/repositories/backup_restore_repository.dart';

class BackupRestoreController extends ChangeNotifier {
  BackupRestoreController({required BackupRestoreRepository repository})
    : _repository = repository;

  final BackupRestoreRepository _repository;
  List<BackupHistoryEntry> history = const [];
  BackupMetadata? selectedBackup;
  BackupMetadata? lastBackup;
  bool loading = false;
  bool creating = false;
  bool validating = false;
  bool restoring = false;
  String? error;
  String? success;

  bool get busy => loading || creating || validating || restoring;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      history = await _repository.getHistory();
      final valid = history.where((entry) => entry.status == 'VALID').toList();
      if (valid.isNotEmpty) {
        lastBackup = _metadataFromHistory(valid.first);
      }
    } catch (_) {
      error = 'load';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<BackupMetadata?> createBackup(String destination) async {
    creating = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      final metadata = await _repository.createBackup(destination: destination);
      lastBackup = metadata;
      success = 'created';
      await _reloadHistory();
      return metadata;
    } catch (_) {
      error = 'create';
      return null;
    } finally {
      creating = false;
      notifyListeners();
    }
  }

  Future<BackupMetadata?> validateBackup(String path) async {
    validating = true;
    error = null;
    success = null;
    selectedBackup = null;
    notifyListeners();
    try {
      selectedBackup = await _repository.validateBackupFile(path);
      return selectedBackup;
    } catch (_) {
      error = 'validate';
      return null;
    } finally {
      validating = false;
      notifyListeners();
    }
  }

  Future<bool> restoreBackup(String path) async {
    restoring = true;
    error = null;
    success = null;
    notifyListeners();
    try {
      await _repository.restoreBackup(path);
      history = const [];
      selectedBackup = null;
      lastBackup = null;
      success = 'restored';
      return true;
    } catch (_) {
      error = 'restore';
      return false;
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  void clearFeedback() {
    error = null;
    success = null;
    notifyListeners();
  }

  Future<void> _reloadHistory() async {
    history = await _repository.getHistory();
  }

  BackupMetadata _metadataFromHistory(BackupHistoryEntry entry) =>
      BackupMetadata(
        backupId: entry.backupId,
        createdAt: entry.createdAt,
        appVersion: '',
        databaseVersion: entry.databaseVersion,
        factoryName: entry.factoryName,
        factoryCode: entry.factoryCode,
        recordCount: 0,
        checksum: entry.checksum,
        backupFormatVersion: 0,
        fileName: entry.fileName,
        location: entry.filePath,
        database: const {},
      );
}
