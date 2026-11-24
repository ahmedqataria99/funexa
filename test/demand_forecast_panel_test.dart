import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/features/ai/presentation/widgets/demand_forecast_panel.dart';

void main() {
  testWidgets('renders response summaries and visible blue/orange series', (
    tester,
  ) async {
    await _pumpPanel(tester, _response(7));

    expect(find.text('إجمالي الطلب المتوقع خلال الفترة'), findsOneWidget);
    expect(find.text('النموذج المستخدم'), findsOneWidget);
    expect(find.text('الطلب الفعلي'), findsOneWidget);
    expect(find.text('الطلب المتوقع'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('historical-demand-legend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forecast-demand-legend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('demand-series-semantics')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('demand-forecast-chart')), findsOneWidget);
  });

  for (final horizon in const [7, 14, 30]) {
    testWidgets('$horizon-day response renders the full forecast summary', (
      tester,
    ) async {
      await _pumpPanel(tester, _response(horizon), horizonDays: horizon);

      expect(
        find.byKey(const ValueKey('demand-forecast-chart')),
        findsOneWidget,
      );
      expect(find.text('ets_guarded'), findsOneWidget);
      expect(find.textContaining('2026-02-'), findsOneWidget);
    });
  }

  testWidgets('empty historical series shows a clear Arabic message', (
    tester,
  ) async {
    final response = _response(7)..['historical'] = <Map<String, Object?>>[];
    await _pumpPanel(tester, response);

    expect(
      find.text('لا توجد بيانات تاريخية أو توقعات كافية لعرض الرسم البياني.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('demand-forecast-chart')), findsNothing);
  });

  testWidgets('short forecast shows insufficient-data state', (tester) async {
    final response = _response(7)
      ..['forecast'] = (_response(7)['forecast'] as List).take(6).toList();
    await _pumpPanel(tester, response);

    expect(
      find.byKey(const ValueKey('forecast-insufficient-state')),
      findsOneWidget,
    );
  });

  testWidgets('invalid quantity shows an error state instead of a chart', (
    tester,
  ) async {
    final response = _response(7);
    (response['forecast'] as List<Map<String, Object?>>).first['forecast'] =
        double.nan;
    await _pumpPanel(tester, response);

    expect(
      find.byKey(const ValueKey('forecast-invalid-state')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('demand-forecast-chart')), findsNothing);
  });

  testWidgets('invalid dates show an error state instead of a chart', (
    tester,
  ) async {
    final response = _response(7);
    (response['historical'] as List<Map<String, Object?>>).first['date'] =
        'not-a-date';
    await _pumpPanel(tester, response);

    expect(
      find.byKey(const ValueKey('forecast-invalid-state')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('demand-forecast-chart')), findsNothing);
  });

  testWidgets('zero-demand observations remain visible without mock data', (
    tester,
  ) async {
    final response = _response(7);
    for (final point in response['historical'] as List<Map<String, Object?>>) {
      point['actual'] = 0;
    }
    await _pumpPanel(tester, response);

    expect(find.byKey(const ValueKey('demand-forecast-chart')), findsOneWidget);
  });

  testWidgets('loading and request error have explicit states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DemandForecastPanel(
            response: null,
            horizonDays: 7,
            loading: true,
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('forecast-loading-state')),
      findsOneWidget,
    );
    expect(find.text('جارٍ استلام التوقعات وعرضها...'), findsOneWidget);

    await _pumpPanel(tester, null, error: 'تعذر تنفيذ التوقع حاليًا.');
    expect(find.byKey(const ValueKey('forecast-error-state')), findsOneWidget);
    expect(find.text('تعذر تنفيذ التوقع حاليًا.'), findsOneWidget);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  Map<String, dynamic>? response, {
  int horizonDays = 7,
  String? error,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: DemandForecastPanel(
            response: response,
            horizonDays: horizonDays,
            loading: false,
            error: error,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Map<String, dynamic> _response(int horizon) => {
  'status': 'ok',
  'horizon_days': horizon,
  'selected_model': 'ets_guarded',
  'historical': [
    for (var index = 0; index < 5; index++)
      {
        'date': DateTime.utc(2026, 1, 27 + index).toIso8601String(),
        'actual': const [0, 4, 2, 0, 7][index],
        'observed': true,
      },
  ],
  'forecast': [
    for (var index = 0; index < horizon; index++)
      {
        'date': DateTime.utc(2026, 2, 1 + index).toIso8601String(),
        'forecast': const [3, 0, 6, 2, 7, 0, 4][index % 7].toDouble(),
      },
  ],
};
