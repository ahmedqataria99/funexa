import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';

abstract class AccountingRepository {
  Future<List<Account>> accounts({bool activeOnly = false});
  Future<Account?> account(String id);
  Future<String> postJournal({
    required DateTime date,
    required String description,
    required List<JournalLineInput> lines,
    String? referenceType,
    String? referenceId,
  });
  Future<List<TrialBalanceLine>> trialBalance({DateTime? from, DateTime? to});
  Future<FinancialStatement> incomeStatement({DateTime? from, DateTime? to});
  Future<BalanceSheet> balanceSheet({DateTime? to});
}
