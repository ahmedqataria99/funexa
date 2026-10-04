import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/ui/form_field.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/shared/widgets/furnexa_form.dart';
import 'package:furnexa/core/theme/app_theme.dart';

void main() {
  testWidgets('renders form sections, required fields, and actions', (
    tester,
  ) async {
    var saved = false;
    var cancelled = false;
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _app(
        FurnexaFormShell(
          formKey: key,
          sections: [
            FurnexaFormSection(
              title: 'Basic information',
              children: [
                FurnexaFormField(
                  labelText: 'Name',
                  required: true,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const Text('Extra field'),
              ],
            ),
          ],
          cancelLabel: 'Cancel',
          saveLabel: 'Save',
          onCancel: () => cancelled = true,
          onSave: () => saved = true,
        ),
      ),
    );

    expect(find.text('Basic information'), findsOneWidget);
    expect(find.text('Name *'), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(saved, isTrue);
    await tester.tap(find.text('Cancel'));
    expect(cancelled, isTrue);
  });

  testWidgets('validation appears and loading disables actions', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      _app(
        FurnexaFormShell(
          formKey: key,
          sections: [
            FurnexaFormSection(
              title: 'Required section',
              children: [
                FurnexaFormField(
                  labelText: 'Code',
                  required: true,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
              ],
            ),
          ],
          cancelLabel: 'Cancel',
          saveLabel: 'Save',
          onCancel: () {},
          onSave: () => key.currentState!.validate(),
          saveLoading: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FurnexaButton>(find.byType(FurnexaButton).last).isLoading,
      isTrue,
    );
    key.currentState!.validate();
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('form follows Arabic RTL, English LTR, and dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Text('Form'), locale: const Locale('ar')),
    );
    expect(
      Directionality.of(tester.element(find.text('Form'))),
      TextDirection.rtl,
    );
    await tester.pumpWidget(
      _app(
        const Text('Form'),
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.text('Form'))),
      TextDirection.ltr,
    );
    expect(
      Theme.of(tester.element(find.text('Form'))).brightness,
      Brightness.dark,
    );
  });
}

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: theme ?? AppTheme.lightTheme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
