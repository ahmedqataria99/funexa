import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/furnexa_status_badge.dart';
import 'package:furnexa/core/shared/widgets/furnexa_table.dart';
import 'package:furnexa/core/theme/app_theme.dart';

void main() {
  final rows = [
    <String, Object?>{'id': '1', 'name': 'Chair', 'status': 'ACTIVE'},
    <String, Object?>{'id': '2', 'name': 'Table', 'status': 'PENDING'},
  ];

  testWidgets('renders columns, cells, status cells, and row actions', (
    tester,
  ) async {
    var actionPressed = false;
    await tester.pumpWidget(
      _app(
        FurnexaDataTable(
          columns: [
            const FurnexaTableColumn(
              key: 'name',
              label: 'Name',
              sortable: true,
            ),
            FurnexaTableColumn(
              key: 'status',
              label: 'Status',
              cellBuilder: (context, row) => FurnexaStatusBadge(
                label: '${row['status']}',
                semantic: FurnexaStatusSemantic.success,
              ),
            ),
          ],
          rows: rows,
          rowId: (row) => '${row['id']}',
          actionsBuilder: (_) => [
            FurnexaTableAction(
              label: 'View',
              icon: Icons.visibility_outlined,
              onPressed: () => actionPressed = true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Chair'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    await tester.tap(find.byTooltip('View').first);
    expect(actionPressed, isTrue);
  });

  testWidgets('sorting callback and controlled selection work', (tester) async {
    String? sortedKey;
    Set<String>? selected;
    await tester.pumpWidget(
      _app(
        FurnexaDataTable(
          columns: const [
            FurnexaTableColumn(key: 'name', label: 'Name', sortable: true),
          ],
          rows: rows,
          rowId: (row) => '${row['id']}',
          onSort: (key) => sortedKey = key,
          onSelectionChanged: (value) => selected = value,
        ),
      ),
    );

    await tester.tap(find.text('Name'));
    expect(sortedKey, 'name');
    await tester.tap(find.byType(Checkbox).at(1));
    expect(selected, contains('1'));
  });

  testWidgets('pagination exposes next and previous controls', (tester) async {
    var page = 0;
    await tester.pumpWidget(
      _app(
        FurnexaDataTable(
          columns: const [FurnexaTableColumn(key: 'name', label: 'Name')],
          rows: rows,
          pagination: FurnexaTablePagination(
            page: 0,
            pageSize: 2,
            total: 5,
            onPageChanged: (value) => page = value,
          ),
        ),
      ),
    );

    expect(find.text('1–2 / 5'), findsOneWidget);
    await tester.tap(find.byTooltip('Next'));
    expect(page, 1);
  });

  testWidgets('empty, loading, and error states render', (tester) async {
    await tester.pumpWidget(
      _app(const FurnexaDataTable(columns: [], rows: []), width: 900),
    );
    expect(find.text('No results'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        const FurnexaDataTable(columns: [], rows: [], loading: true),
        width: 900,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      _app(
        const FurnexaDataTable(
          columns: [],
          rows: [],
          errorMessage: 'Try again',
        ),
        width: 900,
      ),
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('supports RTL, LTR, light, and dark themes', (tester) async {
    await tester.pumpWidget(
      _app(
        const FurnexaDataTable(
          columns: [FurnexaTableColumn(key: 'name', label: 'Name')],
          rows: [],
        ),
        locale: const Locale('ar'),
        theme: AppTheme.lightTheme,
      ),
    );
    expect(
      Directionality.of(tester.element(find.text('لا توجد نتائج'))),
      TextDirection.rtl,
    );

    await tester.pumpWidget(
      _app(
        const FurnexaDataTable(
          columns: [FurnexaTableColumn(key: 'name', label: 'Name')],
          rows: [],
        ),
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.text('No results'))),
      TextDirection.ltr,
    );
    expect(
      Theme.of(tester.element(find.text('No results'))).brightness,
      Brightness.dark,
    );
  });
}

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  double width = 1100,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: theme ?? ThemeData(useMaterial3: true),
  home: Scaffold(
    body: SizedBox(width: width, height: 650, child: child),
  ),
);
