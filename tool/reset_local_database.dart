import 'dart:io';

import 'package:furnexa/core/database/furnexa_database.dart';

Future<void> main() async {
  if (!Platform.isWindows) {
    stderr.writeln('This utility is intended for Windows development only.');
    exitCode = 2;
    return;
  }

  final runningApp = await Process.run('tasklist.exe', [
    '/FI',
    'IMAGENAME eq furnexa.exe',
    '/FO',
    'CSV',
    '/NH',
  ]);
  if (runningApp.exitCode != 0) {
    stderr.writeln(
      'Could not verify whether Furnexa is running; reset aborted.',
    );
    exitCode = 2;
    return;
  }
  if (runningApp.stdout.toString().toLowerCase().contains('"furnexa.exe"')) {
    stderr.writeln('Close Furnexa before running this reset utility.');
    exitCode = 2;
    return;
  }

  final database = FurnexaDatabase.instance;
  final path = await database.databasePath;
  stdout.writeln('Database to reset: $path');
  stdout.writeln(
    'Type RESET $path to create a backup and reset this database:',
  );
  final confirmation = stdin.readLineSync();
  if (confirmation != 'RESET $path') {
    stdout.writeln('Reset cancelled.');
    return;
  }

  final result = await database.resetForLocalDevelopment();
  stdout.writeln('Database recreated: ${result.databasePath}');
  stdout.writeln(
    'Verified backup: ${result.backupPath ?? 'not needed; database was absent'}',
  );
}
