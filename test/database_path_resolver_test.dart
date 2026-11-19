import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/database_path_resolver.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('furnexa-path-resolver-');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test('default platform path is selected without an override', () async {
    final resolver = DatabasePathResolver(
      environment: const {},
      isWindows: false,
      defaultDatabaseDirectory: () async => temp.path,
    );

    final resolution = await resolver.resolve(fileName: 'furnexa.db');

    expect(resolution.path, '${temp.path}${Platform.pathSeparator}furnexa.db');
    expect(resolution.source, DatabasePathSource.platformDefault);
  });

  test(
    'environment override has lower precedence than test and local paths',
    () async {
      final testDirectory = Directory(
        '${temp.path}${Platform.pathSeparator}test',
      );
      await testDirectory.create();
      final localPath = '${temp.path}${Platform.pathSeparator}local.db';
      final environmentPath = '${temp.path}${Platform.pathSeparator}demo.db';

      final resolver = DatabasePathResolver(
        environment: {'FURNEXA_DATABASE_PATH': environmentPath},
        isWindows: false,
        defaultDatabaseDirectory: () async => temp.path,
      );

      final testResolution = await resolver.resolve(
        fileName: 'furnexa.db',
        testDirectory: testDirectory.path,
        localDevelopmentPath: localPath,
      );
      expect(testResolution.source, DatabasePathSource.test);
      expect(testResolution.path, isNot(environmentPath));

      final localResolver = DatabasePathResolver(
        environment: {'FURNEXA_DATABASE_PATH': environmentPath},
        isWindows: false,
        defaultDatabaseDirectory: () async => temp.path,
      );
      final localResolution = await localResolver.resolve(
        fileName: 'furnexa.db',
        localDevelopmentPath: localPath,
      );
      expect(localResolution.source, DatabasePathSource.localDevelopment);
      expect(localResolution.path, localPath);
    },
  );

  test('environment override selects an isolated demo database path', () async {
    final demoPath =
        '${temp.path}${Platform.pathSeparator}demo${Platform.pathSeparator}furnexa-demo.db';
    final resolver = DatabasePathResolver(
      environment: {'FURNEXA_DATABASE_PATH': demoPath},
      isWindows: true,
      defaultDatabaseDirectory: () async => temp.path,
    );

    final resolution = await resolver.resolve(fileName: 'furnexa.db');

    expect(resolution.path, demoPath);
    expect(resolution.source, DatabasePathSource.environment);
  });

  test('empty environment override is rejected without fallback', () async {
    final resolver = DatabasePathResolver(
      environment: {'FURNEXA_DATABASE_PATH': '   '},
      isWindows: false,
      defaultDatabaseDirectory: () async => temp.path,
    );

    await expectLater(
      resolver.resolve(fileName: 'furnexa.db'),
      throwsA(isA<DatabasePathConfigurationException>()),
    );
  });

  test(
    'test database path is isolated from production and demo paths',
    () async {
      final testDirectory = Directory(
        '${temp.path}${Platform.pathSeparator}isolated-test',
      );
      await testDirectory.create();
      final resolver = DatabasePathResolver(
        environment: {
          'FURNEXA_DATABASE_PATH':
              '${temp.path}${Platform.pathSeparator}demo.db',
        },
        isWindows: true,
        defaultDatabaseDirectory: () async => temp.path,
      );

      final resolution = await resolver.resolve(
        fileName: 'furnexa_test.db',
        testDirectory: testDirectory.path,
      );

      expect(resolution.source, DatabasePathSource.test);
      expect(
        resolution.path,
        '${testDirectory.path}${Platform.pathSeparator}furnexa_test.db',
      );
    },
  );

  test('Windows production path is stable and per-user', () async {
    final localAppData = '${temp.path}${Platform.pathSeparator}LocalAppData';
    final resolver = DatabasePathResolver(
      environment: {'LOCALAPPDATA': localAppData},
      isWindows: true,
      resolvedExecutable:
          '${temp.path}${Platform.pathSeparator}bin${Platform.pathSeparator}furnexa.exe',
      defaultDatabaseDirectory: () async =>
          '${temp.path}${Platform.pathSeparator}platform',
    );

    final resolution = await resolver.resolve(fileName: 'furnexa.db');

    expect(
      resolution.path,
      '$localAppData${Platform.pathSeparator}Furnexa${Platform.pathSeparator}furnexa.db',
    );
    expect(resolution.source, DatabasePathSource.windowsProduction);
  });

  test(
    'legacy database and WAL are copied when destination is missing',
    () async {
      final executableDirectory = '${temp.path}${Platform.pathSeparator}bin';
      await Directory(executableDirectory).create(recursive: true);
      final legacyDirectory = Directory(
        '$executableDirectory${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}sqflite_common_ffi${Platform.pathSeparator}databases',
      );
      await legacyDirectory.create(recursive: true);
      final legacyDatabase = File(
        '${legacyDirectory.path}${Platform.pathSeparator}furnexa.db',
      );
      await legacyDatabase.writeAsBytes([1, 2, 3, 4]);
      final legacyWal = File('${legacyDatabase.path}-wal');
      await legacyWal.writeAsBytes([5, 6, 7, 8]);

      final localAppData = '${temp.path}${Platform.pathSeparator}LocalAppData';
      final resolver = DatabasePathResolver(
        environment: {'LOCALAPPDATA': localAppData},
        isWindows: true,
        resolvedExecutable:
            '$executableDirectory${Platform.pathSeparator}furnexa.exe',
        defaultDatabaseDirectory: () async =>
            '${temp.path}${Platform.pathSeparator}platform',
      );

      final resolution = await resolver.resolve(fileName: 'furnexa.db');

      expect(resolution.legacySource, legacyDatabase.path);
      expect(await File(resolution.path).readAsBytes(), [1, 2, 3, 4]);
      expect(await File('${resolution.path}-wal').readAsBytes(), [5, 6, 7, 8]);
    },
  );

  test('existing destination is preserved', () async {
    final executableDirectory = '${temp.path}${Platform.pathSeparator}bin';
    await Directory(executableDirectory).create(recursive: true);
    final legacyDirectory = Directory(
      '$executableDirectory${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}sqflite_common_ffi${Platform.pathSeparator}databases',
    );
    await legacyDirectory.create(recursive: true);
    await File(
      '${legacyDirectory.path}${Platform.pathSeparator}furnexa.db',
    ).writeAsBytes([9, 9, 9]);

    final localAppData = '${temp.path}${Platform.pathSeparator}LocalAppData';
    final stableDirectory = Directory(
      '$localAppData${Platform.pathSeparator}Furnexa',
    );
    await stableDirectory.create(recursive: true);
    final stable = File(
      '${stableDirectory.path}${Platform.pathSeparator}furnexa.db',
    );
    await stable.writeAsBytes([1, 1, 1]);

    final resolver = DatabasePathResolver(
      environment: {'LOCALAPPDATA': localAppData},
      isWindows: true,
      resolvedExecutable:
          '$executableDirectory${Platform.pathSeparator}furnexa.exe',
      defaultDatabaseDirectory: () async =>
          '${temp.path}${Platform.pathSeparator}platform',
    );

    final resolution = await resolver.resolve(fileName: 'furnexa.db');

    expect(resolution.legacySource, isNull);
    expect(await stable.readAsBytes(), [1, 1, 1]);
  });

  test('missing legacy source is reported without fallback', () async {
    final localAppData = '${temp.path}${Platform.pathSeparator}LocalAppData';
    final resolver = DatabasePathResolver(
      environment: {'LOCALAPPDATA': localAppData},
      isWindows: true,
      resolvedExecutable:
          '${temp.path}${Platform.pathSeparator}bin${Platform.pathSeparator}furnexa.exe',
      defaultDatabaseDirectory: () async =>
          '${temp.path}${Platform.pathSeparator}platform',
    );

    final resolution = await resolver.resolve(fileName: 'furnexa.db');

    expect(
      resolution.path,
      '$localAppData${Platform.pathSeparator}Furnexa${Platform.pathSeparator}furnexa.db',
    );
    expect(resolution.legacySource, isNull);
  });

  test('failed legacy copy preserves source and destination', () async {
    final executableDirectory = '${temp.path}${Platform.pathSeparator}bin';
    await Directory(executableDirectory).create(recursive: true);
    final legacyDirectory = Directory(
      '$executableDirectory${Platform.pathSeparator}.dart_tool${Platform.pathSeparator}sqflite_common_ffi${Platform.pathSeparator}databases',
    );
    await legacyDirectory.create(recursive: true);
    final legacyDatabase = File(
      '${legacyDirectory.path}${Platform.pathSeparator}furnexa.db',
    );
    await legacyDatabase.writeAsBytes([4, 5, 6]);

    final localAppData = '${temp.path}${Platform.pathSeparator}LocalAppData';
    final stablePath =
        '$localAppData${Platform.pathSeparator}Furnexa${Platform.pathSeparator}furnexa.db';
    final resolver = DatabasePathResolver(
      environment: {'LOCALAPPDATA': localAppData},
      isWindows: true,
      resolvedExecutable:
          '$executableDirectory${Platform.pathSeparator}furnexa.exe',
      defaultDatabaseDirectory: () async =>
          '${temp.path}${Platform.pathSeparator}platform',
      copyFile: (source, destination) async {
        throw const FileSystemException('Injected copy failure');
      },
    );

    await expectLater(
      resolver.resolve(fileName: 'furnexa.db'),
      throwsA(isA<DatabasePathConfigurationException>()),
    );
    expect(await legacyDatabase.readAsBytes(), [4, 5, 6]);
    expect(await File(stablePath).exists(), isFalse);
  });
}
