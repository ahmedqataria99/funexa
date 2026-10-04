import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/accounting/domain/repositories/accounting_repository.dart';

class AccountingRepositoryImpl implements AccountingRepository {
  AccountingRepositoryImpl([AccountingLocalDataSource? source])
    : _source = source ?? AccountingLocalDataSource();

  final AccountingLocalDataSource _source;

  @override
  Future<List<Account>> accounts({bool activeOnly = false}) =>
      _source.accounts(activeOnly: activeOnly);

  @override
  Future<Account?> account(String id) => _source.account(id);

  @override
  Future<String> postJournal({
    required DateTime date,
    required String description,
    required List<JournalLineInput> lines,
    String? referenceType,
    String? referenceId,
  }) => _source.postJournal(
    date: date,
    description: description,
    lines: lines,
    referenceType: referenceType,
    referenceId: referenceId,
  );

  @override
  Future<List<TrialBalanceLine>> trialBalance({DateTime? from, DateTime? to}) =>
      _source.trialBalance(from: from, to: to);

  @override
  Future<FinancialStatement> incomeStatement({DateTime? from, DateTime? to}) =>
      _source.incomeStatement(from: from, to: to);

  @override
  Future<BalanceSheet> balanceSheet({DateTime? to}) =>
      _source.balanceSheet(to: to);
}
