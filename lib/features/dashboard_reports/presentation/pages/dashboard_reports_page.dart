import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:furnexa/core/shared/widgets/furnexa_card.dart';
import 'package:furnexa/core/shared/widgets/furnexa_table.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/features/dashboard_reports/data/repositories/dashboard_reports_repository_impl.dart';
import 'package:furnexa/features/dashboard_reports/domain/entities/dashboard_report_entities.dart';
import 'package:furnexa/features/dashboard_reports/domain/repositories/dashboard_reports_repository.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class DashboardReportsPage extends StatefulWidget {
  const DashboardReportsPage({
    super.key,
    required this.security,
    this.repository,
    this.onNavigate,
  });

  final SecurityLocalDataSource security;
  final DashboardReportsRepository? repository;
  final ValueChanged<int>? onNavigate;

  @override
  State<DashboardReportsPage> createState() => _DashboardReportsPageState();
}

class _DashboardReportsPageState extends State<DashboardReportsPage> {
  late final DashboardReportsRepository _repository =
      widget.repository ?? DashboardReportsRepositoryImpl();
  DateRangeFilter _range = DateRangeFilter.thisMonth();
  DashboardSnapshot? _snapshot;
  ReportResult? _report;
  ReportType _reportType = ReportType.stockBalance;
  String _preset = 'month';
  String _search = '';
  bool _loading = true;
  bool _reports = false;
  String? _error;

