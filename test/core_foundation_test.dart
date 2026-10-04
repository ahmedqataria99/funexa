import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/error/app_exception.dart';
import 'package:furnexa/core/result/result.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/core/usecase/usecase.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/main.dart';

void main() {
  group('Furnexa core foundation', () {
    setUp(() async {
      await FurnexaDatabase.instance.resetForTesting();
    });

    tearDown(() async {
      await FurnexaDatabase.instance.resetForTesting();
    });

    test('database initializes successfully and opens safely', () async {
      final first = await FurnexaDatabase.instance.database;
      final second = await FurnexaDatabase.instance.database;

      expect(first.isOpen, isTrue);
      expect(second.isOpen, isTrue);
      expect(first.path, contains('furnexa'));
      expect(first.path, endsWith('.db'));
      expect(first.path, equals(second.path));
    });

    test('database version is correct', () async {
      final version = await FurnexaDatabase.instance.getDatabaseVersion();

      expect(version, AppConstants.databaseVersion);
    });

    test('migration mechanism is callable', () async {
      final db = await FurnexaDatabase.instance.database;

      await expectLater(
        FurnexaDatabase.instance.migrate(
          db,
          AppConstants.databaseVersion,
          AppConstants.databaseVersion,
        ),
        completes,
      );
    });

    test('core result and exceptions behave correctly', () {
      final success = Result<String>.success('ok');
      final failure = Result<String>.failure(DatabaseException('DB failed'));

      expect(success.isSuccess, isTrue);
      expect(failure.isSuccess, isFalse);
      expect(success.value, 'ok');
      expect(failure.error, isA<DatabaseException>());
    });

    test('use case base abstraction works', () async {
      final useCase = _TestUseCase();
      final result = await useCase(const NoParams());

      expect(result.isSuccess, isTrue);
      expect(result.value, 'done');
    });

    testWidgets('theme initializes', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme));

      expect(AppTheme.lightTheme, isNotNull);
      expect(AppTheme.darkTheme, isNotNull);
    });

    testWidgets('localization initializes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(),
        ),
      );

      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
      expect(AppLocalizations.supportedLocales, contains(const Locale('ar')));
      expect(
        AppLocalizations.of(tester.element(find.byType(Scaffold))),
        isNotNull,
      );
    });

    testWidgets('application starts successfully', (tester) async {
      await tester.pumpWidget(const FurnexaApp());

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.textContaining('Furnexa'), findsWidgets);
    });
  });
}

class _TestUseCase extends UseCase<NoParams, String> {
  @override
  Future<Result<String>> call(NoParams params) async {
    return Result<String>.success('done');
  }
}
