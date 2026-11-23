import 'package:flutter/material.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/shared/widgets/furnexa_card.dart';
import 'package:furnexa/core/shared/widgets/furnexa_table.dart';
import 'package:furnexa/core/shared/widgets/furnexa_table_toolbar.dart';
import 'package:furnexa/core/theme/app_spacing.dart';
import 'package:furnexa/features/returns_quality/data/datasources/returns_quality_local_data_source.dart';
import 'package:furnexa/features/returns_quality/domain/entities/returns_quality_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class PurchaseReturnsPage extends StatefulWidget {
  const PurchaseReturnsPage({
    super.key,
    required this.security,
    this.dataSource,
  });

  final SecurityLocalDataSource security;
  final ReturnsQualityLocalDataSource? dataSource;

  @override
  State<PurchaseReturnsPage> createState() => _PurchaseReturnsPageState();
}

class _PurchaseReturnsPageState extends State<PurchaseReturnsPage> {
  late final ReturnsQualityLocalDataSource _dataSource =
      widget.dataSource ?? ReturnsQualityLocalDataSource(null, widget.security);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  List<PurchaseReturnWorkflowDetails> _returns = [];
  List<Map<String, Object?>> _suppliers = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;
  String? _supplierFilter;
  DateTimeRange? _dateRange;
  int _page = 0;
  int _pageSize = 10;

