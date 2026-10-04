import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/widgets/furnexa_app_shell.dart';

void main() {
  testWidgets('sidebar expands and collapses with accessible tooltips', (
    tester,
  ) async {
    var expanded = true;
    await tester.pumpWidget(
      _shellApp(
        expanded: expanded,
        onToggleSidebar: () => expanded = !expanded,
      ),
    );

    final sidebarLabel = find.descendant(
      of: find.byType(ListView),
      matching: find.text('Dashboard'),
    );
    expect(sidebarLabel, findsOneWidget);
    await tester.tap(find.byTooltip('Collapse sidebar'));
    expanded = false;
    await tester.pumpWidget(
      _shellApp(
        expanded: expanded,
        onToggleSidebar: () => expanded = !expanded,
      ),
    );

    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Dashboard'),
      ),
      findsNothing,
    );
    expect(find.byTooltip('Dashboard'), findsOneWidget);
  });

  testWidgets('theme and language controls invoke global callbacks', (
    tester,
  ) async {
    var themeToggled = false;
    var localeToggled = false;
    await tester.pumpWidget(
      _shellApp(
        onToggleTheme: () => themeToggled = true,
        onToggleLocale: () => localeToggled = true,
      ),
    );

    await tester.tap(find.byTooltip('Theme: Dark'));
    await tester.tap(find.byTooltip('Language: Arabic'));
    expect(themeToggled, isTrue);
    expect(localeToggled, isTrue);
  });

  testWidgets('breadcrumbs and user menu expose current context and logout', (
    tester,
  ) async {
    var loggedOut = false;
    await tester.pumpWidget(
      _shellApp(
        breadcrumbs: const ['Home', 'Sales', 'Orders'],
        userName: 'System Admin',
        userRole: 'Administrator',
        onLogout: () => loggedOut = true,
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    await tester.tap(find.byTooltip('User'));
    await tester.pumpAndSettle();
    expect(find.text('System Admin'), findsOneWidget);
    expect(find.text('Role: Administrator'), findsOneWidget);
    await tester.tap(find.text('Log out'));
    expect(loggedOut, isTrue);
  });

  testWidgets('breadcrumbs follow English LTR and Arabic RTL direction', (
    tester,
  ) async {
    await tester.pumpWidget(_shellApp(locale: const Locale('en')));
    expect(
      Directionality.of(tester.element(find.text('Home'))),
      TextDirection.ltr,
    );

    await tester.pumpWidget(
      _shellApp(
        locale: const Locale('ar'),
        breadcrumbs: const ['الرئيسية', 'لوحة التشغيل'],
      ),
    );
    expect(
      Directionality.of(tester.element(find.text('الرئيسية'))),
      TextDirection.rtl,
    );
  });
}

Widget _shellApp({
  Locale locale = const Locale('en'),
  bool expanded = true,
  VoidCallback? onToggleSidebar,
  VoidCallback? onToggleTheme,
  VoidCallback? onToggleLocale,
  List<String> breadcrumbs = const ['Home', 'Dashboard'],
  String? userName,
  String? userRole,
  VoidCallback? onLogout,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(useMaterial3: true),
    home: FurnexaAppShell(
      title: locale.languageCode == 'ar' ? 'لوحة التشغيل' : 'Dashboard',
      selectedIndex: 0,
      destinations: const [
        FurnexaNavItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
      ],
      onDestinationSelected: (_) {},
      body: const SizedBox.expand(),
      isSidebarExpanded: expanded,
      onToggleSidebar: onToggleSidebar ?? () {},
      onToggleTheme: onToggleTheme ?? () {},
      onToggleLocale: onToggleLocale ?? () {},
      isDark: false,
      locale: locale,
      breadcrumbs: breadcrumbs,
      userName: userName,
      userRole: userRole,
      onLogout: onLogout,
    ),
  );
}
