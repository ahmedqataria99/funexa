import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'recovery_file_operations.dart';
import 'recovery_state.dart';

class RecoveryJournal {
  const RecoveryJournal({
    required this.operationId,
    required this.formatVersion,
    required this.journalPath,
    required this.canonicalDatabasePath,
    required this.safetyCopyPath,
    required this.safetyCopySha256,
    required this.candidatePath,
    required this.candidateSha256,
    required this.previousDatabasePath,
    required this.previousDatabaseSha256,
    required this.state,
    required this.databaseVersion,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.lastCompletedTransition,
    required this.validation,
  });

  final String operationId;
  final int formatVersion;
  final String journalPath;
  final String canonicalDatabasePath;
  final String safetyCopyPath;
  final String? safetyCopySha256;
  final String candidatePath;
  final String? candidateSha256;
  final String previousDatabasePath;
  final String? previousDatabaseSha256;
  final RecoveryState state;
  final int databaseVersion;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final String? lastCompletedTransition;
  final Map<String, dynamic> validation;

  Map<String, dynamic> toJson() => {
    'candidatePath': candidatePath,
    'candidateSha256': candidateSha256,
    'canonicalDatabasePath': canonicalDatabasePath,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'databaseVersion': databaseVersion,
    'formatVersion': formatVersion,
    'journalPath': journalPath,
    'lastCompletedTransition': lastCompletedTransition,
    'operationId': operationId,
    'previousDatabasePath': previousDatabasePath,
    'previousDatabaseSha256': previousDatabaseSha256,
    'safetyCopyPath': safetyCopyPath,
    'safetyCopySha256': safetyCopySha256,
    'state': state.wireName,
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
    'validation': validation,
  };

  RecoveryJournal copyWith({
    RecoveryState? state,
    DateTime? updatedAtUtc,
    String? lastCompletedTransition,
    String? safetyCopySha256,
    String? candidateSha256,
    String? previousDatabaseSha256,
    Map<String, dynamic>? validation,
  }) => RecoveryJournal(
    operationId: operationId,
    formatVersion: formatVersion,
    journalPath: journalPath,
    canonicalDatabasePath: canonicalDatabasePath,
    safetyCopyPath: safetyCopyPath,
    safetyCopySha256: safetyCopySha256 ?? this.safetyCopySha256,
    candidatePath: candidatePath,
    candidateSha256: candidateSha256 ?? this.candidateSha256,
    previousDatabasePath: previousDatabasePath,
    previousDatabaseSha256:
        previousDatabaseSha256 ?? this.previousDatabaseSha256,
    state: state ?? this.state,
    databaseVersion: databaseVersion,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    lastCompletedTransition:
        lastCompletedTransition ?? this.lastCompletedTransition,
    validation: validation ?? this.validation,
  );
}

class RecoveryJournalException implements Exception {
  const RecoveryJournalException(this.message);

  final String message;

  @override
  String toString() => 'RecoveryJournalException: $message';
}

class RecoveryJournalStore {
  RecoveryJournalStore({
    required String canonicalDatabasePath,
    RecoveryFileOperations? fileOperations,
  }) : canonicalDatabasePath = RecoveryJournalPaths.canonicalizeDatabasePath(
         canonicalDatabasePath,
       ),
       fileOperations = fileOperations ?? const LocalRecoveryFileOperations();

  static const int supportedFormatVersion = 1;
  final String canonicalDatabasePath;
  final RecoveryFileOperations fileOperations;

  static String createOperationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  RecoveryJournal create({String? operationId, required int databaseVersion}) {
    final id = operationId ?? createOperationId();
    _validateOperationId(id);
    final now = DateTime.now().toUtc();
    final paths = RecoveryJournalPaths.forOperation(canonicalDatabasePath, id);
    return RecoveryJournal(
      operationId: id,
      formatVersion: supportedFormatVersion,
      journalPath: paths.journal,
      canonicalDatabasePath: canonicalDatabasePath,
      safetyCopyPath: paths.safetyCopy,
      safetyCopySha256: null,
      candidatePath: paths.candidate,
      candidateSha256: null,
      previousDatabasePath: paths.previous,
      previousDatabaseSha256: null,
      state: RecoveryState.prepared,
      databaseVersion: databaseVersion,
      createdAtUtc: now,
      updatedAtUtc: now,
      lastCompletedTransition: null,
      validation: const {},
    );
  }

