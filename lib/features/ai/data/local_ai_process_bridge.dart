import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class LocalAiBridgeException implements Exception {
  const LocalAiBridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalAiProcessBridge {
  LocalAiProcessBridge({
    this.pythonExecutable,
    this.serviceScript,
    this.startupTimeout = const Duration(seconds: 60),
    this.requestTimeout = const Duration(seconds: 30),
  });

  final String? pythonExecutable;
  final String? serviceScript;
  final Duration startupTimeout;
  final Duration requestTimeout;

  Process? _process;
  int? _processExitCode;
  final List<String> _processOutput = <String>[];
  HttpClient? _client;
  String? _token;
  Uri? _baseUri;
  Future<void>? _startFuture;
  Future<void>? _stopFuture;
  bool _stopRequested = false;
  String? _startedPythonExecutable;
  String? _startedServiceScript;
  String? _startedWorkingDirectory;
  int? _windowsJobHandle;

  bool get isRunning =>
      _process != null && _processExitCode == null && _baseUri != null;

  int? get localPort => _baseUri?.port;

  Future<void> start({
    required String pythonExecutable,
    required String serviceScript,
    String? workingDirectory,
  }) async {
    final stopping = _stopFuture;
    if (stopping != null) await stopping;
    if (_stopRequested) {
      throw const LocalAiBridgeException('Local AI service is stopping');
    }
    if (_startFuture != null) return _startFuture!;
    _startFuture = _start(
      pythonExecutable: pythonExecutable,
      serviceScript: serviceScript,
      workingDirectory: workingDirectory,
    );
    try {
      await _startFuture;
    } finally {
      _startFuture = null;
    }
  }

  Future<void> _start({
    required String pythonExecutable,
    required String serviceScript,
    String? workingDirectory,
  }) async {
    if (isRunning) return;
    if (_process != null) await stop();
    _startedPythonExecutable = pythonExecutable;
    _startedServiceScript = serviceScript;
    _startedWorkingDirectory = workingDirectory;

    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();

    final random = Random.secure();
    _token = List.generate(
      32,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    if (_stopRequested) {
      throw const LocalAiBridgeException('Local AI service startup cancelled');
    }

    _process = await Process.start(
      pythonExecutable,
      serviceScript.isEmpty ? const <String>[] : [serviceScript],
      workingDirectory: workingDirectory,
      environment: {
        ...Platform.environment,
        'FURNEXA_LOCAL_AI_PORT': port.toString(),
        'FURNEXA_LOCAL_AI_TOKEN': _token!,
      },
    );
    if (Platform.isWindows) {
      try {
        _windowsJobHandle = _WindowsJobObject.assign(startedProcess: _process!);
      } on Object catch (error) {
        await _terminateProcess(_process!);
        _clearProcessState();
        throw LocalAiBridgeException(
          'Failed to assign Local AI process to a Windows process job: $error',
        );
      }
    }
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _captureProcessLine(line));
    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _captureProcessLine(line));
    final startedProcess = _process!;
    startedProcess.exitCode.then((code) {
      _processExitCode = code;
      if (identical(_process, startedProcess)) {
        _process = null;
        _baseUri = null;
        _closeWindowsJob();
      }
    });

    _baseUri = Uri.parse('http://127.0.0.1:$port');
    _client = HttpClient()..connectionTimeout = const Duration(seconds: 5);

    final deadline = DateTime.now().add(startupTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_stopRequested) {
        await _terminateProcess(startedProcess);
        _clearProcessState();
        throw const LocalAiBridgeException(
          'Local AI service startup cancelled',
        );
      }
      if (_processExitCode != null) {
        throw LocalAiBridgeException(
          'Local AI process exited during startup with code $_processExitCode '
          '(executable: $pythonExecutable; working directory: '
          '${workingDirectory ?? Directory.current.path})$_diagnosticSuffix',
        );
      }
      try {
        await _get('/health');
        if (_stopRequested) {
          await _terminateProcess(startedProcess);
          _clearProcessState();
          throw const LocalAiBridgeException(
            'Local AI service startup cancelled',
          );
        }
        return;
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } on LocalAiBridgeException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      } on TimeoutException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    await _terminateProcess(startedProcess);
    _clearProcessState();
    throw LocalAiBridgeException(
      'Local AI service readiness timeout$_diagnosticSuffix',
    );
  }

  void _captureProcessLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    _processOutput.add(trimmed);
    if (_processOutput.length > 40) _processOutput.removeAt(0);
  }

  String get _diagnosticSuffix {
    if (_processOutput.isEmpty) return '';
    return '. Process output: ${_processOutput.join(' | ')}';
  }

  Future<Map<String, dynamic>> analyze(Map<String, dynamic> payload) async {
    await _ensureReadyForRequest();
    return _post('/v1/analyze/sales-demand', payload);
  }

  Future<Map<String, dynamic>> forecast(Map<String, dynamic> payload) async {
    await _ensureReadyForRequest();
    return _post('/v1/forecast/sales-demand', payload);
  }

  Future<void> _ensureReadyForRequest() async {
    if (_startFuture != null) await _startFuture;
    if (isRunning) return;
    final pythonExecutable = _startedPythonExecutable;
    if (pythonExecutable == null) {
      throw const LocalAiBridgeException('Local AI service is unavailable');
    }
    await start(
      pythonExecutable: pythonExecutable,
      serviceScript: _startedServiceScript ?? '',
      workingDirectory: _startedWorkingDirectory,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _get('/health').timeout(const Duration(seconds: 2));
    } on SocketException {
      throw const LocalAiBridgeException('Local AI service is unavailable');
    } on TimeoutException {
      throw const LocalAiBridgeException('Local AI service is unavailable');
    } on LocalAiBridgeException {
      rethrow;
    }
    if (_process == null ||
        _baseUri == null ||
        _client == null ||
        _token == null) {
      throw const LocalAiBridgeException('Local AI service is unavailable');
    }
    final encoded = utf8.encode(jsonEncode(payload));
    if (encoded.length > 2 * 1000 * 1000) {
      throw const LocalAiBridgeException('Local AI request is too large');
    }

    final client = _client!;
    final uri = _baseUri!.resolve(path);
    final request = await client.postUrl(uri).timeout(requestTimeout);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_token')
      ..set(HttpHeaders.contentTypeHeader, 'application/json')
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..contentLength = encoded.length;
    request.add(encoded);

    try {
      final response = await request.close().timeout(requestTimeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LocalAiBridgeException(
          'Local AI service rejected the request (${response.statusCode})',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const LocalAiBridgeException('Invalid Local AI response');
      }
      return decoded;
    } on TimeoutException {
      throw const LocalAiBridgeException('Local AI request timed out');
    } on SocketException {
      throw const LocalAiBridgeException('Local AI service is unavailable');
    }
  }

  Future<void> _get(String path) async {
    final request = await _client!
        .getUrl(_baseUri!.resolve(path))
        .timeout(const Duration(seconds: 2));
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    final response = await request.close().timeout(const Duration(seconds: 2));
    await response.drain<void>();
    if (response.statusCode != 200) {
      throw LocalAiBridgeException(
        'Local AI health check failed (${response.statusCode})',
      );
    }
  }

  Future<void> stop() {
    final existing = _stopFuture;
    if (existing != null) return existing;
    final stopping = _stop();
    _stopFuture = stopping;
    return stopping.whenComplete(() {
      if (identical(_stopFuture, stopping)) _stopFuture = null;
    });
  }

  Future<void> _stop() async {
    _stopRequested = true;
    final startup = _startFuture;
    if (startup != null) {
      try {
        await startup;
      } on Object {
        // A cancelled or failed startup is already being cleaned up.
      }
    }
    _client?.close(force: true);
    _client = null;
    _baseUri = null;
    _token = null;
    final process = _process;
    _process = null;
    _processExitCode = null;
    _processOutput.clear();
    if (process != null) {
      await _terminateProcess(process);
    }
    _stopRequested = false;
  }

  Future<void> _terminateProcess(Process process) async {
    if (Platform.isWindows && _windowsJobHandle != null) {
      _WindowsJobObject.terminateAndClose(_windowsJobHandle!);
      _windowsJobHandle = null;
    } else {
      process.kill(ProcessSignal.sigterm);
    }
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }

  void _closeWindowsJob() {
    final handle = _windowsJobHandle;
    if (handle == null) return;
    _WindowsJobObject.close(handle);
    _windowsJobHandle = null;
  }

  void _clearProcessState() {
    _client?.close(force: true);
    _client = null;
    _baseUri = null;
    _token = null;
    _process = null;
    _processExitCode = null;
    _closeWindowsJob();
    _processOutput.clear();
  }
}

