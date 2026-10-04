import 'dart:math' as math;
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/accounting/domain/production_costing_contract.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class AccountingLocalDataSource implements ProductionCostingAccountingSink {
  static int _sequence = 0;

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<List<Account>> accounts({bool activeOnly = false}) async {
    final rows = await (await _db).query(
      'accounts',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'code ASC',
    );
    return rows.map(_account).toList();
  }

  Future<Map<String, int>> moduleCounts() async {
    final db = await _db;
    final tables = <String>[
      'cashboxes',
      'bank_accounts',
      'journal_entries',
      'customer_payments',
      'supplier_payments',
      'expenses',
      'inventory_valuations',
    ];
    final counts = <String, int>{};
    for (final table in tables) {
      final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
      counts[table] = (rows.single['count'] as num).toInt();
    }
    return counts;
  }

  Future<Account> createAccount({
    required String code,
    required String name,
    required AccountType type,
    String? parentId,
    String? description,
    bool systemAccount = false,
  }) async {
    final security = SecurityLocalDataSource();
    await security.requireFresh('ACCOUNTING_POST');
    final db = await _db;
    final now = DateTime.now();
    final id = _id('account');
    await _validateParent(db, parentId, id);
    if (code.trim().isEmpty || name.trim().isEmpty) {
      throw Exception('كود الحساب واسم الحساب مطلوبان');
    }
    await db.transaction((txn) async {
      await txn.insert('accounts', {
        'id': id,
        'code': code.trim(),
        'name': name.trim(),
        'type': _accountTypeValue(type),
        'parentId': parentId,
        'description': description,
        'systemAccount': systemAccount ? 1 : 0,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await _auditWithinTransaction(
        txn,
        security,
        action: 'CREATE',
        entityType: 'Account',
        entityId: id,
        description: 'Accounting account created: ${code.trim()}',
      );
    });
    return (await account(id))!;
  }

  Future<Account?> account(String id) async {
    final rows = await (await _db).query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _account(rows.first);
  }

  Future<Account?> accountByCode(String code) async {
    final rows = await (await _db).query(
      'accounts',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    return rows.isEmpty ? null : _account(rows.first);
  }

  Future<void> setAccountActive(String id, bool active) async {
    final security = SecurityLocalDataSource();
    await security.requireFresh('ACCOUNTING_POST');
    final db = await _db;
    await db.transaction((txn) async {
      final row = await _requireAccount(txn, id);
      if (!active && row['systemAccount'] == 1) {
        throw Exception('لا يمكن تعطيل حساب نظامي');
      }
      await txn.update(
        'accounts',
        {
          'active': active ? 1 : 0,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _auditWithinTransaction(
        txn,
        security,
        action: active ? 'ACTIVATE' : 'DEACTIVATE',
        entityType: 'Account',
        entityId: id,
        description: 'Accounting account status changed',
      );
    });
  }

  Future<void> deleteAccount(String id) async {
    final security = SecurityLocalDataSource();
    await security.requireFresh('ACCOUNTING_POST');
    final db = await _db;
    await db.transaction((txn) async {
      final row = await _requireAccount(txn, id);
      if (row['systemAccount'] == 1) throw Exception('لا يمكن حذف حساب نظامي');
      if ((await txn.query(
        'journal_lines',
        where: 'accountId = ?',
        whereArgs: [id],
      )).isNotEmpty) {
        throw Exception('لا يمكن حذف حساب له قيود تاريخية');
      }
      await txn.delete('accounts', where: 'id = ?', whereArgs: [id]);
      await _auditWithinTransaction(
        txn,
        security,
        action: 'DELETE',
        entityType: 'Account',
        entityId: id,
        description: 'Accounting account deleted',
      );
    });
  }

  Future<AccountingPeriod> createPeriod({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await SecurityLocalDataSource().requireFresh('ACCOUNTING_CLOSE_PERIOD');
    if (endDate.isBefore(startDate))
      throw Exception('نهاية الفترة قبل بدايتها');
    final security = SecurityLocalDataSource();
    await security.requireFresh('ACCOUNTING_CLOSE_PERIOD');
    final db = await _db;
    final now = DateTime.now();
    final id = _id('period');
    await db.transaction((txn) async {
      final overlap = await txn.query(
        'accounting_periods',
        where: 'startDate <= ? AND endDate >= ?',
        whereArgs: [
          endDate.millisecondsSinceEpoch,
          startDate.millisecondsSinceEpoch,
        ],
        limit: 1,
      );
      if (overlap.isNotEmpty)
        throw Exception('الفترة المحاسبية تتداخل مع فترة أخرى');
      await txn.insert('accounting_periods', {
        'id': id,
        'name': name.trim(),
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
        'status': 'OPEN',
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });
      await _auditWithinTransaction(
        txn,
        security,
        action: 'CREATE',
        entityType: 'AccountingPeriod',
        entityId: id,
        description: 'Accounting period created: ${name.trim()}',
      );
    });
    return (await periods()).firstWhere((value) => value.id == id);
  }

  Future<List<AccountingPeriod>> periods() async => (await (await _db).query(
    'accounting_periods',
    orderBy: 'startDate DESC',
  )).map(_period).toList();

  Future<void> closePeriod(String id) async {
    final security = SecurityLocalDataSource();
    await security.requireFresh('ACCOUNTING_CLOSE_PERIOD');
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'accounting_periods',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw Exception('الفترة المحاسبية غير موجودة');
      await txn.update(
        'accounting_periods',
        {
          'status': 'CLOSED',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _auditWithinTransaction(
        txn,
        security,
        action: 'CLOSE',
        entityType: 'AccountingPeriod',
        entityId: id,
        description: 'Accounting period closed',
      );
    });
  }

  Future<String> postJournal({
    required DateTime date,
    required String description,
    required List<JournalLineInput> lines,
    String? referenceType,
    String? referenceId,
    String? partyType,
    String? partyId,
  }) async {
    await SecurityLocalDataSource().requireFresh('ACCOUNTING_POST');
    final db = await _db;
    return db.transaction(
      (txn) => postJournalWithinTransaction(
        executor: txn,
        date: date,
        description: description,
        lines: lines,
        referenceType: referenceType,
        referenceId: referenceId,
        partyType: partyType,
        partyId: partyId,
      ),
    );
  }

  Future<String> postJournalWithinTransaction({
    required DatabaseExecutor executor,
    required DateTime date,
    required String description,
    required List<JournalLineInput> lines,
    String? referenceType,
    String? referenceId,
    String? partyType,
    String? partyId,
  }) async {
    SecurityLocalDataSource().require('ACCOUNTING_POST');
    await _validatePostingDate(executor, date);
    await _validateLines(executor, lines);
    if (referenceType != null && referenceId != null) {
      final existing = await executor.query(
        'journal_entries',
        columns: ['id'],
        where: 'referenceType = ? AND referenceId = ?',
        whereArgs: [referenceType, referenceId],
        limit: 1,
      );
      if (existing.isNotEmpty)
        throw Exception('تم ترحيل العملية المحاسبية مسبقاً');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final entryId = _id('journal');
    await executor.insert('journal_entries', {
      'id': entryId,
      'entryNumber': _number('JE'),
      'date': date.millisecondsSinceEpoch,
      'description': description,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'status': 'POSTED',
      'createdAt': now,
      'updatedAt': now,
    });
    for (final line in lines) {
      await executor.insert('journal_lines', {
        'id': _id('journal-line'),
        'journalEntryId': entryId,
        'accountId': line.accountId,
        'debit': line.debit,
        'credit': line.credit,
        'description': line.description,
      });
    }
    if (partyType != null && partyId != null) {
      await executor.insert('journal_parties', {
        'journalEntryId': entryId,
        'partyType': partyType,
        'partyId': partyId,
      });
    }
    await _auditWithinTransaction(
      executor,
      SecurityLocalDataSource(),
      action: 'POST',
      entityType: 'JournalEntry',
      entityId: entryId,
      description: 'Accounting journal posted: ${referenceType ?? 'MANUAL'}',
    );
    return entryId;
  }

  Future<String> createDraftJournal({
    required DateTime date,
    required String description,
    required List<JournalLineInput> lines,
    String? referenceType,
    String? referenceId,
  }) async {
    await SecurityLocalDataSource().requireFresh('ACCOUNTING_POST');
    final db = await _db;
    await _validateLines(db, lines);
    await _validatePostingDate(db, date);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _id('journal');
    await db.transaction((txn) async {
      await txn.insert('journal_entries', {
        'id': id,
        'entryNumber': _number('JE'),
        'date': date.millisecondsSinceEpoch,
        'description': description,
        'referenceType': referenceType,
        'referenceId': referenceId,
        'status': 'DRAFT',
        'createdAt': now,
        'updatedAt': now,
      });
      for (final line in lines) {
        await txn.insert('journal_lines', {
          'id': _id('journal-line'),
          'journalEntryId': id,
          'accountId': line.accountId,
          'debit': line.debit,
          'credit': line.credit,
          'description': line.description,
        });
      }
      await _auditWithinTransaction(
        txn,
        SecurityLocalDataSource(),
        action: 'CREATE',
        entityType: 'JournalEntry',
        entityId: id,
        description: 'Accounting journal draft created',
      );
    });
    return id;
  }

  Future<void> postDraftJournal(String id) async {
    await SecurityLocalDataSource().requireFresh('ACCOUNTING_POST');
    final db = await _db;
    await db.transaction((txn) async {
      final entries = await txn.query(
        'journal_entries',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (entries.isEmpty) throw Exception('القيد غير موجود');
      if (entries.first['status'] != 'DRAFT')
        throw Exception('القيد المرحل غير قابل للتعديل');
      final lines = await txn.query(
        'journal_lines',
        where: 'journalEntryId = ?',
        whereArgs: [id],
      );
      final inputs = lines
          .map(
            (row) => JournalLineInput(
              accountId: row['accountId'] as String,
              debit: (row['debit'] as num).toDouble(),
              credit: (row['credit'] as num).toDouble(),
              description: row['description'] as String?,
            ),
          )
          .toList();
      await _validateLines(txn, inputs);
      await _validatePostingDate(
        txn,
        DateTime.fromMillisecondsSinceEpoch(entries.first['date'] as int),
      );
      await txn.update(
        'journal_entries',
        {
          'status': 'POSTED',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _auditWithinTransaction(
        txn,
        SecurityLocalDataSource(),
        action: 'POST',
        entityType: 'JournalEntry',
        entityId: id,
        description: 'Accounting journal draft posted',
      );
    });
  }

  Future<void> reverseJournal(String id, {DateTime? date}) async {
    await SecurityLocalDataSource().requireFresh('ACCOUNTING_REVERSE');
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'journal_entries',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['status'] != 'POSTED')
        throw Exception('لا يمكن عكس هذا القيد');
      final lines = await txn.query(
        'journal_lines',
        where: 'journalEntryId = ?',
        whereArgs: [id],
      );
      final reverse = lines
          .map(
            (row) => JournalLineInput(
              accountId: row['accountId'] as String,
              debit: (row['credit'] as num).toDouble(),
              credit: (row['debit'] as num).toDouble(),
              description: 'عكس القيد ${rows.first['entryNumber']}',
            ),
          )
          .toList();
      await postJournalWithinTransaction(
        executor: txn,
        date: date ?? DateTime.now(),
        description: 'عكس القيد ${rows.first['entryNumber']}',
        lines: reverse,
        referenceType: 'REVERSAL',
        referenceId: id,
      );
      await txn.update(
        'journal_entries',
        {'status': 'REVERSED'},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _auditWithinTransaction(
        txn,
        SecurityLocalDataSource(),
        action: 'REVERSE',
        entityType: 'JournalEntry',
        entityId: id,
        description: 'Accounting journal reversed',
      );
    });
  }

  Future<Cashbox> createCashbox({
    required String name,
    required String code,
    required String accountId,
    double openingBalance = 0,
    String? notes,
  }) async {
    final security = SecurityLocalDataSource();
    await security.requireFresh('ACCOUNTING_POST');
    if (openingBalance < 0) throw Exception('الرصيد الافتتاحي غير صالح');
    final db = await _db;
    await _validateAccount(db, accountId, expectedType: AccountType.asset);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _id('cashbox');
    await db.transaction((txn) async {
      await txn.insert('cashboxes', {
        'id': id,
        'name': name,
        'code': code,
        'accountId': accountId,
        'openingBalance': openingBalance,
        'active': 1,
        'notes': notes,
        'createdAt': now,
        'updatedAt': now,
      });
      if (openingBalance > 0) {
        await postJournalWithinTransaction(
          executor: txn,
          date: DateTime.now(),
          description: 'الرصيد الافتتاحي للخزينة $name',
          referenceType: 'CASHBOX_OPENING',
          referenceId: id,
          lines: [
            JournalLineInput(accountId: accountId, debit: openingBalance),
            JournalLineInput(accountId: 'system-3000', credit: openingBalance),
          ],
        );
      }
      await _auditWithinTransaction(
        txn,
        security,
        action: 'CREATE',
        entityType: 'Cashbox',
        entityId: id,
        description: 'Accounting cashbox created: $code',
      );
    });
    return _cashbox(
      (await db.query('cashboxes', where: 'id = ?', whereArgs: [id])).single,
    );
  }

  Future<BankAccount> createBankAccount({
    required String bankName,
    required String accountName,
    required String accountNumber,
    required String accountId,
    double openingBalance = 0,
    String? notes,
  }) async {
    final security = SecurityLocalDataSource();
    await security.requireFresh('ACCOUNTING_POST');
    final db = await _db;
    await _validateAccount(db, accountId, expectedType: AccountType.asset);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _id('bank');
    await db.transaction((txn) async {
      await txn.insert('bank_accounts', {
        'id': id,
        'bankName': bankName,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'accountId': accountId,
        'openingBalance': openingBalance,
        'active': 1,
        'notes': notes,
        'createdAt': now,
        'updatedAt': now,
      });
      if (openingBalance > 0) {
        await postJournalWithinTransaction(
          executor: txn,
          date: DateTime.now(),
          description: 'الرصيد الافتتاحي للبنك $accountName',
          referenceType: 'BANK_OPENING',
          referenceId: id,
          lines: [
            JournalLineInput(accountId: accountId, debit: openingBalance),
            JournalLineInput(accountId: 'system-3000', credit: openingBalance),
          ],
        );
      }
      await _auditWithinTransaction(
        txn,
        security,
        action: 'CREATE',
        entityType: 'BankAccount',
        entityId: id,
        description: 'Accounting bank account created: $accountNumber',
      );
    });
    return _bank(
      (await db.query(
        'bank_accounts',
        where: 'id = ?',
        whereArgs: [id],
      )).single,
    );
  }

  Future<String> postCustomerPayment({
    required String customerId,
    required DateTime date,
    required double amount,
    String? cashboxId,
    String? bankAccountId,
    String? reference,
    String? notes,
    String? operationId,
  }) async => _postPayment(
    table: 'customer_payments',
    partyTable: 'customers',
    partyId: customerId,
    date: date,
    amount: amount,
    cashboxId: cashboxId,
    bankAccountId: bankAccountId,
    reference: reference,
    notes: notes,
    operationId: operationId,
    debitCode: null,
    creditCode: '1200',
  );

  Future<String> postSupplierPayment({
    required String supplierId,
    required DateTime date,
    required double amount,
    String? cashboxId,
    String? bankAccountId,
    String? reference,
    String? notes,
    String? operationId,
  }) async => _postPayment(
    table: 'supplier_payments',
    partyTable: 'suppliers',
    partyId: supplierId,
    date: date,
    amount: amount,
    cashboxId: cashboxId,
    bankAccountId: bankAccountId,
    reference: reference,
    notes: notes,
    operationId: operationId,
    debitCode: '2000',
    creditCode: null,
  );

  Future<String> postExpense({
    required DateTime date,
    required String accountId,
    required double amount,
    required String description,
    String? cashboxId,
    String? bankAccountId,
    String? reference,
  }) async {
    await SecurityLocalDataSource().requireFresh('ACCOUNTING_POST');
    if (amount <= 0) throw Exception('قيمة المصروف يجب أن تكون أكبر من صفر');
    final db = await _db;
    await _validateAccount(db, accountId, expectedType: AccountType.expense);
    final moneyAccount = await _moneyAccount(db, cashboxId, bankAccountId);
    final id = _id('expense');
    final number = _number('EXP');
    await db.transaction((txn) async {
      await txn.insert('expenses', {
        'id': id,
        'expenseNumber': number,
        'date': date.millisecondsSinceEpoch,
        'accountId': accountId,
        'amount': amount,
        'cashboxId': cashboxId,
        'bankAccountId': bankAccountId,
        'description': description,
        'reference': reference,
        'status': 'POSTED',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await postJournalWithinTransaction(
        executor: txn,
        date: date,
        description: description,
        referenceType: 'EXPENSE',
        referenceId: id,
        lines: [
          JournalLineInput(accountId: accountId, debit: amount),
          JournalLineInput(accountId: moneyAccount, credit: amount),
        ],
      );
      await _auditWithinTransaction(
        txn,
        SecurityLocalDataSource(),
        action: 'POST',
        entityType: 'Expense',
        entityId: id,
        description: 'Accounting expense posted: $number',
      );
    });
    return id;
  }

  Future<List<LedgerLine>> accountLedger(
    String accountId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final where = <String>[
      'jl.accountId = ?',
      "je.status IN ('POSTED', 'REVERSED')",
    ];
    final args = <Object?>[accountId];
    if (from != null) {
      where.add('je.date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('je.date <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.rawQuery('''
      SELECT je.date, je.entryNumber, je.description, jl.debit, jl.credit
      FROM journal_lines jl JOIN journal_entries je ON je.id = jl.journalEntryId
      WHERE ${where.join(' AND ')} ORDER BY je.date ASC, je.entryNumber ASC
    ''', args);
    var balance = 0.0;
    return rows.map((row) {
      final debit = (row['debit'] as num).toDouble();
      final credit = (row['credit'] as num).toDouble();
      balance += debit - credit;
      return LedgerLine(
        date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
        reference: row['entryNumber'] as String,
        description: row['description'] as String,
        debit: debit,
        credit: credit,
        balance: balance,
      );
    }).toList();
  }

  Future<List<LedgerLine>> customerLedger(String customerId) =>
      _partyLedger('CUSTOMER', customerId);
  Future<List<LedgerLine>> supplierLedger(String supplierId) =>
      _partyLedger('SUPPLIER', supplierId);

  Future<List<TrialBalanceLine>> trialBalance({
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final conditions = <String>["je.status IN ('POSTED', 'REVERSED')"];
    final args = <Object?>[];
    if (from != null) {
      conditions.add('je.date >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      conditions.add('je.date <= ?');
      args.add(to.millisecondsSinceEpoch);
    }
    final rows = await db.rawQuery('''
      SELECT a.id accountId, a.name accountName,
             COALESCE(totals.debit, 0) debit,
             COALESCE(totals.credit, 0) credit
      FROM accounts a
      LEFT JOIN (
        SELECT jl.accountId, SUM(jl.debit) debit, SUM(jl.credit) credit
        FROM journal_lines jl
        JOIN journal_entries je ON je.id = jl.journalEntryId
        WHERE ${conditions.join(' AND ')}
        GROUP BY jl.accountId
      ) totals ON totals.accountId = a.id
      ORDER BY a.code
    ''', args);
    return rows
        .map(
          (row) => TrialBalanceLine(
            accountId: row['accountId'] as String,
            accountName: row['accountName'] as String,
            debit: (row['debit'] as num).toDouble(),
            credit: (row['credit'] as num).toDouble(),
          ),
        )
        .where((row) => row.debit != 0 || row.credit != 0)
        .toList();
  }

  Future<FinancialStatement> incomeStatement({
    DateTime? from,
    DateTime? to,
  }) async {
    final totals = await _typeTotals(from: from, to: to);
    final revenue = totals[AccountType.revenue]?['all'] ?? 0.0;
    final cogs = totals[AccountType.expense]?['cogs'] ?? 0.0;
    final expenses = (totals[AccountType.expense]?['all'] ?? 0.0) - cogs;
    return FinancialStatement(
      revenue: revenue,
      cogs: cogs,
      expenses: expenses,
      netIncome: revenue - cogs - expenses,
    );
  }

  Future<BalanceSheet> balanceSheet({DateTime? to}) async {
    final rows = await trialBalance(to: to);
    var assets = 0.0, liabilities = 0.0, equity = 0.0;
    for (final row in rows) {
      final entryAccount = await account(row.accountId);
      if (entryAccount == null) continue;
      final balance = row.debit - row.credit;
      switch (entryAccount.type) {
        case AccountType.asset:
          assets += balance;
        case AccountType.liability:
          liabilities -= balance;
        case AccountType.equity:
          equity -= balance;
        default:
          break;
      }
    }
    final income = await incomeStatement(to: to);
    return BalanceSheet(
      assets: assets,
      liabilities: liabilities,
      equity: equity + income.netIncome,
    );
  }

  Future<InventoryValuation?> valuation(
    String warehouseId,
    String itemId,
    String itemType,
  ) async {
    final rows = await (await _db).query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType],
      limit: 1,
    );
    return rows.isEmpty ? null : _valuation(rows.first);
  }

  Future<InventoryValuation?> valuationWithinTransaction(
    DatabaseExecutor executor,
    String warehouseId,
    String itemId,
    String itemType,
  ) async {
    final rows = await executor.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType],
      limit: 1,
    );
    return rows.isEmpty ? null : _valuation(rows.first);
  }

  Future<InventoryValuation> receiveInventoryValue({
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double quantity,
    required double unitCost,
  }) async {
    final db = await _db;
    return db.transaction(
      (txn) => receiveInventoryValueWithinTransaction(
        executor: txn,
        warehouseId: warehouseId,
        itemId: itemId,
        itemType: itemType,
        quantity: quantity,
        unitCost: unitCost,
      ),
    );
  }

  Future<InventoryValuation> receiveInventoryValueWithinTransaction({
    required DatabaseExecutor executor,
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double quantity,
    required double unitCost,
  }) => _changeValuation(
    executor,
    warehouseId,
    itemId,
    itemType,
    quantity,
    unitCost,
    true,
  );

  Future<InventoryValuation> consumeInventoryValue({
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double quantity,
  }) async {
    final current = await valuation(warehouseId, itemId, itemType);
    if (current == null || current.quantity < quantity)
      throw Exception('المخزون غير كاف للتقييم');
    final db = await _db;
    return db.transaction(
      (txn) => _changeValuation(
        txn,
        warehouseId,
        itemId,
        itemType,
        quantity,
        current.averageCost,
        false,
      ),
    );
  }

  Future<String> _postPayment({
    required String table,
    required String partyTable,
    required String partyId,
    required DateTime date,
    required double amount,
    required String? cashboxId,
    required String? bankAccountId,
    required String? reference,
    required String? notes,
    String? operationId,
    required String? debitCode,
    required String? creditCode,
  }) async {
    await SecurityLocalDataSource().requireFresh('ACCOUNTING_POST');
    if (amount <= 0) throw Exception('قيمة الدفعة يجب أن تكون أكبر من صفر');
    if ((cashboxId == null) == (bankAccountId == null))
      throw Exception('اختر خزينة أو حساباً بنكياً واحداً');
    final db = await _db;
    if ((await db.query(
      partyTable,
      columns: ['id'],
      where: 'id = ? AND active = 1',
      whereArgs: [partyId],
    )).isEmpty)
      throw Exception('الطرف غير موجود أو غير نشط');
    final moneyAccount = await _moneyAccount(db, cashboxId, bankAccountId);
    final partyAccount = (await accountByCode(debitCode ?? creditCode!))!;
    var id = _id(table == 'customer_payments' ? 'receipt' : 'payment');
    if (operationId != null && operationId.trim().isEmpty) {
      throw Exception('معرف عملية الدفع غير صالح');
    }
    final operationKey = operationId == null
        ? 'AUTO-${sha256.convert(utf8.encode([table, partyId, date.millisecondsSinceEpoch, amount.toStringAsPrecision(15), cashboxId ?? '', bankAccountId ?? '', reference ?? '', notes ?? ''].join('|')))}'
        : 'CALLER:${operationId.trim()}';
    await db.transaction((txn) async {
      final existing = await txn.query(
        table,
        where: 'operationKey = ?',
        whereArgs: [operationKey],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final row = existing.single;
        final existingParty =
            row[table == 'customer_payments' ? 'customerId' : 'supplierId'];
        if (existingParty != partyId ||
            row['date'] != date.millisecondsSinceEpoch ||
            (row['amount'] as num).toDouble() != amount ||
            row['cashboxId'] != cashboxId ||
            row['bankAccountId'] != bankAccountId ||
            row['reference'] != reference ||
            row['notes'] != notes) {
          throw Exception('معرف عملية الدفع مستخدم لبيانات مختلفة');
        }
        id = row['id'] as String;
        return;
      }
      final payment = <String, Object?>{
        'id': id,
        'operationKey': operationKey,
        'date': date.millisecondsSinceEpoch,
        'amount': amount,
        'cashboxId': cashboxId,
        'bankAccountId': bankAccountId,
        'reference': reference,
        'notes': notes,
        'status': 'POSTED',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };
      payment[table == 'customer_payments' ? 'customerId' : 'supplierId'] =
          partyId;
      await txn.insert(table, payment);
      final lines = debitCode != null
          ? [
              JournalLineInput(accountId: partyAccount.id, debit: amount),
              JournalLineInput(accountId: moneyAccount, credit: amount),
            ]
          : [
              JournalLineInput(accountId: moneyAccount, debit: amount),
              JournalLineInput(accountId: partyAccount.id, credit: amount),
            ];
      await postJournalWithinTransaction(
        executor: txn,
        date: date,
        description: reference ?? 'دفعة محاسبية',
        referenceType: table,
        referenceId: id,
        partyType: table == 'customer_payments' ? 'CUSTOMER' : 'SUPPLIER',
        partyId: partyId,
        lines: lines,
      );
      await _auditWithinTransaction(
        txn,
        SecurityLocalDataSource(),
        action: 'POST',
        entityType: table == 'customer_payments'
            ? 'CustomerPayment'
            : 'SupplierPayment',
        entityId: id,
        description: 'Accounting payment posted',
      );
    });
    return id;
  }

  Future<List<LedgerLine>> _partyLedger(String type, String id) async {
    final db = await _db;
    final accountCode = type == 'CUSTOMER' ? '1200' : '2000';
    final rows = await db.rawQuery(
      '''
      SELECT je.date, je.entryNumber, je.description, jl.debit, jl.credit
      FROM journal_parties jp
      JOIN journal_entries je ON je.id = jp.journalEntryId
      JOIN journal_lines jl ON jl.journalEntryId = je.id
      JOIN accounts a ON a.id = jl.accountId
      WHERE jp.partyType = ? AND jp.partyId = ?
        AND je.status IN ('POSTED', 'REVERSED') AND a.code = ?
      ORDER BY je.date ASC, je.entryNumber ASC
    ''',
      [type, id, accountCode],
    );
    var balance = 0.0;
    return rows.map((row) {
      final debit = (row['debit'] as num).toDouble();
      final credit = (row['credit'] as num).toDouble();
      balance += debit - credit;
      return LedgerLine(
        date: DateTime.fromMillisecondsSinceEpoch(row['date'] as int),
        reference: row['entryNumber'] as String,
        description: row['description'] as String,
        debit: debit,
        credit: credit,
        balance: balance,
      );
    }).toList();
  }

  Future<Map<AccountType, Map<String, double>>> _typeTotals({
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await trialBalance(from: from, to: to);
    final result = <AccountType, Map<String, double>>{};
    for (final row in rows) {
      final entryAccount = await account(row.accountId);
      if (entryAccount == null) continue;
      final value = entryAccount.type == AccountType.revenue
          ? row.credit - row.debit
          : row.debit - row.credit;
      final bucket = result.putIfAbsent(entryAccount.type, () => {});
      bucket['all'] = (bucket['all'] ?? 0) + value;
      if (entryAccount.code == '5000') bucket['cogs'] = value;
    }
    return result;
  }

  Future<InventoryValuation> consumeInventoryValueWithinTransaction({
    required DatabaseExecutor executor,
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double quantity,
  }) async {
    final rows = await executor.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('لا يوجد تقييم للمخزون');
    final current = _valuation(rows.first);
    return _changeValuation(
      executor,
      warehouseId,
      itemId,
      itemType,
      quantity,
      current.averageCost,
      false,
    );
  }

  Future<InventoryValuation> adjustInventoryValueWithinTransaction({
    required DatabaseExecutor executor,
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double difference,
  }) async {
    final rows = await executor.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('لا يوجد تقييم حالي للصنف');
    final current = _valuation(rows.first);
    if (difference > 0) {
      return _changeValuation(
        executor,
        warehouseId,
        itemId,
        itemType,
        difference,
        current.averageCost,
        true,
      );
    }
    return _changeValuation(
      executor,
      warehouseId,
      itemId,
      itemType,
      difference.abs(),
      current.averageCost,
      false,
    );
  }

  Future<String> postInventoryAdjustmentWithinTransaction({
    required DatabaseExecutor executor,
    required String referenceId,
    required DateTime date,
    required double value,
  }) async {
    if (value == 0) throw Exception('قيمة التسوية غير صالحة');
    final inventory =
        (await executor.query(
              'accounts',
              columns: ['id'],
              where: 'code = ? AND active = 1',
              whereArgs: ['1100'],
              limit: 1,
            )).single['id']
            as String;
    final adjustment =
        (await executor.query(
              'accounts',
              columns: ['id'],
              where: 'code = ? AND active = 1',
              whereArgs: [value > 0 ? '5910' : '5920'],
              limit: 1,
            )).single['id']
            as String;
    return postJournalWithinTransaction(
      executor: executor,
      date: date,
      description: 'تسوية مخزون $referenceId',
      referenceType: 'STOCK_ADJUSTMENT',
      referenceId: referenceId,
      lines: value > 0
          ? [
              JournalLineInput(accountId: inventory, debit: value),
              JournalLineInput(accountId: adjustment, credit: value),
            ]
          : [
              JournalLineInput(accountId: adjustment, debit: value.abs()),
              JournalLineInput(accountId: inventory, credit: value.abs()),
            ],
    );
  }

  Future<String> postInventoryTransferWithinTransaction({
    required DatabaseExecutor executor,
    required String referenceId,
    required DateTime date,
    required double value,
  }) async {
    if (value <= 0) throw Exception('قيمة التحويل غير صالحة');
    final inventory =
        (await executor.query(
              'accounts',
              columns: ['id'],
              where: 'code = ? AND active = 1',
              whereArgs: ['1100'],
              limit: 1,
            )).single['id']
            as String;
    return postJournalWithinTransaction(
      executor: executor,
      date: date,
      description: 'تحويل مخزون $referenceId',
      referenceType: 'STOCK_TRANSFER',
      referenceId: referenceId,
      lines: [
        JournalLineInput(accountId: inventory, debit: value),
        JournalLineInput(accountId: inventory, credit: value),
      ],
    );
  }

  @override
  Future<String> receiveProductionCostWithinTransaction({
    required DatabaseExecutor executor,
    required ProductionCostResult result,
  }) async {
    if (result.quantity <= 0 || result.totalCost <= 0) {
      throw Exception('نتيجة تكلفة الإنتاج غير صالحة');
    }
    final inventory =
        (await executor.query(
              'accounts',
              columns: ['id'],
              where: 'code = ? AND active = 1',
              whereArgs: ['1100'],
              limit: 1,
            )).single['id']
            as String;
    final production =
        (await executor.query(
              'accounts',
              columns: ['id'],
              where: 'code = ? AND active = 1',
              whereArgs: ['5900'],
              limit: 1,
            )).single['id']
            as String;
    await receiveInventoryValueWithinTransaction(
      executor: executor,
      warehouseId: result.warehouseId,
      itemId: result.itemId,
      itemType: result.itemType,
      quantity: result.quantity,
      unitCost: result.totalCost / result.quantity,
    );
    return postJournalWithinTransaction(
      executor: executor,
      date: DateTime.now(),
      description: 'تكلفة إنتاج ${result.referenceId}',
      referenceType: 'PRODUCTION_COST',
      referenceId: result.referenceId,
      lines: [
        JournalLineInput(accountId: inventory, debit: result.totalCost),
        JournalLineInput(accountId: production, credit: result.totalCost),
      ],
    );
  }

  Future<InventoryValuation> _changeValuation(
    DatabaseExecutor executor,
    String warehouseId,
    String itemId,
    String itemType,
    double quantity,
    double unitCost,
    bool receive,
  ) async {
    if (quantity <= 0 || unitCost < 0)
      throw Exception('قيمة المخزون غير صالحة');
    final rows = await executor.query(
      'inventory_valuations',
      where: 'warehouseId = ? AND itemId = ? AND itemType = ?',
      whereArgs: [warehouseId, itemId, itemType],
      limit: 1,
    );
    final oldQuantity = rows.isEmpty
        ? 0.0
        : (rows.first['quantity'] as num).toDouble();
    final oldCost = rows.isEmpty
        ? 0.0
        : (rows.first['averageCost'] as num).toDouble();
    final newQuantity = receive
        ? oldQuantity + quantity
        : oldQuantity - quantity;
    if (newQuantity < -0.000001)
      throw Exception('لا يمكن أن يصبح تقييم المخزون سالباً');
    final newCost = receive && newQuantity > 0
        ? ((oldQuantity * oldCost) + (quantity * unitCost)) / newQuantity
        : oldCost;
    final values = {
      'quantity': math.max(0, newQuantity),
      'averageCost': newCost,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (rows.isEmpty)
      await executor.insert('inventory_valuations', {
        'id': _id('valuation'),
        'warehouseId': warehouseId,
        'itemId': itemId,
        'itemType': itemType,
        ...values,
      });
    else
      await executor.update(
        'inventory_valuations',
        values,
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    return InventoryValuation(
      warehouseId: warehouseId,
      itemId: itemId,
      itemType: itemType,
      quantity: math.max(0, newQuantity),
      averageCost: newCost,
    );
  }

  Future<Map<String, Object?>> _requireAccount(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الحساب غير موجود');
    return rows.first;
  }

  Future<void> _validateAccount(
    DatabaseExecutor db,
    String id, {
    AccountType? expectedType,
  }) async {
    final row = await _requireAccount(db, id);
    if (row['active'] != 1) throw Exception('الحساب غير نشط');
    if (expectedType != null && row['type'] != _accountTypeValue(expectedType))
      throw Exception('نوع الحساب غير صالح');
  }

  Future<void> _validateParent(
    DatabaseExecutor db,
    String? parentId,
    String childId,
  ) async {
    if (parentId == null) return;
    await _requireAccount(db, parentId);
    String? current = parentId;
    while (current != null) {
      if (current == childId) throw Exception('لا يمكن إنشاء علاقة دائرية');
      final rows = await db.query(
        'accounts',
        columns: ['parentId'],
        where: 'id = ?',
        whereArgs: [current],
        limit: 1,
      );
      current = rows.isEmpty ? null : rows.first['parentId'] as String?;
    }
  }

  Future<void> _validatePostingDate(DatabaseExecutor db, DateTime date) async {
    final rows = await db.query(
      'accounting_periods',
      where: 'startDate <= ? AND endDate >= ?',
      whereArgs: [date.millisecondsSinceEpoch, date.millisecondsSinceEpoch],
      limit: 1,
    );
    if (rows.isNotEmpty && rows.first['status'] == 'CLOSED')
      throw Exception('الفترة المحاسبية مغلقة');
    if (rows.isEmpty) {
      final countRows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM accounting_periods',
      );
      final count = (countRows.first['count'] as num?)?.toInt() ?? 0;
      if (count > 0)
        throw Exception('لا توجد فترة محاسبية مفتوحة لهذا التاريخ');
    }
  }

  Future<void> _validateLines(
    DatabaseExecutor db,
    List<JournalLineInput> lines,
  ) async {
    if (lines.length < 2)
      throw Exception('القيد يجب أن يحتوي على سطرين على الأقل');
    var debit = 0.0, credit = 0.0;
    for (final line in lines) {
      if ((line.debit > 0) == (line.credit > 0) ||
          line.debit < 0 ||
          line.credit < 0)
        throw Exception('سطر القيد غير صالح');
      await _validateAccount(db, line.accountId);
      debit += line.debit;
      credit += line.credit;
    }
    if ((debit - credit).abs() > 0.000001) throw Exception('القيد غير متوازن');
  }

  Future<String> _moneyAccount(
    DatabaseExecutor db,
    String? cashboxId,
    String? bankAccountId,
  ) async {
    if ((cashboxId == null) == (bankAccountId == null))
      throw Exception('اختر خزينة أو حساباً بنكياً واحداً');
    final table = cashboxId != null ? 'cashboxes' : 'bank_accounts';
    final id = cashboxId ?? bankAccountId!;
    final rows = await db.query(
      table,
      columns: ['accountId'],
      where: 'id = ? AND active = 1',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty)
      throw Exception('الخزينة أو الحساب البنكي غير موجود أو غير نشط');
    return rows.first['accountId'] as String;
  }

  Future<void> _auditWithinTransaction(
    DatabaseExecutor executor,
    SecurityLocalDataSource security, {
    required String action,
    required String entityType,
    required String entityId,
    required String description,
  }) async {
    final session = security.session;
    await executor.insert('audit_logs', {
      'id': _id('audit-accounting'),
      'userId': session?.user.id,
      'usernameSnapshot': session?.user.username ?? 'SYSTEM',
      'action': action,
      'module': 'Accounting',
      'entityType': entityType,
      'entityId': entityId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'description': description,
    });
  }

  Account _account(Map<String, Object?> row) => Account(
    id: row['id'] as String,
    code: row['code'] as String,
    name: row['name'] as String,
    type: _accountType(row['type'] as String),
    parentId: row['parentId'] as String?,
    description: row['description'] as String?,
    active: row['active'] == 1,
    systemAccount: row['systemAccount'] == 1,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
  AccountingPeriod _period(Map<String, Object?> row) => AccountingPeriod(
    id: row['id'] as String,
    name: row['name'] as String,
    startDate: _date(row['startDate']),
    endDate: _date(row['endDate']),
    status: row['status'] == 'CLOSED'
        ? AccountingPeriodStatus.closed
        : AccountingPeriodStatus.open,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
  Cashbox _cashbox(Map<String, Object?> row) => Cashbox(
    id: row['id'] as String,
    name: row['name'] as String,
    code: row['code'] as String,
    accountId: row['accountId'] as String,
    openingBalance: (row['openingBalance'] as num).toDouble(),
    active: row['active'] == 1,
    notes: row['notes'] as String?,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
  BankAccount _bank(Map<String, Object?> row) => BankAccount(
    id: row['id'] as String,
    bankName: row['bankName'] as String,
    accountName: row['accountName'] as String,
    accountNumber: row['accountNumber'] as String,
    accountId: row['accountId'] as String,
    openingBalance: (row['openingBalance'] as num).toDouble(),
    active: row['active'] == 1,
    notes: row['notes'] as String?,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
  InventoryValuation _valuation(Map<String, Object?> row) => InventoryValuation(
    warehouseId: row['warehouseId'] as String,
    itemId: row['itemId'] as String,
    itemType: row['itemType'] as String,
    quantity: (row['quantity'] as num).toDouble(),
    averageCost: (row['averageCost'] as num).toDouble(),
  );
  String _accountTypeValue(AccountType value) => value.name.toUpperCase();
  AccountType _accountType(String value) =>
      AccountType.values.firstWhere((item) => item.name.toUpperCase() == value);
  DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  String _number(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
}
