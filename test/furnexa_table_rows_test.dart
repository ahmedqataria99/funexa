import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/furnexa_table.dart';

void main() {
  testWidgets('FurnexaDataTable materializes and displays each received row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SizedBox(
          height: 480,
          child: FurnexaDataTable(
            columns: const [FurnexaTableColumn(key: 'item', label: 'Item')],
            rows: const [
              {'item': 'PIPELINE-MDF'},
              {'item': 'PIPELINE-PRODUCT'},
            ],
          ),
        ),
      ),
    );

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(2));
    expect(find.text('PIPELINE-MDF'), findsOneWidget);
    expect(find.text('PIPELINE-PRODUCT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
