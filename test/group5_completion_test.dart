import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/import_export/data/datasources/import_export_local_data_source.dart';
import 'package:furnexa/features/global_search/data/datasources/global_search_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late SecurityLocalDataSource security;
  late AccountingLocalDataSource accounting;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    accounting = AccountingLocalDataSource();
    await security.login('admin', DatabaseTestHelper.adminPassword);
  });

  tearDown(() async {
    security.logout();
    await DatabaseTestHelper.reset();
  });

  test(
    'H-01 accounting mutation fails after persisted permission removal',
    () async {
      final role = await security.createRole(name: 'Group 5 Accounting');
      await security.setRolePermissions(role.id, ['ACCOUNTING_POST']);
      final user = await security.createUser(
        username: 'group5-accounting',
        displayName: 'Group 5 Accounting',
        password: 'group5-secret',
        roleId: role.id,
      );
      security.logout();
      await security.login(user.username, 'group5-secret');

      final db = await FurnexaDatabase.instance.database;
      await db.delete(
        'role_permissions',
        where: 'roleId = ?',
        whereArgs: [role.id],
      );

      await expectLater(
        accounting.createAccount(
          code: 'G5-100',
          name: 'Stale Permission',
          type: AccountType.asset,
        ),
        throwsException,
      );
    },
  );

  test(
    'H-02 deactivation invalidates an active session before mutation',
    () async {
      final role = await security.createRole(name: 'Group 5 Deactivation');
      await security.setRolePermissions(role.id, ['ACCOUNTING_POST']);
      final user = await security.createUser(
        username: 'group5-deactivated',
        displayName: 'Group 5 Deactivated',
        password: 'group5-secret',
        roleId: role.id,
      );
      security.logout();
      await security.login(user.username, 'group5-secret');

      final db = await FurnexaDatabase.instance.database;
      await db.update(
        'users',
        {'active': 0},
        where: 'id = ?',
        whereArgs: [user.id],
      );

      await expectLater(
        accounting.createAccount(
          code: 'G5-101',
          name: 'Deactivated Session',
          type: AccountType.asset,
        ),
        throwsException,
      );
      expect(security.session, isNull);
    },
  );

  test('H-04 unsupported and audit imports are rejected', () async {
    final imports = ImportExportLocalDataSource(security: security);
    for (final table in [
      'audit_logs',
      'users',
      'journal_entries',
      'stock_balances',
    ]) {
      await expectLater(
        imports.importData(
          jsonEncode({
            'module': 'products',
            'records': [
              {
                'table': table,
                'rows': [
                  {'id': 'forbidden'},
                ],
              },
            ],
          }),
        ),
        throwsException,
      );
    }
  });

  test(
    'H-02/H-03 persisted scope reduction removes stale search access',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.insert('factories', {
        'id': 'group5-factory',
        'name': 'Group 5 Factory',
        'code': 'GROUP5-F',
        'createdAt': 1,
        'updatedAt': 1,
      });
      await db.insert('warehouses', {
        'id': 'group5-warehouse',
        'factoryId': 'group5-factory',
        'name': 'Group 5 Warehouse',
        'code': 'GROUP5-W',
        'state': 'active',
        'createdAt': 1,
        'updatedAt': 1,
      });
      final role = await security.createRole(name: 'Group 5 Search');
      await security.setRolePermissions(role.id, ['WAREHOUSE_STOCK_VIEW']);
      final user = await security.createUser(
        username: 'group5-search',
        displayName: 'Group 5 Search',
        password: 'group5-secret',
        roleId: role.id,
      );
      await security.setUserScopes(user.id, [
        UserScope(
          id: 'group5-scope',
          userId: user.id,
          type: ScopeType.warehouse,
          scopeId: 'group5-warehouse',
        ),
      ]);
      security.logout();
      await security.login(user.username, 'group5-secret');
      await db.delete('user_scopes', where: 'userId = ?', whereArgs: [user.id]);

      final results = await GlobalSearchLocalDataSource(
        security: security,
      ).search('Group 5 Warehouse');
      expect(results, isEmpty);
    },
  );

  test(
    'H-07 first-run setup replaces predictable administrator credentials',
    () async {
      await DatabaseTestHelper.reset(createInitialAdmin: false);
      security = SecurityLocalDataSource();
      expect(await security.initialAdminSetupRequired(), isTrue);
      await expectLater(security.login('admin', 'admin'), throwsException);
      await security.setupInitialAdmin(
        username: 'first-admin',
        displayName: 'First Admin',
        password: 'Group5-Initial-Secret!',
      );
      expect(await security.initialAdminSetupRequired(), isFalse);
      expect(
        (await security.login(
          'first-admin',
          'Group5-Initial-Secret!',
        )).isSystemAdmin,
        isTrue,
      );
      security.logout();
      await expectLater(
        security.setupInitialAdmin(
          username: 'second-admin',
          displayName: 'Second Admin',
          password: 'Group5-Second-Secret!',
        ),
        throwsException,
      );
    },
  );
}
