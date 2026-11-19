import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'recovery_journal.dart';

class RecoveryProcessLeaseMetadata {
  const RecoveryProcessLeaseMetadata({
    required this.canonicalDatabaseIdentity,
    required this.operationId,
    required this.processId,
    required this.processNonce,
    required this.executable,
  });

  final String canonicalDatabaseIdentity;
  final String operationId;
  final int processId;
  final String processNonce;
  final String executable;

  Map<String, dynamic> toJson() => {
    'canonicalDatabaseIdentity': canonicalDatabaseIdentity,
    'executable': executable,
    'operationId': operationId,
    'processId': processId,
    'processNonce': processNonce,
  };
}

class RecoveryProcessLeaseException implements Exception {
  const RecoveryProcessLeaseException(this.message);

  final String message;

  @override
  String toString() => 'RecoveryProcessLeaseException: $message';
}

class RecoveryProcessLease {
  RecoveryProcessLease({required String canonicalDatabasePath})
    : canonicalDatabasePath = RecoveryJournalPaths.canonicalizeDatabasePath(
        canonicalDatabasePath,
      );

  final String canonicalDatabasePath;
  RandomAccessFile? _handle;
  String? _leasePath;
  bool _released = false;

  String get databaseIdentity {
    final bytes = utf8.encode(canonicalDatabasePath);
    return sha256.convert(bytes).toString();
  }

  String get leasePath {
    final directory = p.dirname(canonicalDatabasePath);
    return p.join(directory, '.furnexa-recovery-$databaseIdentity.lock');
  }

  bool get isAcquired => _handle != null && !_released;

  Future<RecoveryProcessLeaseMetadata> acquire({
    required String operationId,
  }) async {
    if (isAcquired) {
      throw const RecoveryProcessLeaseException(
        'This process already owns the recovery lease',
      );
    }

    final file = File(leasePath);
    await file.parent.create(recursive: true);
    late RandomAccessFile handle;
    try {
      handle = await file.open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive, 0, 1);
    } catch (error) {
      try {
        await handle.close();
      } catch (_) {}
      throw RecoveryProcessLeaseException(
        'Exclusive recovery lease unavailable: $error',
      );
    }

    final nonceBytes = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    );
    final nonce = nonceBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final metadata = RecoveryProcessLeaseMetadata(
      canonicalDatabaseIdentity: databaseIdentity,
      operationId: operationId,
      processId: pid,
      processNonce: nonce,
      executable: Platform.resolvedExecutable,
    );

    try {
      await handle.truncate(0);
      await handle.setPosition(0);
      await handle.writeString(jsonEncode(metadata.toJson()));
      await handle.flush();
    } catch (error) {
      await handle.unlock(0, 1);
      await handle.close();
      throw RecoveryProcessLeaseException(
        'Could not persist recovery lease metadata: $error',
      );
    }

    _handle = handle;
    _leasePath = leasePath;
    _released = false;
    return metadata;
  }

  Future<void> release() async {
    final handle = _handle;
    if (handle == null || _released) return;
    await handle.unlock(0, 1);
    await handle.close();
    _handle = null;
    _released = true;

    final leaseFile = File(_leasePath!);
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (await leaseFile.exists()) await leaseFile.delete();
        break;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
  }

  Future<RecoveryProcessLeaseMetadata?> readOwnerMetadata() async {
    final file = File(_leasePath ?? leasePath);
    if (!await file.exists()) return null;
    try {
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return RecoveryProcessLeaseMetadata(
        canonicalDatabaseIdentity:
            decoded['canonicalDatabaseIdentity'] as String,
        operationId: decoded['operationId'] as String,
        processId: decoded['processId'] as int,
        processNonce: decoded['processNonce'] as String,
        executable: decoded['executable'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}
