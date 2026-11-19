import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/recovery/process_lease.dart';
import 'package:furnexa/core/recovery/recovery_file_operations.dart';
import 'package:furnexa/core/recovery/recovery_journal.dart';
import 'package:furnexa/core/recovery/recovery_state.dart';
import 'package:furnexa/core/recovery/startup_recovery_decision.dart';

Future<void> deleteTemporaryDirectoryWithRetry(Directory directory) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
      return;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

class FailingRecoveryFileOperations extends LocalRecoveryFileOperations {
  FailingRecoveryFileOperations({
    this.failCreate = false,
    this.failCopy = false,
  });

  final bool failCreate;
  final bool failCopy;

  @override
  Future<void> createNewFile(String path, List<int> bytes) async {
    if (failCreate)
      throw const RecoveryFileOperationException('injected create failure');
    await super.createNewFile(path, bytes);
  }

  @override
  Future<void> copyFile(String source, String destination) async {
    if (failCopy)
      throw const RecoveryFileOperationException('injected copy failure');
    await super.copyFile(source, destination);
  }
}

void main() {
  group('recovery journal', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('furnexa-recovery-journal-');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test(
      'serialization and deserialization are deterministic and strict',
      () async {
        final db = '${temp.path}/canonical.db';
        final store = RecoveryJournalStore(canonicalDatabasePath: db);
        final journal = store.create(databaseVersion: 41);

        await store.save(journal);
        final loaded = await store.read(operationId: journal.operationId);

        expect(loaded.toJson(), journal.toJson());
        expect(await File(journal.journalPath).exists(), isTrue);
        expect(journal.formatVersion, 1);
      },
    );

    test('rejects unsupported versions and malformed data', () async {
      final db = '${temp.path}/canonical.db';
      final store = RecoveryJournalStore(canonicalDatabasePath: db);
      final journal = store.create(databaseVersion: 41);
      final unsupported = journal.toJson()..['formatVersion'] = 999;

      expect(
        () => store.parse(unsupported, journalPath: journal.journalPath),
        throwsA(isA<RecoveryJournalException>()),
      );

      final malformed = journal.toJson()..remove('operationId');
      expect(
        () => store.parse(malformed, journalPath: journal.journalPath),
        throwsA(isA<RecoveryJournalException>()),
      );
    });

    test('rejects traversal, alternate-stream, and unexpected paths', () async {
      final db = '${temp.path}/canonical.db';
      final store = RecoveryJournalStore(canonicalDatabasePath: db);
      final journal = store.create(databaseVersion: 41);

      expect(
        () => store.parse(
          journal.toJson()..['safetyCopyPath'] = '${temp.path}/../outside.db',
          journalPath: journal.journalPath,
        ),
        throwsA(isA<RecoveryJournalException>()),
      );

      expect(
        () => store.parse(
          journal.toJson()
            ..['candidatePath'] = '${temp.path}/other-candidate.db',
          journalPath: journal.journalPath,
        ),
        throwsA(isA<RecoveryJournalException>()),
      );

      expect(
        () => RecoveryJournalPaths.canonicalizeDatabasePath('../canonical.db'),
        throwsA(isA<RecoveryJournalException>()),
      );
    });

    test('rejects operation ID mismatch and digest mismatch', () async {
      final db = '${temp.path}/canonical.db';
      final store = RecoveryJournalStore(canonicalDatabasePath: db);
      final journal = store.create(databaseVersion: 41);

      expect(
        () => store.parse(
          journal.toJson(),
          journalPath: journal.journalPath,
          operationId: '00000000000000000000000000000002',
        ),
        throwsA(isA<RecoveryJournalException>()),
      );

      final safety = File(journal.safetyCopyPath);
      await safety.writeAsBytes([1, 2, 3]);
      final digest = await const LocalRecoveryFileOperations().sha256(
        safety.path,
      );
      final withMismatch = journal.copyWith(
        safetyCopySha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
      );
      await safety.writeAsBytes([4, 5, 6]);

      expect(digest, isNot(withMismatch.safetyCopySha256));
      expect(
        () => store.verifyArtifactDigests(withMismatch),
        throwsA(isA<RecoveryJournalException>()),
      );
    });

    test('never overwrites another operation journal', () async {
      final db = '${temp.path}/canonical.db';
      final store = RecoveryJournalStore(canonicalDatabasePath: db);
      final first = store.create(databaseVersion: 41);
      await store.save(first);

      final second = store.create(
        operationId: '00000000000000000000000000000002',
        databaseVersion: 41,
      );
      expect(second.journalPath, isNot(first.journalPath));
      await store.save(second);
      expect(
        await store
            .read(operationId: first.operationId)
            .then((j) => j.operationId),
        first.operationId,
      );
    });

    test('journal persistence failure is surfaced', () async {
      final db = '${temp.path}/canonical.db';
      final failing = FailingRecoveryFileOperations(failCreate: true);
      final store = RecoveryJournalStore(
        canonicalDatabasePath: db,
        fileOperations: failing,
      );

      expect(
        () => store.save(store.create(databaseVersion: 41)),
        throwsA(isA<RecoveryFileOperationException>()),
      );
    });
  });

  group('recovery state machine', () {
    test('accepts valid transitions and rejects invalid transitions', () async {
      final temp = await Directory.systemTemp.createTemp(
        'furnexa-recovery-state-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final db = '${temp.path}/canonical.db';
      final store = RecoveryJournalStore(canonicalDatabasePath: db);
      var journal = store.create(databaseVersion: 41);

      await store.transition(journal, RecoveryState.safetyCopyCreated);
      journal = await store.read(operationId: journal.operationId);
      expect(journal.state, RecoveryState.safetyCopyCreated);

      expect(
        () => store.transition(journal, RecoveryState.candidateVerified),
        throwsA(isA<RecoveryStateTransitionException>()),
      );
    });

    test('repeated transition is idempotent', () async {
      final temp = await Directory.systemTemp.createTemp(
        'furnexa-recovery-repeat-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final store = RecoveryJournalStore(
        canonicalDatabasePath: '${temp.path}/db.db',
      );
      final initial = store.create(databaseVersion: 41);

      await store.transition(initial, RecoveryState.safetyCopyCreated);
      var journal = await store.read(operationId: initial.operationId);
      await store.transition(journal, RecoveryState.safetyCopyCreated);
      journal = await store.read(operationId: initial.operationId);

      expect(journal.state, RecoveryState.safetyCopyCreated);
      expect(
        journal.lastCompletedTransition,
        'prepared -> safety_copy_created',
      );
    });

    test('terminal states reject further transitions', () async {
      final journal = RecoveryJournal(
        operationId: '00000000000000000000000000000001',
        formatVersion: 1,
        journalPath: '/tmp/journal',
        canonicalDatabasePath: '/tmp/db.db',
        safetyCopyPath: '/tmp/safety.db',
        safetyCopySha256: null,
        candidatePath: '/tmp/candidate.db',
        candidateSha256: null,
        previousDatabasePath: '/tmp/previous.db',
        previousDatabaseSha256: null,
        state: RecoveryState.completed,
        databaseVersion: 41,
        createdAtUtc: DateTime.utc(2026),
        updatedAtUtc: DateTime.utc(2026),
        lastCompletedTransition: 'candidate_reopened -> completed',
        validation: const {},
      );

      expect(
        () => RecoveryStateMachine.validateTransition(
          journal.state,
          RecoveryState.rollbackStarted,
        ),
        throwsA(isA<RecoveryStateTransitionException>()),
      );
    });
  });

  group('file operation seam', () {
    test('create, copy, sha, identity, move, and sidecar inspection', () async {
      final temp = await Directory.systemTemp.createTemp(
        'furnexa-recovery-files-',
      );
      addTearDown(() => temp.delete(recursive: true));
      const ops = LocalRecoveryFileOperations();

      final source = '${temp.path}/source.db';
      await ops.createNewFile(source, [1, 2, 3]);
      expect(await ops.exists(source), isTrue);
      expect((await ops.verifyIdentity(source)).size, 3);
      expect((await ops.sha256(source)).length, 64);

      final copy = '${temp.path}/copy.db';
      await ops.copyFile(source, copy);
      expect(await ops.sha256(copy), await ops.sha256(source));

      final sidecars = await ops.inspectSidecars(source);
      expect(sidecars.wal, isNull);
      expect(sidecars.shm, isNull);

      final moved = '${temp.path}/moved.db';
      await ops.renameWithoutOverwrite(copy, moved);
      expect(await ops.exists(copy), isFalse);
      expect(await ops.exists(moved), isTrue);

      await expectLater(
        ops.renameWithoutOverwrite(source, moved),
        throwsA(isA<RecoveryFileOperationException>()),
      );
    });

    test('deterministic copy failure injection', () async {
      final temp = await Directory.systemTemp.createTemp(
        'furnexa-recovery-failure-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final ops = FailingRecoveryFileOperations(failCopy: true);

      await expectLater(
        ops.copyFile('${temp.path}/missing.db', '${temp.path}/copy.db'),
        throwsA(isA<RecoveryFileOperationException>()),
      );
    });
  });

  group('process lease', () {
    test(
      'acquires, exposes diagnostics, rejects second, and releases',
      () async {
        final temp = await Directory.systemTemp.createTemp(
          'furnexa-recovery-lease-',
        );
        addTearDown(() => deleteTemporaryDirectoryWithRetry(temp));
        final db = '${temp.path}/canonical.db';
        final first = RecoveryProcessLease(canonicalDatabasePath: db);
        final metadata = await first.acquire(
          operationId: '00000000000000000000000000000001',
        );

        expect(metadata.processId, pid);
        expect(metadata.canonicalDatabaseIdentity, first.databaseIdentity);

        final second = RecoveryProcessLease(canonicalDatabasePath: db);
        await expectLater(
          second.acquire(operationId: '00000000000000000000000000000002'),
          throwsA(isA<RecoveryProcessLeaseException>()),
        );

        await first.release();
        final third = RecoveryProcessLease(canonicalDatabasePath: db);
        await third.acquire(operationId: '00000000000000000000000000000003');
        await third.release();
      },
    );

    test('independent process cannot acquire an active lease', () async {
      if (!Platform.isWindows) return;
      final temp = await Directory.systemTemp.createTemp(
        'furnexa-recovery-proc-',
      );
      addTearDown(() => deleteTemporaryDirectoryWithRetry(temp));
      final dart = r'C:\flutter\bin\cache\dart-sdk\bin\dart.exe';

      final first = await Process.start(dart, [
        'run',
        'test/fixtures/recovery_lease_probe.dart',
        '${temp.path}/db.db',
      ], workingDirectory: Directory.current.path);
      late String line;
      await for (final outputLine
          in first.stdout
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (outputLine == 'LEASE_ACQUIRED') {
          line = outputLine;
          break;
        }
      }
      expect(line, 'LEASE_ACQUIRED');

      final second = await Process.run(dart, [
        'run',
        'test/fixtures/recovery_lease_probe.dart',
        '${temp.path}/db.db',
      ]);
      expect(second.exitCode, 2);

      await first.stdin.close();
      await first.exitCode;
    });

    test('process termination releases abandoned ownership', () async {
      if (!Platform.isWindows) return;
      final temp = await Directory.systemTemp.createTemp(
        'furnexa-recovery-crash-',
      );
      addTearDown(() => deleteTemporaryDirectoryWithRetry(temp));
      final db = '${temp.path}/crash.db';
      final dart = r'C:\flutter\bin\cache\dart-sdk\bin\dart.exe';

      final process = await Process.start(dart, [
        'run',
        'test/fixtures/recovery_lease_probe.dart',
        db,
      ], workingDirectory: Directory.current.path);
      await Future<void>.delayed(const Duration(seconds: 2));

      Process.killPid(process.pid, ProcessSignal.sigkill);
      await Future<void>.delayed(const Duration(seconds: 1));

      final lease = RecoveryProcessLease(canonicalDatabasePath: db);
      await lease.acquire(operationId: '00000000000000000000000000000004');
      await lease.release();
    });
  });

  group('startup recovery decision', () {
    test('returns decisions for every journal state', () async {
      const component = StartupRecoveryDecisionComponent();
      final temp = await Directory.systemTemp.createTemp(
        'furnexa-recovery-decision-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final base = RecoveryJournal(
        operationId: '00000000000000000000000000000001',
        formatVersion: 1,
        journalPath: '${temp.path}/journal',
        canonicalDatabasePath: '${temp.path}/db.db',
        safetyCopyPath: '${temp.path}/safety.db',
        safetyCopySha256: null,
        candidatePath: '${temp.path}/candidate.db',
        candidateSha256: 'a' * 64,
        previousDatabasePath: '${temp.path}/previous.db',
        previousDatabaseSha256: 'b' * 64,
        state: RecoveryState.prepared,
        databaseVersion: 41,
        createdAtUtc: DateTime.utc(2026),
        updatedAtUtc: DateTime.utc(2026),
        lastCompletedTransition: null,
        validation: const {},
      );

      expect(
        component.inspect(null).type,
        StartupRecoveryDecisionType.noRecoveryRequired,
      );
      expect(
        component.inspect(base).type,
        StartupRecoveryDecisionType.recoveryPending,
      );

      final safety = base.copyWith(
        state: RecoveryState.safetyCopyVerified,
        lastCompletedTransition: 'safety_copy_created -> safety_copy_verified',
        safetyCopySha256: 'c' * 64,
      );
      expect(
        component.inspect(safety).type,
        StartupRecoveryDecisionType.recoveryPending,
      );

      final switchState = base.copyWith(
        state: RecoveryState.switchStarted,
        lastCompletedTransition: 'candidate_verified -> switch_started',
      );
      expect(
        component.inspect(switchState).type,
        StartupRecoveryDecisionType.rollbackRequired,
      );

      final completed = base.copyWith(
        state: RecoveryState.completed,
        lastCompletedTransition: 'candidate_reopened -> completed',
      );
      expect(
        component.inspect(completed).type,
        StartupRecoveryDecisionType.completedRequiresVerification,
      );

      final failed = base.copyWith(
        state: RecoveryState.recoveryFailed,
        lastCompletedTransition: 'candidate_placed -> recovery_failed',
      );
      expect(
        component.inspect(failed).type,
        StartupRecoveryDecisionType.failClosed,
      );
    });

    test('ambiguous state fails closed', () async {
      const component = StartupRecoveryDecisionComponent();
      final ambiguous = RecoveryJournal(
        operationId: '00000000000000000000000000000001',
        formatVersion: 1,
        journalPath: '/tmp/journal',
        canonicalDatabasePath: '/tmp/db.db',
        safetyCopyPath: '/tmp/safety.db',
        safetyCopySha256: null,
        candidatePath: '/tmp/candidate.db',
        candidateSha256: null,
        previousDatabasePath: '/tmp/previous.db',
        previousDatabaseSha256: null,
        state: RecoveryState.candidateVerified,
        databaseVersion: 41,
        createdAtUtc: DateTime.utc(2026),
        updatedAtUtc: DateTime.utc(2026),
        lastCompletedTransition: 'candidate_created -> candidate_verified',
        validation: const {},
      );

      expect(
        component.inspect(ambiguous).type,
        StartupRecoveryDecisionType.failClosed,
      );
    });
  });
}
