import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/features/ai/data/local_ai_process_bridge.dart';

void main() {
  final servicePath = Platform.environment['FURNEXA_TEST_AI_SERVICE'];
  final bridge = LocalAiProcessBridge(
    requestTimeout: const Duration(seconds: 90),
  );

  tearDown(() async => bridge.stop());

  test(
    'Dart starts the packaged onedir executable with its launch environment',
    () async {
      if (servicePath == null || servicePath.isEmpty) return;
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final token = 'diagnostic-${DateTime.now().microsecondsSinceEpoch}';
      final process = await Process.start(
        servicePath,
        const <String>[],
        workingDirectory: File(servicePath).parent.path,
        environment: {
          ...Platform.environment,
          'FURNEXA_LOCAL_AI_PORT': '$port',
          'FURNEXA_LOCAL_AI_TOKEN': token,
        },
      );
      final output = <String>[];
      process.stdout
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen(output.add);
      process.stderr
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen(output.add);
      final client = HttpClient();
      try {
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (DateTime.now().isBefore(deadline)) {
          if (await process.exitCode
                  .then<int?>((code) => code)
                  .timeout(
                    const Duration(milliseconds: 10),
                    onTimeout: () => null,
                  )
              case final int code) {
            fail(
              'Dart-started service exited with code $code: ${output.join(' | ')}',
            );
          }
          try {
            final request = await client.getUrl(
              Uri.parse('http://127.0.0.1:$port/health'),
            );
            request.headers.set(
              HttpHeaders.authorizationHeader,
              'Bearer $token',
            );
            final response = await request.close().timeout(
              const Duration(seconds: 1),
            );
            expect(response.statusCode, 200);
            await response.drain<void>();
            return;
          } on Object {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        fail(
          'Dart-started service did not become ready: ${output.join(' | ')}',
        );
      } finally {
        client.close(force: true);
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return process.exitCode.timeout(const Duration(seconds: 5));
          },
        );
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'packaged Python service runs real 7, 14, and 30 day forecasts',
    () async {
      if (servicePath == null || servicePath.isEmpty) return;
      await Future.wait([
        bridge.start(
          pythonExecutable: servicePath,
          serviceScript: '',
          workingDirectory: File(servicePath).parent.path,
        ),
        bridge.start(
          pythonExecutable: servicePath,
          serviceScript: '',
          workingDirectory: File(servicePath).parent.path,
        ),
      ]);
      final port = bridge.localPort!;
      for (final horizon in const [7, 14, 30]) {
        final result = await bridge.forecast(_payload(horizon, 365));
        expect(result['status'], 'ok');
        expect(result['selected_model'], isNotNull);
        expect(result['observations_used'], 365);
        expect(result['forecast'], hasLength(horizon));
        expect(
          (result['forecast'] as List).every(
            (point) => (point['forecast'] as num) >= 0,
          ),
          isTrue,
        );
      }
      final insufficient = await bridge.forecast(_payload(7, 179));
      expect(insufficient['status'], 'insufficient_data');
      expect(insufficient['forecast'], isEmpty);

      await bridge.stop();
      expect(bridge.isRunning, isFalse);
      final releasedPort = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await releasedPort.close();

      await bridge.start(
        pythonExecutable: servicePath,
        serviceScript: '',
        workingDirectory: File(servicePath).parent.path,
      );
      expect(bridge.localPort, isNotNull);
      expect((await bridge.forecast(_payload(7, 365)))['status'], 'ok');
    },
    skip: servicePath == null || servicePath.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Map<String, dynamic> _payload(int horizon, int days) {
  final start = DateTime.utc(2025, 1, 1);
  return {
    'request_id': 'packaged-runtime-$horizon-$days',
    'sales': {
      'contract_version': 'sales-demand-v1',
      'purpose': 'demand_forecasting',
      'period_start': start.toIso8601String().substring(0, 10),
      'period_end': start
          .add(Duration(days: days - 1))
          .toIso8601String()
          .substring(0, 10),
      'horizon_days': horizon,
      'excluded_counts': <String, int>{},
      'observations': [
        for (var index = 0; index < days; index++)
          {
            'delivery_date': start
                .add(Duration(days: index))
                .toIso8601String()
                .substring(0, 10),
            'warehouse_token': 'warehouse-token',
            'product_token': 'product-token',
            'variant_token': 'variant-token',
            'base_unit_token': 'unit-token',
            'gross_delivered_base_quantity':
                (8 + (index % 7 == 0 ? 2 : 0) + (index % 13 == 0 ? 1 : 0))
                    .toDouble(),
            'accepted_return_base_quantity': 0,
            'net_delivered_base_quantity':
                (8 + (index % 7 == 0 ? 2 : 0) + (index % 13 == 0 ? 1 : 0))
                    .toDouble(),
            'observed_coverage': true,
            'demand_state': 'observed_positive',
          },
      ],
    },
  };
}
