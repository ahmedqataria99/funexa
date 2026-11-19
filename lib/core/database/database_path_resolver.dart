import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum DatabasePathSource {
  test,
  localDevelopment,
  environment,
  windowsProduction,
  platformDefault,
}

class DatabasePathResolution {
  const DatabasePathResolution({
    required this.path,
    required this.source,
    this.legacySource,
  });

  final String path;
  final DatabasePathSource source;
  final String? legacySource;
}

class DatabasePathConfigurationException implements Exception {
  const DatabasePathConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'DatabasePathConfigurationException: $message';
}

class DatabasePathResolver {
  DatabasePathResolver({
    Map<String, String>? environment,
    bool? isWindows,
    String? resolvedExecutable,
    Future<String> Function()? defaultDatabaseDirectory,
    Future<void> Function(File source, File destination)? copyFile,
  }) : environment = environment ?? Platform.environment,
       isWindows = isWindows ?? Platform.isWindows,
       resolvedExecutable = resolvedExecutable ?? Platform.resolvedExecutable,
       defaultDatabaseDirectory = defaultDatabaseDirectory ?? getDatabasesPath,
       copyFile =
           copyFile ??
           ((source, destination) =>
               source.copy(destination.path).then((_) {}));

  static const environmentPathVariable = 'FURNEXA_DATABASE_PATH';

  final Map<String, String> environment;
  final bool isWindows;
  final String resolvedExecutable;
  final Future<String> Function() defaultDatabaseDirectory;
  final Future<void> Function(File source, File destination) copyFile;

  static String windowsDatabasePath({
    required String localAppData,
    required String fileName,
  }) => p.join(localAppData, 'Furnexa', fileName);

  Future<DatabasePathResolution> resolve({
    required String fileName,
    String? testDirectory,
    String? localDevelopmentPath,
  }) async {
    if (testDirectory != null) {
      final directory = _validateConfiguredDirectory(
        testDirectory,
        label: 'Test database directory',
      );
      return DatabasePathResolution(
        path: p.join(directory, fileName),
        source: DatabasePathSource.test,
      );
    }

    if (localDevelopmentPath != null) {
      final configuredPath = _validateConfiguredFilePath(
        localDevelopmentPath,
        label: 'Local development database path',
      );
      return DatabasePathResolution(
        path: configuredPath,
        source: DatabasePathSource.localDevelopment,
      );
    }

    if (environment.containsKey(environmentPathVariable)) {
      final configured = environment[environmentPathVariable]?.trim() ?? '';
      if (configured.isEmpty) {
        throw const DatabasePathConfigurationException(
          'FURNEXA_DATABASE_PATH is configured but empty.',
        );
      }
      final configuredPath = _validateConfiguredFilePath(
        configured,
        label: 'FURNEXA_DATABASE_PATH',
      );
      return DatabasePathResolution(
        path: configuredPath,
        source: DatabasePathSource.environment,
      );
    }

    if (isWindows) {
      final localAppData = environment['LOCALAPPDATA']?.trim();
      if (localAppData != null && localAppData.isNotEmpty) {
        final stablePath = windowsDatabasePath(
          localAppData: _validateConfiguredDirectory(
            localAppData,
            label: 'LOCALAPPDATA',
          ),
          fileName: fileName,
        );
        await Directory(p.dirname(stablePath)).create(recursive: true);

        final stableFile = File(stablePath);
        String? legacySource;
        if (!await stableFile.exists()) {
          final executableDirectory = p.dirname(resolvedExecutable);
          final legacyPaths = <String>[
            p.join(
              executableDirectory,
              '.dart_tool',
              'sqflite_common_ffi',
              'databases',
              fileName,
            ),
            p.join(await defaultDatabaseDirectory(), fileName),
          ];
          legacySource = await _copyLegacyDatabaseIfNeeded(
            stablePath: stablePath,
            legacyPaths: legacyPaths,
          );
        }

        return DatabasePathResolution(
          path: stablePath,
          source: DatabasePathSource.windowsProduction,
          legacySource: legacySource,
        );
      }
    }

    final directory = _validateConfiguredDirectory(
      await defaultDatabaseDirectory(),
      label: 'Platform database directory',
    );
    return DatabasePathResolution(
      path: p.join(directory, fileName),
      source: DatabasePathSource.platformDefault,
    );
  }

  String _validateConfiguredDirectory(String value, {required String label}) {
    if (value.trim().isEmpty) {
      throw DatabasePathConfigurationException('$label cannot be empty.');
    }
    return p.normalize(p.absolute(value));
  }

  String _validateConfiguredFilePath(String value, {required String label}) {
    if (value.trim().isEmpty) {
      throw DatabasePathConfigurationException('$label cannot be empty.');
    }
    return p.normalize(p.absolute(value));
  }

  Future<String?> _copyLegacyDatabaseIfNeeded({
    required String stablePath,
    required List<String> legacyPaths,
  }) async {
    for (final legacyPath in legacyPaths) {
      final normalizedLegacy = p.normalize(p.absolute(legacyPath));
      final normalizedStable = p.normalize(p.absolute(stablePath));
      if (normalizedLegacy.toLowerCase() == normalizedStable.toLowerCase()) {
        continue;
      }

      final source = File(normalizedLegacy);
      if (!await source.exists()) {
        continue;
      }
      try {
        if (await source.length() == 0) {
          continue;
        }
      } on FileSystemException {
        continue;
      }

      final stable = File(normalizedStable);
      if (await stable.exists()) {
        return null;
      }

      final suffix = DateTime.now().toUtc().microsecondsSinceEpoch;
      final temporaryDatabase = File('$normalizedStable.furnexa-copy-$suffix');
      final temporaryWal = File('${temporaryDatabase.path}-wal');
      final sourceWal = File('$normalizedLegacy-wal');

      try {
        await copyFile(source, temporaryDatabase);
        if (await source.length() != await temporaryDatabase.length()) {
          throw const DatabasePathConfigurationException(
            'Legacy database copy verification failed.',
          );
        }

        if (await sourceWal.exists()) {
          await copyFile(sourceWal, temporaryWal);
        }

        if (await stable.exists()) {
          await _deleteTemporaryFile(temporaryDatabase);
          await _deleteTemporaryFile(temporaryWal);
          return null;
        }

        await temporaryDatabase.rename(normalizedStable);

        if (await temporaryWal.exists() &&
            !await File('$normalizedStable-wal').exists()) {
          await temporaryWal.rename('$normalizedStable-wal');
        } else {
          await _deleteTemporaryFile(temporaryWal);
        }
        return normalizedLegacy;
      } on DatabasePathConfigurationException {
        await _deleteTemporaryFile(temporaryDatabase);
        await _deleteTemporaryFile(temporaryWal);
        rethrow;
      } catch (error) {
        await _deleteTemporaryFile(temporaryDatabase);
        await _deleteTemporaryFile(temporaryWal);
        throw DatabasePathConfigurationException(
          'Failed to copy legacy database from "$normalizedLegacy" to "$normalizedStable": $error',
        );
      }
    }
    return null;
  }

  Future<void> _deleteTemporaryFile(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