  Future<RecoveryJournal> read({String? operationId}) async {
    final journalPath = operationId == null
        ? _discoverJournalPath()
        : RecoveryJournalPaths.forOperation(
            canonicalDatabasePath,
            operationId,
          ).journal;
    if (!await fileOperations.exists(journalPath)) {
      throw const RecoveryJournalException('Recovery journal does not exist');
    }
    final source = await File(journalPath).readAsString();
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(source) as Map<String, dynamic>;
    } catch (_) {
      throw const RecoveryJournalException('Malformed recovery journal JSON');
    }
    return parse(decoded, journalPath: journalPath, operationId: operationId);
  }

  RecoveryJournal parse(
    Map<String, dynamic> json, {
    required String journalPath,
    String? operationId,
  }) {
    const keys = {
      'candidatePath',
      'candidateSha256',
      'canonicalDatabasePath',
      'createdAtUtc',
      'databaseVersion',
      'formatVersion',
      'journalPath',
      'lastCompletedTransition',
      'operationId',
      'previousDatabasePath',
      'previousDatabaseSha256',
      'safetyCopyPath',
      'safetyCopySha256',
      'state',
      'updatedAtUtc',
      'validation',
    };
    if (json.keys.toSet().length != json.length ||
        json.keys.length != keys.length ||
        !json.keys.every(keys.contains)) {
      throw const RecoveryJournalException(
        'Malformed or unexpected recovery journal fields',
      );
    }

    final formatVersion = json['formatVersion'];
    if (formatVersion is! int || formatVersion != supportedFormatVersion) {
      throw const RecoveryJournalException(
        'Unsupported recovery journal version',
      );
    }
    final id = json['operationId'];
    if (id is! String) {
      throw const RecoveryJournalException('Invalid recovery operation ID');
    }
    _validateOperationId(id);
    if (operationId != null && id != operationId) {
      throw const RecoveryJournalException('Recovery operation ID mismatch');
    }

    final databaseVersion = json['databaseVersion'];
    if (databaseVersion is! int || databaseVersion <= 0) {
      throw const RecoveryJournalException('Invalid database version');
    }
    final stateName = json['state'];
    if (stateName is! String) {
      throw const RecoveryJournalException('Invalid recovery state');
    }
    final state = RecoveryStateName.parse(stateName);
    if (state == null) {
      throw const RecoveryJournalException('Unknown recovery state');
    }

    final createdAt = _parseUtcTimestamp(json['createdAtUtc']);
    final updatedAt = _parseUtcTimestamp(json['updatedAtUtc']);
    if (updatedAt.isBefore(createdAt)) {
      throw const RecoveryJournalException(
        'Journal update timestamp precedes creation timestamp',
      );
    }

    final lastTransition = json['lastCompletedTransition'];
    if (lastTransition != null && lastTransition is! String) {
      throw const RecoveryJournalException('Invalid last completed transition');
    }
    if (lastTransition is String &&
        lastTransition != 'none' &&
        !lastTransition.contains(' -> ')) {
      throw const RecoveryJournalException(
        'Malformed last completed transition',
      );
    }
    if (state != RecoveryState.prepared) {
      if (lastTransition is! String ||
          !lastTransition.endsWith(' -> ${state.wireName}')) {
        throw const RecoveryJournalException(
          'Contradictory recovery state and last transition',
        );
      }
    } else if (lastTransition is String && lastTransition != 'none') {
      throw const RecoveryJournalException(
        'Contradictory prepared state and completed transition',
      );
    }

    final validation = json['validation'];
    if (validation is! Map || validation.length > 32) {
      throw const RecoveryJournalException(
        'Invalid recovery validation metadata',
      );
    }

    final canonical = json['canonicalDatabasePath'];
    final parsedCanonical = canonical is String
        ? RecoveryJournalPaths.canonicalizeDatabasePath(canonical)
        : null;
    if (parsedCanonical != canonicalDatabasePath) {
      throw const RecoveryJournalException('Canonical database path mismatch');
    }

    final parsedJournalPath = RecoveryJournalPaths.canonicalizeFilePath(
      journalPath,
    );
    if (json['journalPath'] is! String ||
        RecoveryJournalPaths.canonicalizeFilePath(
              json['journalPath'] as String,
            ) !=
            parsedJournalPath) {
      throw const RecoveryJournalException('Journal path mismatch');
    }
    final expected = RecoveryJournalPaths.forOperation(
      canonicalDatabasePath,
      id,
    );
    if (parsedJournalPath != expected.journal) {
      throw const RecoveryJournalException('Unexpected recovery journal path');
    }

    _validateOptionalDigest(json['safetyCopySha256']);
    _validateOptionalDigest(json['candidateSha256']);
    _validateOptionalDigest(json['previousDatabaseSha256']);

    final safety = json['safetyCopyPath'];
    final candidate = json['candidatePath'];
    final previous = json['previousDatabasePath'];
    if (safety is! String || candidate is! String || previous is! String) {
      throw const RecoveryJournalException('Invalid recovery artifact paths');
    }
    if (RecoveryJournalPaths.canonicalizeFilePath(safety) !=
            expected.safetyCopy ||
        RecoveryJournalPaths.canonicalizeFilePath(candidate) !=
            expected.candidate ||
        RecoveryJournalPaths.canonicalizeFilePath(previous) !=
            expected.previous) {
      throw const RecoveryJournalException('Unexpected recovery artifact path');
    }

    return RecoveryJournal(
      operationId: id,
      formatVersion: formatVersion,
      journalPath: parsedJournalPath,
      canonicalDatabasePath: parsedCanonical!,
      safetyCopyPath: expected.safetyCopy,
      safetyCopySha256: json['safetyCopySha256'] as String?,
      candidatePath: expected.candidate,
      candidateSha256: json['candidateSha256'] as String?,
      previousDatabasePath: expected.previous,
      previousDatabaseSha256: json['previousDatabaseSha256'] as String?,
      state: state,
      databaseVersion: databaseVersion,
      createdAtUtc: createdAt,
      updatedAtUtc: updatedAt,
      lastCompletedTransition: lastTransition is String ? lastTransition : null,
      validation: Map<String, dynamic>.from(validation),
    );
  }

  Future<RecoveryJournal> save(RecoveryJournal journal) async {
    final parsed = parse(
      journal.toJson(),
      journalPath: journal.journalPath,
      operationId: journal.operationId,
    );
    final bytes = utf8.encode(_deterministicJson(parsed.toJson()));
    final tempPath = '${parsed.journalPath}.tmp-${createOperationId()}';

    await fileOperations.createNewFile(tempPath, bytes);
    await fileOperations.flushFile(tempPath);

    if (await fileOperations.exists(parsed.journalPath)) {
      final existing = await read(operationId: parsed.operationId);
      if (existing.operationId != parsed.operationId ||
          existing.canonicalDatabasePath != parsed.canonicalDatabasePath) {
        throw const RecoveryJournalException(
          'Refusing to overwrite a journal belonging to another operation',
        );
      }
      final backupPath = '${parsed.journalPath}.replace-${createOperationId()}';
      await fileOperations.renameWithoutOverwrite(
        parsed.journalPath,
        backupPath,
      );
      try {
        await fileOperations.renameWithoutOverwrite(
          tempPath,
          parsed.journalPath,
        );
      } catch (_) {
        await fileOperations.renameWithoutOverwrite(
          backupPath,
          parsed.journalPath,
        );
        rethrow;
      }
      await File(backupPath).delete();
    } else {
      await fileOperations.renameWithoutOverwrite(tempPath, parsed.journalPath);
    }

    await read(operationId: parsed.operationId);
    return parsed;
  }

  Future<void> transition(RecoveryJournal journal, RecoveryState next) async {
    RecoveryStateMachine.validateTransition(journal.state, next);
    if (journal.state == next) {
      await save(journal);
      return;
    }
    final now = DateTime.now().toUtc();
    final transition = '${journal.state.wireName} -> ${next.wireName}';
    await save(
      journal.copyWith(
        state: next,
        updatedAtUtc: now,
        lastCompletedTransition: transition,
      ),
    );
  }

  Future<void> verifyArtifactDigests(RecoveryJournal journal) async {
    final artifacts = <String, String?>{
      journal.safetyCopyPath: journal.safetyCopySha256,
      journal.candidatePath: journal.candidateSha256,
      journal.previousDatabasePath: journal.previousDatabaseSha256,
    };
    for (final entry in artifacts.entries) {
      if (entry.value == null) continue;
      if (!await fileOperations.exists(entry.key)) {
        throw RecoveryJournalException(
          'Missing journal artifact: ${entry.key}',
        );
      }
      final actual = await fileOperations.sha256(entry.key);
      if (actual != entry.value) {
        throw RecoveryJournalException(
          'Digest mismatch for journal artifact: ${entry.key}',
        );
      }
    }
  }

  String _discoverJournalPath() {
    final directory = p.dirname(canonicalDatabasePath);
    final base = p.basename(canonicalDatabasePath);
    throw RecoveryJournalException(
      'Recovery journal discovery requires operationId: $directory/$base',
    );
  }

  static DateTime _parseUtcTimestamp(dynamic value) {
    if (value is! String || !value.endsWith('Z')) {
      throw const RecoveryJournalException('Timestamp must be UTC RFC 3339');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      throw const RecoveryJournalException('Malformed UTC timestamp');
    }
    return parsed.toUtc();
  }

  static void _validateOptionalDigest(dynamic value) {
    if (value == null) return;
    if (value is! String || !RegExp(r'^([0-9a-f]{64})$').hasMatch(value)) {
      throw const RecoveryJournalException('Invalid SHA-256 digest');
    }
  }

  static void _validateOperationId(String value) {
    if (!RegExp(r'^([0-9a-f]{32})$').hasMatch(value)) {
      throw const RecoveryJournalException('Invalid recovery operation ID');
    }
  }

  static String _deterministicJson(Map<String, dynamic> value) {
    dynamic sorted(dynamic item) {
      if (item is Map) {
        final keys = item.keys.map((key) => key.toString()).toList()..sort();
        final result = SplayTreeMap<String, dynamic>();
        for (final key in keys) {
          result[key] = sorted(item[key]);
        }
        return result;
      }
      if (item is List) return item.map(sorted).toList();
      return item;
    }

    return jsonEncode(sorted(value));
  }
}

