import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';
import '../tool/demo_data_seeder.dart';

void main() {
  late SecurityLocalDataSource security;
  late DemoDataSeeder seeder;

  setUp(() async {
    await DatabaseTestHelper.reset();
    security = SecurityLocalDataSource();
    await security.login('admin', DatabaseTestHelper.adminPassword);
    seeder = DemoDataSeeder(security: security);
  });

  tearDown(() async {
    security.logout();
    await DatabaseTestHelper.reset();
  });

  test('demo seeding is relationally valid and idempotent', () async {
    final db = await FurnexaDatabase.instance.database;
    final administrator = (await db.query(
      'users',
      columns: ['passwordHash'],
      where: 'username = ?',
      whereArgs: ['admin'],
      limit: 1,
    )).single;

    final first = await seeder.seed();
    final tableNames = [
      'stock_balances',
      'stock_transactions',
      'inventory_valuations',
      'purchase_receipts',
      'sales_invoices',
      'sales_invoice_items',
      'sales_deliveries',
      'production_material_consumptions',
      'production_outputs',
      'customer_payments',
      'expenses',
      'journal_entries',
      'journal_lines',
    ];
    final firstCounts = {
      for (final table in tableNames)
        table: (await db.rawQuery(
          'SELECT COUNT(*) AS n FROM "$table"',
        )).single['n'],
    };

    await seeder.seed();

    final secondCounts = {
      for (final table in tableNames)
        table: (await db.rawQuery(
          'SELECT COUNT(*) AS n FROM "$table"',
        )).single['n'],
    };
    expect(secondCounts, firstCounts);
    expect(first.databasePath, await FurnexaDatabase.instance.databasePath);
    expect(first.counts['factories'], 1);
    expect(first.counts['sections'], greaterThanOrEqualTo(3));
    expect(first.counts['warehouses'], greaterThanOrEqualTo(4));
    expect(first.counts['products'], greaterThanOrEqualTo(3));
    expect(first.counts['customers'], greaterThanOrEqualTo(3));
    expect(first.counts['suppliers'], greaterThanOrEqualTo(2));

    final invoice = (await db.query(
      'sales_invoices',
      where: 'operationId = ?',
      whereArgs: ['DEMO-INVOICE-001'],
    )).single;
    expect(invoice['grandTotal'], 50000);
    final partialOrder = (await db.query(
      'sales_orders',
      where: 'id = ?',
      whereArgs: [DemoDataSeeder.salesOrderOneId],
    )).single;
    expect(partialOrder['status'], 'PARTIALLY_DELIVERED');
    final pendingDelivery = (await db.query(
      'sales_deliveries',
      where: 'operationId = ?',
      whereArgs: ['DEMO-DELIVERY-PENDING-002'],
    )).single;
    expect(pendingDelivery['status'], 'PENDING');
    expect(pendingDelivery['inventoryPosted'], 0);
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    expect(
      (await db.query(
        'users',
        columns: ['passwordHash'],
        where: 'username = ?',
        whereArgs: ['admin'],
        limit: 1,
      )).single['passwordHash'],
      administrator['passwordHash'],
    );
  });
}
