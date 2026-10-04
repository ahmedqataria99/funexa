enum AccountType { asset, liability, equity, revenue, expense }

enum JournalEntryStatus { draft, posted, reversed }

enum AccountingPeriodStatus { open, closed }

enum AccountingPaymentStatus { draft, posted, reversed }

class Account {
  const Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.description,
    this.active = true,
    this.systemAccount = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String name;
  final AccountType type;
  final String? parentId;
  final String? description;
  final bool active;
  final bool systemAccount;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class JournalLineInput {
  const JournalLineInput({
    required this.accountId,
    this.debit = 0,
    this.credit = 0,
    this.description,
  });

  final String accountId;
  final double debit;
  final double credit;
  final String? description;
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.entryNumber,
    required this.date,
    required this.description,
    required this.status,
    required this.lines,
    this.referenceType,
    this.referenceId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String entryNumber;
  final DateTime date;
  final String description;
  final String? referenceType;
  final String? referenceId;
  final JournalEntryStatus status;
  final List<JournalLineInput> lines;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class AccountingPeriod {
  const AccountingPeriod({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final AccountingPeriodStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class Cashbox {
  const Cashbox({
    required this.id,
    required this.name,
    required this.code,
    required this.accountId,
    required this.openingBalance,
    required this.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String code;
  final String accountId;
  final double openingBalance;
  final bool active;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.accountId,
    required this.openingBalance,
    required this.active,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String accountId;
  final double openingBalance;
  final bool active;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class LedgerLine {
  const LedgerLine({
    required this.date,
    required this.reference,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final DateTime date;
  final String reference;
  final String description;
  final double debit;
  final double credit;
  final double balance;
}

class TrialBalanceLine {
  const TrialBalanceLine({
    required this.accountId,
    required this.accountName,
    required this.debit,
    required this.credit,
  });

  final String accountId;
  final String accountName;
  final double debit;
  final double credit;
}

class FinancialStatement {
  const FinancialStatement({
    required this.revenue,
    required this.cogs,
    required this.expenses,
    required this.netIncome,
  });

  final double revenue;
  final double cogs;
  final double expenses;
  final double netIncome;
}

class BalanceSheet {
  const BalanceSheet({
    required this.assets,
    required this.liabilities,
    required this.equity,
  });

  final double assets;
  final double liabilities;
  final double equity;
}

class InventoryValuation {
  const InventoryValuation({
    required this.warehouseId,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.averageCost,
  });

  final String warehouseId;
  final String itemId;
  final String itemType;
  final double quantity;
  final double averageCost;

  double get totalValue => quantity * averageCost;
}

class ProductionCostResult {
  const ProductionCostResult({
    required this.referenceId,
    required this.warehouseId,
    required this.itemId,
    required this.itemType,
    required this.quantity,
    required this.totalCost,
  });

  final String referenceId;
  final String warehouseId;
  final String itemId;
  final String itemType;
  final double quantity;
  final double totalCost;
}
