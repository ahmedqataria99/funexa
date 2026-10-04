import 'package:flutter_test/flutter_test.dart';
import 'package:furnexa/core/constants/app_constants.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/accounting/domain/production_costing_contract.dart';
import 'package:furnexa/features/hr/data/datasources/hr_local_data_source.dart';
import 'package:furnexa/features/hr/domain/entities/hr_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/datasources/warehouses_stock_local_data_source.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'test_helpers/database_test_helper.dart';

void main() {
  late AccountingLocalDataSource source;
  late Account cash;
  late Account bank;
  late Account revenue;

  setUp(() async {
    await DatabaseTestHelper.reset();
    await SecurityLocalDataSource().login('admin', 'Furnexa-Test-Admin-2026!');
    source = AccountingLocalDataSource();
    final db = await FurnexaDatabase.instance.database;
    await db.insert('factories', {
      'id': 'accounting-factory',
      'name': 'مصنع محاسبي',
      'code': 'ACCOUNTING-F',
      'createdAt': 1,
      'updatedAt': 1,
    });
    for (final warehouse in ['w', 'source', 'destination']) {
      await db.insert('warehouses', {
        'id': warehouse,
        'factoryId': 'accounting-factory',
        'name': warehouse,
        'code': 'ACCOUNTING-$warehouse',
        'state': 'active',
        'createdAt': 1,
        'updatedAt': 1,
      });
    }
    await db.insert('categories', {
      'id': 'accounting-category',
      'name': 'خامات',
      'code': 'ACCOUNTING-C',
      'active': 1,
      'createdAt': 1,
      'updatedAt': 1,
    });
    await db.insert('units', {
      'id': 'accounting-unit',
      'name': 'قطعة',
      'abbreviation': 'قط',
      'active': 1,
      'createdAt': 1,
      'updatedAt': 1,
    });
    await db.insert('raw_materials', {
      'id': 'accounting-item',
      'name': 'خامة',
      'code': 'ACCOUNTING-I',
      'categoryId': 'accounting-category',
      'unitId': 'accounting-unit',
      'active': 1,
      'createdAt': 1,
      'updatedAt': 1,
    });
    cash = (await source.accountByCode('1000'))!;
    bank = (await source.accountByCode('1010'))!;
    revenue = (await source.accountByCode('4000'))!;
  });

  tearDown(() async {
    SecurityLocalDataSource().logout();
    await DatabaseTestHelper.reset();
  });

  test(
    'migration creates accounting schema and default system accounts',
    () async {
      expect(
        await FurnexaDatabase.instance.getDatabaseVersion(),
        AppConstants.databaseVersion,
      );
      final tables = await (await FurnexaDatabase.instance.database).query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );
      expect(
        tables.map((row) => row['name']),
        containsAll([
          'accounts',
          'journal_entries',
          'journal_lines',
          'cashboxes',
          'bank_accounts',
          'accounting_periods',
          'inventory_valuations',
        ]),
      );
      expect(
        (await source.accounts()).where((account) => account.systemAccount),
        hasLength(12),
      );
    },
  );

  test('account creation persists configurable hierarchy', () async {
    final parent = await source.createAccount(
      code: '1300',
      name: 'أصول ثابتة',
      type: AccountType.asset,
    );
    final child = await source.createAccount(
      code: '1310',
      name: 'معدات',
      type: AccountType.asset,
      parentId: parent.id,
    );
    expect((await source.account(child.id))!.parentId, parent.id);
  });

  test('duplicate account code is rejected', () async {
    expect(
      () => source.createAccount(
        code: cash.code,
        name: 'مكرر',
        type: AccountType.asset,
      ),
      throwsException,
    );
  });

  test('missing account parent is rejected', () async {
    expect(
      () => source.createAccount(
        code: '1399',
        name: 'حساب',
        type: AccountType.asset,
        parentId: 'missing',
      ),
      throwsException,
    );
  });

  test('system accounts cannot be disabled', () async {
    expect(() => source.setAccountActive(cash.id, false), throwsException);
  });

  test('system accounts cannot be deleted', () async {
    expect(() => source.deleteAccount(cash.id), throwsException);
  });

  test(
    'cashbox links to an asset account and records opening balance',
    () async {
      final cashbox = await source.createCashbox(
        name: 'الخزينة الرئيسية',
        code: 'C-01',
        accountId: cash.id,
        openingBalance: 100,
      );
      expect(cashbox.accountId, cash.id);
      final ledger = await source.accountLedger(cash.id);
      expect(ledger, isNotEmpty);
    },
  );

  test('bank account links to an asset account', () async {
    final account = await source.createBankAccount(
      bankName: 'بنك مصر',
      accountName: 'الحساب الجاري',
      accountNumber: '001',
      accountId: bank.id,
    );
    expect(account.accountId, bank.id);
  });

  test('balanced journal entry posts atomically', () async {
    final id = await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'إيداع',
      lines: [
        JournalLineInput(accountId: cash.id, debit: 250),
        JournalLineInput(accountId: revenue.id, credit: 250),
      ],
    );
    expect(id, isNotEmpty);
    expect(
      (await source.trialBalance()).fold<double>(
        0,
        (sum, row) => sum + row.debit,
      ),
      250,
    );
  });

  test('unbalanced journal entry is rejected', () async {
    expect(
      () => source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'غير متوازن',
        lines: [
          JournalLineInput(accountId: cash.id, debit: 250),
          JournalLineInput(accountId: revenue.id, credit: 200),
        ],
      ),
      throwsException,
    );
  });

  test('account mutations require an authorized session', () async {
    final security = SecurityLocalDataSource();
    security.logout();
    await expectLater(
      source.createAccount(
        code: '1398',
        name: 'Unauthenticated',
        type: AccountType.asset,
      ),
      throwsException,
    );

    await security.login('admin', 'Furnexa-Test-Admin-2026!');
    final role = await security.createRole(name: 'Accounting Viewer');
    await security.setRolePermissions(role.id, ['ACCOUNTING_VIEW']);
    await security.createUser(
      username: 'accounting-viewer',
      displayName: 'Accounting Viewer',
      password: 'secret123',
      roleId: role.id,
    );
    security.logout();
    await security.login('accounting-viewer', 'secret123');
    await expectLater(
      source.createAccount(
        code: '1397',
        name: 'Unauthorized',
        type: AccountType.asset,
      ),
      throwsException,
    );
  });

  test('journal line cannot contain both debit and credit', () async {
    expect(
      () => source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'سطر خاطئ',
        lines: [
          JournalLineInput(accountId: cash.id, debit: 1, credit: 1),
          JournalLineInput(accountId: revenue.id, credit: 2),
        ],
      ),
      throwsException,
    );
  });

  test('journal line must have a positive amount', () async {
    expect(
      () => source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'سطر صفري',
        lines: [
          JournalLineInput(accountId: cash.id),
          JournalLineInput(accountId: revenue.id),
        ],
      ),
      throwsException,
    );
  });

  test('inactive accounts cannot be posted', () async {
    final account = await source.createAccount(
      code: '5999',
      name: 'مصروف مؤقت',
      type: AccountType.expense,
    );
    await source.setAccountActive(account.id, false);
    expect(
      () => source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'نشاط',
        lines: [
          JournalLineInput(accountId: cash.id, debit: 1),
          JournalLineInput(accountId: account.id, credit: 1),
        ],
      ),
      throwsException,
    );
  });

  test('draft journal can be posted once', () async {
    final id = await source.createDraftJournal(
      date: DateTime(2026, 9, 19),
      description: 'مسودة',
      lines: [
        JournalLineInput(accountId: cash.id, debit: 20),
        JournalLineInput(accountId: revenue.id, credit: 20),
      ],
    );
    await source.postDraftJournal(id);
    expect(() => source.postDraftJournal(id), throwsException);
  });

  test(
    'posted journal is immutable and reversal is a separate entry',
    () async {
      final id = await source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'قيد تاريخي',
        referenceType: 'TEST',
        referenceId: 'immutable',
        lines: [
          JournalLineInput(accountId: cash.id, debit: 20),
          JournalLineInput(accountId: revenue.id, credit: 20),
        ],
      );
      expect(
        () => source.postJournal(
          date: DateTime(2026, 9, 19),
          description: 'مكرر',
          referenceType: 'TEST',
          referenceId: 'immutable',
          lines: [
            JournalLineInput(accountId: cash.id, debit: 20),
            JournalLineInput(accountId: revenue.id, credit: 20),
          ],
        ),
        throwsException,
      );
      await source.reverseJournal(id);
      expect((await source.accountLedger(cash.id)).length, 2);
    },
  );

  test('accounting periods reject overlaps', () async {
    await source.createPeriod(
      name: 'سبتمبر',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
    );
    expect(
      () => source.createPeriod(
        name: 'متداخل',
        startDate: DateTime(2026, 9, 15),
        endDate: DateTime(2026, 10, 1),
      ),
      throwsException,
    );
  });

  test('closed period rejects posting', () async {
    final period = await source.createPeriod(
      name: 'أغسطس',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31),
    );
    await source.closePeriod(period.id);
    expect(
      () => source.postJournal(
        date: DateTime(2026, 8, 10),
        description: 'مغلق',
        lines: [
          JournalLineInput(accountId: cash.id, debit: 1),
          JournalLineInput(accountId: revenue.id, credit: 1),
        ],
      ),
      throwsException,
    );
  });

  test('posting outside configured periods is rejected', () async {
    await source.createPeriod(
      name: 'سبتمبر',
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
    );
    expect(
      () => source.postJournal(
        date: DateTime(2026, 10, 1),
        description: 'خارج الفترة',
        lines: [
          JournalLineInput(accountId: cash.id, debit: 1),
          JournalLineInput(accountId: revenue.id, credit: 1),
        ],
      ),
      throwsException,
    );
  });

  test('customer payment posts cash against receivables', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.insert('customers', {
      'id': 'customer-1',
      'name': 'عميل',
      'code': 'CUST-1',
      'active': 1,
      'createdAt': 1,
      'updatedAt': 1,
    });
    final cashbox = await source.createCashbox(
      name: 'خزينة',
      code: 'C-1',
      accountId: cash.id,
    );
    final id = await source.postCustomerPayment(
      customerId: 'customer-1',
      date: DateTime(2026, 9, 19),
      amount: 50,
      cashboxId: cashbox.id,
    );
    expect(id, isNotEmpty);
  });

  test('supplier payment posts payables against cash', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.insert('suppliers', {
      'id': 'supplier-1',
      'name': 'مورد',
      'code': 'SUP-1',
      'active': 1,
      'createdAt': 1,
      'updatedAt': 1,
    });
    final cashbox = await source.createCashbox(
      name: 'خزينة',
      code: 'C-1',
      accountId: cash.id,
    );
    expect(
      await source.postSupplierPayment(
        supplierId: 'supplier-1',
        date: DateTime(2026, 9, 19),
        amount: 50,
        cashboxId: cashbox.id,
      ),
      isNotEmpty,
    );
  });

  test(
    'payment operation retries do not duplicate accounting entries',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.insert('customers', {
        'id': 'customer-idempotent',
        'name': 'عميل التكرار',
        'code': 'CUST-IDEMPOTENT',
        'active': 1,
        'createdAt': 1,
        'updatedAt': 1,
      });
      final cashbox = await source.createCashbox(
        name: 'خزينة التكرار',
        code: 'C-IDEMPOTENT',
        accountId: cash.id,
      );
      final date = DateTime(2026, 9, 19);
      final first = await source.postCustomerPayment(
        customerId: 'customer-idempotent',
        date: date,
        amount: 25,
        cashboxId: cashbox.id,
        operationId: 'receipt-1',
      );
      final retry = await source.postCustomerPayment(
        customerId: 'customer-idempotent',
        date: date,
        amount: 25,
        cashboxId: cashbox.id,
        operationId: 'receipt-1',
      );
      expect(retry, first);
      expect(
        await db.query(
          'customer_payments',
          where: 'operationKey = ?',
          whereArgs: ['CALLER:receipt-1'],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceId = ?',
          whereArgs: [first],
        ),
        hasLength(1),
      );
      await expectLater(
        source.postCustomerPayment(
          customerId: 'customer-idempotent',
          date: date,
          amount: 30,
          cashboxId: cashbox.id,
          operationId: 'receipt-1',
        ),
        throwsException,
      );
      final other = await source.postCustomerPayment(
        customerId: 'customer-idempotent',
        date: date,
        amount: 25,
        cashboxId: cashbox.id,
        operationId: 'receipt-2',
      );
      expect(other, isNot(first));
    },
  );

  test('customer ledger is queryable', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.insert('customers', {
      'id': 'customer-1',
      'name': 'عميل',
      'code': 'CUST-1',
      'active': 1,
      'createdAt': 1,
      'updatedAt': 1,
    });
    final cashbox = await source.createCashbox(
      name: 'خزينة',
      code: 'C-1',
      accountId: cash.id,
    );
    await source.postCustomerPayment(
      customerId: 'customer-1',
      date: DateTime(2026, 9, 19),
      amount: 50,
      cashboxId: cashbox.id,
    );
    expect((await source.customerLedger('customer-1')).single.credit, 50);
  });

  test('supplier ledger is queryable', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.insert('suppliers', {
      'id': 'supplier-1',
      'name': 'مورد',
      'code': 'SUP-1',
      'active': 1,
      'createdAt': 1,
      'updatedAt': 1,
    });
    final cashbox = await source.createCashbox(
      name: 'خزينة',
      code: 'C-1',
      accountId: cash.id,
    );
    await source.postSupplierPayment(
      supplierId: 'supplier-1',
      date: DateTime(2026, 9, 19),
      amount: 50,
      cashboxId: cashbox.id,
    );
    expect((await source.supplierLedger('supplier-1')).single.debit, 50);
  });

  test('expense requires an expense account', () async {
    final cashbox = await source.createCashbox(
      name: 'خزينة',
      code: 'C-1',
      accountId: cash.id,
    );
    expect(
      () => source.postExpense(
        date: DateTime(2026, 9, 19),
        accountId: cash.id,
        amount: 10,
        description: 'خطأ',
        cashboxId: cashbox.id,
      ),
      throwsException,
    );
  });

  test('expense posting creates a balanced entry', () async {
    final expense = (await source.accountByCode('5900'))!;
    final cashbox = await source.createCashbox(
      name: 'خزينة',
      code: 'C-1',
      accountId: cash.id,
    );
    await source.postExpense(
      date: DateTime(2026, 9, 19),
      accountId: expense.id,
      amount: 10,
      description: 'نقل',
      cashboxId: cashbox.id,
    );
    expect((await source.accountLedger(expense.id)).single.debit, 10);
  });

  test('weighted average cost updates after receipts', () async {
    await source.receiveInventoryValue(
      warehouseId: 'w',
      itemId: 'i',
      itemType: 'RAW_MATERIAL',
      quantity: 100,
      unitCost: 100,
    );
    final value = await source.receiveInventoryValue(
      warehouseId: 'w',
      itemId: 'i',
      itemType: 'RAW_MATERIAL',
      quantity: 50,
      unitCost: 130,
    );
    expect(value.averageCost, closeTo(110, 0.0001));
  });

  test('inventory valuation decreases at current average cost', () async {
    await source.receiveInventoryValue(
      warehouseId: 'w',
      itemId: 'i',
      itemType: 'RAW_MATERIAL',
      quantity: 150,
      unitCost: 110,
    );
    final value = await source.consumeInventoryValue(
      warehouseId: 'w',
      itemId: 'i',
      itemType: 'RAW_MATERIAL',
      quantity: 50,
    );
    expect(value.quantity, 100);
    expect(value.totalValue, 11000);
  });

  test('inventory valuation rejects negative stock', () async {
    expect(
      () => source.consumeInventoryValue(
        warehouseId: 'w',
        itemId: 'i',
        itemType: 'RAW_MATERIAL',
        quantity: 1,
      ),
      throwsException,
    );
  });

  test('inventory transfer valuation can preserve total value', () async {
    await source.receiveInventoryValue(
      warehouseId: 'source',
      itemId: 'i',
      itemType: 'PRODUCT',
      quantity: 10,
      unitCost: 25,
    );
    final moved = await source.consumeInventoryValue(
      warehouseId: 'source',
      itemId: 'i',
      itemType: 'PRODUCT',
      quantity: 4,
    );
    final received = await source.receiveInventoryValue(
      warehouseId: 'destination',
      itemId: 'i',
      itemType: 'PRODUCT',
      quantity: 4,
      unitCost: moved.averageCost,
    );
    expect(received.totalValue, 100);
  });

  test(
    'positive stock adjustment can be represented by a balanced entry',
    () async {
      final adjustment = (await source.accountByCode('5910'))!;
      await source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'تسوية موجبة',
        lines: [
          JournalLineInput(
            accountId: (await source.accountByCode('1100'))!.id,
            debit: 20,
          ),
          JournalLineInput(accountId: adjustment.id, credit: 20),
        ],
      );
      expect((await source.accountLedger(adjustment.id)).single.credit, 20);
    },
  );

  test(
    'negative stock adjustment can be represented by a balanced entry',
    () async {
      final adjustment = (await source.accountByCode('5920'))!;
      await source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'تسوية سالبة',
        lines: [
          JournalLineInput(accountId: adjustment.id, debit: 20),
          JournalLineInput(
            accountId: (await source.accountByCode('1100'))!.id,
            credit: 20,
          ),
        ],
      );
      expect((await source.accountLedger(adjustment.id)).single.debit, 20);
    },
  );

  test('trial balance total debits equal credits', () async {
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'ميزان',
      lines: [
        JournalLineInput(accountId: cash.id, debit: 40),
        JournalLineInput(accountId: revenue.id, credit: 40),
      ],
    );
    final rows = await source.trialBalance();
    expect(
      rows.fold<double>(0, (sum, row) => sum + row.debit),
      rows.fold<double>(0, (sum, row) => sum + row.credit),
    );
  });

  test('trial balance filters drafts and dates but nets reversals', () async {
    final draft = await source.createDraftJournal(
      date: DateTime(2026, 9, 19),
      description: 'Draft excluded',
      lines: [
        JournalLineInput(accountId: cash.id, debit: 90),
        JournalLineInput(accountId: revenue.id, credit: 90),
      ],
    );
    expect(
      (await source.trialBalance()).fold<double>(
        0,
        (sum, row) => sum + row.debit,
      ),
      0,
    );
    await source.postDraftJournal(draft);
    expect(
      (await source.trialBalance(
        from: DateTime(2026, 9, 20),
      )).fold<double>(0, (sum, row) => sum + row.debit),
      0,
    );
    await source.reverseJournal(draft);
    final cashLine = (await source.trialBalance()).singleWhere(
      (row) => row.accountId == cash.id,
    );
    expect(cashLine.debit, 90);
    expect(cashLine.credit, 90);
  });

  test('income statement calculates revenue and expenses', () async {
    final expense = (await source.accountByCode('5900'))!;
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'دخل',
      lines: [
        JournalLineInput(accountId: cash.id, debit: 100),
        JournalLineInput(accountId: revenue.id, credit: 100),
      ],
    );
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'مصروف',
      lines: [
        JournalLineInput(accountId: expense.id, debit: 30),
        JournalLineInput(accountId: cash.id, credit: 30),
      ],
    );
    final statement = await source.incomeStatement();
    expect(statement.netIncome, 70);
  });

  test('balance sheet equation includes current net income', () async {
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'ميزانية',
      lines: [
        JournalLineInput(accountId: cash.id, debit: 100),
        JournalLineInput(accountId: revenue.id, credit: 100),
      ],
    );
    final statement = await source.balanceSheet();
    expect(
      statement.assets,
      closeTo(statement.liabilities + statement.equity, 0.0001),
    );
  });

  test('purchase receipt reference is idempotent', () async {
    final inventory = (await source.accountByCode('1100'))!;
    final payable = (await source.accountByCode('2000'))!;
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'شراء',
      referenceType: 'PURCHASE_RECEIPT',
      referenceId: 'GR-1',
      lines: [
        JournalLineInput(accountId: inventory.id, debit: 100),
        JournalLineInput(accountId: payable.id, credit: 100),
      ],
    );
    expect(
      () => source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'شراء مكرر',
        referenceType: 'PURCHASE_RECEIPT',
        referenceId: 'GR-1',
        lines: [
          JournalLineInput(accountId: inventory.id, debit: 100),
          JournalLineInput(accountId: payable.id, credit: 100),
        ],
      ),
      throwsException,
    );
  });

  test('sales revenue and COGS are separate balanced entries', () async {
    final inventory = (await source.accountByCode('1100'))!;
    final cogs = (await source.accountByCode('5000'))!;
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'إيراد بيع',
      referenceType: 'SALES_REVENUE',
      referenceId: 'DL-1',
      lines: [
        JournalLineInput(
          accountId: (await source.accountByCode('1200'))!.id,
          debit: 100,
        ),
        JournalLineInput(accountId: revenue.id, credit: 100),
      ],
    );
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'تكلفة بيع',
      referenceType: 'SALES_COGS',
      referenceId: 'DL-1',
      lines: [
        JournalLineInput(accountId: cogs.id, debit: 40),
        JournalLineInput(accountId: inventory.id, credit: 40),
      ],
    );
    expect((await source.accountLedger(cogs.id)).single.debit, 40);
  });

  test('payroll snapshot can post salary expense', () async {
    final salary = (await source.accountByCode('5100'))!;
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'رواتب سبتمبر',
      referenceType: 'PAYROLL',
      referenceId: 'PAY-1',
      lines: [
        JournalLineInput(accountId: salary.id, debit: 500),
        JournalLineInput(
          accountId: (await source.accountByCode('2000'))!.id,
          credit: 500,
        ),
      ],
    );
    expect((await source.accountLedger(salary.id)).single.debit, 500);
  });

  test('atomic failure leaves no journal header', () async {
    expect(
      () => source.postJournal(
        date: DateTime(2026, 9, 19),
        description: 'فشل ذري',
        referenceType: 'ATOMIC',
        referenceId: '1',
        lines: [
          JournalLineInput(accountId: cash.id, debit: 5),
          JournalLineInput(accountId: 'missing', credit: 5),
        ],
      ),
      throwsException,
    );
    final db = await FurnexaDatabase.instance.database;
    expect(
      await db.query(
        'journal_entries',
        where: 'referenceType = ?',
        whereArgs: ['ATOMIC'],
      ),
      isEmpty,
    );
  });

  test('cashbox current balance is derived from its account ledger', () async {
    final cashbox = await source.createCashbox(
      name: 'خزينة',
      code: 'C-1',
      accountId: cash.id,
      openingBalance: 50,
    );
    expect((await source.accountLedger(cashbox.accountId)).single.debit, 50);
  });

  test('bank statement uses linked accounting account', () async {
    final account = await source.createBankAccount(
      bankName: 'بنك',
      accountName: 'حساب',
      accountNumber: '1',
      accountId: bank.id,
      openingBalance: 75,
    );
    expect((await source.accountLedger(account.accountId)).single.debit, 75);
  });

  test('historical posted entries remain readable after reversal', () async {
    final id = await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'تاريخي',
      lines: [
        JournalLineInput(accountId: cash.id, debit: 10),
        JournalLineInput(accountId: revenue.id, credit: 10),
      ],
    );
    await source.reverseJournal(id);
    expect((await source.accountLedger(cash.id)).length, 2);
  });

  test('account ledger exposes running balances', () async {
    await source.postJournal(
      date: DateTime(2026, 9, 19),
      description: 'حركة',
      lines: [
        JournalLineInput(accountId: cash.id, debit: 10),
        JournalLineInput(accountId: revenue.id, credit: 10),
      ],
    );
    expect((await source.accountLedger(cash.id)).single.balance, 10);
  });

  test(
    'approved payroll creates salary accounting from snapshot and cannot duplicate',
    () async {
      final db = await FurnexaDatabase.instance.database;
      await db.insert('workers', {
        'id': 'worker-accounting',
        'employeeCode': 'ACC-W-1',
        'name': 'عامل',
        'hireDate': 1,
        'basicSalary': 700,
        'salaryType': 'MONTHLY',
        'active': 1,
        'createdAt': 1,
        'updatedAt': 1,
      });
      await db.insert('payroll_periods', {
        'id': 'period-accounting',
        'name': 'فترة محاسبية',
        'startDate': 1,
        'endDate': 4102444800000,
        'status': 'CALCULATED',
        'createdAt': 1,
        'updatedAt': 1,
      });
      await db.insert('payroll_records', {
        'id': 'payroll-accounting',
        'payrollPeriodId': 'period-accounting',
        'workerId': 'worker-accounting',
        'basicSalary': 700,
        'regularEarnings': 700,
        'overtimeHours': 0,
        'overtimeAmount': 50,
        'deductionsAmount': 20,
        'grossSalary': 750,
        'netSalary': 730,
        'notes': 'snapshot',
        'status': 'CALCULATED',
        'createdAt': 1,
        'updatedAt': 1,
      });
      final hr = HrLocalDataSource();
      final approved = await hr.approvePayroll('payroll-accounting');
      expect(approved.status, PayrollRecordStatus.approved);
      expect(
        (await source.accountLedger(
          (await source.accountByCode('5100'))!.id,
        )).single.debit,
        750,
      );
      await hr.approvePayroll('payroll-accounting');
      final approvalEntries = await db.query(
        'journal_entries',
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: ['PAYROLL_APPROVAL', 'payroll-accounting'],
      );
      expect(approvalEntries, hasLength(1));
    },
  );

  test('paid payroll creates payable to cash movement', () async {
    final db = await FurnexaDatabase.instance.database;
    await db.insert('workers', {
      'id': 'worker-payment',
      'employeeCode': 'ACC-W-2',
      'name': 'عامل',
      'hireDate': 1,
      'basicSalary': 500,
      'salaryType': 'MONTHLY',
      'active': 1,
      'createdAt': 1,
      'updatedAt': 1,
    });
    await db.insert('payroll_periods', {
      'id': 'period-payment',
      'name': 'فترة صرف',
      'startDate': 1,
      'endDate': 4102444800000,
      'status': 'APPROVED',
      'createdAt': 1,
      'updatedAt': 1,
    });
    await db.insert('payroll_records', {
      'id': 'payroll-payment',
      'payrollPeriodId': 'period-payment',
      'workerId': 'worker-payment',
      'basicSalary': 500,
      'regularEarnings': 500,
      'overtimeHours': 0,
      'overtimeAmount': 0,
      'deductionsAmount': 0,
      'grossSalary': 500,
      'netSalary': 500,
      'notes': 'snapshot',
      'status': 'APPROVED',
      'createdAt': 1,
      'updatedAt': 1,
    });
    final cashbox = await source.createCashbox(
      name: 'رواتب',
      code: 'PAY-CASH',
      accountId: cash.id,
    );
    final paid = await HrLocalDataSource().payPayroll(
      payrollRecordId: 'payroll-payment',
      cashboxId: cashbox.id,
    );
    expect(paid.status, PayrollRecordStatus.paid);
    expect(
      (await source.accountLedger(
        (await source.accountByCode('2010'))!.id,
      )).single.debit,
      500,
    );
  });

  test(
    'positive and negative stock adjustments post balanced, traceable journals',
    () async {
      final stock = WarehousesStockLocalDataSource();
      final item = const StockItemOption(
        id: 'accounting-item',
        name: 'خامة',
        code: 'ACCOUNTING-I',
        unitId: 'accounting-unit',
        type: StockItemType.rawMaterial,
        active: true,
      );
      await source.receiveInventoryValue(
        warehouseId: 'source',
        itemId: item.id,
        itemType: item.type.value,
        quantity: 20,
        unitCost: 10,
      );
      await dbSeedStock(stock, item, 'source', 20);
      await stock.adjust(
        warehouseId: 'source',
        item: item,
        difference: 2,
        date: DateTime(2026, 9, 19),
        reason: 'ADJ-POS',
      );
      await stock.adjust(
        warehouseId: 'source',
        item: item,
        difference: -1,
        date: DateTime(2026, 9, 19),
        reason: 'ADJ-NEG',
      );
      final db = await FurnexaDatabase.instance.database;
      final entries = await db.query(
        'journal_entries',
        where: 'referenceType = ?',
        whereArgs: ['STOCK_ADJUSTMENT'],
      );
      expect(entries, hasLength(2));
      expect(
        (await source.trialBalance()).fold<double>(
          0,
          (sum, row) => sum + row.debit,
        ),
        (await source.trialBalance()).fold<double>(
          0,
          (sum, row) => sum + row.credit,
        ),
      );
    },
  );

  test(
    'warehouse transfer preserves valuation without revenue or COGS',
    () async {
      final stock = WarehousesStockLocalDataSource();
      final item = const StockItemOption(
        id: 'accounting-item',
        name: 'خامة',
        code: 'ACCOUNTING-I',
        unitId: 'accounting-unit',
        type: StockItemType.rawMaterial,
        active: true,
      );
      await source.receiveInventoryValue(
        warehouseId: 'source',
        itemId: item.id,
        itemType: item.type.value,
        quantity: 10,
        unitCost: 100,
      );
      await dbSeedStock(stock, item, 'source', 10);
      await stock.transfer(
        sourceWarehouseId: 'source',
        destinationWarehouseId: 'destination',
        item: item,
        quantity: 4,
        date: DateTime(2026, 9, 19),
        reference: 'TRANSFER-ACCOUNTING',
      );
      expect(
        (await source.valuation(
          'source',
          item.id,
          item.type.value,
        ))!.totalValue,
        600,
      );
      expect(
        (await source.valuation(
          'destination',
          item.id,
          item.type.value,
        ))!.totalValue,
        400,
      );
      final db = await FurnexaDatabase.instance.database;
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType = ?',
          whereArgs: ['STOCK_TRANSFER'],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'journal_entries',
          where: 'referenceType IN (?, ?)',
          whereArgs: ['SALES_REVENUE', 'SALES_COGS'],
        ),
        isEmpty,
      );
    },
  );

  test(
    'production costing accounting contract is available without costing implementation',
    () {
      expect(source, isA<ProductionCostingAccountingSink>());
    },
  );
}

Future<void> dbSeedStock(
  WarehousesStockLocalDataSource stock,
  StockItemOption item,
  String warehouseId,
  double quantity,
) async {
  final db = await FurnexaDatabase.instance.database;
  await db.insert('stock_balances', {
    'id': 'seed-$warehouseId',
    'warehouseId': warehouseId,
    'itemId': item.id,
    'itemType': item.type.value,
    'quantity': quantity,
    'createdAt': 1,
    'updatedAt': 1,
  });
}