  bool _can(String permission) =>
      widget.security.session?.can(permission) ?? false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _repository.loadDashboard(_range);
      if (!mounted) return;
      setState(() {
        _snapshot = value;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _repository.loadReport(
        _reportType,
        _range,
        search: _search,
      );
      if (!mounted) return;
      setState(() {
        _report = value;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _range.startDay, end: _range.end),
    );
    if (picked == null) return;
    setState(() {
      _preset = 'custom';
      _range = DateRangeFilter(start: picked.start, end: picked.end);
    });
    _reports ? _loadReport() : _loadDashboard();
  }

  void _setPreset(String preset) {
    final range = switch (preset) {
      'today' => DateRangeFilter.today(),
      'week' => DateRangeFilter.thisWeek(),
      _ => DateRangeFilter.thisMonth(),
    };
    setState(() {
      _preset = preset;
      _range = range;
    });
    _reports ? _loadReport() : _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_reports ? 'التقارير التشغيلية' : 'لوحة التشغيل'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading
                ? null
                : (_reports ? _loadReport : _loadDashboard),
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('اللوحة'),
                  icon: Icon(Icons.dashboard_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('التقارير'),
                  icon: Icon(Icons.table_chart_outlined),
                ),
              ],
              selected: {_reports},
              onSelectionChanged: (value) {
                setState(() {
                  _reports = value.first;
                  _loading = true;
                });
                _reports ? _loadReport() : _loadDashboard();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            range: _range,
            preset: _preset,
            onPreset: _setPreset,
            onCustom: _selectCustomRange,
          ),
          Expanded(child: _reports ? _buildReports() : _buildDashboard()),
        ],
      ),
    );
  }

  bool _isEmptyDashboard(DashboardSnapshot snapshot) {
    return snapshot.inventoryQuantity == 0 &&
        snapshot.inventoryValue == 0 &&
        snapshot.purchaseOrders == 0 &&
        snapshot.salesOrders == 0 &&
        snapshot.salesValue == 0 &&
        snapshot.productionInProgress == 0 &&
        snapshot.activeWorkers == 0 &&
        snapshot.netResult == 0 &&
        snapshot.salesTrend.isEmpty &&
        snapshot.productionTrend.isEmpty &&
        snapshot.inventoryDistribution.isEmpty &&
        snapshot.productionStatus.isEmpty &&
        snapshot.attendanceSummary.isEmpty &&
        snapshot.recentActivity.isEmpty;
  }

  Widget _buildDashboard() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return _ErrorState(message: _error!, onRetry: _loadDashboard);
    final snapshot = _snapshot;
    if (snapshot == null || _isEmptyDashboard(snapshot))
      return const _EmptyState();
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'نظرة تشغيلية',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatDate(_range.startDay)} - ${_formatDate(_range.end)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _quickActions(),
          const SizedBox(height: 16),
          _kpis(snapshot),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 920;
              final charts = [
                if (_can('SALES_VIEW'))
                  _ChartPanel(
                    title: 'اتجاه المبيعات',
                    points: snapshot.salesTrend,
                    color: AppTheme.warning,
                  ),
                if (_can('PRODUCTION_VIEW'))
                  _ChartPanel(
                    title: 'اتجاه الإنتاج',
                    points: snapshot.productionTrend,
                    color: AppTheme.info,
                  ),
                if (_can('WAREHOUSE_STOCK_VIEW'))
                  _BreakdownPanel(
                    title: 'توزيع المخزون',
                    points: snapshot.inventoryDistribution,
                  ),
                if (_can('PRODUCTION_VIEW'))
                  _BreakdownPanel(
                    title: 'حالة الإنتاج',
                    points: snapshot.productionStatus,
                  ),
                if (_can('HR_VIEW'))
                  _BreakdownPanel(
                    title: 'الحضور',
                    points: snapshot.attendanceSummary,
                  ),
              ];
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: charts
                    .map(
                      (chart) => SizedBox(
                        width: wide
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth,
                        child: chart,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_can('AUDIT_VIEW')) _activity(snapshot),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final actions = <Widget>[];
    void add(String label, IconData icon, String permission, int destination) {
      if (_can(permission))
        actions.add(
          ActionChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onPressed: () => widget.onNavigate?.call(destination),
          ),
        );
    }

    add('إضافة مخزون', Icons.add_box_outlined, 'WAREHOUSE_STOCK_EDIT', 3);
    add('طلب شراء', Icons.shopping_cart_outlined, 'PURCHASING_VIEW', 4);
    add('طلب بيع', Icons.point_of_sale_outlined, 'SALES_VIEW', 5);
    add(
      'أمر إنتاج',
      Icons.precision_manufacturing_outlined,
      'PRODUCTION_EDIT',
      6,
    );
    add('الحضور', Icons.groups_outlined, 'HR_VIEW', 7);
    add('مصروف', Icons.account_balance_outlined, 'ACCOUNTING_POST', 8);
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  Widget _kpis(DashboardSnapshot snapshot) {
    final cards = <Widget>[];
    if (_can('WAREHOUSE_STOCK_VIEW')) {
      cards.add(
        _KpiCard(
          'قيمة المخزون',
          _money(snapshot.inventoryValue),
          Icons.inventory_2_outlined,
          Colors.brown,
        ),
      );
      cards.add(
        _KpiCard(
          'كمية المخزون',
          _number(snapshot.inventoryQuantity),
          Icons.warehouse_outlined,
          AppTheme.info,
        ),
      );
    }
    if (_can('PURCHASING_VIEW'))
      cards.add(
        _KpiCard(
          'أوامر الشراء',
          '${snapshot.purchaseOrders}',
          Icons.shopping_cart_outlined,
          AppTheme.warning,
        ),
      );
    if (_can('SALES_VIEW')) {
      cards.add(
        _KpiCard(
          'أوامر البيع',
          '${snapshot.salesOrders}',
          Icons.point_of_sale_outlined,
          Colors.teal,
        ),
      );
      cards.add(
        _KpiCard(
          'قيمة المبيعات',
          _money(snapshot.salesValue),
          Icons.trending_up,
          AppTheme.success,
        ),
      );
    }
    if (_can('PRODUCTION_VIEW'))
      cards.add(
        _KpiCard(
          'قيد الإنتاج',
          '${snapshot.productionInProgress}',
          Icons.precision_manufacturing_outlined,
          Colors.indigo,
        ),
      );
    if (_can('HR_VIEW'))
      cards.add(
        _KpiCard(
          'العاملون النشطون',
          '${snapshot.activeWorkers}',
          Icons.groups_outlined,
          Colors.deepOrange,
        ),
      );
    if (_can('ACCOUNTING_VIEW'))
      cards.add(
        _KpiCard(
          'صافي النتيجة',
          _money(snapshot.netResult),
          Icons.account_balance_outlined,
          AppTheme.info,
        ),
      );
    if (cards.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCardsPerRow = cards.length > 4 ? 4 : cards.length.clamp(1, 4);
        final cardWidth = constraints.maxWidth / maxCardsPerRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: cardWidth.clamp(180.0, constraints.maxWidth),
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _activity(DashboardSnapshot snapshot) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.history),
      title: const Text('النشاط الأخير'),
      children: snapshot.recentActivity.isEmpty
          ? [const ListTile(title: Text('لا يوجد نشاط في الفترة الحالية'))]
          : snapshot.recentActivity
                .map(
                  (log) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 8),
                    title: Text('${log.action} • ${log.module}'),
                    subtitle: Text(
                      '${log.usernameSnapshot} • ${log.description ?? ''}',
                    ),
                    trailing: Text(_formatDate(log.timestamp)),
                  ),
                )
                .toList(),
    ),
  );

  Widget _buildReports() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return _ErrorState(message: _error!, onRetry: _loadReport);
    final result = _report;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<ReportType>(
          value: _reportType,
          decoration: const InputDecoration(labelText: 'التقرير'),
          items: ReportType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(_reportLabel(type)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _reportType = value);
            _loadReport();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'بحث',
          ),
          onChanged: (value) {
            _search = value;
          },
          onSubmitted: (_) => _loadReport(),
        ),
        const SizedBox(height: 16),
        if (result == null || result.rows.isEmpty)
          const _EmptyState()
        else
          _ReportTable(result: result),
      ],
    );
  }

  String _money(double value) => NumberFormat('#,##0.##').format(value);
  String _number(double value) => NumberFormat('#,##0.##').format(value);
  String _formatDate(DateTime value) => DateFormat('dd/MM/yyyy').format(value);

  String _reportLabel(ReportType type) => switch (type) {
    ReportType.stockBalance => 'أرصدة المخزون',
    ReportType.stockMovement => 'حركة المخزون',
    ReportType.warehouse => 'تقرير المخازن',
    ReportType.purchase => 'المشتريات',
    ReportType.pendingPurchaseOrders => 'أوامر الشراء المعلقة',
    ReportType.receiving => 'الاستلام',
    ReportType.sales => 'المبيعات',
    ReportType.customerSales => 'مبيعات العملاء',
    ReportType.productSales => 'مبيعات المنتجات',
    ReportType.delivery => 'التسليم',
    ReportType.outstandingSalesOrders => 'أوامر البيع المعلقة',
    ReportType.production => 'الإنتاج',
    ReportType.productionStage => 'مراحل الإنتاج',
    ReportType.materialConsumption => 'استهلاك المواد',
    ReportType.waste => 'الهالك',
    ReportType.attendance => 'الحضور',
    ReportType.late => 'التأخير',
    ReportType.overtime => 'العمل الإضافي',
    ReportType.leave => 'الإجازات',
    ReportType.payrollSummary => 'ملخص الرواتب',
  };
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.range,
    required this.preset,
    required this.onPreset,
    required this.onCustom,
  });
  final DateRangeFilter range;
  final String preset;
  final ValueChanged<String> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.date_range_outlined, size: 20),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('اليوم'),
              selected: preset == 'today',
              onSelected: (_) => onPreset('today'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('هذا الأسبوع'),
              selected: preset == 'week',
              onSelected: (_) => onPreset('week'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('هذا الشهر'),
              selected: preset == 'month',
              onSelected: (_) => onPreset('month'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onCustom,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(
                '${DateFormat('dd/MM').format(range.startDay)} - ${DateFormat('dd/MM').format(range.end)}',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.title, this.value, this.icon, this.color);
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      FurnexaKpiCard(title: title, value: value, icon: icon, accent: color);
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.points,
    required this.color,
  });
  final String title;
  final List<TrendPoint> points;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: points.isEmpty
                ? const _EmptyState(compact: true)
                : _Bars(points: points, color: color),
          ),
        ],
      ),
    ),
  );
}

