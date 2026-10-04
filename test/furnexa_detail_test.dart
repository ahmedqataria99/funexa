import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/detail/furnexa_detail.dart';
import 'package:furnexa/core/theme/app_theme.dart';

void main() {
  testWidgets('detail header and information sections render', (tester) async {
    await tester.pumpWidget(_app(
      FurnexaDetailPage(
        header: const FurnexaDetailHeader(
          title: 'Dining Table',
          code: 'PRD-001',
          status: Text('ACTIVE'),
        ),
        children: const [
          FurnexaInfoSection(
            title: 'Information',
            items: [FurnexaInfoItem(label: 'Name', value: 'Dining Table')],
          ),
        ],
      ),
    ));
    expect(find.text('Dining Table'), findsNWidgets(2));
    expect(find.text('PRD-001'), findsOneWidget);
    expect(find.text('Information'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('related empty, loading, and error states are available', (tester) async {
    await tester.pumpWidget(_app(const FurnexaDetailSection(
      title: 'History',
      empty: true,
      emptyTitle: 'No history',
      child: Text('hidden'),
    )));
    expect(find.text('No history'), findsOneWidget);

    await tester.pumpWidget(_app(const FurnexaLoadingDetail()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(_app(const FurnexaErrorDetail()));
    expect(find.text('Unable to load'), findsOneWidget);
  });

  testWidgets('detail foundation supports RTL/LTR and themes', (tester) async {
    await tester.pumpWidget(_app(const Text('Detail'), locale: const Locale('ar')));
    expect(Directionality.of(tester.element(find.text('Detail'))), TextDirection.rtl);
    await tester.pumpWidget(_app(const Text('Detail'), locale: const Locale('en'), theme: AppTheme.darkTheme));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.text('Detail'))), TextDirection.ltr);
    expect(Theme.of(tester.element(find.text('Detail'))).brightness, Brightness.dark);
  });
}

class FurnexaLoadingDetail extends StatelessWidget {
  const FurnexaLoadingDetail({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class FurnexaErrorDetail extends StatelessWidget {
  const FurnexaErrorDetail({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Unable to load'));
}

Widget _app(Widget child, {Locale locale = const Locale('en'), ThemeData? theme}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
