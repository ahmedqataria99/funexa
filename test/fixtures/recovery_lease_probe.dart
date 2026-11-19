import 'dart:io';

import 'package:furnexa/core/recovery/process_lease.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: recovery_lease_probe <databasePath>');
    exitCode = 64;
    return;
  }

  final lease = RecoveryProcessLease(canonicalDatabasePath: args.first);
  try {
    await lease.acquire(operationId: '00000000000000000000000000000001');
  } catch (_) {
    stdout.writeln('LEASE_BUSY');
    exitCode = 2;
    return;
  }

  stdout.writeln('LEASE_ACQUIRED');
  await stdin.first;
  await lease.release();
}
