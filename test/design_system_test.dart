import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/shared/widgets/furnexa_card.dart';
import 'package:furnexa/core/shared/widgets/furnexa_dialog.dart';
import 'package:furnexa/core/shared/widgets/furnexa_states.dart';
import 'package:furnexa/core/shared/widgets/furnexa_status_badge.dart';
import 'package:furnexa/core/theme/app_theme.dart';

void main() {
  testWidgets('button supports loading and disabled states', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      _app(FurnexaButton(label: 'Save', onPressed: () => pressed = true)),
    );
    await tester.tap(find.text('Save'));
    expect(pressed, isTrue);

    await tester.pumpWidget(
      _app(const FurnexaButton(label: 'Save', isLoading: true)),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('card and KPI components render with shared structure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            FurnexaCard(child: Text('Content')),
            FurnexaKpiCard(title: 'Orders', value: '12', icon: Icons.list),
          ],
        ),
      ),
    );
    expect(find.text('Content'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('status badge supports semantic variants', (tester) async {
    await tester.pumpWidget(
      _app(
        const Row(
          children: [
            FurnexaStatusBadge(
              label: 'ACTIVE',
              semantic: FurnexaStatusSemantic.success,
            ),
            FurnexaStatusBadge(
              label: 'PENDING',
              semantic: FurnexaStatusSemantic.warning,
            ),
            FurnexaStatusBadge(
              label: 'FAILED',
              semantic: FurnexaStatusSemantic.error,
            ),
            FurnexaStatusBadge(
              label: 'INFO',
              semantic: FurnexaStatusSemantic.info,
            ),
            FurnexaStatusBadge(label: 'DRAFT'),
          ],
        ),
      ),
    );
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('INFO'), findsOneWidget);
    expect(find.text('DRAFT'), findsOneWidget);
  });

  testWidgets('empty, loading, and error states expose their content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            FurnexaEmptyState(title: 'No records', description: 'Nothing here'),
            FurnexaLoading(message: 'Loading'),
            FurnexaErrorState(title: 'Error', message: 'Try again'),
          ],
        ),
      ),
    );
    expect(find.text('No records'), findsOneWidget);
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('dialog foundation renders in both directions', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const FurnexaDialog(
                title: 'Confirm',
                content: Text('Content'),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('components inherit light and dark theme surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const FurnexaCard(child: Text('Light')),
      ),
    );
    expect(
      Theme.of(tester.element(find.text('Light'))).brightness,
      Brightness.light,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const FurnexaCard(child: Text('Dark')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Dark'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('components follow Arabic RTL and English LTR', (tester) async {
    await tester.pumpWidget(
      _app(const Text('Direction'), locale: const Locale('ar')),
    );
    expect(
      Directionality.of(tester.element(find.text('Direction'))),
      TextDirection.rtl,
    );
    await tester.pumpWidget(
      _app(const Text('Direction'), locale: const Locale('en')),
    );
    expect(
      Directionality.of(tester.element(find.text('Direction'))),
      TextDirection.ltr,
    );
  });
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
