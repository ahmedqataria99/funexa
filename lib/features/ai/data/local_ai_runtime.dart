import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'local_ai_process_bridge.dart';

class LocalAiRuntime {
  static Future<void> start(LocalAiProcessBridge bridge) async {
    final executableDirectory = p.dirname(Platform.resolvedExecutable);
    final runtimeDirectory = p.join(executableDirectory, 'ai_runtime');
    final packagedService = File(
      p.join(runtimeDirectory, 'furnexa_ai_service.exe'),
    );
    if (!await packagedService.exists()) {
      final nestedPackagedService = File(
        p.join(
          runtimeDirectory,
          'furnexa_ai_service',
          'furnexa_ai_service.exe',
        ),
      );
      if (await nestedPackagedService.exists()) {
        await bridge.start(
          pythonExecutable: nestedPackagedService.path,
          serviceScript: '',
          workingDirectory: p.dirname(nestedPackagedService.path),
        );
        return;
      }
    }
    if (await packagedService.exists()) {
      await bridge.start(
        pythonExecutable: packagedService.path,
        serviceScript: '',
        workingDirectory: p.dirname(packagedService.path),
      );
      return;
    }

    if (kReleaseMode) {
      throw const LocalAiBridgeException(
        'Packaged Local AI service was not found in the ai_runtime folder.',
      );
    }

    final environment = Platform.environment;
    final configuredScript = environment['FURNEXA_LOCAL_AI_SERVICE_SCRIPT']
        ?.trim();
    final aiRoot = p.normalize(
      p.join(Directory.current.path, '..', 'furnixa-ai'),
    );
    final candidates = <String?>[
      configuredScript,
      p.normalize(p.join(aiRoot, 'src', 'api', 'local_ai_service.py')),
    ];
    String? serviceScript;
    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final file = File(candidate);
      if (await file.exists() && await file.length() > 0) {
        serviceScript = file.absolute.path;
        break;
      }
    }
    if (serviceScript == null) {
      throw const LocalAiBridgeException(
        'Local AI service source was not found for development.',
      );
    }

    final configuredPython = environment['FURNEXA_PYTHON_EXECUTABLE']?.trim();
    final venvPython = p.normalize(
      p.join(aiRoot, '.venv', 'Scripts', 'python.exe'),
    );
    final pythonExecutable =
        configuredPython != null && configuredPython.isNotEmpty
        ? configuredPython
        : await File(venvPython).exists()
        ? venvPython
        : 'python';

    await bridge.start(
      pythonExecutable: pythonExecutable,
      serviceScript: serviceScript,
      workingDirectory: aiRoot,
    );
  }
}