class RecoveryJournalPaths {
  const RecoveryJournalPaths({
    required this.journal,
    required this.safetyCopy,
    required this.candidate,
    required this.previous,
  });

  final String journal;
  final String safetyCopy;
  final String candidate;
  final String previous;

  static String canonicalizeDatabasePath(String path) {
    if (path.isEmpty || path.contains('..')) {
      throw const RecoveryJournalException('Invalid canonical database path');
    }
    if (!p.isAbsolute(path)) {
      throw const RecoveryJournalException(
        'Canonical database path must be absolute',
      );
    }
    if (Platform.isWindows && path.contains(':')) {
      if (!RegExp(r'^[^:]+:[/\\]').hasMatch(path)) {
        throw const RecoveryJournalException('Invalid Windows file path');
      }
      if (path.substring(3).contains(':')) {
        throw const RecoveryJournalException(
          'Invalid Windows alternate stream',
        );
      }
      final normalized = p.normalize(path).replaceAll(r'\', '/');
      return normalized.toLowerCase();
    }
    return p.normalize(path);
  }

  static String canonicalizeFilePath(String path) {
    if (path.isEmpty || path.contains('..')) {
      throw const RecoveryJournalException('Invalid recovery file path');
    }
    if (!p.isAbsolute(path)) {
      throw const RecoveryJournalException(
        'Recovery file path must be absolute',
      );
    }
    if (Platform.isWindows && path.contains(':')) {
      final drivePattern = RegExp(r'^[^:]+:[/\\]');
      if (!drivePattern.hasMatch(path)) {
        throw const RecoveryJournalException('Invalid Windows file path');
      }
      if (path.substring(3).contains(':')) {
        throw const RecoveryJournalException(
          'Windows alternate-stream syntax is not allowed',
        );
      }
      return p.normalize(path).replaceAll(r'\', '/').toLowerCase();
    }
    return p.normalize(path);
  }

  static RecoveryJournalPaths forOperation(
    String canonicalDatabasePath,
    String operationId,
  ) {
    RecoveryJournalStore._validateOperationId(operationId);
    final canonical = canonicalizeDatabasePath(canonicalDatabasePath);
    final parent = p.dirname(canonical);
    final basename = p.basename(canonical);
    final base = basename.toLowerCase().endsWith('.db')
        ? basename.substring(0, basename.length - 3)
        : basename;
    if (parent.isEmpty || base.isEmpty) {
      throw const RecoveryJournalException('Invalid database identity');
    }
    return RecoveryJournalPaths(
      journal: canonicalizeFilePath(
        p.join(parent, '.furnexa-$base-$operationId.journal'),
      ),
      safetyCopy: canonicalizeFilePath(
        p.join(parent, '.furnexa-$base-$operationId.safety.db'),
      ),
      candidate: canonicalizeFilePath(
        p.join(parent, '.furnexa-$base-$operationId.candidate.db'),
      ),
      previous: canonicalizeFilePath(
        p.join(parent, '.furnexa-$base-$operationId.previous.db'),
      ),
    );
  }
}