class _BreakdownPanel extends StatelessWidget {
  const _BreakdownPanel({required this.title, required this.points});
  final String title;
  final List<BreakdownPoint> points;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: points.isEmpty
                ? const _EmptyState(compact: true)
                : Column(
                    children: points
                        .map(
                          (point) => _ProgressRow(
                            point: point,
                            total: points.fold(
                              0.0,
                              (sum, item) => sum + item.value,
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

class _Bars extends StatelessWidget {
  const _Bars({required this.points, required this.color});
  final List<TrendPoint> points;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final max = points
        .map((point) => point.value)
        .fold(0.0, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points
          .take(14)
          .map(
            (point) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: max == 0 ? 0 : point.value / max,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.label.length > 5
                          ? point.label.substring(5)
                          : point.label,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.point, required this.total});
  final BreakdownPoint point;
  final double total;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(point.label, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : point.value / total,
            minHeight: 8,
          ),
        ),
        const SizedBox(width: 8),
        Text(NumberFormat('#,##0.##').format(point.value)),
      ],
    ),
  );
}

class _ReportTable extends StatefulWidget {
  const _ReportTable({required this.result});
  final ReportResult result;

  @override
  State<_ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<_ReportTable> {
  int? _sortColumn;
  bool _ascending = true;

  @override
  Widget build(BuildContext context) {
    var rows = widget.result.rows
        .map((row) => Map<String, Object?>.from(row.values))
        .toList();
    if (_sortColumn != null) {
      final key = widget.result.columns[_sortColumn!];
      rows.sort(
        (left, right) => '${left[key] ?? ''}'.compareTo('${right[key] ?? ''}'),
      );
      if (!_ascending) rows = rows.reversed.toList();
    }
    return FurnexaCard(
      child: FurnexaDataTable(
        columns: widget.result.columns
            .map(
              (column) => FurnexaTableColumn(
                key: column,
                label: column,
                sortable: true,
              ),
            )
            .toList(),
        rows: rows,
        sortKey: _sortColumn == null
            ? null
            : widget.result.columns[_sortColumn!],
        sortAscending: _ascending,
        onSort: (key) {
          final index = widget.result.columns.indexOf(key);
          setState(() {
            if (_sortColumn == index) {
              _ascending = !_ascending;
            } else {
              _sortColumn = index;
              _ascending = true;
            }
          });
        },
        emptyTitle: 'لا توجد بيانات للفترة المحددة',
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(compact ? 8 : 32),
      child: Text('لا توجد بيانات للفترة المحددة'),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  );
}
