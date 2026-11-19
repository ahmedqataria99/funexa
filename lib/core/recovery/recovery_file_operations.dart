import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

class RecoveryFileIdentity {
  const RecoveryFileIdentity({
    required this.canonicalPath,
    required this.size,
    required this.modifiedUtc,
  });

  final String canonicalPath;
  final int size;
  final DateTime modifiedUtc;

  Map<String, dynamic> toJson() => {
    'canonicalPath': canonicalPath,
    'size': size,
    'modifiedUtc': modifiedUtc.toUtc().toIso8601String(),
  };
}

class RecoverySidecars {
  const RecoverySidecars({required this.wal, required this.shm});

  final RecoveryFileIdentity? wal;
  final RecoveryFileIdentity? shm;
}

abstract interface class RecoveryFileOperations {
  Future<void> createNewFile(String path, List<int> bytes);
  Future<void> copyFile(String source, String destination);
  Future<String> sha256(String path);
  Future<bool> exists(String path);
  Future<RecoveryFileIdentity> verifyIdentity(String path);
  Future<void> renameWithoutOverwrite(String source, String destination);
  Future<void> flushFile(String path);
  Future<RecoverySidecars> inspectSidecars(String databasePath);
}

class LocalRecoveryFileOperations implements RecoveryFileOperations {
  const LocalRecoveryFileOperations();

  String _canonicalPath(String path) =>
      File(path).absolute.path.replaceAll(r'\', '/');

  @override
  Future<void> createNewFile(String path, List<int> bytes) async {
    final file = File(path);
    await file.create(exclusive: true, recursive: true);
    final random = file.openSync(mode: FileMode.writeOnly);
    try {
      random.writeFromSync(bytes);
      random.flushSync();
    } finally {
      random.closeSync();
    }
  }

  @override
  Future<void> copyFile(String source, String destination) async {
    await File(source).copy(destination);
  }

  @override
  Future<String> sha256(String path) async {
    final digest = await crypto.sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<RecoveryFileIdentity> verifyIdentity(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw RecoveryFileOperationException('File does not exist: $path');
    }
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw RecoveryFileOperationException('Not a regular file: $path');
    }
    return RecoveryFileIdentity(
      canonicalPath: _canonicalPath(path),
      size: stat.size,
      modifiedUtc: stat.modified.toUtc(),
    );
  }

  @override
  Future<void> renameWithoutOverwrite(String source, String destination) async {
    if (await File(destination).exists()) {
      throw RecoveryFileOperationException(
        'Refusing to overwrite existing destination: $destination',
      );
    }
    await File(source).rename(destination);
  }

  @override
  Future<void> flushFile(String path) async {
    final random = File(path).openSync(mode: FileMode.append);
    try {
      random.flushSync();
    } finally {
      random.closeSync();
    }
  }

  @override
  Future<RecoverySidecars> inspectSidecars(String databasePath) async {
    final wal = File('$databasePath-wal');
    final shm = File('$databasePath-shm');
    return RecoverySidecars(
      wal: await wal.exists() ? await verifyIdentity(wal.path) : null,
      shm: await shm.exists() ? await verifyIdentity(shm.path) : null,
    );
  }
}

class RecoveryFileOperationException implements Exception {
  const RecoveryFileOperationException(this.message);

  final String message;

  @override
  String toString() => 'RecoveryFileOperationException: $message';
}
