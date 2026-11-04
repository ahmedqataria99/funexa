import 'dart:async';
import 'package:flutter/material.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/accounting/domain/repositories/accounting_repository.dart';
import 'package:furnexa/features/accounting/presentation/pages/accounting_page.dart';
import 'package:furnexa/features/factory_structure/data/repositories/factory_structure_repository_impl.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/purchasing/data/repositories/purchasing_repository_impl.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/purchasing/domain/repositories/purchasing_repository.dart';
import 'package:furnexa/features/purchasing/presentation/pages/supplier_profile_page.dart';
import 'package:furnexa/features/purchasing/presentation/pages/purchase_document_pages.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class PurchasingPage extends StatefulWidget {
  const PurchasingPage({super.key});
  @override
  State<PurchasingPage> createState() => _PurchasingPageState();
}

class _PurchasingPageState extends State<PurchasingPage>
    with SingleTickerProviderStateMixin {
  final PurchasingRepository _repository = PurchasingRepositoryImpl();
  final AccountingRepository _accountingRepository = AccountingRepositoryImpl();
  final SecurityLocalDataSource _security = SecurityLocalDataSource();
  final FactoryStructureRepositoryImpl _factoryRepository =
      FactoryStructureRepositoryImpl();
  late final TabController _tabs;
  List<Supplier> _suppliers = [];
  Map<String, Supplier> _orderSuppliers = const {};
  List<PurchaseRequest> _requests = [];
  List<PurchaseOrder> _orders = [];
  List<StockItemOption> _items = [];
  List<Warehouse> _warehouses = [];
  Map<String, String> _unitNames = const {};
  String _supplierQuery = '';
  final ScrollController _supplierScrollController = ScrollController();
  final ScrollController _requestScrollController = ScrollController();
  final ScrollController _orderScrollController = ScrollController();
  bool _loading = true;
  bool _loadFailed = false;
  int _loadRequestId = 0;
  int _lastRepositoryRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'purchaseRequest',
        layer: 'pageState',
        state: 'initial',
        reason: 'initState initialized empty local state before the first load',
        pageStateCount: _requests.length,
        requestId: _loadRequestId,
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _supplierScrollController.dispose();
    _requestScrollController.dispose();
    _orderScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_loadRequestId;
    _loadFailed = false;
    if (mounted) setState(() => _loading = true);
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'purchaseRequest',
        layer: 'viewModel',
        state: 'loading',
        reason: 'page load started its Future.wait dependencies',
        pageStateCount: _requests.length,
        requestId: requestId,
      ),
    );
    try {
      final requestsFuture = _repository.requests().then((requests) {
        _lastRepositoryRequestCount = requests.length;
        unawaited(
          FurnexaDatabaseDiagnostics.recordUiPipeline(
            feature: 'purchaseRequest',
            layer: 'repository',
            state: requests.isEmpty ? 'empty' : 'success',
            reason:
                'requests repository Future completed independently of other Future.wait dependencies',
            repositoryCount: requests.length,
            requestId: requestId,
          ),
        );
        return requests;
      });
      final result = await Future.wait([
        _repository.suppliers(_supplierQuery),
        requestsFuture,
        _repository.orders(),
        _repository.activeItems(),
        _repository.activeWarehouses(),
        _repository.unitNames(),
      ]);
      final repositoryRequests = result[1] as List<PurchaseRequest>;
      final orders = result[2] as List<PurchaseOrder>;
      final orderSuppliers = <String, Supplier>{};
      await Future.wait(
        orders.map((order) => order.supplierId).toSet().map((supplierId) async {
          final supplier = await _repository.supplierById(supplierId);
          if (supplier != null) orderSuppliers[supplierId] = supplier;
        }),
      );
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'purchaseRequest',
          layer: 'viewModel',
          state: repositoryRequests.isEmpty ? 'empty' : 'success',
          reason:
              'page load received the requests result after Future.wait completed',
          repositoryCount: repositoryRequests.length,
          viewModelCount: repositoryRequests.length,
          requestId: requestId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _suppliers = result[0] as List<Supplier>;
        _orderSuppliers = orderSuppliers;
        _requests = repositoryRequests;
        _orders = orders;
        _items = result[3] as List<StockItemOption>;
        _warehouses = result[4] as List<Warehouse>;
        _unitNames = result[5] as Map<String, String>;
      });
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'purchaseRequest',
          layer: 'state',
          state: _requests.isEmpty ? 'empty' : 'success',
          reason: 'setState committed the request result from Future.wait',
          repositoryCount: repositoryRequests.length,
          viewModelCount: repositoryRequests.length,
          emittedStateCount: _requests.length,
          pageStateCount: _requests.length,
          requestId: requestId,
        ),
      );
      await FurnexaDatabaseDiagnostics.capture(
        source: 'page.purchasing.stateCommitted',
        purchaseRequestRepositoryRows: _requests.length,
        stageCounts: {
          'viewModelSupplierRows': _suppliers.length,
          'viewModelRequestRows': _requests.length,
          'viewModelOrderRows': _orders.length,
          'committedToState': true,
        },
      );
    } catch (error, stackTrace) {
      await FurnexaDatabaseDiagnostics.reportFailure(
        source: 'page.purchasing.load',
        error: error,
        stackTrace: stackTrace,
      );
      unawaited(
        FurnexaDatabaseDiagnostics.recordUiPipeline(
          feature: 'purchaseRequest',
          layer: 'state',
          state: 'error',
          reason:
              'a Future.wait dependency failed; no state assignment occurred: $error',
          repositoryCount: _lastRepositoryRequestCount,
          pageStateCount: _requests.length,
          requestId: requestId,
        ),
      );
      if (mounted) _loadFailed = true;
      if (mounted) _message('تعذر تحميل بيانات المشتريات', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  String _number(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';
  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppTheme.error : AppTheme.success,
        ),
      );
  Future<void> _save(Future<void> Function() action) async {
    try {
      await action();
      await _load();
      if (mounted) _message('تم الحفظ بنجاح');
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _loadFailed
        ? 'error'
        : _loading
        ? 'loading'
        : _requests.isEmpty
        ? 'empty'
        : 'success';
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'purchaseRequest',
        layer: 'page',
        state: state,
        reason: 'build selected the page loading or TabBarView branch',
        repositoryCount: _lastRepositoryRequestCount,
        viewModelCount: _lastRepositoryRequestCount,
        emittedStateCount: _requests.length,
        pageStateCount: _requests.length,
        renderItemCount: _loading ? 0 : _requests.length,
        requestId: _loadRequestId,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('المشتريات والموردين'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'الموردين'),
            Tab(text: 'طلبات الشراء'),
            Tab(text: 'أوامر الشراء'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [_suppliersView(), _requestsView(), _ordersView()],
            ),
    );
  }

  Widget _suppliersView() => _panel(
    title: 'الموردين',
    addLabel: 'إضافة مورد',
    onAdd: () => _supplierForm(),
    scrollController: _supplierScrollController,
    search: TextField(
      onChanged: (value) {
        _supplierQuery = value;
        _load();
      },
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: 'بحث بالاسم أو الكود',
        border: OutlineInputBorder(),
      ),
    ),
    children: _suppliers
        .map(
          (supplier) => ListTile(
            title: Text('${supplier.name} • ${supplier.code}'),
            subtitle: Text(
              '${supplier.phone ?? '-'} | ${supplier.email ?? '-'}',
            ),
            leading: Icon(
              supplier.active
                  ? Icons.person_outline
                  : Icons.person_off_outlined,
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'ملف المورد',
                  onPressed: () => _supplierProfile(supplier),
                  icon: const Icon(Icons.person_search_outlined),
                ),
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: () => _supplierForm(supplier),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: supplier.active ? 'تعطيل' : 'تفعيل',
                  onPressed: () => _save(
                    () => _repository.setSupplierActive(
                      supplier.id,
                      !supplier.active,
                    ),
                  ),
                  icon: Icon(
                    supplier.active ? Icons.toggle_on : Icons.toggle_off,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );

  Widget _requestsView() {
    final requests = List<PurchaseRequest>.of(_requests);
    final requestWidgets = requests.map((request) {
      final linkedOrder = _orders
          .where((order) => order.purchaseRequestId == request.id)
          .firstOrNull;
      return ListTile(
        onTap: () => _requestDetails(request),
        title: Text(request.requestNumber),
        subtitle: Text(
          '${_requestArabic(request.status)} | ${request.items.length} أصناف | ${_date(request.requestDate)}',
        ),
        trailing: Wrap(
          children: [
            if (request.status == PurchaseRequestStatus.draft)
              IconButton(
                tooltip: 'إرسال',
                onPressed: () => _save(
                  () => _repository.changeRequestStatus(
                    request.id,
                    PurchaseRequestStatus.pending,
                  ),
                ),
                icon: const Icon(Icons.send_outlined),
              ),
            if (request.status == PurchaseRequestStatus.pending ||
                (request.status == PurchaseRequestStatus.approved &&
                    linkedOrder == null))
              FilledButton.tonalIcon(
                onPressed: () => _approveRequest(request),
                icon: const Icon(Icons.task_alt_outlined),
                label: Text(
                  request.status == PurchaseRequestStatus.pending
                      ? 'اعتماد وتحويل إلى أمر شراء'
                      : 'إنشاء أمر الشراء',
                ),
              ),
            if (linkedOrder != null)
              IconButton(
                tooltip: 'فتح أمر الشراء ${linkedOrder.orderNumber}',
                onPressed: () => _orderDetails(linkedOrder),
                icon: const Icon(Icons.open_in_new),
              ),
          ],
        ),
      );
    }).toList();
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: 'purchaseRequest',
        layer: 'list',
        state: requestWidgets.isEmpty ? 'empty' : 'success',
        reason:
            'request ListTile collection was generated and passed directly to _panel',
        repositoryCount: _lastRepositoryRequestCount,
        viewModelCount: _lastRepositoryRequestCount,
        emittedStateCount: _requests.length,
        pageStateCount: requests.length,
        renderItemCount: requestWidgets.length,
        receivedItemCount: requestWidgets.length,
        renderedRowCount: requestWidgets.length,
        requestId: _loadRequestId,
      ),
    );
    return _panel(
      title: 'طلبات الشراء',
      addLabel: 'طلب جديد',
      onAdd: () => _requestForm(),
      scrollController: _requestScrollController,
      children: requestWidgets,
    );
  }

  Widget _ordersView() => _panel(
    title: 'أوامر الشراء',
    addLabel: 'أمر جديد',
    onAdd: () => _orderForm(),
    scrollController: _orderScrollController,
    children: _orders.map((order) {
      final supplier = _orderSuppliers[order.supplierId];
      return ListTile(
        onTap: () => _orderDetails(order),
        title: Text('${order.orderNumber} • ${supplier?.name ?? '-'}'),
        subtitle: Text(
          '${_orderArabic(order.status)} | الإجمالي ${order.grandTotal.toStringAsFixed(2)}',
        ),
        trailing: Wrap(
          children: [
            if (order.status == PurchaseOrderStatus.draft)
              IconButton(
                tooltip: 'اعتماد',
                onPressed: () => _save(
                  () => _repository.changeOrderStatus(
                    order.id,
                    PurchaseOrderStatus.approved,
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline),
              ),
            if (order.status == PurchaseOrderStatus.approved ||
                order.status == PurchaseOrderStatus.partiallyReceived)
              IconButton(
                tooltip: 'استلام',
                onPressed: () => _receiptForm(order),
                icon: const Icon(Icons.move_to_inbox_outlined),
              ),
          ],
        ),
      );
    }).toList(),
  );

  String _orderArabic(PurchaseOrderStatus status) => switch (status) {
    PurchaseOrderStatus.draft => 'مسودة',
    PurchaseOrderStatus.approved => 'معتمد',
    PurchaseOrderStatus.partiallyReceived => 'مستلم جزئياً',
    PurchaseOrderStatus.fullyReceived => 'مستلم بالكامل',
    PurchaseOrderStatus.cancelled => 'ملغى',
  };
  String _requestArabic(PurchaseRequestStatus status) => switch (status) {
    PurchaseRequestStatus.draft => 'مسودة',
    PurchaseRequestStatus.pending => 'قيد الاعتماد',
    PurchaseRequestStatus.approved => 'معتمد',
    PurchaseRequestStatus.rejected => 'مرفوض',
    PurchaseRequestStatus.converted => 'محول',
    PurchaseRequestStatus.cancelled => 'ملغى',
  };

  Widget _panel({
    required String title,
    required String addLabel,
    required VoidCallback onAdd,
    required ScrollController scrollController,
    Widget? search,
    required List<Widget> children,
  }) => Padding(
    padding: const EdgeInsets.all(16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(addLabel),
                ),
              ],
            ),
            if (search != null) ...[
              const SizedBox(height: 12),
              SizedBox(width: 320, child: search),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: children.isEmpty
                  ? const Center(child: Text('لا توجد بيانات بعد.'))
                  : Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: ListView(
                        controller: scrollController,
                        children: children,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _supplierForm([Supplier? current]) async {
    final values = await _form(
      current == null ? 'إضافة مورد' : 'تعديل المورد',
      [
        _FormFieldData('name', 'اسم المورد', current?.name),
        _FormFieldData('code', 'الكود', current?.code),
        _FormFieldData('phone', 'الهاتف', current?.phone, true),
        _FormFieldData('email', 'البريد الإلكتروني', current?.email, true),
        _FormFieldData('address', 'العنوان', current?.address, true),
        _FormFieldData('taxNumber', 'الرقم الضريبي', current?.taxNumber, true),
        _FormFieldData('notes', 'ملاحظات', current?.notes, true),
      ],
    );
    if (values == null) return;
    final now = DateTime.now();
    await _save(
      () => _repository.saveSupplier(
        Supplier(
          id: current?.id ?? _id('supplier'),
          name: values['name']!,
          code: values['code']!,
          phone: values['phone'],
          email: values['email'],
          address: values['address'],
          taxNumber: values['taxNumber'],
          notes: values['notes'],
          active: current?.active ?? true,
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
  }

  Future<void> _supplierProfile(Supplier supplier) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SupplierProfilePage(repository: _repository, supplier: supplier),
      ),
    );
    await _load();
  }

  Future<void> _approveRequest(PurchaseRequest request) async {
    try {
      final order = await _repository.approveRequest(request.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم اعتماد طلب الشراء وإنشاء أمر الشراء'),
          action: SnackBarAction(
            label: 'فتح أمر الشراء',
            onPressed: () => _orderDetails(order),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  Future<void> _requestForm() async {
    if (!_items.any((item) => item.type == StockItemType.rawMaterial)) {
      _message('أضف خامة نشطة أولاً', error: true);
      return;
    }
    final activeSuppliers = _suppliers.where((value) => value.active).toList();
    if (activeSuppliers.isEmpty) {
      _message('أضف مورداً نشطاً أولاً', error: true);
      return;
    }
    final request = await Navigator.of(context).push<PurchaseRequest>(
      MaterialPageRoute(
        builder: (_) => PurchaseRequestDocumentPage(
          suppliers: activeSuppliers,
          items: _items,
          unitNames: _unitNames,
          createId: _id,
          createNumber: _number,
        ),
      ),
    );
    if (request == null) return;
    await _save(() => _repository.saveRequest(request));
  }

  Future<void> _orderForm({PurchaseOrder? existingOrder}) async {
    final activeSuppliers = _suppliers.where((value) => value.active).toList();
    if (activeSuppliers.isEmpty ||
        !_items.any((item) => item.type == StockItemType.rawMaterial)) {
      _message('أضف مورداً وخامة نشطة أولاً', error: true);
      return;
    }
    if (existingOrder != null &&
        activeSuppliers.every(
          (value) => value.id != existingOrder.supplierId,
        )) {
      final currentSupplier = _suppliers
          .where((value) => value.id == existingOrder.supplierId)
          .firstOrNull;
      if (currentSupplier != null) activeSuppliers.add(currentSupplier);
    }
    final order = await Navigator.of(context).push<PurchaseOrder>(
      MaterialPageRoute(
        builder: (_) => PurchaseOrderDocumentPage(
          suppliers: activeSuppliers,
          items: _items,
          unitNames: _unitNames,
          createId: _id,
          createNumber: _number,
          initialOrder: existingOrder,
        ),
      ),
    );
    if (order == null) return;
    await _save(() => _repository.saveOrder(order));
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _requestDetails(PurchaseRequest request) async {
    final supplier = _suppliers
        .where((value) => value.id == request.supplierId)
        .firstOrNull;
    final generatedOrder = _orders
        .where((order) => order.purchaseRequestId == request.id)
        .firstOrNull;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PurchaseDocumentDetailsPage(
          request: request,
          generatedOrder: generatedOrder,
          supplier: supplier,
          items: _items,
          unitNames: _unitNames,
          onPrint: () => _printRequest(request, supplier),
          onOpenOrder: generatedOrder == null
              ? null
              : () => _orderDetails(generatedOrder),
        ),
      ),
    );
  }

  Future<void> _orderDetails(PurchaseOrder order) async {
    final supplier = await _repository.supplierById(order.supplierId);
    final request = _requests
        .where((value) => value.id == order.purchaseRequestId)
        .firstOrNull;
    final receipts = await _repository.receipts(order.id);
    final receiptJournalEntries = <String, JournalEntry>{};
    if (_security.can('ACCOUNTING_VIEW')) {
      for (final receipt in receipts) {
        final entry = await _accountingRepository.journalEntryByReference(
          referenceType: 'PURCHASE_RECEIPT',
          referenceId: receipt.id,
        );
        if (entry != null) receiptJournalEntries[receipt.id] = entry;
      }
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PurchaseDocumentDetailsPage(
          order: order,
          purchaseRequestNumber: request?.requestNumber,
          receipts: receipts,
          receiptJournalEntries: receiptJournalEntries,
          supplier: supplier,
          items: _items,
          unitNames: _unitNames,
          warehouses: _warehouses,
          onPrint: () => _printOrder(order, supplier),
          onOpenAccountingEntry: _security.can('ACCOUNTING_VIEW')
              ? _openAccountingEntry
              : null,
          onEditOrder:
              order.status == PurchaseOrderStatus.draft ||
                  order.status == PurchaseOrderStatus.approved
              ? () => _orderForm(existingOrder: order)
              : null,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openAccountingEntry(JournalEntry entry) async {
    final accounts = await _accountingRepository.accounts();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            AccountingJournalEntryDetailsPage(entry: entry, accounts: accounts),
      ),
    );
  }

  Future<void> _printRequest(
    PurchaseRequest request,
    Supplier? supplier,
  ) async {
    final factory = await _factoryRepository.getFactory();
    await printPurchaseDocument(
      factoryName: factory?.name ?? '',
      title: 'طلب شراء',
      number: request.requestNumber,
      date: request.requestDate,
      supplier: supplier,
      notes: request.notes,
      items: request.items,
      catalog: _items,
      unitNames: _unitNames,
    );
  }

  Future<void> _printOrder(PurchaseOrder order, Supplier? supplier) async {
    final factory = await _factoryRepository.getFactory();
    await printPurchaseDocument(
      factoryName: factory?.name ?? '',
      title: 'أمر شراء',
      number: order.orderNumber,
      date: order.orderDate,
      supplier: supplier,
      notes: order.notes,
      items: order.items,
      catalog: _items,
      unitNames: _unitNames,
      showFinancials: true,
      subtotal: order.subtotal,
      discount: order.discount,
      tax: order.tax,
      grandTotal: order.grandTotal,
    );
  }

  Future<void> _receiptForm(PurchaseOrder order) async {
    final pending = order.items
        .where((item) => item.remainingQuantity > 0)
        .toList();
    if (_warehouses.isEmpty || pending.isEmpty) {
      _message('لا يوجد مخزن نشط أو أصناف متبقية', error: true);
      return;
    }
    final values = await _form(
      'استلام أمر ${order.orderNumber}',
      [
        _FormFieldData('quantity', 'الكمية المستلمة'),
        _FormFieldData('notes', 'ملاحظات', null, true),
      ],
      selects: [
        _SelectData('warehouseId', 'المخزن', {
          for (final warehouse in _warehouses) warehouse.id: warehouse.name,
        }),
        _SelectData('itemId', 'صنف الأمر', {
          for (final item in pending)
            item.id:
                '${_receiptItemLabel(item)} | المتبقي ${item.remainingQuantity}',
        }),
      ],
    );
    if (values == null) return;
    final item = pending.firstWhere((value) => value.id == values['itemId']);
    final now = DateTime.now();
    final operationId = _id('receipt-operation');
    await _save(
      () => _repository.postReceipt(
        order: order,
        warehouseId: values['warehouseId']!,
        receiptDate: now,
        notes: values['notes'],
        operationId: operationId,
        items: [
          PurchasingItem(
            id: item.id,
            itemId: item.itemId,
            itemType: item.itemType,
            quantity: double.parse(values['quantity']!),
            unitId: item.unitId,
          ),
        ],
      ),
    );
  }

  String _receiptItemLabel(PurchasingItem line) {
    final itemType = line.itemType == PurchasingItemType.product
        ? StockItemType.product
        : StockItemType.rawMaterial;
    final material = _items
        .where((item) => item.id == line.itemId && item.type == itemType)
        .firstOrNull;
    if (material == null) return 'غير معروف';
    return '${material.name} • ${material.code}';
  }

  Future<Map<String, String>?> _form(
    String title,
    List<_FormFieldData> fields, {
    List<_SelectData> selects = const [],
  }) => showDialog<Map<String, String>>(
    context: context,
    builder: (_) =>
        _PurchasingForm(title: title, fields: fields, selects: selects),
  );
}

class _FormFieldData {
  const _FormFieldData(
    this.key,
    this.label, [
    this.initial,
    this.optional = false,
  ]);
  final String key, label;
  final String? initial;
  final bool optional;
}

class _SelectData {
  const _SelectData(this.key, this.label, this.items);
  final String key, label;
  final Map<String, String> items;
}

class _PurchasingForm extends StatefulWidget {
  const _PurchasingForm({
    required this.title,
    required this.fields,
    required this.selects,
  });
  final String title;
  final List<_FormFieldData> fields;
  final List<_SelectData> selects;
  @override
  State<_PurchasingForm> createState() => _PurchasingFormState();
}

class _PurchasingFormState extends State<_PurchasingForm> {
  final _key = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = <String, String?>{};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field.key] = TextEditingController(
        text: field.initial ?? '',
      );
    }
    for (final select in widget.selects) {
      _values[select.key] = null;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...widget.fields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _controllers[field.key],
                      maxLines: field.key == 'notes' ? 2 : 1,
                      keyboardType:
                          {
                            'quantity',
                            'unitPrice',
                            'discount',
                            'tax',
                          }.contains(field.key)
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : null,
                      decoration: InputDecoration(
                        labelText: field.label,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!field.optional &&
                            (value == null || value.trim().isEmpty)) {
                          return 'هذا الحقل مطلوب';
                        }
                        if (field.key == 'quantity' &&
                            (double.tryParse(value ?? '') ?? 0) <= 0) {
                          return 'يجب أن تكون الكمية أكبر من صفر';
                        }
                        if (field.key == 'unitPrice' &&
                            double.tryParse(value ?? '') == null) {
                          return 'أدخل رقماً صحيحاً';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                ...widget.selects.map(
                  (select) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _values[select.key],
                      decoration: InputDecoration(
                        labelText: select.label,
                        border: const OutlineInputBorder(),
                      ),
                      items: select.items.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _values[select.key] = value),
                      validator: (value) =>
                          value == null ? 'هذا الحقل مطلوب' : null,
                    ),
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
            final result = <String, String>{
              for (final entry in _controllers.entries)
                entry.key: entry.value.text.trim(),
              for (final entry in _values.entries)
                if (entry.value != null) entry.key: entry.value!,
            };
            Navigator.pop(context, result);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