class _WindowsJobObject {
  static int assign({required Process startedProcess}) {
    final jobHandle = CreateJobObject(nullptr, nullptr);
    if (jobHandle == 0) {
      throw StateError('CreateJobObjectW failed');
    }

    final information = calloc<_JobObjectExtendedLimitInformation>();
    try {
      information.ref.basic.limitFlags = 0x00002000;
      final configured = SetInformationJobObject(
        jobHandle,
        9,
        information.cast(),
        sizeOf<_JobObjectExtendedLimitInformation>(),
      );
      if (configured == 0) {
        CloseHandle(jobHandle);
        throw StateError('SetInformationJobObject failed');
      }
    } finally {
      calloc.free(information);
    }

    final processHandle = OpenProcess(0x1F0FFF, 0, startedProcess.pid);
    if (processHandle == 0) {
      CloseHandle(jobHandle);
      throw StateError('OpenProcess failed for PID ${startedProcess.pid}');
    }
    final assigned = AssignProcessToJobObject(jobHandle, processHandle);
    CloseHandle(processHandle);
    if (assigned == 0) {
      CloseHandle(jobHandle);
      throw StateError('AssignProcessToJobObject failed');
    }
    return jobHandle;
  }

  static void terminateAndClose(int jobHandle) {
    TerminateJobObject(jobHandle, 1);
    CloseHandle(jobHandle);
  }

  static void close(int jobHandle) {
    CloseHandle(jobHandle);
  }
}

final class _JobObjectBasicLimitInformation extends Struct {
  @Uint64()
  external int perProcessUserTimeLimit;

  @Uint64()
  external int perJobUserTimeLimit;

  @Uint32()
  external int limitFlags;

  @Size()
  external int minimumWorkingSetSize;

  @Size()
  external int maximumWorkingSetSize;

  @Uint32()
  external int activeProcessLimit;

  @Size()
  external int affinity;

  @Uint32()
  external int priorityClass;

  @Uint32()
  external int schedulingClass;
}

final class _IoCounters extends Struct {
  @Uint64()
  external int readOperationCount;

  @Uint64()
  external int writeOperationCount;

  @Uint64()
  external int otherOperationCount;

  @Uint64()
  external int readTransferCount;

  @Uint64()
  external int writeTransferCount;

  @Uint64()
  external int otherTransferCount;
}

final class _JobObjectExtendedLimitInformation extends Struct {
  external _JobObjectBasicLimitInformation basic;

  external _IoCounters ioInfo;

  @Size()
  external int processMemoryLimit;

  @Size()
  external int jobMemoryLimit;

  @Size()
  external int peakProcessMemoryUsed;

  @Size()
  external int peakJobMemoryUsed;
}
