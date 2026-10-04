import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/backup_restore/domain/entities/backup_restore_entities.dart';
import 'package:furnexa/features/backup_restore/domain/repositories/backup_restore_repository.dart';
import 'package:furnexa/features/backup_restore/presentation/controllers/backup_restore_controller.dart';
import 'package:furnexa/features/backup_restore/presentation/pages/backup_restore_page.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

void main() {
  late _FakeRepository repository;

  setUp(() {
    repository = _FakeRepository();
  });

  testWidgets('backup page renders its three main areas', (tester) async {
    await tester.pumpWidget(
      _app(
        BackupRestorePage(
          security: _FakeSecurity(admin: true),
          repository: repository,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('النسخ الاحتياطي والاستعادة'), findsOneWidget);
    expect(find.text('النسخ الاحتياطي'), findsOneWidget);
    expect(find.text('الاستعادة'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('سجل النسخ الاحتياطية'), 400);
    expect(find.text('سجل النسخ الاحتياطية'), findsOneWidget);
  });

  testWidgets('backup actions are hidden for unauthorized users', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        BackupRestorePage(
          security: _FakeSecurity(admin: false),
          repository: repository,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('إنشاء نسخة احتياطية'), findsNothing);
    expect(find.text('استعادة نسخة احتياطية'), findsNothing);
  });

  testWidgets('existing history renders metadata and unavailable status', (
    tester,
  ) async {
    repository.history = [_history(status: 'VALID', filePath: '')];
    await tester.pumpWidget(
      _app(
        BackupRestorePage(
          security: _FakeSecurity(admin: true),
          repository: repository,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(find.text('factory.furnexa'), 400);
    expect(find.text('factory.furnexa'), findsOneWidget);
    expect(find.text('الملف غير متاح'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  test('controller exposes valid preview metadata and success state', () async {
    final controller = BackupRestoreController(repository: repository);
    final metadata = await controller.validateBackup('valid.furnexa');

    expect(metadata?.factoryName, 'مصنع Furnexa');
    expect(controller.selectedBackup?.databaseVersion, 20);
    expect(await controller.restoreBackup('valid.furnexa'), isTrue);
    expect(controller.success, 'restored');
    controller.dispose();
  });

  test('controller exposes failure state for invalid backup', () async {
    repository.invalid = true;
    final controller = BackupRestoreController(repository: repository);

    expect(await controller.validateBackup('invalid.furnexa'), isNull);
    expect(controller.error, 'validate');
    controller.dispose();
  });
}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: ThemeData(useMaterial3: true),
  home: child,
);

BackupHistoryEntry _history({
  required String status,
  required String filePath,
}) => BackupHistoryEntry(
  id: 'history-1',
  backupId: 'backup-1',
  createdAt: DateTime(2026, 9, 20, 12),
  factoryName: 'مصنع Furnexa',
  factoryCode: 'F-001',
  databaseVersion: 20,
  fileName: 'factory.furnexa',
  sizeBytes: 2048,
  status: status,
  checksum: 'checksum',
  filePath: filePath,
);

class _FakeRepository implements BackupRestoreRepository {
  List<BackupHistoryEntry> history = [];
  bool invalid = false;

  @override
  Future<BackupMetadata> createBackup({required String destination}) async =>
      _metadata();

  @override
  Future<BackupMetadata> validateBackupFile(String path) async {
    if (invalid) throw Exception('Invalid backup file');
    return _metadata();
  }

  @override
  Future<void> restoreBackup(String path) async {}

  @override
  Future<List<BackupHistoryEntry>> getHistory() async => history;

  @override
  Future<String> createSafetyBackup() async => 'safety.db';

  BackupMetadata _metadata() => BackupMetadata(
    backupId: 'backup-1',
    createdAt: DateTime(2026, 9, 20, 12),
    appVersion: 'Furnexa ERP',
    databaseVersion: 20,
    factoryName: 'مصنع Furnexa',
    factoryCode: 'F-001',
    recordCount: 12453,
    checksum: 'checksum',
    backupFormatVersion: 1,
    fileName: 'factory.furnexa',
    location: 'C:/Backups',
    database: const {},
  );
}

class _FakeSecurity extends SecurityLocalDataSource {
  _FakeSecurity({required this.admin});
  final bool admin;

  @override
  SecuritySession? get session => SecuritySession(
    user: SecurityUser(
      id: 'user-1',
      username: 'admin',
      displayName: 'Admin',
      roleId: 'role-1',
      active: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    role: SecurityRole(
      id: 'role-1',
      name: admin ? 'Admin' : 'Viewer',
      description: null,
      active: true,
      isSystemRole: admin,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    permissions: admin
        ? {'BACKUP_VIEW', 'BACKUP_CREATE', 'BACKUP_RESTORE'}
        : const {},
    scopes: const [],
  );
}
