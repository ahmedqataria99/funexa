import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'package:furnexa/features/users_roles_permissions/presentation/pages/login_page.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late SecurityLocalDataSource security;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.ensureInitialAdmin();
  });

  tearDown(() async {
    security.logout();
    await DatabaseTestHelper.reset();
  });

  Future<void> loginAdmin() =>
      security.login('admin', 'Furnexa-Test-Admin-2026!');

  test('fresh install requires secure one-time administrator setup', () async {
    await DatabaseTestHelper.reset(createInitialAdmin: false);
    security = SecurityLocalDataSource();
    expect(await security.initialAdminSetupRequired(), isTrue);
    await expectLater(security.login('admin', 'admin'), throwsException);
    await expectLater(
      security.setupInitialAdmin(
        username: 'admin',
        displayName: 'System Admin',
        password: 'Furnexa-Setup-Secret-2026!',
      ),
      completes,
    );
    expect(await security.initialAdminSetupRequired(), isFalse);
    expect(
      (await security.login(
        'admin',
        'Furnexa-Setup-Secret-2026!',
      )).isSystemAdmin,
      isTrue,
    );
    security.logout();
    await expectLater(
      security.setupInitialAdmin(
        username: 'another-admin',
        displayName: 'Second Admin',
        password: 'Furnexa-Setup-Secret-2026!',
      ),
      throwsException,
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'short setup password explains minimum length in ${locale.languageCode}',
      (tester) async {
        await DatabaseTestHelper.reset(createInitialAdmin: false);
        security = SecurityLocalDataSource();
        await _pumpLoginPage(tester, security, locale, setupRequired: true);
        await _submitSetup(tester, locale, 'short', 'short');

        expect(
          find.text(AppLocalizations(locale).initialAdminPasswordTooShort),
          findsOneWidget,
        );
        expect(await security.initialAdminSetupRequired(), isTrue);
      },
    );

    testWidgets(
      'setup password mismatch is explained in ${locale.languageCode}',
      (tester) async {
        await DatabaseTestHelper.reset(createInitialAdmin: false);
        security = SecurityLocalDataSource();
        await _pumpLoginPage(tester, security, locale, setupRequired: true);
        await _submitSetup(
          tester,
          locale,
          'long-enough-password',
          'different-password',
        );

        expect(
          find.text(AppLocalizations(locale).passwordMismatch),
          findsOneWidget,
        );
        expect(await security.initialAdminSetupRequired(), isTrue);
      },
    );

    testWidgets(
      'normal login failure remains generic in ${locale.languageCode}',
      (tester) async {
        await _pumpLoginPage(tester, security, locale, setupRequired: false);
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'admin');
        await tester.enterText(fields.at(1), 'wrong-password');
        await tester.tap(find.text(AppLocalizations(locale).login));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizations(locale).invalidCredentials),
          findsOneWidget,
        );
      },
    );
  }

  test(
    'configured administrator password is not stored in plaintext',
    () async {
      final db = await FurnexaDatabase.instance.database;
      final row = (await db.query(
        'users',
        where: 'username = ?',
        whereArgs: ['admin'],
      )).single;
      expect(row['passwordHash'], isNot(DatabaseTestHelper.adminPassword));
      expect(
        (row['passwordHash'] as String).startsWith('pbkdf2-sha256\$'),
        isTrue,
      );
    },
  );

  test('legacy password hashes migrate after successful login', () async {
    await loginAdmin();
    final user = await security.createUser(
      username: 'legacy-user',
      displayName: 'Legacy User',
      password: 'legacy-secret',
      roleId: 'role-system-admin',
    );
    final salt = List<int>.generate(16, (index) => index + 1);
    final legacyHash =
        '${base64UrlEncode(salt)}:${sha256.convert([...salt, ...utf8.encode('legacy-secret')])}';
    final db = await FurnexaDatabase.instance.database;
    await db.update(
      'users',
      {'passwordHash': legacyHash},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    security.logout();

    await security.login('legacy-user', 'legacy-secret');
    final migrated =
        (await db.query(
              'users',
              columns: ['passwordHash'],
              where: 'id = ?',
              whereArgs: [user.id],
              limit: 1,
            )).single['passwordHash']
            as String;
    expect(migrated.startsWith('pbkdf2-sha256\$'), isTrue);
    security.logout();
    await expectLater(security.login('legacy-user', 'wrong'), throwsException);
  });

  test('admin can log in initially and invalid login is generic', () async {
    final session = await security.login('admin', 'Furnexa-Test-Admin-2026!');
    expect(session.isSystemAdmin, isTrue);
    security.logout();
    expect(() => security.login('admin', 'wrong'), throwsException);
  });

  test('inactive user cannot login', () async {
    await loginAdmin();
    final user = await security.createUser(
      username: 'inactive',
      displayName: 'Inactive',
      password: 'secret',
      roleId: 'role-system-admin',
    );
    await security.setUserActive(user.id, false);
    security.logout();
    expect(() => security.login('inactive', 'secret'), throwsException);
  });

  test('changing username and password invalidates old credentials', () async {
    await loginAdmin();
    final user = await security.createUser(
      username: 'operator',
      displayName: 'Operator',
      password: 'old-secret',
      roleId: 'role-system-admin',
    );
    await security.changeCredentials(
      userId: user.id,
      username: 'operator-new',
      password: 'new-secret',
    );
    security.logout();
    expect(() => security.login('operator', 'old-secret'), throwsException);
    expect(
      (await security.login('operator-new', 'new-secret')).user.username,
      'operator-new',
    );
  });

  test(
    'runtime session is not restored by a new service instance and logout clears it',
    () async {
      await loginAdmin();
      expect(security.session, isNotNull);
      security.logout();
      expect(security.session, isNull);
      expect(SecurityLocalDataSource().session, isNull);
    },
  );

  test('user creation rejects duplicate usernames', () async {
    await loginAdmin();
    await security.createUser(
      username: 'duplicate',
      displayName: 'One',
      password: 'secret',
      roleId: 'role-system-admin',
    );
    expect(
      () => security.createUser(
        username: 'duplicate',
        displayName: 'Two',
        password: 'secret',
        roleId: 'role-system-admin',
      ),
      throwsException,
    );
  });

  test(
    'custom role permissions are assigned and reflected after relogin',
    () async {
      await loginAdmin();
      final role = await security.createRole(name: 'Warehouse Operator');
      await security.setRolePermissions(role.id, ['WAREHOUSE_STOCK_VIEW']);
      final user = await security.createUser(
        username: 'warehouse',
        displayName: 'Warehouse',
        password: 'secret',
        roleId: role.id,
      );
      security.logout();
      final session = await security.login('warehouse', 'secret');
      expect(session.can('WAREHOUSE_STOCK_VIEW'), isTrue);
      expect(session.can('ACCOUNTING_POST'), isFalse);
      expect(user.username, 'warehouse');
    },
  );

  test(
    'users cannot grant themselves role permissions or broader scopes',
    () async {
      await loginAdmin();
      final role = await security.createRole(name: 'Self Manager');
      await security.setRolePermissions(role.id, ['USERS_EDIT', 'ROLES_EDIT']);
      final user = await security.createUser(
        username: 'self-manager',
        displayName: 'Self Manager',
        password: 'secret123',
        roleId: role.id,
      );
      security.logout();
      await security.login(user.username, 'secret123');

      await expectLater(
        security.setRolePermissions(role.id, ['USERS_EDIT', 'ACCOUNTING_POST']),
        throwsException,
      );
      await expectLater(
        security.setUserScopes(user.id, [
          UserScope(
            id: 'new-scope',
            userId: user.id,
            type: ScopeType.warehouse,
            scopeId: 'warehouse-a',
          ),
        ]),
        throwsException,
      );
      await expectLater(
        security.updateUser(userId: user.id, roleId: 'role-system-admin'),
        throwsException,
      );
    },
  );

  test('deactivating the current user revokes its cached session', () async {
    await loginAdmin();
    final role = await security.createRole(name: 'Self Deactivator');
    await security.setRolePermissions(role.id, ['USERS_EDIT']);
    final user = await security.createUser(
      username: 'self-deactivator',
      displayName: 'Self Deactivator',
      password: 'secret123',
      roleId: role.id,
    );
    security.logout();
    await security.login(user.username, 'secret123');

    await security.setUserActive(user.id, false);

    expect(security.session, isNull);
    expect(() => security.require('USERS_EDIT'), throwsException);
  });

  test(
    'permission denial and allow are enforced by business authorization service',
    () async {
      await loginAdmin();
      final role = await security.createRole(name: 'Accountant');
      await security.setRolePermissions(role.id, ['ACCOUNTING_POST']);
      final user = await security.createUser(
        username: 'accountant',
        displayName: 'Accountant',
        password: 'secret',
        roleId: role.id,
      );
      security.logout();
      await security.login('accountant', 'secret');
      security.require('ACCOUNTING_POST');
      expect(() => security.require('ACCOUNTING_REVERSE'), throwsException);
      expect(user.username, 'accountant');
    },
  );

  test('business data sources deny unauthorized accounting actions', () async {
    await loginAdmin();
    final role = await security.createRole(name: 'Viewer');
    await security.setRolePermissions(role.id, ['ACCOUNTING_VIEW']);
    await security.createUser(
      username: 'viewer',
      displayName: 'Viewer',
      password: 'secret',
      roleId: role.id,
    );
    security.logout();
    await security.login('viewer', 'secret');
    expect(() => security.require('ACCOUNTING_POST'), throwsException);
    expect(() => security.require('WAREHOUSE_STOCK_EDIT'), throwsException);
  });

  test(
    'scope assignment restricts warehouse access and admin is unrestricted',
    () async {
      await loginAdmin();
      final role = await security.createRole(name: 'Scoped Warehouse');
      await security.setRolePermissions(role.id, ['WAREHOUSE_STOCK_EDIT']);
      final user = await security.createUser(
        username: 'scoped',
        displayName: 'Scoped',
        password: 'secret',
        roleId: role.id,
      );
      await security.setUserScopes(user.id, [
        UserScope(
          id: 'ignored',
          userId: user.id,
          type: ScopeType.warehouse,
          scopeId: 'warehouse-a',
        ),
      ]);
      security.logout();
      await security.login('scoped', 'secret');
      security.requireScope(ScopeType.warehouse, 'warehouse-a');
      expect(
        () => security.requireScope(ScopeType.warehouse, 'warehouse-b'),
        throwsException,
      );
      security.logout();
      await loginAdmin();
      security.requireScope(ScopeType.warehouse, 'warehouse-b');
    },
  );

  test('last active system admin cannot be deactivated', () async {
    await loginAdmin();
    final admin =
        (await (await FurnexaDatabase.instance.database).query(
              'users',
              where: 'username = ?',
              whereArgs: ['admin'],
            )).single['id']
            as String;
    expect(() => security.setUserActive(admin, false), throwsException);
  });

  test(
    'login and user changes create audit records without passwords',
    () async {
      await loginAdmin();
      await security.createUser(
        username: 'audited',
        displayName: 'Audited',
        password: 'secret-password',
        roleId: 'role-system-admin',
      );
      final logs = await security.auditLogs();
      expect(logs.any((log) => log.action == 'LOGIN_SUCCESS'), isTrue);
      expect(logs.any((log) => log.action == 'CREATE'), isTrue);
      final db = await FurnexaDatabase.instance.database;
      final raw = await db.rawQuery('SELECT * FROM audit_logs');
      expect(raw.join(' '), isNot(contains('secret-password')));
    },
  );

  test('audit records cannot be updated or deleted', () async {
    await loginAdmin();
    await security.createUser(
      username: 'immutable',
      displayName: 'Immutable',
      password: 'secret',
      roleId: 'role-system-admin',
    );
    final db = await FurnexaDatabase.instance.database;
    final log = (await db.query('audit_logs')).first;
    expect(
      () => db.update(
        'audit_logs',
        {'description': 'changed'},
        where: 'id = ?',
        whereArgs: [log['id']],
      ),
      throwsException,
    );
    expect(
      () => db.delete('audit_logs', where: 'id = ?', whereArgs: [log['id']]),
      throwsException,
    );
  });

  test(
    'scope type supports workshop and production stage dimensions',
    () async {
      await loginAdmin();
      final user = await security.createUser(
        username: 'scoped-all',
        displayName: 'Scoped All',
        password: 'secret',
        roleId: 'role-system-admin',
      );
      await security.setUserScopes(user.id, [
        UserScope(
          id: '1',
          userId: user.id,
          type: ScopeType.workshop,
          scopeId: 'workshop-1',
        ),
        UserScope(
          id: '2',
          userId: user.id,
          type: ScopeType.productionStage,
          scopeId: 'stage-1',
        ),
      ]);
      final db = await FurnexaDatabase.instance.database;
      expect(
        await db.query(
          'user_scopes',
          where: 'userId = ?',
          whereArgs: [user.id],
        ),
        hasLength(2),
      );
    },
  );
}

Future<void> _pumpLoginPage(
  WidgetTester tester,
  SecurityLocalDataSource security,
  Locale locale, {
  required bool setupRequired,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginPage(
        security: security,
        onLoggedIn: () {},
        setupRequired: setupRequired,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitSetup(
  WidgetTester tester,
  Locale locale,
  String password,
  String confirmation,
) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Ahmed');
  await tester.enterText(fields.at(1), confirmation);
  await tester.enterText(fields.at(2), password);
  await tester.tap(find.text(AppLocalizations(locale).setupAdmin));
  await tester.pumpAndSettle();
}
