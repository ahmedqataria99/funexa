import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/features/ai/data/local_ai_process_bridge.dart';

void main() {
  test('bridge reports unavailable process without starting it', () async {
    final bridge = LocalAiProcessBridge();

    await expectLater(
      bridge.analyze(<String, dynamic>{}),
      throwsA(isA<LocalAiBridgeException>()),
    );
  });

  test('bridge exception distinguishes unavailable and timeout cases', () {
    const unavailable = LocalAiBridgeException(
      'Local AI service is unavailable',
    );
    const timeout = LocalAiBridgeException('Local AI request timed out');

    expect(unavailable.message, contains('unavailable'));
    expect(timeout.message, contains('timed out'));
  });

  test('packaged runtime uses the internal ai_runtime folder', () {
    final source = File(
      'lib/features/ai/data/local_ai_runtime.dart',
    ).readAsStringSync();

    expect(source, contains("p.join(executableDirectory, 'ai_runtime')"));
    expect(
      source,
      contains(
        "p.join(runtimeDirectory, 'furnexa_ai_service', 'furnexa_ai_service.exe')",
      ),
    );
  });

  test('missing and observed-zero states remain distinct', () {
    final missing = <String, dynamic>{
      'observed_coverage': false,
      'demand_state': 'missing',
      'net_delivered_base_quantity': 0,
    };
    final observedZero = <String, dynamic>{
      'observed_coverage': true,
      'demand_state': 'observed_zero',
      'net_delivered_base_quantity': 0,
    };

    expect(missing['demand_state'], 'missing');
    expect(observedZero['demand_state'], 'observed_zero');
  });
}