  bool get _canEdit => widget.security.can('RETURNS_EDIT');
  bool get _canQualityEdit => widget.security.can('QUALITY_EDIT');

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
      final headers = await _dataSource.purchaseReturns();
      final details = await Future.wait(
        headers.map((value) => _dataSource.purchaseReturnDetails(value.id)),
      );
      final suppliers = await _dataSource.purchaseReturnSuppliers();
      if (!mounted) return;
      setState(() {
        _returns = details;
        _suppliers = suppliers;
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

  String _workflowStatus(PurchaseReturnWorkflowDetails detail) {
    final value = detail.purchaseReturn;
    if (value.status == ReturnStatus.completed) return 'COMPLETED';
    if (value.status == ReturnStatus.rejected) return 'REJECTED';
    if (value.status == ReturnStatus.cancelled) return 'CANCELLED';
    if (value.status == ReturnStatus.approved) {
      return detail.handovers.isEmpty ? 'APPROVED' : 'PARTIALLY_HANDED_OVER';
    }
    if (detail.receipts.isEmpty) return 'PENDING_RECEIPT';
    if (!detail.hasInspectionRecords || !detail.receiptQcComplete) {
      return 'PENDING_QC';
    }
    return 'PENDING_APPROVAL';
  }

  String _statusLabel(AppLocalizations l10n, String status) => switch (status) {
    'COMPLETED' => l10n.completedStatus,
    'REJECTED' => l10n.rejectedStatus,
    'CANCELLED' => l10n.cancelledStatus,
    'APPROVED' => l10n.awaitingHandover,
    'PARTIALLY_HANDED_OVER' => l10n.partiallyHandedOver,
    'PENDING_RECEIPT' => l10n.awaitingReceipt,
    'PENDING_QC' => l10n.awaitingInspection,
    _ => l10n.awaitingApproval,
  };

  List<PurchaseReturnWorkflowDetails> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _returns.where((detail) {
      final matchesQuery =
          query.isEmpty ||
          detail.purchaseReturn.returnNumber.toLowerCase().contains(query) ||
          detail.supplierName.toLowerCase().contains(query) ||
          detail.purchaseOrderNumber.toLowerCase().contains(query);
      final matchesStatus =
          _statusFilter == null || _workflowStatus(detail) == _statusFilter;
      final matchesSupplier =
          _supplierFilter == null ||
          detail.purchaseReturn.supplierId == _supplierFilter;
      final matchesDate =
          _dateRange == null ||
          (!detail.purchaseReturn.returnDate.isBefore(_dateRange!.start) &&
              !detail.purchaseReturn.returnDate.isAfter(
                DateTime(
                  _dateRange!.end.year,
                  _dateRange!.end.month,
                  _dateRange!.end.day,
                  23,
                  59,
                  59,
                  999,
                ),
              ));
      return matchesQuery && matchesStatus && matchesSupplier && matchesDate;
    }).toList();
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PurchaseReturnCreatePage(
          security: widget.security,
          dataSource: _dataSource,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _open(PurchaseReturnWorkflowDetails detail) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _PurchaseReturnDetailsPage(
          returnId: detail.purchaseReturn.id,
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
        .map(
          (detail) => {
            'id': detail.purchaseReturn.id,
            'reference': detail.purchaseReturn.returnNumber,
            'supplier': detail.supplierName,
            'order': detail.purchaseOrderNumber,
            'warehouse': detail.warehouseName,
            'date': _date(detail.purchaseReturn.returnDate),
            'requested': _sum(
              detail.lines.map((line) => line.requestedQuantity),
            ),
            'received': _sum(detail.lines.map((line) => line.receivedQuantity)),
            'status': _statusLabel(l10n, _workflowStatus(detail)),
          },
        )
        .toList();

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
                            l10n.purchaseReturns,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(l10n.purchaseReturnsDescription),
                        ],
                      ),
                    ),
                    if (_canEdit)
                      FurnexaButton(
                        label: l10n.createPurchaseReturn,
                        icon: Icons.add,
                        onPressed: _create,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
                      title: l10n.awaitingReceipt,
                      value:
                          '${_returns.where((value) => _workflowStatus(value) == 'PENDING_RECEIPT').length}',
                      icon: Icons.move_to_inbox_outlined,
                    ),
                    if (widget.security.can('QUALITY_VIEW') || _canQualityEdit)
                      FurnexaKpiCard(
                        title: l10n.awaitingInspection,
                        value:
                            '${_returns.where((value) => _workflowStatus(value) == 'PENDING_QC').length}',
                        icon: Icons.fact_check_outlined,
                      ),
                    FurnexaKpiCard(
                      title: l10n.awaitingApproval,
                      value:
                          '${_returns.where((value) => _workflowStatus(value) == 'PENDING_APPROVAL').length}',
                      icon: Icons.rule_folder_outlined,
                    ),
                    FurnexaKpiCard(
                      title: l10n.awaitingHandover,
                      value:
                          '${_returns.where((value) => _workflowStatus(value) == 'APPROVED' || _workflowStatus(value) == 'PARTIALLY_HANDED_OVER').length}',
                      icon: Icons.local_shipping_outlined,
                    ),
                    FurnexaKpiCard(
                      title: l10n.completedStatus,
                      value:
                          '${_returns.where((value) => value.purchaseReturn.status == ReturnStatus.completed).length}',
                      icon: Icons.task_alt_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                FurnexaTableToolbar(
                  title: l10n.purchaseReturns,
                  count: filtered.length,
                  search: SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() => _page = 0),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.searchPurchaseReturns,
                        isDense: true,
                      ),
                    ),
                  ),
                  filters: [
                    DropdownButton<String?>(
                      value: _supplierFilter,
                      hint: Text(l10n.supplierLabel),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.allSuppliers),
                        ),
                        for (final supplier in _suppliers)
                          DropdownMenuItem<String?>(
                            value: supplier['id'] as String,
                            child: Text(supplier['name'] as String),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _supplierFilter = value;
                        _page = 0;
                      }),
                    ),
                    DropdownButton<String?>(
                      value: _statusFilter,
                      hint: Text(l10n.allStatuses),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(l10n.allStatuses),
                        ),
                        for (final status in const [
                          'PENDING_RECEIPT',
                          'PENDING_QC',
                          'PENDING_APPROVAL',
                          'APPROVED',
                          'PARTIALLY_HANDED_OVER',
                          'COMPLETED',
                          'REJECTED',
                          'CANCELLED',
                        ])
                          DropdownMenuItem<String?>(
                            value: status,
                            child: Text(_statusLabel(l10n, status)),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _statusFilter = value;
                        _page = 0;
                      }),
                    ),
                    IconButton(
                      tooltip: l10n.returnDate,
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
                const SizedBox(height: AppSpacing.sm),
                FurnexaDataTable(
                    verticalScrollable: false,
                    columns: [
                      FurnexaTableColumn(
                        key: 'reference',
                        label: l10n.purchaseReturnReference,
                        flex: 2,
                      ),
                      FurnexaTableColumn(
                        key: 'supplier',
                        label: l10n.supplierLabel,
                        flex: 2,
                      ),
                      FurnexaTableColumn(
                        key: 'order',
                        label: l10n.originalPurchaseOrder,
                        flex: 2,
                      ),
                      FurnexaTableColumn(
                        key: 'warehouse',
                        label: l10n.sourceWarehouse,
                        flex: 2,
                      ),
                      FurnexaTableColumn(key: 'date', label: l10n.returnDate),
                      FurnexaTableColumn(
                        key: 'requested',
                        label: l10n.requestedReturnQuantity,
                      ),
                      FurnexaTableColumn(
                        key: 'received',
                        label: l10n.receivedQuantity,
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
                    emptyTitle: l10n.noPurchaseReturns,
                    emptyDescription: l10n.noPurchaseReturnsDescription,
                    actionsBuilder: (row) => [
                      FurnexaTableAction(
                        label: l10n.returnDetails,
                        icon: Icons.open_in_new,
                        onPressed: () {
                          final detail = _returns.firstWhere(
                            (value) => value.purchaseReturn.id == row['id'],
                          );
                          _open(detail);
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
}

class _PurchaseReturnCreatePage extends StatefulWidget {
  const _PurchaseReturnCreatePage({
    required this.security,
    required this.dataSource,
  });

  final SecurityLocalDataSource security;
  final ReturnsQualityLocalDataSource dataSource;

  @override
  State<_PurchaseReturnCreatePage> createState() =>
      _PurchaseReturnCreatePageState();
}

class _PurchaseReturnCreatePageState extends State<_PurchaseReturnCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _reasonController = TextEditingController();
  final _notesController = TextEditingController();
  List<Map<String, Object?>> _suppliers = [];
  List<PurchaseReturnSourceOrder> _orders = [];
  List<PurchaseReturnSourceLine> _lines = [];
  final Set<String> _selected = {};
  final Map<String, TextEditingController> _quantities = {};
  String? _supplierId;
  String? _orderId;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final id = DateTime.now().microsecondsSinceEpoch;
    _referenceController.text = 'PR-$id';
    _loadSuppliers();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    for (final controller in _quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _lineKey(PurchaseReturnSourceLine line) =>
      '${line.receiptId}:${line.purchaseOrderItemId}:${line.variantId ?? ''}';

  Future<void> _loadSuppliers() async {
    try {
      final rows = await widget.dataSource.purchaseReturnSuppliers();
      if (mounted) setState(() => _suppliers = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _selectSupplier(String? value) async {
    setState(() {
      _supplierId = value;
      _orderId = null;
      _lines = [];
      _orders = [];
      _selected.clear();
    });
    if (value == null) return;
    try {
      final orders = await widget.dataSource.purchaseReturnSourceOrders(
        supplierId: value,
      );
      if (mounted) setState(() => _orders = orders);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _selectOrder(String? value) async {
    setState(() {
      _orderId = value;
      _lines = [];
      _selected.clear();
      _loading = value != null;
      _error = null;
    });
    if (value == null) return;
    try {
      final lines = await widget.dataSource.purchaseReturnSourceLines(value);
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _loading = false;
        for (final line in lines) {
          final key = _lineKey(line);
          _quantities.putIfAbsent(
            key,
            () => TextEditingController(
              text: line.returnableQuantity.toStringAsFixed(3),
            ),
          );
        }
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _loading = false;
        });
    }
  }

  void _toggleLine(PurchaseReturnSourceLine line, bool? selected) {
    if (selected != true) {
      setState(() => _selected.remove(_lineKey(line)));
      return;
    }
    final selectedWarehouses = _lines
        .where((candidate) => _selected.contains(_lineKey(candidate)))
        .map((candidate) => candidate.sourceWarehouseId)
        .toSet();
    if (selectedWarehouses.isNotEmpty &&
        !selectedWarehouses.contains(line.sourceWarehouseId)) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.singleSourceWarehouseRequired)),
      );
      return;
    }
    setState(() => _selected.add(_lineKey(line)));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty || _orderId == null || _supplierId == null) {
      setState(() => _error = l10n.selectReturnItem);
      return;
    }
    final chosenLines = _lines
        .where((line) => _selected.contains(_lineKey(line)))
        .toList();
    final warehouseIds = chosenLines
        .map((line) => line.sourceWarehouseId)
        .toSet();
    if (warehouseIds.length != 1) {
      setState(() => _error = l10n.singleSourceWarehouseRequired);
      return;
    }
    final items = <PurchaseReturnItem>[];
    for (final line in chosenLines) {
      final quantity = double.tryParse(_quantities[_lineKey(line)]!.text);
      if (quantity == null ||
          !quantity.isFinite ||
          quantity <= 0 ||
          quantity > line.returnableQuantity + 0.000001) {
        setState(() => _error = l10n.invalidReturnQuantity);
        return;
      }
      items.add(
        PurchaseReturnItem(
          id: '${_referenceController.text}:${items.length + 1}',
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
          unitPrice: line.unitPrice,
          sourceReceiptId: line.receiptId,
          purchaseOrderItemId: line.purchaseOrderItemId,
        ),
      );
    }
    final order = _orders.firstWhere((value) => value.id == _orderId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.returnDetails),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n.purchaseReturnReference}: ${_referenceController.text.trim()}',
                ),
                Text(
                  '${l10n.supplierLabel}: ${_suppliers.firstWhere((value) => value['id'] == _supplierId)['name']}',
                ),
                Text('${l10n.originalPurchaseOrder}: ${order.orderNumber}'),
                Text(
                  '${l10n.sourceWarehouse}: ${chosenLines.first.sourceWarehouseId}',
                ),
                Text(
                  '${l10n.purchaseReturnReason}: ${_reasonController.text.trim()}',
                ),
                const Divider(),
                for (var index = 0; index < chosenLines.length; index++)
                  Text(
                    '${chosenLines[index].itemName}: ${items[index].quantity} ${chosenLines[index].unitName}',
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.purchaseReturnCreationNoPosting),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.submitReturn),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.dataSource.createPurchaseReturn(
        id: _referenceController.text.trim(),
        returnNumber: _referenceController.text.trim(),
        purchaseOrderId: order.id,
        supplierId: _supplierId!,
        warehouseId: warehouseIds.single,
        returnDate: DateTime.now(),
        reason: _reasonController.text.trim(),
        notes: _notesController.text.trim(),
        items: items,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.purchaseReturnCreated)));
      Navigator.of(context).pop(true);
    } catch (error) {
      setState(() => _error = _cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedWarehouse = _lines
        .where((line) => _selected.contains(_lineKey(line)))
        .map((line) => line.sourceWarehouseId)
        .firstOrNull;
    final visibleLines = selectedWarehouse == null
        ? _lines
        : _lines
              .where((line) => line.sourceWarehouseId == selectedWarehouse)
              .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPurchaseReturn)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              DropdownButtonFormField<String>(
                value: _supplierId,
                decoration: InputDecoration(labelText: l10n.supplierLabel),
                items: [
                  for (final supplier in _suppliers)
                    DropdownMenuItem(
                      value: supplier['id'] as String,
                      child: Text(supplier['name'] as String),
                    ),
                ],
                onChanged: _selectSupplier,
                validator: (value) =>
                    value == null ? l10n.chooseSupplier : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: _orderId,
                decoration: InputDecoration(
                  labelText: l10n.originalPurchaseOrder,
                ),
                items: [
                  for (final order in _orders)
                    DropdownMenuItem(
                      value: order.id,
                      child: Text(order.orderNumber),
                    ),
                ],
                onChanged: _selectOrder,
                validator: (value) =>
                    value == null ? l10n.choosePurchaseOrder : null,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading) const LinearProgressIndicator(),
              if (_lines.isNotEmpty) ...[
                Text(
                  l10n.returnItems,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final line in visibleLines)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: _selected.contains(_lineKey(line)),
                      onChanged: (value) => _toggleLine(line, value),
                    ),
                    title: Text(
                      '${line.itemName}${line.variantName == null ? '' : ' · ${line.variantName}'}',
                    ),
                    subtitle: Text(
                      '${l10n.purchaseReceiptSource}: ${line.receiptNumber} · ${l10n.sourceWarehouse}: ${line.sourceWarehouseId}\n${l10n.totalReceivedQuantity}: ${line.receivedQuantity} ${line.unitName} · ${l10n.alreadyReservedQuantity}: ${line.returnedBaseQuantity} · ${l10n.availableReturnQuantity}: ${line.returnableQuantity.toStringAsFixed(3)}',
                    ),
                    trailing: SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _quantities[_lineKey(line)],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.requestedReturnQuantity,
                        ),
                        enabled: _selected.contains(_lineKey(line)),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: l10n.purchaseReturnReference,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.purchaseReturnReference
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: l10n.purchaseReturnReason,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.returnReasonRequired
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: l10n.purchaseReturnNotes,
                ),
                maxLines: 3,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FurnexaButton(
                  label: l10n.submitReturn,
                  icon: Icons.save_outlined,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseReturnDetailsPage extends StatefulWidget {
  const _PurchaseReturnDetailsPage({
    required this.returnId,
    required this.security,
    required this.dataSource,
  });

  final String returnId;
  final SecurityLocalDataSource security;
  final ReturnsQualityLocalDataSource dataSource;

  @override
  State<_PurchaseReturnDetailsPage> createState() =>
      _PurchaseReturnDetailsPageState();
}

class _PurchaseReturnDetailsPageState
    extends State<_PurchaseReturnDetailsPage> {
  PurchaseReturnWorkflowDetails? _details;
  bool _loading = true;
  String? _error;

  bool get _canEdit => widget.security.can('RETURNS_EDIT');
  bool get _canQualityEdit => widget.security.can('QUALITY_EDIT');
  bool get _canQualityView =>
      widget.security.can('QUALITY_VIEW') || _canQualityEdit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.dataSource.purchaseReturnDetails(
        widget.returnId,
      );
      if (mounted)
        setState(() {
          _details = detail;
          _loading = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
    }
  }

  Future<void> _recordReceipt(PurchaseReturnWorkflowDetails details) async {
    final l10n = AppLocalizations.of(context);
    final warehouses = await widget.dataSource
        .purchaseReturnQuarantineWarehouses();
    if (!mounted) return;
    if (warehouses.isEmpty) {
      setState(() => _error = l10n.chooseQuarantineWarehouse);
      return;
    }
    final controllers = <String, TextEditingController>{};
    for (final line in details.lines) {
      final remaining = line.requestedQuantity - line.receivedQuantity;
      if (remaining > 0) {
        controllers[line.item.id] = TextEditingController(
          text: remaining.toStringAsFixed(3),
        );
      }
    }
    String? warehouseId = warehouses.first['id'] as String;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.recordReceipt),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: warehouseId,
                    decoration: InputDecoration(
                      labelText: l10n.quarantineWarehouse,
                    ),
                    items: [
                      for (final warehouse in warehouses)
                        DropdownMenuItem(
                          value: warehouse['id'] as String,
                          child: Text(warehouse['name'] as String),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => warehouseId = value),
                  ),
                  for (final line in details.lines)
                    if (controllers.containsKey(line.item.id))
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: TextFormField(
                          controller: controllers[line.item.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                '${line.itemName} · ${l10n.remainingQuantity}: ${(line.requestedQuantity - line.receivedQuantity).toStringAsFixed(3)} ${line.unitName}',
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.recordReceipt),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true || warehouseId == null) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      return;
    }
    final receiptItems = <PurchaseReturnReceiptItem>[];
    for (final line in details.lines) {
      final controller = controllers[line.item.id];
      if (controller == null) continue;
      final quantity = double.tryParse(controller.text);
      if (quantity == null ||
          !quantity.isFinite ||
          quantity < 0 ||
          quantity >
              line.requestedQuantity - line.receivedQuantity + 0.000001) {
        setState(() => _error = l10n.receiptQuantityInvalid);
        for (final value in controllers.values) {
          value.dispose();
        }
        return;
      }
      if (quantity == 0) continue;
      receiptItems.add(
        PurchaseReturnReceiptItem(
          purchaseReturnItemId: line.item.id,
          quantity: quantity,
        ),
      );
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (receiptItems.isEmpty) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    try {
      await widget.dataSource.receivePurchaseReturn(
        returnId: details.purchaseReturn.id,
        receiptId: 'pr-receipt-$stamp',
        receiptNumber: 'PRR-$stamp',
        quarantineWarehouseId: warehouseId!,
        receiptDate: DateTime.now(),
        items: receiptItems,
      );
      await _load();
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _recordInspection(
    PurchaseReturnWorkflowDetails details,
    PurchaseReturnReceiptRecord receipt,
  ) async {
    final l10n = AppLocalizations.of(context);
    if (receipt.items.any((item) => item.id == null)) {
      setState(() => _error = l10n.actionFailed);
      return;
    }
    final inspected = <String, TextEditingController>{};
    final accepted = <String, TextEditingController>{};
    final rejected = <String, TextEditingController>{};
    final quarantined = <String, TextEditingController>{};
    for (final receiptItem in receipt.items) {
      final remaining = receiptItem.quantity - receiptItem.inspectedQuantity;
      if (remaining <= 0) continue;
      final receiptItemId = receiptItem.id!;
      inspected[receiptItemId] = TextEditingController(
        text: remaining.toStringAsFixed(3),
      );
      accepted[receiptItemId] = TextEditingController(
        text: remaining.toStringAsFixed(3),
      );
      rejected[receiptItemId] = TextEditingController(text: '0');
      quarantined[receiptItemId] = TextEditingController(text: '0');
    }
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.qualityInspection),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final receiptItem in receipt.items)
                  if (inspected.containsKey(receiptItem.id!))
                    Builder(
                      builder: (context) {
                        final line = details.lines.firstWhere(
                          (value) =>
                              value.item.id == receiptItem.purchaseReturnItemId,
                        );
                        final remaining =
                            receiptItem.quantity -
                            receiptItem.inspectedQuantity;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${line.itemName} · ${l10n.remainingQuantity}: ${remaining.toStringAsFixed(3)} ${line.unitName}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: inspected[receiptItem.id!],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: l10n.inspectedQuantity,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: TextField(
                                      controller: accepted[receiptItem.id!],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: l10n.acceptedQuantity,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: TextField(
                                      controller: rejected[receiptItem.id!],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: l10n.rejectedQuantity,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: TextField(
                                      controller: quarantined[receiptItem.id!],
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: l10n.quarantinedQuantity,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.completeInspection),
          ),
        ],
      ),
    );
    if (shouldSave != true) {
      for (final controller in [
        ...inspected.values,
        ...accepted.values,
        ...rejected.values,
        ...quarantined.values,
      ]) {
        controller.dispose();
      }
      return;
    }
    final items = <QualityInspectionItem>[];
    for (final receiptItem in receipt.items) {
      final receiptItemId = receiptItem.id!;
      final line = details.lines.firstWhere(
        (value) => value.item.id == receiptItem.purchaseReturnItemId,
      );
      final remaining = receiptItem.quantity - receiptItem.inspectedQuantity;
      if (remaining <= 0) continue;
      final inspectedQty = double.tryParse(inspected[receiptItemId]!.text);
      final acceptQty = double.tryParse(accepted[receiptItemId]!.text);
      final rejectQty = double.tryParse(rejected[receiptItemId]!.text);
      final quarantineQty = double.tryParse(quarantined[receiptItemId]!.text);
      if (inspectedQty == null ||
          acceptQty == null ||
          rejectQty == null ||
          quarantineQty == null ||
          !inspectedQty.isFinite ||
          !acceptQty.isFinite ||
          !rejectQty.isFinite ||
          !quarantineQty.isFinite ||
          inspectedQty <= 0 ||
          inspectedQty > remaining + 0.000001 ||
          acceptQty < 0 ||
          rejectQty < 0 ||
          quarantineQty < 0 ||
          (acceptQty + rejectQty + quarantineQty - inspectedQty).abs() >
              0.000001) {
        setState(() => _error = l10n.inspectionPendingForReceipt);
        for (final controller in [
          ...inspected.values,
          ...accepted.values,
          ...rejected.values,
          ...quarantined.values,
        ]) {
          controller.dispose();
        }
        return;
      }
      items.add(
        QualityInspectionItem(
          id: 'qi:${receipt.id}:$receiptItemId',
          itemId: line.item.itemId,
          itemType: line.item.itemType,
          sourceReturnItemId: line.item.id,
          purchaseReturnReceiptItemId: receiptItemId,
          productId: line.item.itemId,
          variantId: line.item.variantId,
          inventoryIdentityKind: line.item.inventoryIdentityKind,
          identitySnapshotStatus: line.item.identitySnapshotStatus,
          unitId: line.item.unitId,
          baseUnitId: line.item.baseUnitId ?? line.item.unitId,
          unitConversionFactor: line.item.unitConversionFactor,
          requestedQuantity: remaining,
          inspectedQuantity: inspectedQty,
          acceptedQuantity: acceptQty,
          rejectedQuantity: rejectQty,
          quarantinedQuantity: quarantineQty,
        ),
      );
    }
    for (final controller in [
      ...inspected.values,
      ...accepted.values,
      ...rejected.values,
      ...quarantined.values,
    ]) {
      controller.dispose();
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    try {
      final session = widget.security.session;
      await widget.dataSource.createQualityInspection(
        id: 'pr-qi-$stamp',
        inspectionNumber: 'PRQI-$stamp',
        sourceType: 'PURCHASE_RETURN',
        sourceId: details.purchaseReturn.id,
        purchaseReturnReceiptId: receipt.id,
        warehouseId: receipt.warehouseId,
        itemId: items.first.itemId,
        itemType: items.first.itemType,
        inspectedBy: session?.user.id,
        inspectionDate: DateTime.now(),
        status: QualityInspectionStatus.completed,
        items: items,
      );
      await _load();
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _approve(PurchaseReturnWorkflowDetails details) async {
    final l10n = AppLocalizations.of(context);
    final noteController = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reviewApproval),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.approvalRequiresReceiptAndQc),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteController,
              decoration: InputDecoration(labelText: l10n.decisionNotes),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.approveReturn),
          ),
        ],
      ),
    );
    if (approved != true) {
      noteController.dispose();
      return;
    }
    try {
      await widget.dataSource.updatePurchaseReturnStatus(
        details.purchaseReturn.id,
        ReturnStatus.approved,
        decisionNotes: noteController.text,
      );
      await _load();
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _decide(
    PurchaseReturnWorkflowDetails details,
    ReturnStatus status,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          status == ReturnStatus.rejected
              ? l10n.rejectedStatus
              : l10n.cancelledStatus,
        ),
        content: Text(l10n.approvalRequiresReceiptAndQc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.back),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.dataSource.updatePurchaseReturnStatus(
        details.purchaseReturn.id,
        status,
      );
      await _load();
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _handover(PurchaseReturnWorkflowDetails details) async {
    final l10n = AppLocalizations.of(context);
    if (details.receipts.any(
      (receipt) => receipt.items.any((item) => item.id == null),
    )) {
      setState(() => _error = l10n.actionFailed);
      return;
    }
    final controllers = <String, TextEditingController>{};
    for (final receipt in details.receipts) {
      for (final receiptItem in receipt.items) {
        final receiptItemId = receiptItem.id!;
        if (receiptItem.inspectionStatus !=
            QualityInspectionStatus.completed.value) {
          continue;
        }
        final remaining =
            receiptItem.acceptedQuantity - receiptItem.handedOverQuantity;
        if (remaining > 0)
          controllers[receiptItemId] = TextEditingController(
            text: remaining.toStringAsFixed(3),
          );
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.supplierHandover),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.handoverOnlyPosting),
                Text(l10n.confirmHandover),
                for (final receipt in details.receipts)
                  for (final receiptItem in receipt.items)
                    if (controllers.containsKey(receiptItem.id!))
                      Builder(
                        builder: (context) {
                          final line = details.lines.firstWhere(
                            (value) =>
                                value.item.id ==
                                receiptItem.purchaseReturnItemId,
                          );
                          return TextField(
                            controller: controllers[receiptItem.id!],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  '${line.itemName} · ${l10n.availableReturnQuantity}: ${controllers[receiptItem.id!]!.text} ${line.unitName}',
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.recordHandover),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      return;
    }
    final items = <PurchaseReturnHandoverItem>[];
    for (final receipt in details.receipts) {
      for (final receiptItem in receipt.items) {
        final receiptItemId = receiptItem.id!;
        final controller = controllers[receiptItemId];
        if (controller == null) continue;
        final quantity = double.tryParse(controller.text);
        final remaining =
            receiptItem.acceptedQuantity - receiptItem.handedOverQuantity;
        if (quantity == null ||
            !quantity.isFinite ||
            quantity <= 0 ||
            quantity > remaining + 0.000001) {
          setState(() => _error = l10n.handoverQuantityInvalid);
          for (final value in controllers.values) {
            value.dispose();
          }
          return;
        }
        items.add(
          PurchaseReturnHandoverItem(
            purchaseReturnItemId: receiptItem.purchaseReturnItemId,
            purchaseReturnReceiptItemId: receiptItemId,
            quantity: quantity,
          ),
        );
      }
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (items.isEmpty) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    try {
      await widget.dataSource.recordPurchaseReturnHandover(
        handoverId: 'pr-ho-$stamp',
        handoverNumber: 'PRH-$stamp',
        returnId: details.purchaseReturn.id,
        supplierId: details.purchaseReturn.supplierId,
        quarantineWarehouseId: details.receipts.first.warehouseId,
        handoverDate: DateTime.now(),
        items: items,
      );
      await _load();
    } catch (error) {
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _statusLabel(AppLocalizations l10n, ReturnStatus status) =>
      switch (status) {
        ReturnStatus.pending => l10n.pendingStatus,
        ReturnStatus.approved => l10n.approvedStatus,
        ReturnStatus.rejected => l10n.rejectedStatus,
        ReturnStatus.cancelled => l10n.cancelledStatus,
        ReturnStatus.completed => l10n.completedStatus,
        ReturnStatus.draft => l10n.draft,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = _details;
    if (_loading && details == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (details == null)
      return Scaffold(
        appBar: AppBar(title: Text(l10n.returnDetails)),
        body: Center(child: Text(_error ?? l10n.tableLoadFailed)),
      );
    final value = details.purchaseReturn;
    final hasReceipts = details.receipts.isNotEmpty;
    final hasQc = details.receiptQcComplete;
    final canApprove =
        _canEdit &&
        value.status == ReturnStatus.pending &&
        hasReceipts &&
        hasQc;
    final canReceive = _canEdit && value.status == ReturnStatus.pending;
    final canHandover =
        _canEdit && value.status == ReturnStatus.approved && hasQc;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.returnDetails}: ${value.returnNumber}'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (canReceive)
                        OutlinedButton.icon(
                          onPressed: () => _recordReceipt(details),
                          icon: const Icon(Icons.move_to_inbox_outlined),
                          label: Text(l10n.recordReceipt),
                        ),
                      if (_canQualityEdit &&
                          value.status == ReturnStatus.pending)
                        for (final receipt in details.receipts)
                          if (receipt.items.any(
                            (item) =>
                                item.inspectedQuantity + 0.000001 <
                                item.quantity,
                          ))
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _recordInspection(details, receipt),
                              icon: const Icon(Icons.fact_check_outlined),
                              label: Text(
                                '${l10n.startInspection}: ${receipt.receiptNumber}',
                              ),
                            ),
                      if (canApprove)
                        FilledButton.icon(
                          onPressed: () => _approve(details),
                          icon: const Icon(Icons.check),
                          label: Text(l10n.approveReturn),
                        ),
                      if (_canEdit &&
                          value.status == ReturnStatus.pending &&
                          !hasReceipts) ...[
                        OutlinedButton(
                          onPressed: () =>
                              _decide(details, ReturnStatus.rejected),
                          child: Text(l10n.rejectedStatus),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              _decide(details, ReturnStatus.cancelled),
                          child: Text(l10n.cancelledStatus),
                        ),
                      ],
                      if (canHandover)
                        FilledButton.icon(
                          onPressed: () => _handover(details),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: Text(l10n.recordHandover),
                        ),
                    ],
                  ),
                  if (value.status == ReturnStatus.pending &&
                      (!hasReceipts || !hasQc))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(l10n.approvalRequiresReceiptAndQc),
                    ),
                  if (value.status == ReturnStatus.approved)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Text(l10n.handoverOnlyPosting),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  _section(context, l10n.information, [
                    _detailRow(
                      l10n.purchaseReturnReference,
                      value.returnNumber,
                    ),
                    _detailRow(l10n.supplierLabel, details.supplierName),
                    _detailRow(
                      l10n.originalPurchaseOrder,
                      details.purchaseOrderNumber,
                    ),
                    _detailRow(l10n.sourceWarehouse, details.warehouseName),
                    _detailRow(l10n.returnDate, _date(value.returnDate)),
                    _detailRow(l10n.status, _statusLabel(l10n, value.status)),
                    if (value.approvedAt != null)
                      _detailRow(
                        l10n.approvalStage,
                        '${_date(value.approvedAt!)} · ${value.approvedBy ?? ''}',
                      ),
                    if (value.approvalNotes?.isNotEmpty == true)
                      _detailRow(l10n.approvalStage, value.approvalNotes!),
                    _detailRow(l10n.purchaseReturnReason, value.reason ?? ''),
                    _detailRow(l10n.purchaseReturnNotes, value.notes ?? ''),
                  ]),
                  _section(context, l10n.returnItems, [
                    for (final line in details.lines)
                      _detailRow(
                        line.itemName,
                        '${l10n.requestedReturnQuantity}: ${line.requestedQuantity} ${line.unitName} · ${l10n.receivedQuantity}: ${line.receivedQuantity} · ${l10n.inspectedQuantity}: ${line.inspectedQuantity} · ${l10n.acceptedQuantity}: ${line.acceptedQuantity} · ${l10n.rejectedQuantity}: ${line.rejectedQuantity} · ${l10n.quarantinedQuantity}: ${line.quarantinedQuantity} · ${l10n.supplierHandover}: ${line.handedOverQuantity}',
                      ),
                  ]),
                  _section(context, l10n.physicalReceipt, [
                    if (details.receipts.isEmpty) Text(l10n.noReceiptYet),
                    for (final receipt in details.receipts) ...[
                      _detailRow(
                        '${l10n.purchaseReceiptSource}: ${receipt.receiptNumber}',
                        '${receipt.warehouseName} · ${_date(receipt.receiptDate)}',
                      ),
                      for (final item in receipt.items)
                        _detailRow(
                          item.purchaseReturnItemId,
                          '${item.quantity} · ${item.movementReference ?? ''}',
                        ),
                    ],
                  ]),
                  _section(context, l10n.qualityInspection, [
                    if (!details.hasInspectionRecords)
                      Text(l10n.noInspectionYet),
                    if (details.hasInspectionRecords && !_canQualityView)
                      for (final line in details.lines)
                        _detailRow(
                          line.itemName,
                          '${l10n.inspectedQuantity}: ${line.inspectedQuantity} · ${l10n.acceptedQuantity}: ${line.acceptedQuantity} · ${l10n.rejectedQuantity}: ${line.rejectedQuantity} · ${l10n.quarantinedQuantity}: ${line.quarantinedQuantity}',
                        ),
                    if (_canQualityView)
                      for (final inspection in details.inspections)
                        _detailRow(
                          inspection.inspectionNumber,
                          '${_statusLabel(l10n, inspection.status == QualityInspectionStatus.completed ? ReturnStatus.completed : ReturnStatus.pending)} · ${_date(inspection.inspectionDate)}',
                        ),
                  ]),
                  _section(context, l10n.supplierHandover, [
                    if (details.handovers.isEmpty) Text(l10n.noRelatedRecords),
                    for (final handover in details.handovers) ...[
                      _detailRow(
                        handover.handoverNumber,
                        _date(handover.handoverDate),
                      ),
                      for (final item in handover.items)
                        _detailRow(
                          l10n.inventoryMovement,
                          item.movementReference ??
                              item.purchaseReturnReceiptItemId,
                        ),
                      if (handover.journalNumber != null)
                        _detailRow(
                          l10n.accountingJournal,
                          handover.journalNumber!,
                        ),
                    ],
                  ]),
                ],
              ),
      ),
    );
  }
}

Widget _section(BuildContext context, String title, List<Widget> children) =>
    Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          ...children,
        ],
      ),
    );

Widget _detailRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 190, child: Text(label)),
      Expanded(child: Text(value)),
    ],
  ),
);

double _sum(Iterable<double> values) =>
    values.fold(0, (sum, value) => sum + value);

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
