import 'dart:async';

import 'package:flutter/material.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/core/shared/widgets/furnexa_card.dart';
import 'package:furnexa/core/shared/widgets/furnexa_table.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/warehouses_stock/data/repositories/warehouses_stock_repository_impl.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/warehouses_stock/domain/repositories/warehouses_stock_repository.dart';

class WarehousesStockPage extends StatefulWidget {
  const WarehousesStockPage({super.key, this.initialWarehouseId});

  final String? initialWarehouseId;
  @override
  State<WarehousesStockPage> createState() => _WarehousesStockPageState();
}

class _WarehousesStockPageState extends State<WarehousesStockPage> {
  final WarehousesStockRepository _repository = WarehousesStockRepositoryImpl();
  List<Warehouse> _warehouses = [];
  List<StockItemOption> _items = [];
  List<StockLine> _stock = [];
  String? _warehouseId;
  String _query = '';
  StockItemType? _itemType;
  bool _loading = true;
  bool _hasLoaded = false;
  bool _loadFailed = false;
  int _loadRequestId = 0;
  int _lastRepositoryWarehouseCount = 0;
  int _lastRepositoryStockCount = 0;

  @override
  void initState() {
    super.initState();
    _warehouseId = widget.initialWarehouseId;
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'warehouse',
        layer: 'pageState',
        state: 'initial',
        reason: 'initState initialized empty warehouse selector state',
        pageStateCount: _warehouses.length,
        requestId: _loadRequestId,
      ),
    );
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'stock',
        layer: 'pageState',
        state: 'initial',
        reason: 'initState initialized empty local state before the first load',
        pageStateCount: _stock.length,
        requestId: _loadRequestId,
      ),
    );
    _load();
  }

  Future<bool> _load() async {
    final requestId = ++_loadRequestId;
    final requestedWarehouseId = _warehouseId;
    final query = _query;
    final itemType = _itemType;
    if (mounted) _loadFailed = false;
    if (mounted && !_hasLoaded) setState(() => _loading = true);
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'warehouse',
        layer: 'viewModel',
        state: 'loading',
        reason: 'active warehouse selector load started',
        pageStateCount: _warehouses.length,
        requestId: requestId,
      ),
    );
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'stock',
        layer: 'viewModel',
        state: 'loading',
        reason: _hasLoaded
            ? 'refresh started; existing rows retained until latest request commits'
            : 'initial repository load started',
        pageStateCount: _stock.length,
        requestId: requestId,
      ),
    );
    try {
      final warehouses = await _repository.warehouses();
      final items = await _repository.activeItems();
      final stock = await _repository.stock(
        requestedWarehouseId,
        query: query,
        itemType: itemType,
      );
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'warehouse',
          layer: 'repository',
          state: warehouses.isEmpty ? 'empty' : 'success',
          reason: 'active warehouse repository Future completed',
          repositoryCount: warehouses.length,
          requestId: requestId,
        ),
      );
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'warehouse',
          layer: 'viewModel',
          state: warehouses.isEmpty ? 'empty' : 'success',
          reason: 'page load received the active warehouse result',
          repositoryCount: warehouses.length,
          viewModelCount: warehouses.length,
          requestId: requestId,
        ),
      );
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'stock',
          layer: 'repository',
          state: stock.isEmpty ? 'empty' : 'success',
          reason: 'stock repository Future completed',
          repositoryCount: stock.length,
          requestId: requestId,
        ),
      );
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'stock',
          layer: 'viewModel',
          state: stock.isEmpty ? 'empty' : 'success',
          reason: 'page load received the repository stock result',
          repositoryCount: stock.length,
          viewModelCount: stock.length,
          requestId: requestId,
        ),
      );
      if (!mounted) return false;
      if (requestId != _loadRequestId) {
        unawaited(
          FurnexaDatabaseDiagnostics.recordUiPipeline(
            feature: 'warehouse',
            layer: 'viewModel',
            state: 'loading',
            reason:
                'warehouse result discarded because a newer request ID exists',
            repositoryCount: warehouses.length,
            viewModelCount: warehouses.length,
            pageStateCount: _warehouses.length,
            requestId: requestId,
          ),
        );
        unawaited(
          FurnexaDatabaseDiagnostics.recordUiPipeline(
            feature: 'stock',
            layer: 'viewModel',
            state: 'loading',
            reason: 'result discarded because a newer request ID exists',
            repositoryCount: stock.length,
            viewModelCount: stock.length,
            pageStateCount: _stock.length,
            requestId: requestId,
          ),
        );
        return false;
      }
      _lastRepositoryWarehouseCount = warehouses.length;
      _lastRepositoryStockCount = stock.length;
      setState(() {
        _warehouses = warehouses;
        _items = items;
        _warehouseId = requestedWarehouseId ?? _warehouseId;
        _stock = stock;
        _hasLoaded = true;
      });
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'warehouse',
          layer: 'state',
          state: warehouses.isEmpty ? 'empty' : 'success',
          reason: 'setState committed the latest active warehouse result',
          repositoryCount: warehouses.length,
          viewModelCount: warehouses.length,
          emittedStateCount: _warehouses.length,
          pageStateCount: _warehouses.length,
          requestId: requestId,
        ),
      );
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'stock',
          layer: 'state',
          state: stock.isEmpty ? 'empty' : 'success',
          reason: 'setState committed the latest repository result',
          repositoryCount: stock.length,
          viewModelCount: stock.length,
          emittedStateCount: _stock.length,
          pageStateCount: _stock.length,
          requestId: requestId,
        ),
      );
      await FurnexaDatabaseDiagnostics.capture(
        source: 'page.warehousesStock.stateCommitted',
        stockWarehouseRepositoryRows: warehouses.length,
        stockRepositoryRows: stock.length,
        warehouseId: requestedWarehouseId,
        stockQuery: query,
        stockItemTypeFilter: itemType?.value,
        stageCounts: {
          'viewModelWarehouseRows': warehouses.length,
          'viewModelActiveItemRows': items.length,
          'viewModelStockRows': stock.length,
          'selectedWarehouseId': requestedWarehouseId,
          'loadRequestId': requestId,
          'committedToState': true,
        },
      );
      return true;
    } catch (error, stackTrace) {
      await FurnexaDatabaseDiagnostics.reportFailure(
        source: 'page.warehousesStock.load',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && requestId == _loadRequestId) _loadFailed = true;
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'warehouse',
          layer: 'state',
          state: 'error',
          reason:
              'a warehouse/stock repository dependency failed before state commit: $error',
          repositoryCount: _lastRepositoryWarehouseCount,
          pageStateCount: _warehouses.length,
          requestId: requestId,
        ),
      );
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'stock',
          layer: 'state',
          state: 'error',
          reason:
              'repository dependency threw before successful state commit: $error',
          repositoryCount: _lastRepositoryStockCount,
          pageStateCount: _stock.length,
          requestId: requestId,
        ),
      );
      if (mounted && requestId == _loadRequestId) {
        _message('تعذر تحميل المخزون', error: true);
      }
      return false;
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _loading = false);
        unawaited(
          FurnexaDatabaseDiagnostics.recordUiPipeline(
            feature: 'warehouse',
            layer: 'state',
            state: _loadFailed
                ? 'error'
                : _warehouses.isEmpty
                ? 'empty'
                : 'success',
            reason:
                'load Future completed and warehouse loading flag was cleared',
            repositoryCount: _lastRepositoryWarehouseCount,
            viewModelCount: _lastRepositoryWarehouseCount,
            emittedStateCount: _warehouses.length,
            pageStateCount: _warehouses.length,
            renderItemCount: _warehouses.length,
            requestId: requestId,
          ),
        );
        unawaited(
          FurnexaDatabaseDiagnostics.recordUiPipeline(
            feature: 'stock',
            layer: 'state',
            state: _loadFailed
                ? 'error'
                : _stock.isEmpty
                ? 'empty'
                : 'success',
            reason: 'load Future completed and loading flag was cleared',
            repositoryCount: _lastRepositoryStockCount,
            viewModelCount: _lastRepositoryStockCount,
            emittedStateCount: _stock.length,
            pageStateCount: _stock.length,
            renderItemCount: _stock.length,
            requestId: requestId,
          ),
        );
      }
    }
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppTheme.error : AppTheme.success,
        ),
      );
  String _error(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.contains('database') ? 'تعذر حفظ حركة المخزون' : text;
  }

  Future<void> _operation(String kind) async {
    if (_warehouses.isEmpty || _items.isEmpty) {
      _message('أضف مخزناً وصنفاً نشطاً أولاً', error: true);
      return;
    }
    final result = await showDialog<_MovementInput>(
      context: context,
      builder: (_) => _MovementDialog(
        kind: kind,
        warehouses: _warehouses,
        items: _items,
        selectedWarehouseId:
            _warehouseId ?? (_warehouses.isEmpty ? null : _warehouses.first.id),
      ),
    );
    if (result == null) {
      return;
    }
    try {
      if (kind == 'in') {
        await _repository.stockIn(
          warehouseId: result.warehouseId!,
          item: result.item!,
          quantity: result.quantity,
          date: result.date,
          reference: result.reference,
          notes: result.notes,
        );
      }
      if (kind == 'out') {
        await _repository.stockOut(
          warehouseId: result.warehouseId!,
          item: result.item!,
          quantity: result.quantity,
          date: result.date,
          reference: result.reference,
          notes: result.notes,
        );
      }
      if (kind == 'transfer') {
        await _repository.transfer(
          sourceWarehouseId: result.sourceWarehouseId!,
          destinationWarehouseId: result.destinationWarehouseId!,
          item: result.item!,
          quantity: result.quantity,
          date: result.date,
          reference: result.reference,
          notes: result.notes,
        );
      }
      if (kind == 'adjust') {
        await _repository.adjust(
          warehouseId: result.warehouseId!,
          item: result.item!,
          difference: result.quantity,
          date: result.date,
          reason: result.reference ?? '',
          notes: result.notes,
        );
      }
      final refreshed = await _load();
      if (mounted && refreshed) _message('تم حفظ حركة المخزون');
    } catch (error) {
      if (mounted) _message(_error(error), error: true);
    }
  }

  Future<void> _ledger(StockLine line) async {
    if (_warehouseId == null) {
      _message('اختر مخزناً واحداً لعرض سجل الحركات', error: true);
      return;
    }
    final rows = await _repository.ledger(
      _warehouseId!,
      line.item.id,
      line.item.type,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('سجل ${line.item.name}'),
        content: SizedBox(
          width: 720,
          height: 420,
          child: rows.isEmpty
              ? const Center(child: Text('لا توجد حركات لهذا الصنف'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    final sign = row.transaction.signedQuantity >= 0 ? '+' : '';
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${row.transaction.transactionType.arabic}  $sign${row.transaction.signedQuantity}',
                      ),
                      subtitle: Text(
                        '${row.transaction.transactionDate.toString().substring(0, 10)} | ${row.transaction.reference ?? '-'} | ${row.transaction.notes ?? ''}',
                      ),
                      trailing: Text('الرصيد ${row.balanceAfter}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouseOptions = [
      const DropdownMenuItem<String?>(value: null, child: Text('كل المخازن')),
      ..._warehouses.map(
        (warehouse) => DropdownMenuItem<String?>(
          value: warehouse.id,
          child: Text('${warehouse.name} (${warehouse.code})'),
        ),
      ),
    ];
    final state = _loadFailed
        ? 'error'
        : !_hasLoaded
        ? 'initial'
        : _loading
        ? 'loading'
        : _stock.isEmpty
        ? 'empty'
        : 'success';
    final warehouseState = _loadFailed
        ? 'error'
        : !_hasLoaded
        ? 'initial'
        : _loading
        ? 'loading'
        : _warehouses.isEmpty
        ? 'empty'
        : 'success';
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'warehouse',
        layer: 'page',
        state: warehouseState,
        reason:
            'build read page-local _warehouses state for the warehouse selector',
        repositoryCount: _lastRepositoryWarehouseCount,
        viewModelCount: _lastRepositoryWarehouseCount,
        emittedStateCount: _warehouses.length,
        pageStateCount: _warehouses.length,
        renderItemCount: _loading ? 0 : _warehouses.length,
        requestId: _loadRequestId,
      ),
    );
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'warehouse',
        layer: 'selector',
        state: warehouseState,
        reason:
            'DropdownMenuItem collection includes each warehouse and the all-warehouses option',
        repositoryCount: _lastRepositoryWarehouseCount,
        viewModelCount: _lastRepositoryWarehouseCount,
        emittedStateCount: _warehouses.length,
        pageStateCount: _warehouses.length,
        renderItemCount: _loading || _warehouses.isEmpty
            ? 0
            : warehouseOptions.length,
        receivedItemCount: _warehouses.length,
        renderedRowCount: _loading || _warehouses.isEmpty
            ? 0
            : warehouseOptions.length,
        requestId: _loadRequestId,
      ),
    );
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'stock',
        layer: 'page',
        state: state,
        reason:
            'build read the page-local _stock state and selected the content branch',
        repositoryCount: _lastRepositoryStockCount,
        viewModelCount: _lastRepositoryStockCount,
        emittedStateCount: _stock.length,
        pageStateCount: _stock.length,
        renderItemCount: _stock.length,
        requestId: _loadRequestId,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('المخازن والمخزون'),
        actions: [
          FilledButton.icon(
            onPressed: () => _operation('in'),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('إضافة مخزون'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _operation('out'),
            icon: const Icon(Icons.outbox_outlined),
            label: const Text('صرف'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _operation('transfer'),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('تحويل'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _operation('adjust'),
            icon: const Icon(Icons.tune),
            label: const Text('تسوية'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FurnexaCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'مستودع المخزون',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'مراجعة الرصيد والمخرجات والتحويلات حسب المخزن',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            if (_warehouses.isNotEmpty)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 220,
                                  maxWidth: 320,
                                ),
                                child: DropdownButtonFormField<String?>(
                                  value: _warehouseId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'المخزن',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: warehouseOptions,
                                  onChanged: (value) {
                                    _warehouseId = value;
                                    _load();
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 280,
                              child: TextField(
                                onChanged: (value) {
                                  _query = value;
                                  _load();
                                },
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'بحث في الأصناف',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: DropdownButtonFormField<StockItemType?>(
                                value: _itemType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'نوع الصنف',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text('كل الأنواع'),
                                  ),
                                  DropdownMenuItem(
                                    value: StockItemType.rawMaterial,
                                    child: Text('خامات'),
                                  ),
                                  DropdownMenuItem(
                                    value: StockItemType.product,
                                    child: Text('منتجات'),
                                  ),
                                ],
                                onChanged: (value) {
                                  _itemType = value;
                                  _load();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _stock.isEmpty
                        ? const Center(
                            child: Text('لا يوجد مخزون في هذا المخزن.'),
                          )
                        : FurnexaCard(
                            padding: EdgeInsets.zero,
                            child: FurnexaDataTable(
                              diagnosticFeature: 'stock',
                              diagnosticPageStateCount: _stock.length,
                              columns: const [
                                FurnexaTableColumn(
                                  key: 'item',
                                  label: 'الصنف',
                                  sortable: true,
                                ),
                                FurnexaTableColumn(
                                  key: 'type',
                                  label: 'النوع',
                                  sortable: true,
                                ),
                                FurnexaTableColumn(
                                  key: 'unit',
                                  label: 'الوحدة',
                                ),
                                FurnexaTableColumn(
                                  key: 'quantity',
                                  label: 'الرصيد',
                                  sortable: true,
                                  alignment: AlignmentDirectional.centerEnd,
                                ),
                              ],
                              rows: _stock
                                  .map(
                                    (line) => <String, Object?>{
                                      'id': line.item.id,
                                      'item':
                                          '${line.item.name} • ${line.item.code}',
                                      'type': line.item.type.arabic,
                                      'unit': line.unitName,
                                      'quantity': '${line.balance.quantity}',
                                    },
                                  )
                                  .toList(),
                              rowId: (row) => '${row['id']}',
                              actionsBuilder: (row) {
                                final line = _stock.firstWhere(
                                  (item) => item.item.id == row['id'],
                                );
                                return [
                                  FurnexaTableAction(
                                    label: 'سجل الحركات',
                                    icon: Icons.history,
                                    onPressed: () => _ledger(line),
                                  ),
                                ];
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MovementInput {
  const _MovementInput({
    this.warehouseId,
    this.sourceWarehouseId,
    this.destinationWarehouseId,
    required this.item,
    required this.quantity,
    required this.date,
    this.reference,
    this.notes,
  });
  final String? warehouseId,
      sourceWarehouseId,
      destinationWarehouseId,
      reference,
      notes;
  final StockItemOption? item;
  final double quantity;
  final DateTime date;
}

class _MovementDialog extends StatefulWidget {
  const _MovementDialog({
    required this.kind,
    required this.warehouses,
    required this.items,
    this.selectedWarehouseId,
  });
  final String kind;
  final List<Warehouse> warehouses;
  final List<StockItemOption> items;
  final String? selectedWarehouseId;
  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _key = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _warehouse, _source, _destination, _item;
  DateTime _date = DateTime.now();
  @override
  void initState() {
    super.initState();
    _warehouse = widget.selectedWarehouseId;
    _source = widget.selectedWarehouseId;
    _item = widget.items.first.id;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _transfer => widget.kind == 'transfer';
  bool get _adjust => widget.kind == 'adjust';
  String get _title => switch (widget.kind) {
    'in' => 'إضافة مخزون',
    'out' => 'صرف مخزون',
    'transfer' => 'تحويل مخزون',
    _ => 'تسوية مخزون',
  };
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_title),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _select(
                'الصنف',
                _item,
                widget.items.map(
                  (i) => DropdownMenuItem(
                    value: i.id,
                    child: Text('${i.name} (${i.type.arabic})'),
                  ),
                ),
                (v) => _item = v,
              ),
              if (_transfer) ...[
                _select(
                  'المخزن المصدر',
                  _source,
                  widget.warehouses.map(
                    (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ),
                  (v) => _source = v,
                ),
                _select(
                  'المخزن الوجهة',
                  _destination,
                  widget.warehouses.map(
                    (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ),
                  (v) => _destination = v,
                ),
              ] else
                _select(
                  'المخزن',
                  _warehouse,
                  widget.warehouses.map(
                    (w) => DropdownMenuItem(value: w.id, child: Text(w.name)),
                  ),
                  (v) => _warehouse = v,
                ),
              _field(
                _adjust ? 'فرق التسوية (+/-)' : 'الكمية',
                _quantity,
                numeric: true,
                allowNegative: _adjust,
              ),
              _field(
                _adjust ? 'سبب التسوية' : 'المرجع (اختياري)',
                _reference,
                required: _adjust,
              ),
              _field('الملاحظات (اختياري)', _notes, maxLines: 2),
              ListTile(
                title: Text('التاريخ: ${_date.toString().substring(0, 10)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: _date,
                    );
                    if (date != null) setState(() => _date = date);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_key.currentState?.validate() ?? false)) return;
          final item = widget.items.where((i) => i.id == _item).first;
          Navigator.pop(
            context,
            _MovementInput(
              warehouseId: _warehouse,
              sourceWarehouseId: _source,
              destinationWarehouseId: _destination,
              item: item,
              quantity: double.parse(_quantity.text),
              date: _date,
              reference: _reference.text.trim().isEmpty
                  ? null
                  : _reference.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
          );
        },
        child: const Text('حفظ'),
      ),
    ],
  );
  Widget _select(
    String label,
    String? value,
    Iterable<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.toList(),
      onChanged: (value) => setState(() => onChanged(value)),
      validator: (value) => value == null ? 'هذا الحقل مطلوب' : null,
    ),
  );
  Widget _field(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    bool required = false,
    bool allowNegative = false,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'هذا الحقل مطلوب';
        }
        if (numeric &&
            (double.tryParse(value ?? '') == null ||
                (allowNegative
                    ? double.parse(value!) == 0
                    : double.parse(value!) <= 0))) {
          return allowNegative
              ? 'أدخل فرقاً غير صفري'
              : 'أدخل كمية أكبر من صفر';
        }
        return null;
      },
    ),
  );
}
