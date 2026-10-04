import 'package:flutter/material.dart';
import 'package:furnexa/features/accounting/data/datasources/accounting_local_data_source.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class AccountingPage extends StatefulWidget {
  const AccountingPage({super.key, required this.security});

  final SecurityLocalDataSource security;

  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage> {
  final AccountingLocalDataSource _source = AccountingLocalDataSource();
  bool _loading = true;
  String? _error;
  List<Account> _accounts = [];
  List<TrialBalanceLine> _trialBalance = [];
  List<AccountingPeriod> _periods = [];
  Map<String, int> _moduleCounts = {};
  FinancialStatement? _incomeStatement;
  BalanceSheet? _balanceSheet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await _source.accounts();
      final trialBalance = await _source.trialBalance();
      final incomeStatement = await _source.incomeStatement();
      final balanceSheet = await _source.balanceSheet();
      final periods = await _source.periods();
      final moduleCounts = await _source.moduleCounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _trialBalance = trialBalance;
        _incomeStatement = incomeStatement;
        _balanceSheet = balanceSheet;
        _periods = periods;
        _moduleCounts = moduleCounts;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المحاسبة')),
      body: !widget.security.can('ACCOUNTING_VIEW')
          ? const Center(child: Text('ليس لديك صلاحية عرض المحاسبة'))
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statCard(
                        'دليل الحسابات',
                        _accounts.length.toString(),
                        Icons.account_tree_outlined,
                      ),
                      _statCard(
                        'الحسابات المستخدمة',
                        _trialBalance.length.toString(),
                        Icons.receipt_long_outlined,
                      ),
                      _statCard(
                        'صافي الدخل',
                        _incomeStatement?.netIncome.toStringAsFixed(2) ??
                            '0.00',
                        Icons.trending_up,
                      ),
                      _statCard(
                        'إجمالي الأصول',
                        _balanceSheet?.assets.toStringAsFixed(2) ?? '0.00',
                        Icons.account_balance_wallet_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'الوحدات المحاسبية',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _moduleCard(
                        'الخزائن',
                        Icons.point_of_sale_outlined,
                        'cashboxes',
                      ),
                      _moduleCard(
                        'الحسابات البنكية',
                        Icons.account_balance_outlined,
                        'bank_accounts',
                      ),
                      _moduleCard(
                        'القيود اليومية',
                        Icons.menu_book_outlined,
                        'journal_entries',
                      ),
                      _moduleCard(
                        'تحصيلات العملاء',
                        Icons.payments_outlined,
                        'customer_payments',
                      ),
                      _moduleCard(
                        'مدفوعات الموردين',
                        Icons.request_quote_outlined,
                        'supplier_payments',
                      ),
                      _moduleCard(
                        'المصروفات',
                        Icons.money_off_outlined,
                        'expenses',
                      ),
                      _moduleCard(
                        'تقييم المخزون و COGS',
                        Icons.inventory_2_outlined,
                        'inventory_valuations',
                      ),
                      _moduleCard(
                        'دفتر حساب',
                        Icons.account_tree_outlined,
                        'account_ledger',
                      ),
                      _moduleCard(
                        'دفتر العملاء',
                        Icons.people_outline,
                        'customer_ledger',
                      ),
                      _moduleCard(
                        'دفتر الموردين',
                        Icons.local_shipping_outlined,
                        'supplier_ledger',
                      ),
                      _moduleCard(
                        'الفترات والإقفال',
                        Icons.event_available_outlined,
                        'periods',
                      ),
                      _moduleCard(
                        'قائمة الدخل والميزانية',
                        Icons.assessment_outlined,
                        'statements',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _periodsCard(),
                  const SizedBox(height: 12),
                  Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.account_tree_outlined),
                      title: const Text('دليل الحسابات'),
                      children: _accounts
                          .map(
                            (account) => ListTile(
                              dense: true,
                              title: Text('${account.code}  ${account.name}'),
                              subtitle: Text(account.type.name.toUpperCase()),
                              trailing: Icon(
                                account.active
                                    ? Icons.check_circle
                                    : Icons.pause_circle,
                                size: 18,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.balance_outlined),
                      title: const Text('ميزان المراجعة'),
                      children: _trialBalance
                          .map(
                            (line) => ListTile(
                              dense: true,
                              title: Text(line.accountName),
                              trailing: Text(
                                'مدين ${line.debit.toStringAsFixed(2)}  دائن ${line.credit.toStringAsFixed(2)}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _moduleCard(String title, IconData icon, String key) {
    final count = _moduleCounts[key];
    return SizedBox(
      width: 220,
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(count == null ? 'متاح' : '$count سجل'),
        ),
      ),
    );
  }

  Widget _periodsCard() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.event_available_outlined),
        title: const Text('الفترات المحاسبية والإقفال'),
        children: _periods.isEmpty
            ? [const ListTile(title: Text('لا توجد فترات محاسبية'))]
            : _periods
                  .map(
                    (period) => ListTile(
                      title: Text(period.name),
                      subtitle: Text(period.status.name.toUpperCase()),
                      trailing:
                          period.status == AccountingPeriodStatus.open &&
                              widget.security.can('ACCOUNTING_CLOSE_PERIOD')
                          ? IconButton(
                              tooltip: 'إقفال الفترة',
                              icon: const Icon(Icons.lock_outline),
                              onPressed: () async {
                                await _source.closePeriod(period.id);
                                await _load();
                              },
                            )
                          : null,
                    ),
                  )
                  .toList(),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
