import 'package:flutter/material.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/shared/widgets/furnexa_card.dart';
import 'package:furnexa/core/shared/widgets/furnexa_table.dart';
import 'package:furnexa/core/shared/widgets/furnexa_table_toolbar.dart';
import 'package:furnexa/core/theme/app_spacing.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/returns_quality/data/datasources/returns_quality_local_data_source.dart';
import 'package:furnexa/features/returns_quality/domain/entities/returns_quality_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class SalesReturnsPage extends StatefulWidget {
  const SalesReturnsPage({super.key, required this.security, this.dataSource});

  final SecurityLocalDataSource security;
  final ReturnsQualityLocalDataSource? dataSource;

  @override
  State<SalesReturnsPage> createState() => _SalesReturnsPageState();
}

class _SalesReturnsPageState extends State<SalesReturnsPage> {
  late final ReturnsQualityLocalDataSource _dataSource =
      widget.dataSource ?? ReturnsQualityLocalDataSource(null, widget.security);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  List<SalesReturnWorkflowDetails> _returns = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;
  DateTimeRange? _dateRange;
  int _page = 0;
  int _pageSize = 10;

  bool get _canEdit => widget.security.can('RETURNS_EDIT');
  bool get _canQualityView => widget.security.can('QUALITY_VIEW');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = await _dataSource.salesReturns();
      final details = await Future.wait(
        headers.map((value) => _dataSource.salesReturnDetails(value.id)),
      );
      if (!mounted) return;
      setState(() {
        _returns = details;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _loading = false;
      });
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  List<SalesReturnWorkflowDetails> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _returns.where((detail) {
      final value = detail.salesReturn;
      final matchesQuery =
          query.isEmpty ||
          value.returnNumber.toLowerCase().contains(query) ||
          detail.customerName.toLowerCase().contains(query) ||
          detail.deliveryNumber.toLowerCase().contains(query) ||
          detail.salesOrderNumber.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == null || value.status.value == _statusFilter;
      final date = value.returnDate;
      final endOfDateRange = _dateRange == null
          ? null
          : DateTime(
              _dateRange!.end.year,
              _dateRange!.end.month,
              _dateRange!.end.day,
              23,
              59,
              59,
              999,
            );
      final matchesDate =
          _dateRange == null ||
          !date.isBefore(_dateRange!.start) && !date.isAfter(endOfDateRange!);
      return matchesQuery && matchesStatus && matchesDate;
    }).toList();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SalesReturnCreatePage(
          security: widget.security,
          dataSource: _dataSource,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _open(SalesReturnWorkflowDetails detail) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SalesReturnDetailsPage(
          returnId: detail.salesReturn.id,
          security: widget.security,
          dataSource: _dataSource,
        ),
      ),
    );
    await _load();
  }

  Future<void> _chooseDateRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (selected != null) setState(() => _dateRange = selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = _filtered;
    final pageCount = filtered.isEmpty
        ? 1
        : (filtered.length / _pageSize).ceil();
    final safePage = _page.clamp(0, pageCount - 1);
    final rows = filtered
        .skip(safePage * _pageSize)
        .take(_pageSize)
        .map((detail) => _row(detail, l10n))
        .toList();
    final awaitingReceipt = _returns.where(_isAwaitingReceipt).length;
    final awaitingInspection = _canQualityView
        ? _returns.where(_isAwaitingInspection).length
        : null;
    final awaitingApproval = _canQualityView
        ? _returns.where(_isAwaitingApproval).length
        : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _pageScrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.salesReturns,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.salesReturnsDescription,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_canEdit)
                      FurnexaButton(
                        label: l10n.createSalesReturn,
                        icon: Icons.add,
                        onPressed: _create,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FurnexaKpiCard(
                      title: l10n.totalReturns,
                      value: '${_returns.length}',
                      icon: Icons.assignment_return_outlined,
                    ),
                    FurnexaKpiCard(
                      title: l10n.pendingReturns,
                      value:
                          '${_returns.where((value) => value.salesReturn.status == ReturnStatus.pending).length}',
                      icon: Icons.pending_actions_outlined,
                    ),
                    FurnexaKpiCard(
                      title: l10n.awaitingReceipt,
                      value: '$awaitingReceipt',
                      icon: Icons.move_to_inbox_outlined,
                    ),
                    if (awaitingInspection != null)
                      FurnexaKpiCard(
                        title: l10n.awaitingInspection,
                        value: '$awaitingInspection',
                        icon: Icons.fact_check_outlined,
                      ),
                    if (awaitingApproval != null)
                      FurnexaKpiCard(
                        title: l10n.awaitingApproval,
                        value: '$awaitingApproval',
                        icon: Icons.rule_folder_outlined,
                      ),
                    FurnexaKpiCard(
                      title: l10n.approvedReturns,
                      value:
                          '${_returns.where((value) => value.salesReturn.status == ReturnStatus.approved).length}',
                      icon: Icons.task_alt_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                FurnexaTableToolbar(
                  title: l10n.salesReturns,
                  count: filtered.length,
                  search: SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.searchReturns,
                        isDense: true,
                      ),
                    ),
                  ),
                  filters: [
                    DropdownButton<String?>(
                      value: _statusFilter,
                      hint: Text(l10n.allStatuses),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.allStatuses),
                        ),
                        for (final status in ReturnStatus.values)
                          DropdownMenuItem<String?>(
                            value: status.value,
                            child: Text(_returnStatusLabel(l10n, status)),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _statusFilter = value;
                        _page = 0;
                      }),
                    ),
                    IconButton(
                      tooltip: _dateRange == null
                          ? l10n.returnDate
                          : '${_date(_dateRange!.start)} - ${_date(_dateRange!.end)}',
                      onPressed: _chooseDateRange,
                      icon: const Icon(Icons.date_range_outlined),
                    ),
                    if (_dateRange != null)
                      IconButton(
                        tooltip: l10n.clearSearch,
                        onPressed: () => setState(() => _dateRange = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
                FurnexaDataTable(
                    verticalScrollable: false,
                    columns: [
                      FurnexaTableColumn(
                        key: 'returnNumber',
                        label: l10n.returnNumber,
                        flex: 2,
                      ),
                      FurnexaTableColumn(
                        key: 'source',
                        label: l10n.originalSale,
                        flex: 3,
                      ),
                      FurnexaTableColumn(
                        key: 'customer',
                        label: l10n.customer,
                        flex: 2,
                      ),
                      FurnexaTableColumn(key: 'date', label: l10n.returnDate),
                      FurnexaTableColumn(
                        key: 'updated',
                        label: l10n.lastUpdated,
                      ),
                      FurnexaTableColumn(
                        key: 'quantity',
                        label: l10n.totalReturnedQuantity,
                      ),
                      FurnexaTableColumn(
                        key: 'status',
                        label: l10n.status,
                        cellBuilder: (context, row) => Chip(
                          label: Text('${row['status']}'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                    rows: rows,
                    rowId: (row) => row['id'] as String,
                    loading: _loading,
                    errorMessage: _error,
                    onRetry: _load,
                    emptyTitle: l10n.noSalesReturns,
                    emptyDescription: l10n.noSalesReturnsDescription,
                    actionsBuilder: (row) => [
                      FurnexaTableAction(
                        label: l10n.returnDetails,
                        icon: Icons.open_in_new,
                        onPressed: () {
                          final match = _returns.firstWhere(
                            (detail) => detail.salesReturn.id == row['id'],
                          );
                          _open(match);
                        },
                      ),
                    ],
                    pagination: FurnexaTablePagination(
                      page: safePage,
                      pageSize: _pageSize,
                      total: filtered.length,
                      onPageChanged: (page) => setState(() => _page = page),
                      onPageSizeChanged: (pageSize) => setState(() {
                        _pageSize = pageSize;
                        _page = 0;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, Object?> _row(
    SalesReturnWorkflowDetails detail,
    AppLocalizations l10n,
  ) {
    final value = detail.salesReturn;
    final quantity = detail.lines.fold<double>(
      0,
      (sum, line) => sum + line.item.quantity,
    );
    return {
      'id': value.id,
      'returnNumber': value.returnNumber,
      'source': '${detail.salesOrderNumber} / ${detail.deliveryNumber}',
      'customer': detail.customerName,
      'date': _date(value.returnDate),
      'updated': _date(value.updatedAt),
      'quantity': _quantity(quantity),
      'status': _returnStatusLabel(l10n, value.status),
    };
  }

  bool _isAwaitingReceipt(SalesReturnWorkflowDetails detail) {
    if (detail.salesReturn.status != ReturnStatus.pending) return false;
    return detail.lines.any(
      (line) =>
          line.receivedBaseQuantity + 0.000001 <
          (line.item.baseQuantity ??
              line.item.quantity * line.item.unitConversionFactor),
    );
  }

  bool _isAwaitingInspection(SalesReturnWorkflowDetails detail) =>
      detail.salesReturn.status == ReturnStatus.pending &&
      !_isAwaitingReceipt(detail) &&
      detail.inspection?.status != QualityInspectionStatus.completed;

  bool _isAwaitingApproval(SalesReturnWorkflowDetails detail) =>
      detail.salesReturn.status == ReturnStatus.pending &&
      detail.inspection?.status == QualityInspectionStatus.completed;
}

class SalesReturnCreatePage extends StatefulWidget {
  const SalesReturnCreatePage({
    super.key,
    required this.security,
    required this.dataSource,
  });

  final SecurityLocalDataSource security;
  final ReturnsQualityLocalDataSource dataSource;

  @override
  State<SalesReturnCreatePage> createState() => _SalesReturnCreatePageState();
}

class _SalesReturnCreatePageState extends State<SalesReturnCreatePage> {
  final TextEditingController _sourceSearch = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  final Map<String, TextEditingController> _quantityControllers = {};
  List<SalesReturnSourceDelivery> _deliveries = [];
  List<SalesReturnSourceLine> _lines = [];
  List<Warehouse> _sellableWarehouses = [];
  SalesReturnSourceDelivery? _delivery;
  Warehouse? _destination;
  final Set<String> _selectedLines = {};
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _sourceSearch.dispose();
    _reason.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSources() async {
    try {
      final deliveries = await widget.dataSource.salesReturnSourceDeliveries();
      final warehouses = await widget.dataSource.salesReturnWarehouses(
        WarehousePurpose.sellable,
      );
      if (!mounted) return;
      setState(() {
        _deliveries = deliveries;
        _sellableWarehouses = warehouses;
        _destination = warehouses.isEmpty ? null : warehouses.first;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _searchSources(String query) async {
    try {
      final deliveries = await widget.dataSource.salesReturnSourceDeliveries(
        query: query,
      );
      if (mounted) setState(() => _deliveries = deliveries);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _selectDelivery(SalesReturnSourceDelivery delivery) async {
    setState(() {
      _delivery = delivery;
      _lines = [];
      _selectedLines.clear();
      _error = null;
    });
    try {
      final lines = await widget.dataSource.salesReturnSourceLines(delivery.id);
      if (!mounted) return;
      for (final controller in _quantityControllers.values) {
        controller.dispose();
      }
      _quantityControllers.clear();
      for (final line in lines) {
        _quantityControllers[line.deliveryItemId] = TextEditingController();
      }
      setState(() => _lines = lines);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  List<(SalesReturnSourceLine, double)> get _chosen {
    final result = <(SalesReturnSourceLine, double)>[];
    for (final line in _lines) {
      if (!_selectedLines.contains(line.deliveryItemId)) continue;
      final quantity = double.tryParse(
        _quantityControllers[line.deliveryItemId]?.text.trim() ?? '',
      );
      if (quantity != null && quantity.isFinite && quantity > 0) {
        result.add((line, quantity));
      }
    }
    return result;
  }

  void _continue() {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    if (_step == 0) {
      if (_delivery == null) {
        setState(() => _error = l10n.chooseDeliveredSale);
        return;
      }
      if (_lines.every((line) => line.returnableQuantity <= 0)) {
        setState(() => _error = l10n.noResults);
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_selectedLines.isEmpty) {
        setState(() => _error = l10n.selectReturnItem);
        return;
      }
      for (final line in _lines.where(
        (line) => _selectedLines.contains(line.deliveryItemId),
      )) {
        final quantity = double.tryParse(
          _quantityControllers[line.deliveryItemId]?.text.trim() ?? '',
        );
        if (quantity == null ||
            !quantity.isFinite ||
            quantity <= 0 ||
            quantity > line.returnableQuantity + 0.000001) {
          setState(() => _error = l10n.invalidReturnQuantity);
          return;
        }
      }
      if (_destination == null) {
        setState(() => _error = l10n.destinationWarehouse);
        return;
      }
      if (_reason.text.trim().isEmpty) {
        setState(() => _error = l10n.returnReasonRequired);
        return;
      }
      setState(() => _step = 2);
    }
  }

  Future<void> _submit() async {
    final delivery = _delivery;
    final destination = _destination;
    if (delivery == null || destination == null || _chosen.isEmpty || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final id = 'sales-return-${now.microsecondsSinceEpoch}';
    try {
      await widget.dataSource.createSalesReturn(
        id: id,
        returnNumber: 'SR-${now.millisecondsSinceEpoch}',
        salesOrderId: delivery.salesOrderId,
        customerId: delivery.customerId,
        warehouseId: destination.id,
        returnDate: now,
        salesDeliveryId: delivery.id,
        reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
        status: ReturnStatus.pending,
        items: _chosen.map((choice) {
          final line = choice.$1;
          final quantity = choice.$2;
          return SalesReturnItem(
            id: '$id-item-${line.deliveryItemId}',
            itemId: line.itemId,
            itemType: line.itemType,
            quantity: quantity,
            unitId: line.unitId,
            variantId: line.variantId,
            baseUnitId: line.baseUnitId,
            unitConversionFactor: line.unitConversionFactor,
            baseQuantity: quantity * line.unitConversionFactor,
            inventoryIdentityKind: line.inventoryIdentityKind,
            identitySnapshotStatus: line.identitySnapshotStatus,
            sourceDeliveryItemId: line.deliveryItemId,
          );
        }).toList(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createSalesReturn)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _step,
                  onStepContinue: _step == 2 ? _submit : _continue,
                  onStepCancel: _step == 0
                      ? () => Navigator.of(context).pop(false)
                      : () => setState(() => _step -= 1),
                  controlsBuilder: (context, details) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        FurnexaButton(
                          label: _step == 2
                              ? l10n.submitReturn
                              : l10n.continueLabel,
                          icon: _step == 2 ? Icons.check : Icons.arrow_forward,
                          onPressed: _saving ? null : details.onStepContinue,
                          isLoading: _saving,
                        ),
                        FurnexaButton(
                          label: _step == 0 ? l10n.cancel : l10n.back,
                          variant: FurnexaButtonVariant.text,
                          onPressed: details.onStepCancel,
                        ),
                      ],
                    ),
                  ),
                  steps: [
                    Step(
                      title: Text(l10n.originalSale),
                      isActive: _step >= 0,
                      content: _sourceStep(l10n),
                    ),
                    Step(
                      title: Text(l10n.returnItems),
                      isActive: _step >= 1,
                      content: _itemsStep(l10n),
                    ),
                    Step(
                      title: Text(l10n.reviewApproval),
                      isActive: _step >= 2,
                      content: _reviewStep(l10n),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sourceStep(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _sourceSearch,
        onChanged: _searchSources,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: l10n.searchDeliveredSales,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (_deliveries.isEmpty)
        Text(l10n.noResults)
      else
        ..._deliveries.map(
          (delivery) => Card(
            child: ListTile(
              selected: _delivery?.id == delivery.id,
              title: Text(
                '${delivery.deliveryNumber} • ${delivery.salesOrderNumber}',
              ),
              subtitle: Text(
                '${delivery.customerName} • ${_date(delivery.deliveryDate)}',
              ),
              trailing: _delivery?.id == delivery.id
                  ? const Icon(Icons.check_circle)
                  : const Icon(Icons.chevron_right),
              onTap: () => _selectDelivery(delivery),
            ),
          ),
        ),
      if (_error != null) _InlineError(message: _error!),
    ],
  );

  Widget _itemsStep(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_delivery != null)
        Text('${_delivery!.customerName} • ${_delivery!.deliveryNumber}'),
      const SizedBox(height: AppSpacing.sm),
      DropdownButtonFormField<Warehouse>(
        initialValue: _destination,
        decoration: InputDecoration(labelText: l10n.destinationWarehouse),
        items: _sellableWarehouses
            .map(
              (warehouse) => DropdownMenuItem(
                value: warehouse,
                child: Text(warehouse.name),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _destination = value),
      ),
      const SizedBox(height: AppSpacing.md),
      ..._lines.map((line) {
        final selected = _selectedLines.contains(line.deliveryItemId);
        final unitController = _quantityControllers[line.deliveryItemId]!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: line.returnableQuantity <= 0
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _selectedLines.add(line.deliveryItemId);
                          } else {
                            _selectedLines.remove(line.deliveryItemId);
                          }
                        }),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.itemName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text('${line.variantName ?? ''} ${line.itemType}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    '${l10n.deliveredQuantity}: ${_quantity(line.deliveredQuantity)}',
                  ),
                ),
                Expanded(
                  child: Text(
                    '${l10n.returnableQuantity}: ${_quantity(line.returnableQuantity)} ${line.unitName}',
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: unitController,
                    enabled: selected,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.requestedQuantity,
                      suffixText: line.unitName,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        controller: _reason,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(labelText: l10n.returnReason),
      ),
      if (_error != null) _InlineError(message: _error!),
    ],
  );

  Widget _reviewStep(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListTile(
        title: Text(l10n.customer),
        subtitle: Text(_delivery?.customerName ?? ''),
      ),
      ListTile(
        title: Text(l10n.originalSale),
        subtitle: Text(
          '${_delivery?.salesOrderNumber ?? ''} / ${_delivery?.deliveryNumber ?? ''}',
        ),
      ),
      ListTile(
        title: Text(l10n.destinationWarehouse),
        subtitle: Text(_destination?.name ?? ''),
      ),
      for (final choice in _chosen)
        ListTile(
          title: Text(choice.$1.itemName),
          subtitle: Text('${_quantity(choice.$2)} ${choice.$1.unitName}'),
        ),
      if (_reason.text.trim().isNotEmpty)
        ListTile(
          title: Text(l10n.returnReason),
          subtitle: Text(_reason.text.trim()),
        ),
      Text(l10n.pendingStatus),
      if (_error != null) _InlineError(message: _error!),
    ],
  );
}

class SalesReturnDetailsPage extends StatefulWidget {
  const SalesReturnDetailsPage({
    super.key,
    required this.returnId,
    required this.security,
    required this.dataSource,
  });

  final String returnId;
  final SecurityLocalDataSource security;
  final ReturnsQualityLocalDataSource dataSource;

  @override
  State<SalesReturnDetailsPage> createState() => _SalesReturnDetailsPageState();
}

class _SalesReturnDetailsPageState extends State<SalesReturnDetailsPage> {
  SalesReturnWorkflowDetails? _details;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canEdit => widget.security.can('RETURNS_EDIT');
  bool get _canQualityEdit => widget.security.can('QUALITY_EDIT');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final details = await widget.dataSource.salesReturnDetails(
        widget.returnId,
      );
      if (mounted) {
        setState(() {
          _details = details;
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  bool get _fullyReceived {
    final details = _details;
    if (details == null || details.lines.isEmpty) return false;
    return details.lines.every(
      (line) =>
          line.receivedBaseQuantity + 0.000001 >=
          (line.item.baseQuantity ??
              line.item.quantity * line.item.unitConversionFactor),
    );
  }

  Future<void> _receive() async {
    final details = _details;
    if (details == null) return;
    final warehouses = await widget.dataSource.salesReturnWarehouses(
      WarehousePurpose.quarantine,
    );
    if (!mounted) return;
    final request = await showDialog<_ReceiptRequest>(
      context: context,
      builder: (_) =>
          _SalesReturnReceiptDialog(details: details, warehouses: warehouses),
    );
    if (request == null) return;
    await _perform(() async {
      final stamp = DateTime.now();
      final receiptId = 'sales-return-receipt-${stamp.microsecondsSinceEpoch}';
      await widget.dataSource.receiveSalesReturn(
        returnId: details.salesReturn.id,
        receiptId: receiptId,
        receiptNumber: 'SRR-${stamp.millisecondsSinceEpoch}',
        quarantineWarehouseId: request.warehouse.id,
        receiptDate: request.date,
        items: request.items,
      );
    });
  }

  Future<void> _inspect() async {
    final details = _details;
    if (details == null || !_fullyReceived) return;
    final warehouseId = details.receipts.first.warehouseId;
    final inspectionItems = await showDialog<List<QualityInspectionItem>>(
      context: context,
      builder: (_) => _SalesReturnInspectionDialog(details: details),
    );
    if (inspectionItems == null || inspectionItems.isEmpty) return;
    await _perform(() async {
      final stamp = DateTime.now();
      await widget.dataSource.createQualityInspection(
        id: 'sales-return-inspection-${stamp.microsecondsSinceEpoch}',
        inspectionNumber: 'SRI-${stamp.millisecondsSinceEpoch}',
        sourceType: 'SALES_RETURN',
        sourceId: details.salesReturn.id,
        warehouseId: warehouseId,
        itemId: inspectionItems.first.itemId,
        itemType: inspectionItems.first.itemType,
        inspectedBy: widget.security.session?.user.displayName,
        inspectionDate: stamp,
        status: QualityInspectionStatus.completed,
        result: inspectionItems.any((item) => item.rejectedQuantity > 0)
            ? QualityInspectionResult.rejected
            : QualityInspectionResult.passed,
        items: inspectionItems,
      );
    });
  }

  Future<void> _completeExistingInspection() async {
    final inspection = _details?.inspection;
    if (inspection == null) return;
    await _perform(
      () => widget.dataSource.updateQualityInspectionStatus(
        inspection.id,
        QualityInspectionStatus.completed,
      ),
    );
  }

  Future<void> _approve() async {
    await _perform(
      () => widget.dataSource.updateSalesReturnStatus(
        widget.returnId,
        ReturnStatus.approved,
      ),
    );
  }

  Future<void> _perform(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = _details;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (details == null) {
      return Scaffold(
        body: Center(child: Text(_error ?? l10n.tableLoadFailed)),
      );
    }
    final value = details.salesReturn;
    final inspection = details.inspection;
    final awaitingReceipt = !_fullyReceived;
    final canInspect =
        _canQualityEdit &&
        value.status == ReturnStatus.pending &&
        _fullyReceived &&
        inspection == null;
    final canComplete =
        _canQualityEdit &&
        inspection?.status == QualityInspectionStatus.inProgress;
    final canApprove =
        _canEdit &&
        value.status == ReturnStatus.pending &&
        _fullyReceived &&
        inspection?.status == QualityInspectionStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.returnDetails} • ${value.returnNumber}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _workflowProgress(l10n, value.status, _fullyReceived, inspection),
            const SizedBox(height: AppSpacing.md),
            _detailSection(l10n.returnDetails, [
              _detailValue(l10n.returnNumber, value.returnNumber),
              _detailValue(l10n.customer, details.customerName),
              _detailValue(l10n.originalSale, details.salesOrderNumber),
              _detailValue(l10n.delivery, details.deliveryNumber),
              _detailValue(l10n.returnDate, _date(value.returnDate)),
              _detailValue(l10n.creationDate, _date(value.createdAt)),
              _detailValue(l10n.status, _returnStatusLabel(l10n, value.status)),
              if (value.reason?.isNotEmpty == true)
                _detailValue(l10n.returnReason, value.reason!),
            ]),
            _detailSection(l10n.returnItems, [
              for (final line in details.lines)
                _detailValue(
                  '${line.itemName} • ${line.unitName}',
                  '${l10n.deliveredQuantity}: ${_quantity(line.deliveredQuantity)}  |  '
                      '${l10n.requestedQuantity}: ${_quantity(line.item.quantity)}  |  '
                      '${l10n.receivedQuantity}: ${_quantity(line.receivedQuantity)}  |  '
                      '${l10n.acceptedQuantity}: ${_quantity(line.acceptedQuantity)}  |  '
                      '${l10n.rejectedQuantity}: ${_quantity(line.rejectedQuantity)}',
                ),
            ]),
            _detailSection(l10n.physicalReceipt, [
              if (details.receipts.isEmpty)
                Text(l10n.noReceiptYet)
              else
                for (final receipt in details.receipts)
                  _detailValue(
                    receipt.receiptNumber,
                    '${receipt.warehouseName} • ${_date(receipt.receiptDate)} • '
                    '${receipt.items.fold<double>(0, (sum, item) => sum + item.baseQuantity!)}',
                  ),
              if (_canEdit &&
                  value.status == ReturnStatus.pending &&
                  inspection == null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FurnexaButton(
                    label: l10n.recordReceipt,
                    icon: Icons.move_to_inbox_outlined,
                    onPressed: _saving ? null : _receive,
                  ),
                ),
            ]),
            _detailSection(l10n.qualityInspection, [
              if (inspection == null)
                Text(awaitingReceipt ? l10n.noReceiptYet : l10n.noInspectionYet)
              else ...[
                _detailValue(
                  l10n.status,
                  _inspectionStatusLabel(l10n, inspection.status),
                ),
                for (final item in inspection.items)
                  _detailValue(
                    item.itemId,
                    '${l10n.acceptedQuantity}: ${_quantity(item.acceptedQuantity)}  |  '
                    '${l10n.rejectedQuantity}: ${_quantity(item.rejectedQuantity)}',
                  ),
              ],
              if (canInspect)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FurnexaButton(
                    label: l10n.startInspection,
                    icon: Icons.fact_check_outlined,
                    onPressed: _saving ? null : _inspect,
                  ),
                ),
              if (canComplete)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FurnexaButton(
                    label: l10n.completeInspection,
                    icon: Icons.task_alt_outlined,
                    onPressed: _saving ? null : _completeExistingInspection,
                  ),
                ),
              Text(l10n.rejectedRemainQuarantined),
            ]),
            if (value.status == ReturnStatus.pending)
              _detailSection(l10n.reviewApproval, [
                for (final line in details.lines)
                  _detailValue(
                    line.itemName,
                    '${l10n.receivedQuantity}: ${_quantity(line.receivedQuantity)}  |  '
                    '${l10n.acceptedQuantity}: ${_quantity(line.acceptedQuantity)}  |  '
                    '${l10n.rejectedQuantity}: ${_quantity(line.rejectedQuantity)}',
                  ),
                _detailValue(
                  l10n.destinationWarehouse,
                  details.destinationWarehouseName,
                ),
                Text(l10n.expectedCreditNotShown),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FurnexaButton(
                    label: l10n.approveReturn,
                    icon: Icons.check_circle_outline,
                    onPressed: canApprove && !_saving ? _approve : null,
                  ),
                ),
              ]),
            if (value.status == ReturnStatus.approved)
              _detailSection(l10n.finalResult, [
                _detailValue(l10n.status, l10n.approvedStatus),
                _detailValue(
                  l10n.destinationWarehouse,
                  details.destinationWarehouseName,
                ),
                _detailValue(
                  l10n.stockTransfer,
                  '${details.acceptedTransferCount}',
                ),
                _detailValue(
                  l10n.accountingEntry,
                  details.journalNumber ?? '-',
                ),
                Text(l10n.rejectedRemainQuarantined),
              ]),
            if (_error != null) _InlineError(message: _error!),
            if (_saving) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _workflowProgress(
    AppLocalizations l10n,
    ReturnStatus status,
    bool received,
    QualityInspection? inspection,
  ) {
    final current = status == ReturnStatus.approved
        ? 4
        : inspection?.status == QualityInspectionStatus.completed
        ? 2
        : received
        ? 1
        : 0;
    final labels = [
      l10n.returnCreated,
      l10n.awaitingReceiptStage,
      l10n.inspectionStage,
      l10n.approvalStage,
      l10n.completedStatus,
    ];
    return FurnexaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.workflowProgress,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: current / (labels.length - 1)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: labels
                .asMap()
                .entries
                .map(
                  (entry) => Text(
                    '${entry.key <= current ? '✓ ' : ''}${entry.value}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: FurnexaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    ),
  );

  Widget _detailValue(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 190,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ReceiptRequest {
  const _ReceiptRequest({
    required this.warehouse,
    required this.date,
    required this.items,
  });
  final Warehouse warehouse;
  final DateTime date;
  final List<SalesReturnReceiptItem> items;
}

class _SalesReturnReceiptDialog extends StatefulWidget {
  const _SalesReturnReceiptDialog({
    required this.details,
    required this.warehouses,
  });
  final SalesReturnWorkflowDetails details;
  final List<Warehouse> warehouses;

  @override
  State<_SalesReturnReceiptDialog> createState() =>
      _SalesReturnReceiptDialogState();
}

class _SalesReturnReceiptDialogState extends State<_SalesReturnReceiptDialog> {
  late Warehouse? _warehouse = widget.warehouses.isEmpty
      ? null
      : widget.warehouses.first;
  late DateTime _receiptDate = DateTime.now();
  late final Map<String, TextEditingController> _quantities = {
    for (final line in widget.details.lines)
      line.item.id: TextEditingController(
        text: _quantity(
          (line.item.quantity - line.receivedQuantity).clamp(
            0,
            line.item.quantity,
          ),
        ),
      ),
  };
  String? _error;

  @override
  void dispose() {
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _receiptDate,
      firstDate: DateTime(_receiptDate.year - 5),
      lastDate: DateTime(_receiptDate.year + 1),
    );
    if (picked != null) setState(() => _receiptDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.physicalReceipt),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<Warehouse>(
                initialValue: _warehouse,
                decoration: InputDecoration(
                  labelText: l10n.quarantineWarehouse,
                ),
                items: widget.warehouses
                    .map(
                      (warehouse) => DropdownMenuItem(
                        value: warehouse,
                        child: Text(warehouse.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _warehouse = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${l10n.receiptDate}: ${_date(_receiptDate)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                ),
              ),
              for (final line in widget.details.lines)
                if (line.item.quantity > line.receivedQuantity)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${line.itemName} • ${line.unitName}'),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _quantities[line.item.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.receivedQuantity,
                              helperText:
                                  '${l10n.returnableQuantity}: ${_quantity(line.item.quantity - line.receivedQuantity)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (_error != null) _InlineError(message: _error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.recordReceipt)),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_warehouse == null) {
      setState(() => _error = l10n.quarantineWarehouse);
      return;
    }
    final items = <SalesReturnReceiptItem>[];
    for (final line in widget.details.lines) {
      if (line.item.quantity <= line.receivedQuantity) continue;
      final quantity = double.tryParse(_quantities[line.item.id]!.text.trim());
      final remaining = line.item.quantity - line.receivedQuantity;
      if (quantity == null ||
          !quantity.isFinite ||
          quantity <= 0 ||
          quantity > remaining + 0.000001) {
        setState(() => _error = l10n.invalidReturnQuantity);
        return;
      }
      items.add(
        SalesReturnReceiptItem(
          salesReturnItemId: line.item.id,
          quantity: quantity,
        ),
      );
    }
    if (items.isEmpty) {
      setState(() => _error = l10n.invalidReturnQuantity);
      return;
    }
    Navigator.pop(
      context,
      _ReceiptRequest(warehouse: _warehouse!, date: _receiptDate, items: items),
    );
  }
}

class _SalesReturnInspectionDialog extends StatefulWidget {
  const _SalesReturnInspectionDialog({required this.details});
  final SalesReturnWorkflowDetails details;

  @override
  State<_SalesReturnInspectionDialog> createState() =>
      _SalesReturnInspectionDialogState();
}

class _SalesReturnInspectionDialogState
    extends State<_SalesReturnInspectionDialog> {
  late final Map<String, TextEditingController> _accepted = {
    for (final line in widget.details.lines)
      line.item.id: TextEditingController(
        text: _quantity(line.receivedQuantity),
      ),
  };
  late final Map<String, TextEditingController> _rejected = {
    for (final line in widget.details.lines)
      line.item.id: TextEditingController(text: '0'),
  };
  String? _error;

  @override
  void dispose() {
    for (final controller in [..._accepted.values, ..._rejected.values]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.qualityInspection),
      content: SizedBox(
        width: 780,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final line in widget.details.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.itemName} • ${line.unitName}\n${l10n.receivedQuantity}: ${_quantity(line.receivedQuantity)}',
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _accepted[line.item.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.acceptedQuantity,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _rejected[line.item.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.rejectedQuantity,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(l10n.rejectedRemainQuarantined),
              if (_error != null) _InlineError(message: _error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.saveAndComplete)),
      ],
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final items = <QualityInspectionItem>[];
    for (final line in widget.details.lines) {
      final accepted = double.tryParse(_accepted[line.item.id]!.text.trim());
      final rejected = double.tryParse(_rejected[line.item.id]!.text.trim());
      final received = line.receivedQuantity;
      if (accepted == null ||
          rejected == null ||
          !accepted.isFinite ||
          !rejected.isFinite ||
          accepted < 0 ||
          rejected < 0 ||
          (accepted + rejected - received).abs() > 0.000001) {
        setState(() => _error = l10n.invalidReturnQuantity);
        return;
      }
      final item = line.item;
      items.add(
        QualityInspectionItem(
          id: 'quality-${item.id}-${DateTime.now().microsecondsSinceEpoch}',
          itemId: item.itemId,
          itemType: item.itemType,
          requestedQuantity: received,
          inspectedQuantity: received,
          acceptedQuantity: accepted,
          rejectedQuantity: rejected,
          sourceReturnItemId: item.id,
          productId: item.itemId,
          variantId: item.variantId,
          inventoryIdentityKind: item.inventoryIdentityKind,
          identitySnapshotStatus: item.identitySnapshotStatus,
          unitId: item.unitId,
          baseUnitId: item.baseUnitId ?? item.unitId,
          unitConversionFactor: item.unitConversionFactor,
          result: rejected > 0
              ? QualityInspectionResult.rejected
              : QualityInspectionResult.passed,
        ),
      );
    }
    Navigator.pop(context, items);
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.sm),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

String _returnStatusLabel(AppLocalizations l10n, ReturnStatus status) =>
    switch (status) {
      ReturnStatus.pending => l10n.pendingStatus,
      ReturnStatus.approved => l10n.approvedStatus,
      ReturnStatus.rejected => l10n.rejectedStatus,
      ReturnStatus.cancelled => l10n.cancelledStatus,
      ReturnStatus.completed => l10n.completedStatus,
      ReturnStatus.draft => l10n.draft,
    };

String _inspectionStatusLabel(
  AppLocalizations l10n,
  QualityInspectionStatus status,
) => switch (status) {
  QualityInspectionStatus.pending => l10n.pendingStatus,
  QualityInspectionStatus.inProgress => l10n.inProgressStatus,
  QualityInspectionStatus.completed => l10n.completedStatus,
  QualityInspectionStatus.rejected => l10n.rejectedStatus,
  QualityInspectionStatus.quarantined => l10n.quarantineWarehouse,
};

String _quantity(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
