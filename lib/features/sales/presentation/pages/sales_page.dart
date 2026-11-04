import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:furnexa/core/inventory/inventory_identity.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/detail/furnexa_detail.dart';
import 'package:furnexa/features/factory_structure/data/repositories/factory_structure_repository_impl.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/pricing/data/datasources/pricing_local_data_source.dart';
import 'package:furnexa/features/raw_materials_products/data/repositories/raw_materials_products_repository_impl.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/sales/domain/repositories/sales_repository.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/repositories/warehouses_stock_repository_impl.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

int _salesDeliveryOperationSequence = 0;

String _newSalesDeliveryOperationId() {
  _salesDeliveryOperationSequence++;
  return 'sales-delivery-${DateTime.now().microsecondsSinceEpoch}-$_salesDeliveryOperationSequence';
}

class SalesPage extends StatefulWidget {
  const SalesPage({super.key, this.initialCustomerId, this.initialOrderId});

  final String? initialCustomerId;
  final String? initialOrderId;
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage>
    with SingleTickerProviderStateMixin {
  final SalesRepository repository = SalesRepositoryImpl();
  final WarehousesStockRepositoryImpl stockRepository =
      WarehousesStockRepositoryImpl();
  late final TabController tabs;
  List<Customer> customers = [];
  List<Quotation> quotations = [];
  List<SalesOrder> orders = [];
  Map<String, String> unitNames = {};
  Map<String, bool> orderHasDeliverableStock = {};
  final customerSearchController = TextEditingController();
  bool loading = true;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
    load();
  }

  @override
  void dispose() {
    tabs.dispose();
    customerSearchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final results = await Future.wait<Object>([
      repository.customers(),
      repository.quotations(),
      repository.orders(),
      RawMaterialsProductsRepositoryImpl()
          .units()
          .then<Object>((value) => value)
          .catchError((_) => <Object>[]),
    ]);
    if (!mounted) return;
    final units = results[3] as List;
    final loadedOrders = results[2] as List<SalesOrder>;
    final deliveryStock = <String, bool>{};
    try {
      final warehouses = await repository.activeWarehouses();
      for (final order in loadedOrders) {
        var available = false;
        for (final item in order.items.where(
          (item) => item.remainingQuantity > 0,
        )) {
          for (final warehouse in warehouses) {
            if (await stockRepository.balance(
                  warehouse.id,
                  item.itemId,
                  StockItemType.product,
                  variantId: item.variantId,
                  identityKind: InventoryIdentityKindValue.parse(
                    item.inventoryIdentityKind,
                  ),
                ) >
                0) {
              available = true;
              break;
            }
          }
          if (available) break;
        }
        deliveryStock[order.id] = available;
      }
    } catch (_) {
      for (final order in loadedOrders) {
        deliveryStock[order.id] = false;
      }
    }
    if (!mounted) return;
    setState(() {
      customers = results[0] as List<Customer>;
      quotations = results[1] as List<Quotation>;
      orders = loadedOrders;
      orderHasDeliverableStock = deliveryStock;
      unitNames = {
        for (final unit in units)
          unit.id as String: (unit.abbreviation as String).trim().isEmpty
              ? unit.name as String
              : unit.abbreviation as String,
      };
      loading = false;
    });
    if (widget.initialCustomerId != null) {
      tabs.index = 0;
      final customer = customers
          .where((value) => value.id == widget.initialCustomerId)
          .firstOrNull;
      if (customer != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) openCustomerProfile(customer);
        });
      }
    } else if (widget.initialOrderId != null) {
      tabs.index = 2;
    }
  }

  void message(String text) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text.replaceFirst('Exception: ', ''))));
  String customerName(String id) =>
      customers.where((v) => v.id == id).firstOrNull?.name ?? '-';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('المبيعات والعملاء'),
      bottom: TabBar(
        controller: tabs,
        tabs: const [
          Tab(text: 'العملاء'),
          Tab(text: 'عروض الأسعار'),
          Tab(text: 'أوامر البيع'),
        ],
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: tabs,
            children: [customerList(), quotationList(), orderList()],
          ),
  );
  Widget customerList() {
    final query = customerSearchController.text.trim().toLowerCase();
    final filteredCustomers = customers.where((customer) {
      if (query.isEmpty) return true;
      return [
        customer.name,
        customer.code,
        customer.phone ?? '',
        customer.email ?? '',
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
    return panel('العملاء', 'إضافة عميل', customerForm, [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: TextField(
          controller: customerSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث باسم العميل أو الكود أو الهاتف...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: customerSearchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: () {
                      customerSearchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      if (filteredCustomers.isEmpty)
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              query.isEmpty ? 'لا يوجد عملاء بعد.' : 'لا توجد نتائج مطابقة.',
            ),
          ),
        ),
      ...filteredCustomers.map(
        (customer) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: ListTile(
            dense: true,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(6),
            ),
            title: Text(
              customer.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: Wrap(
              spacing: 18,
              runSpacing: 2,
              children: [
                Text('الكود: ${customer.code}'),
                if (customer.phone?.trim().isNotEmpty == true)
                  Text('الهاتف: ${customer.phone}'),
                if (customer.email?.trim().isNotEmpty == true)
                  Text('البريد: ${customer.email}'),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: customer.active ? 'تعطيل العميل' : 'تفعيل العميل',
                  icon: Icon(
                    customer.active ? Icons.toggle_on : Icons.toggle_off,
                  ),
                  onPressed: () async {
                    await repository.setCustomerActive(
                      customer.id,
                      !customer.active,
                    );
                    await load();
                  },
                ),
                IconButton(
                  tooltip: 'تعديل العميل',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => customerForm(customer),
                ),
              ],
            ),
            onTap: () => openCustomerProfile(customer),
          ),
        ),
      ),
    ]);
  }

  Widget quotationList() => panel(
    'عروض الأسعار',
    'عرض جديد',
    quotationForm,
    quotations
        .map(
          (quotation) => ListTile(
            title: Text(
              '${quotation.quotationNumber} • ${customerName(quotation.customerId)}',
            ),
            subtitle: Text(_quotationStatusLabel(context, quotation.status)),
            onTap: () => openQuotationDetails(quotation),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (quotation.status == QuotationStatus.draft)
                  IconButton(
                    tooltip: 'إرسال',
                    icon: const Icon(Icons.send),
                    onPressed: () =>
                        changeQuotation(quotation, QuotationStatus.sent),
                  ),
                if (quotation.status == QuotationStatus.sent)
                  IconButton(
                    tooltip: 'قبول',
                    icon: const Icon(Icons.check),
                    onPressed: () =>
                        changeQuotation(quotation, QuotationStatus.accepted),
                  ),
              ],
            ),
          ),
        )
        .toList(),
  );
  Widget orderList() => panel(
    'أوامر البيع',
    'أمر جديد',
    orderForm,
    orders
        .map(
          (order) => ListTile(
            title: Text(
              '${order.orderNumber} • ${customerName(order.customerId)}',
            ),
            subtitle: Text(_orderStatusLabel(context, order.status)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (order.status == SalesOrderStatus.draft)
                  IconButton(
                    tooltip: 'تأكيد',
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () =>
                        changeOrder(order, SalesOrderStatus.confirmed),
                  ),
                if (order.status == SalesOrderStatus.confirmed ||
                    order.status == SalesOrderStatus.partiallyDelivered)
                  IconButton(
                    tooltip: orderHasDeliverableStock[order.id] == true
                        ? 'تسجيل التسليم'
                        : 'لا توجد كمية متاحة للتسليم حالياً',
                    icon: const Icon(Icons.local_shipping_outlined),
                    onPressed: orderHasDeliverableStock[order.id] == true
                        ? () => deliveryForm(order)
                        : null,
                  ),
                if (order.status == SalesOrderStatus.draft ||
                    order.status == SalesOrderStatus.confirmed)
                  IconButton(
                    tooltip: 'إلغاء',
                    icon: const Icon(Icons.cancel_outlined),
                    onPressed: () =>
                        changeOrder(order, SalesOrderStatus.cancelled),
                  ),
              ],
            ),
          ),
        )
        .toList(),
  );
  Widget panel(
    String title,
    String action,
    VoidCallback add,
    List<Widget> children,
  ) => Padding(
    padding: const EdgeInsets.all(16),
    child: Card(
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            trailing: FilledButton.icon(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: Text(action),
            ),
          ),
          Expanded(
            child: children.isEmpty
                ? const Center(child: Text('لا توجد بيانات بعد.'))
                : ListView(children: children),
          ),
        ],
      ),
    ),
  );
  Future<Customer?> customerForm([Customer? current]) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => CustomerFormDialog(
        title: current == null ? 'إضافة عميل' : 'تعديل العميل',
        current: current,
        customers: customers,
      ),
    );
    if (values == null) return null;
    final now = DateTime.now();
    try {
      final customer = Customer(
        id: current?.id ?? 'customer-${now.microsecondsSinceEpoch}',
        name: values['name']!,
        code: values['code']!,
        phone: values['phone'],
        email: values['email'],
        active: current?.active ?? true,
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
      );
      await repository.saveCustomer(customer);
      await load();
      return customer;
    } catch (e) {
      message(e.toString());
      return null;
    }
  }

  Future<void> quotationForm() async {
    final activeCustomers = customers.where((value) => value.active).toList();
    final items = await repository.activeItems();
    if (!mounted) return;
    if (activeCustomers.isEmpty || items.isEmpty) {
      message('أضف عميلاً وصنفاً نشطاً أولاً');
      return;
    }
    final value = await Navigator.of(context).push<_SalesDocumentDraft>(
      MaterialPageRoute(
        builder: (_) => SalesDocumentForm(
          title: 'عرض سعر جديد',
          customers: activeCustomers,
          items: items,
          unitNames: unitNames,
          quotationActions: true,
          onCreateCustomer: customerForm,
        ),
      ),
    );
    if (value == null) return;
    final now = DateTime.now();
    final quotationId = 'quotation-${now.microsecondsSinceEpoch}';
    try {
      await repository.saveQuotation(
        Quotation(
          id: quotationId,
          quotationNumber: 'QT-${now.millisecondsSinceEpoch}',
          customerId: value.customer.id,
          quotationDate: now,
          status: QuotationStatus.draft,
          subtotal: value.subtotal,
          discount: value.discount,
          tax: value.tax,
          grandTotal: value.grandTotal,
          notes: value.notes.isEmpty ? null : value.notes,
          createdAt: now,
          updatedAt: now,
          items: value.items,
        ),
      );
      if (value.sendNow) {
        await repository.changeQuotationStatus(
          quotationId,
          QuotationStatus.sent,
        );
      }
      await load();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> orderForm() async {
    final activeCustomers = customers.where((value) => value.active).toList();
    final items = await repository.activeItems();
    if (!mounted) return;
    if (activeCustomers.isEmpty || items.isEmpty) {
      message('أضف عميلاً وصنفاً نشطاً أولاً');
      return;
    }
    final value = await Navigator.of(context).push<_SalesDocumentDraft>(
      MaterialPageRoute(
        builder: (_) => SalesDocumentForm(
          title: 'أمر بيع جديد',
          customers: activeCustomers,
          items: items,
          unitNames: unitNames,
          onCreateCustomer: customerForm,
        ),
      ),
    );
    if (value == null) return;
    final now = DateTime.now();
    try {
      await repository.saveOrder(
        SalesOrder(
          id: 'order-${now.microsecondsSinceEpoch}',
          orderNumber: 'SO-${now.millisecondsSinceEpoch}',
          customerId: value.customer.id,
          orderDate: now,
          status: SalesOrderStatus.draft,
          subtotal: value.subtotal,
          discount: value.discount,
          tax: value.tax,
          grandTotal: value.grandTotal,
          notes: value.notes.isEmpty ? null : value.notes,
          createdAt: now,
          updatedAt: now,
          items: value.items,
        ),
      );
      await load();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> changeQuotation(Quotation value, QuotationStatus status) async {
    try {
      await repository.changeQuotationStatus(value.id, status);
      await load();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> changeOrder(SalesOrder value, SalesOrderStatus status) async {
    try {
      await repository.changeOrderStatus(value.id, status);
      await load();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> deliveryForm(SalesOrder order) async {
    final warehouses = await repository.activeWarehouses();
    if (!mounted) return;
    if (warehouses.isEmpty) {
      message('أضف مخزناً نشطاً أولاً');
      return;
    }
    final items = order.items
        .where((item) => item.remainingQuantity > 0)
        .toList();
    if (items.isEmpty) return;
    final catalog = await repository.activeItems();
    if (!mounted) return;
    final value = await showDialog<_DeliveryDraft>(
      context: context,
      builder: (_) => DeliveryForm(
        warehouses: warehouses,
        items: items,
        catalog: catalog,
        unitNames: unitNames,
        operationId: _newSalesDeliveryOperationId(),
      ),
    );
    if (value == null) return;
    try {
      await repository.postDelivery(
        order: order,
        warehouseId: value.warehouse.id,
        deliveryDate: DateTime.now(),
        items: [
          SalesItem(
            id: value.item.id,
            itemId: value.item.itemId,
            itemType: value.item.itemType,
            quantity: value.quantity,
            unitId: value.item.unitId,
            variantId: value.item.variantId,
            baseUnitId: value.item.baseUnitId,
            unitConversionFactor: value.item.unitConversionFactor,
            baseQuantity: value.item.baseQuantity,
            inventoryIdentityKind: value.item.inventoryIdentityKind,
          ),
        ],
        operationId: value.operationId,
      );
      await load();
    } catch (e) {
      message(e.toString());
    }
  }

  Future<void> openCustomerProfile(Customer customer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CustomerProfilePage(repository: repository, customer: customer),
      ),
    );
    await load();
  }

  Future<void> openQuotationDetails(Quotation quotation) async {
    final customer = customers
        .where((value) => value.id == quotation.customerId)
        .firstOrNull;
    final catalog = await repository.activeItems();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotationDetailsPage(
          repository: repository,
          quotation: quotation,
          customerName: customer?.name ?? '-',
          customerCode: customer?.code ?? '-',
          customerPhone: customer?.phone,
          catalog: catalog,
          unitNames: unitNames,
          linkedOrder: orders.firstWhereOrNull(
            (order) => order.quotationId == quotation.id,
          ),
        ),
      ),
    );
    await load();
  }
}

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({
    required this.repository,
    required this.customer,
    super.key,
  });
  final SalesRepository repository;
  final Customer customer;

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  List<Quotation> quotations = [];
  List<SalesOrder> orders = [];
  List<SalesDelivery> deliveries = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final results = await Future.wait([
      widget.repository.quotations(),
      widget.repository.orders(),
    ]);
    final allQuotations = results[0] as List<Quotation>;
    final allOrders = results[1] as List<SalesOrder>;
    final customerOrders = allOrders
        .where((value) => value.customerId == widget.customer.id)
        .toList();
    final orderDeliveries = await Future.wait(
      customerOrders.map((value) => widget.repository.deliveries(value.id)),
    );
    if (!mounted) return;
    setState(() {
      quotations = allQuotations
          .where((value) => value.customerId == widget.customer.id)
          .toList();
      orders = customerOrders;
      deliveries = orderDeliveries.expand((value) => value).toList();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('ملف العميل: ${widget.customer.name}')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : FurnexaDetailPage(
            header: FurnexaDetailHeader(
              title: widget.customer.name,
              code: widget.customer.code,
              status: furnexaActiveStatus(context, widget.customer.active),
            ),
            children: [
              FurnexaInfoSection(
                title: AppLocalizations.of(context).information,
                items: [
                  FurnexaInfoItem(
                    label: AppLocalizations.of(context).name,
                    value: widget.customer.name,
                  ),
                  FurnexaInfoItem(
                    label: AppLocalizations.of(context).code,
                    value: widget.customer.code,
                  ),
                  FurnexaInfoItem(
                    label: AppLocalizations.of(context).phone,
                    value: widget.customer.phone ?? '-',
                  ),
                  FurnexaInfoItem(
                    label: AppLocalizations.of(context).email,
                    value: widget.customer.email ?? '-',
                  ),
                  FurnexaInfoItem(
                    label: AppLocalizations.of(context).address,
                    value: widget.customer.address ?? '-',
                  ),
                  FurnexaInfoItem(
                    label: AppLocalizations.of(context).taxNumber,
                    value: widget.customer.taxNumber ?? '-',
                  ),
                ],
              ),
              _historySection(
                'عروض الأسعار',
                quotations
                    .map(
                      (value) => ListTile(
                        leading: const Icon(Icons.request_quote_outlined),
                        title: Text(value.quotationNumber),
                        subtitle: Text(
                          '${_dateText(value.quotationDate)} • ${_quotationStatusLabel(context, value.status)}',
                        ),
                        trailing: Text(value.grandTotal.toStringAsFixed(2)),
                      ),
                    )
                    .toList(),
              ),
              _historySection(
                'أوامر البيع',
                orders
                    .map(
                      (value) => ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(value.orderNumber),
                        subtitle: Text(
                          '${_dateText(value.orderDate)} • ${_orderStatusLabel(context, value.status)}',
                        ),
                        trailing: Text(value.grandTotal.toStringAsFixed(2)),
                      ),
                    )
                    .toList(),
              ),
              _historySection(
                'التسليمات',
                deliveries
                    .map(
                      (value) => ListTile(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: Text(value.deliveryNumber),
                        subtitle: Text(_dateText(value.deliveryDate)),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
  );

  Widget _historySection(String title, List<Widget> children) =>
      FurnexaDetailSection(
        title: title,
        empty: children.isEmpty,
        emptyTitle: AppLocalizations.of(context).noRelatedRecords,
        child: Column(children: children),
      );
}

class QuotationDetailsPage extends StatefulWidget {
  const QuotationDetailsPage({
    required this.repository,
    required this.quotation,
    required this.customerName,
    required this.customerCode,
    this.customerPhone,
    this.catalog = const [],
    this.unitNames = const {},
    this.linkedOrder,
    super.key,
  });
  final SalesRepository repository;
  final Quotation quotation;
  final String customerName;
  final String customerCode;
  final String? customerPhone;
  final List<StockItemOption> catalog;
  final Map<String, String> unitNames;
  final SalesOrder? linkedOrder;

  @override
  State<QuotationDetailsPage> createState() => _QuotationDetailsPageState();
}

class _QuotationDetailsPageState extends State<QuotationDetailsPage> {
  bool working = false;
  late QuotationStatus status = widget.quotation.status;
  late SalesOrder? linkedOrder = widget.linkedOrder;

  bool get canConvert => status == QuotationStatus.accepted;
  bool get canCancel =>
      status == QuotationStatus.draft ||
      status == QuotationStatus.sent ||
      status == QuotationStatus.accepted;

  List<StockItemOption> get _productCatalog => widget.catalog;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.quotation.quotationNumber),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('إغلاق'),
        ),
        FilledButton.tonalIcon(
          onPressed: working ? null : printDocument,
          icon: const Icon(Icons.print_outlined),
          label: const Text('طباعة'),
        ),
        if (status == QuotationStatus.converted && linkedOrder != null)
          FilledButton.tonalIcon(
            onPressed: () => _openOrder(linkedOrder!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('فتح أمر البيع'),
          ),
        if (canCancel)
          IconButton(
            tooltip: 'إلغاء عرض السعر',
            onPressed: working ? null : cancelQuotation,
            icon: const Icon(Icons.cancel_outlined),
          ),
        if (canConvert)
          FilledButton.icon(
            onPressed: working ? null : convert,
            icon: const Icon(Icons.transform_outlined),
            label: const Text('تحويل إلى أمر بيع'),
          ),
        const SizedBox(width: 12),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SalesSection(
          title: 'بيانات عرض السعر',
          child: Wrap(
            spacing: 32,
            runSpacing: 18,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DocumentValue(
                label: 'رقم العرض',
                value: widget.quotation.quotationNumber,
              ),
              _DocumentValue(
                label: 'تاريخ العرض',
                value: _dateText(widget.quotation.quotationDate),
              ),
              _DocumentValue(
                label: 'صالح حتى',
                value: widget.quotation.validUntil == null
                    ? 'غير محدد'
                    : _dateText(widget.quotation.validUntil!),
              ),
              Chip(label: Text(_quotationStatusLabel(context, status))),
              _DocumentValue(label: 'العميل', value: widget.customerName),
              _DocumentValue(label: 'كود العميل', value: widget.customerCode),
              if (widget.customerPhone?.trim().isNotEmpty == true)
                _DocumentValue(label: 'الهاتف', value: widget.customerPhone!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SalesSection(
          title: 'تفاصيل الأصناف',
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 22,
                  columns: const [
                    DataColumn(label: Text('الصنف')),
                    DataColumn(label: Text('الكود')),
                    DataColumn(label: Text('الكمية'), numeric: true),
                    DataColumn(label: Text('الوحدة')),
                    DataColumn(label: Text('سعر الوحدة'), numeric: true),
                    DataColumn(label: Text('الخصم'), numeric: true),
                    DataColumn(label: Text('الضريبة'), numeric: true),
                    DataColumn(label: Text('الإجمالي'), numeric: true),
                  ],
                  rows: widget.quotation.items.map((item) {
                    final product = _productCatalog
                        .where((candidate) => candidate.id == item.itemId)
                        .firstOrNull;
                    return DataRow(
                      cells: [
                        DataCell(Text(product?.name ?? 'غير متاح')),
                        DataCell(Text(product?.code ?? 'غير متاح')),
                        DataCell(Text(_quantityText(item.quantity))),
                        DataCell(
                          Text(widget.unitNames[item.unitId] ?? 'غير متاح'),
                        ),
                        DataCell(Text(item.unitPrice.toStringAsFixed(2))),
                        DataCell(Text(item.discount.toStringAsFixed(2))),
                        DataCell(Text(item.tax.toStringAsFixed(2))),
                        DataCell(Text(item.lineTotal.toStringAsFixed(2))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SalesSection(
          title: 'الإجماليات',
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  _TotalLine(
                    label: 'الإجمالي الفرعي',
                    value: widget.quotation.subtotal,
                  ),
                  _TotalLine(label: 'الخصم', value: widget.quotation.discount),
                  _TotalLine(label: 'الضريبة', value: widget.quotation.tax),
                  const Divider(),
                  _TotalLine(
                    label: 'الإجمالي النهائي',
                    value: widget.quotation.grandTotal,
                    prominent: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.quotation.notes?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 16),
          _SalesSection(title: 'ملاحظات', child: Text(widget.quotation.notes!)),
        ],
      ],
    ),
  );

  Future<void> printDocument() async {
    setState(() => working = true);
    try {
      final factory = await FactoryStructureRepositoryImpl().getFactory();
      if (factory == null || factory.name.trim().isEmpty) {
        throw Exception('يرجى إعداد اسم المصنع أو المعرض قبل طباعة المستند');
      }
      final bytes = await generateSalesDocumentPdf(
        factoryName: factory.name,
        title: 'عرض سعر',
        number: widget.quotation.quotationNumber,
        date: widget.quotation.quotationDate,
        customer: Customer(
          id: widget.quotation.customerId,
          name: widget.customerName,
          code: widget.customerCode,
          createdAt: widget.quotation.createdAt,
          updatedAt: widget.quotation.updatedAt,
        ),
        notes: widget.quotation.notes,
        items: widget.quotation.items,
        catalog: _productCatalog,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> convert() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تحويل عرض السعر'),
        content: Text(
          'سيتم إنشاء أمر بيع من ${widget.quotation.quotationNumber} مع الحفاظ على العرض الأصلي. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تحويل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => working = true);
    final now = DateTime.now();
    try {
      final order = SalesOrder(
        id: 'order-${now.microsecondsSinceEpoch}',
        orderNumber: 'SO-${now.millisecondsSinceEpoch}',
        customerId: widget.quotation.customerId,
        quotationId: widget.quotation.id,
        orderDate: now,
        status: SalesOrderStatus.draft,
        subtotal: widget.quotation.subtotal,
        discount: widget.quotation.discount,
        tax: widget.quotation.tax,
        grandTotal: widget.quotation.grandTotal,
        notes: widget.quotation.notes,
        createdAt: now,
        updatedAt: now,
        items: widget.quotation.items,
      );
      final convertedOrder = await widget.repository.convertQuotationToOrder(
        widget.quotation,
        order,
      );
      if (!mounted) return;
      setState(() {
        status = QuotationStatus.converted;
        linkedOrder = convertedOrder;
        working = false;
      });
      final orderNumber = convertedOrder.orderNumber;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء أمر البيع: $orderNumber')),
      );
      if (!mounted) return;
      await _openOrder(convertedOrder);
    } catch (error) {
      if (!mounted) return;
      setState(() => working = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر التحويل: $error')));
    }
  }

  Future<void> cancelQuotation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء عرض السعر'),
        content: Text(
          'هل تريد إلغاء العرض ${widget.quotation.quotationNumber}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => working = true);
    try {
      await widget.repository.changeQuotationStatus(
        widget.quotation.id,
        QuotationStatus.cancelled,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _openOrder(SalesOrder order) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SalesOrderDetailsPage(
        repository: widget.repository,
        order: order,
        customerName: widget.customerName,
        customerCode: widget.customerCode,
        catalog: widget.catalog,
        unitNames: widget.unitNames,
        quotationNumber: widget.quotation.quotationNumber,
      ),
    ),
  );
}

class SalesOrderDetailsPage extends StatelessWidget {
  const SalesOrderDetailsPage({
    required this.repository,
    required this.order,
    required this.customerName,
    required this.customerCode,
    this.catalog = const [],
    this.unitNames = const {},
    this.quotationNumber,
    super.key,
  });

  final SalesRepository repository;
  final SalesOrder order;
  final String customerName;
  final String customerCode;
  final List<StockItemOption> catalog;
  final Map<String, String> unitNames;
  final String? quotationNumber;

  @override
  Widget build(BuildContext context) {
    final productCatalog = catalog;
    return Scaffold(
      appBar: AppBar(
        title: Text(order.orderNumber),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SalesSection(
            title: 'بيانات أمر البيع',
            child: Wrap(
              spacing: 32,
              runSpacing: 18,
              children: [
                _DocumentValue(label: 'رقم الأمر', value: order.orderNumber),
                _DocumentValue(label: 'العميل', value: customerName),
                _DocumentValue(label: 'كود العميل', value: customerCode),
                _DocumentValue(
                  label: 'حالة الأمر',
                  value: _orderStatusLabel(context, order.status),
                ),
                _DocumentValue(
                  label: 'التاريخ',
                  value: _dateText(order.orderDate),
                ),
                if (quotationNumber != null)
                  _DocumentValue(
                    label: 'عرض السعر المصدر',
                    value: quotationNumber!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SalesSection(
            title: 'تفاصيل الأصناف',
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 22,
                    columns: const [
                      DataColumn(label: Text('الصنف')),
                      DataColumn(label: Text('الكود')),
                      DataColumn(label: Text('الكمية'), numeric: true),
                      DataColumn(label: Text('الوحدة')),
                      DataColumn(label: Text('سعر الوحدة'), numeric: true),
                      DataColumn(label: Text('الخصم'), numeric: true),
                      DataColumn(label: Text('الضريبة'), numeric: true),
                      DataColumn(label: Text('الإجمالي'), numeric: true),
                    ],
                    rows: order.items.map((item) {
                      final product = productCatalog
                          .where((candidate) => candidate.id == item.itemId)
                          .firstOrNull;
                      return DataRow(
                        cells: [
                          DataCell(Text(product?.name ?? 'غير متاح')),
                          DataCell(Text(product?.code ?? 'غير متاح')),
                          DataCell(Text(_quantityText(item.quantity))),
                          DataCell(Text(unitNames[item.unitId] ?? 'غير متاح')),
                          DataCell(Text(item.unitPrice.toStringAsFixed(2))),
                          DataCell(Text(item.discount.toStringAsFixed(2))),
                          DataCell(Text(item.tax.toStringAsFixed(2))),
                          DataCell(Text(item.lineTotal.toStringAsFixed(2))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SalesSection(
            title: 'الإجماليات',
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    _TotalLine(label: 'الإجمالي الفرعي', value: order.subtotal),
                    _TotalLine(label: 'الخصم', value: order.discount),
                    _TotalLine(label: 'الضريبة', value: order.tax),
                    const Divider(),
                    _TotalLine(
                      label: 'الإجمالي النهائي',
                      value: order.grandTotal,
                      prominent: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (order.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _SalesSection(title: 'ملاحظات', child: Text(order.notes!)),
          ],
        ],
      ),
    );
  }
}

Future<Uint8List> generateSalesDocumentPdf({
  required String factoryName,
  required String title,
  required String number,
  required DateTime date,
  required Customer customer,
  required String? notes,
  required List<SalesItem> items,
  required List<StockItemOption> catalog,
}) async {
  if (factoryName.trim().isEmpty) {
    throw Exception('يرجى إعداد اسم المصنع أو المعرض قبل طباعة المستند');
  }
  final regular = pw.Font.ttf(
    (await rootBundle.load(
      'assets/fonts/NotoSansArabic-Regular.ttf',
    )).buffer.asByteData(),
  );
  final bold = pw.Font.ttf(
    (await rootBundle.load(
      'assets/fonts/NotoSansArabic-Bold.ttf',
    )).buffer.asByteData(),
  );
  final pdf = pw.Document();
  final navy = PdfColor.fromHex('#17324D');
  final wood = PdfColor.fromHex('#A66A3F');
  final amber = PdfColor.fromHex('#D29A5A');
  final cream = PdfColor.fromHex('#F6F1E8');
  final format = DateFormat('yyyy/MM/dd');
  final rows = items.map((line) {
    final product = catalog.where((item) => item.id == line.itemId).firstOrNull;
    final values = [
      product?.name ?? 'غير متاح',
      product?.code ?? 'غير متاح',
      line.quantity.toStringAsFixed(2),
      line.unitPrice.toStringAsFixed(2),
      line.discount.toStringAsFixed(2),
      line.tax.toStringAsFixed(2),
      line.lineTotal.toStringAsFixed(2),
    ];
    return values;
  }).toList();
  final subtotal = items.fold(
    0.0,
    (sum, item) => sum + item.quantity * item.unitPrice,
  );
  final totalDiscount = items.fold(0.0, (sum, item) => sum + item.discount);
  final totalTax = items.fold(0.0, (sum, item) => sum + item.tax);
  final grandTotal = subtotal - totalDiscount + totalTax;
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 30),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (context) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: pw.BoxDecoration(
                  color: cream,
                  border: pw.Border(
                    bottom: pw.BorderSide(color: wood, width: 2),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            factoryName,
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 20,
                              color: navy,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            title,
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 16,
                              color: wood,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FAF8F4'),
                  border: pw.Border.all(color: cream),
                ),
                child: pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1),
                    1: pw.FlexColumnWidth(1),
                  },
                  children: [
                    _pdfInfoRow(
                      'رقم المستند',
                      number,
                      'التاريخ',
                      format.format(date),
                    ),
                    _pdfInfoRow(
                      'العميل',
                      customer.name,
                      'الكود',
                      customer.code,
                    ),
                    if (customer.phone?.trim().isNotEmpty == true)
                      _pdfInfoRow('الهاتف', customer.phone!, ' ', ''),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Container(width: 3, height: 18, color: amber),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    'الأصناف',
                    style: pw.TextStyle(font: bold, fontSize: 11, color: navy),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: [
                  'اسم المنتج',
                  'الكود',
                  'الكمية',
                  'سعر الوحدة',
                  'الخصم',
                  'الضريبة',
                  'الإجمالي',
                ],
                data: rows,
                headerStyle: pw.TextStyle(
                  font: bold,
                  fontSize: 8,
                  color: PdfColors.white,
                ),
                cellStyle: pw.TextStyle(font: regular, fontSize: 8),
                headerDecoration: pw.BoxDecoration(color: navy),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                oddRowDecoration: pw.BoxDecoration(color: cream),
                cellAlignment: pw.Alignment.centerRight,
                headerAlignment: pw.Alignment.centerRight,
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(color: cream, width: .7),
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 5,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  width: 250,
                  padding: const pw.EdgeInsets.all(9),
                  decoration: pw.BoxDecoration(
                    color: cream,
                    border: pw.Border(
                      right: pw.BorderSide(color: wood, width: 2),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _pdfTotalLine('المجموع الفرعي', subtotal),
                      _pdfTotalLine('إجمالي الخصم', totalDiscount),
                      _pdfTotalLine('إجمالي الضريبة', totalTax),
                      pw.Container(
                        margin: const pw.EdgeInsets.only(top: 6),
                        padding: const pw.EdgeInsets.only(top: 5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: wood, width: 1),
                          ),
                        ),
                        child: _pdfTotalLine(
                          'الإجمالي النهائي',
                          grandTotal,
                          prominent: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (notes?.trim().isNotEmpty == true) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'ملاحظات',
                  style: pw.TextStyle(font: bold, fontSize: 9, color: navy),
                ),
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(top: 4),
                  padding: const pw.EdgeInsets.all(7),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FAF8F4'),
                    border: pw.Border.all(color: cream),
                  ),
                  child: pw.Text(
                    notes!,
                    style: pw.TextStyle(font: regular, fontSize: 8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
  return Uint8List.fromList(await pdf.save());
}

pw.Widget _pdfTotalLine(String label, double value, {bool prominent = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: prominent ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: prominent ? 10 : 8,
            ),
          ),
          pw.Text(
            value.toStringAsFixed(2),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: prominent ? 11 : 8,
              color: prominent ? PdfColor.fromHex('#17324D') : null,
            ),
          ),
        ],
      ),
    );

pw.TableRow _pdfInfoRow(
  String labelOne,
  String valueOne,
  String labelTwo,
  String valueTwo,
) => pw.TableRow(
  children: [
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$labelOne: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: valueOne),
          ],
        ),
      ),
    ),
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$labelTwo: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: valueTwo),
          ],
        ),
      ),
    ),
  ],
);

String _dateText(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _quotationStatusLabel(BuildContext context, QuotationStatus status) {
  final english = AppLocalizations.of(context).locale.languageCode == 'en';
  return switch (status) {
    QuotationStatus.draft => english ? 'Draft' : 'مسودة',
    QuotationStatus.sent => english ? 'Sent' : 'مرسل',
    QuotationStatus.accepted => english ? 'Accepted' : 'مقبول',
    QuotationStatus.rejected => english ? 'Rejected' : 'مرفوض',
    QuotationStatus.expired => english ? 'Expired' : 'منتهي',
    QuotationStatus.converted => english ? 'Converted' : 'تم تحويله',
    QuotationStatus.cancelled => english ? 'Cancelled' : 'ملغي',
  };
}

String _orderStatusLabel(BuildContext context, SalesOrderStatus status) {
  final english = AppLocalizations.of(context).locale.languageCode == 'en';
  return switch (status) {
    SalesOrderStatus.draft => english ? 'Draft' : 'مسودة',
    SalesOrderStatus.confirmed => english ? 'Confirmed' : 'مؤكد',
    SalesOrderStatus.partiallyDelivered =>
      english ? 'Partially delivered' : 'تم تسليم جزء منه',
    SalesOrderStatus.fullyDelivered =>
      english ? 'Fully delivered' : 'تم تسليمه بالكامل',
    SalesOrderStatus.cancelled => english ? 'Cancelled' : 'ملغي',
  };
}

String _quantityText(double value) => value == value.truncateToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

class _SalesDocumentDraft {
  const _SalesDocumentDraft({
    required this.customer,
    required this.items,
    required this.notes,
    required this.sendNow,
  });
  final Customer customer;
  final List<SalesItem> items;
  final String notes;
  final bool sendNow;
  double get subtotal =>
      items.fold(0.0, (sum, item) => sum + item.quantity * item.unitPrice);
  double get discount => items.fold(0.0, (sum, item) => sum + item.discount);
  double get tax => items.fold(0.0, (sum, item) => sum + item.tax);
  double get grandTotal => subtotal - discount + tax;
}

class _SalesSection extends StatelessWidget {
  const _SalesSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(8),
    ),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _DocumentValue extends StatelessWidget {
  const _DocumentValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.titleSmall),
    ],
  );
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final double value;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: prominent ? Theme.of(context).textTheme.titleSmall : null,
        ),
        Text(
          value.toStringAsFixed(2),
          style: prominent
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                )
              : Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class _SalesLineDraft {
  _SalesLineDraft({
    required this.product,
    String? unitId,
    double? quantity,
    double? unitPrice,
    double? discount,
    double? tax,
  }) : quantityController = TextEditingController(
         text: quantity?.toString() ?? '1',
       ),
       priceController = TextEditingController(
         text: unitPrice?.toString() ?? '0',
       ),
       discountController = TextEditingController(
         text: discount?.toString() ?? '0',
       ),
       taxController = TextEditingController(text: tax?.toString() ?? '0'),
       unitId = unitId ?? product.unitId;

  final TextEditingController quantityController;
  final TextEditingController priceController;
  final TextEditingController discountController;
  final TextEditingController taxController;
  StockItemOption product;
  String unitId;
  double unitConversionFactor = 1;

  double get quantity => double.tryParse(quantityController.text) ?? 0;
  double get unitPrice => double.tryParse(priceController.text) ?? 0;
  double get discount => double.tryParse(discountController.text) ?? 0;
  double get tax => double.tryParse(taxController.text) ?? 0;
  double get baseQuantity => quantity * unitConversionFactor;
  double get lineTotal => quantity * unitPrice - discount + tax;

  SalesItem toSalesItem({required String id}) => SalesItem(
    id: id,
    itemId: product.baseProductId,
    itemType: product.type == StockItemType.product
        ? SalesItemType.product
        : SalesItemType.rawMaterial,
    quantity: quantity,
    unitId: unitId,
    variantId: product.variantId,
    baseUnitId: product.unitId,
    unitConversionFactor: unitConversionFactor,
    baseQuantity: baseQuantity,
    inventoryIdentityKind: product.identityKind.value,
    unitPrice: unitPrice,
    discount: discount,
    tax: tax,
    lineTotal: lineTotal,
  );

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
    discountController.dispose();
    taxController.dispose();
  }
}

class _DeliveryDraft {
  const _DeliveryDraft({
    required this.warehouse,
    required this.item,
    required this.quantity,
    required this.operationId,
  });
  final Warehouse warehouse;
  final SalesItem item;
  final double quantity;
  final String operationId;
}

class DeliveryForm extends StatefulWidget {
  const DeliveryForm({
    required this.warehouses,
    required this.items,
    required this.catalog,
    required this.unitNames,
    required this.operationId,
    super.key,
  });
  final List<Warehouse> warehouses;
  final List<SalesItem> items;
  final List<StockItemOption> catalog;
  final Map<String, String> unitNames;
  final String operationId;

  @override
  State<DeliveryForm> createState() => _DeliveryFormState();
}

class _DeliveryFormState extends State<DeliveryForm> {
  late Warehouse warehouse = widget.warehouses.first;
  late SalesItem item = widget.items.first;
  final quantity = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    quantity.text = item.remainingQuantity.toString();
  }

  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تسجيل تسليم'),
    content: Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Warehouse>(
            initialValue: warehouse,
            decoration: const InputDecoration(labelText: 'المخزن'),
            items: widget.warehouses
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => warehouse = value!),
          ),
          DropdownButtonFormField<SalesItem>(
            initialValue: item,
            decoration: const InputDecoration(labelText: 'الصنف'),
            items: widget.items
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      '${widget.catalog.where((product) => product.id == value.itemId && product.variantId == value.variantId).firstOrNull?.name ?? 'غير متاح'} • متبقي ${_quantityText(value.remainingQuantity)} ${widget.unitNames[value.unitId] ?? ''}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                item = value!;
                quantity.text = item.remainingQuantity.toString();
              });
            },
          ),
          TextFormField(
            controller: quantity,
            decoration: const InputDecoration(labelText: 'الكمية المسلمة'),
            keyboardType: TextInputType.number,
            validator: (value) {
              final parsed = double.tryParse(value ?? '');
              return parsed == null ||
                      parsed <= 0 ||
                      parsed > item.remainingQuantity
                  ? 'تجاوز الكمية المتبقية'
                  : null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _DeliveryDraft(
              warehouse: warehouse,
              item: item,
              quantity: double.parse(quantity.text),
              operationId: widget.operationId,
            ),
          );
        },
        child: const Text('ترحيل التسليم'),
      ),
    ],
  );
}

class SalesDocumentForm extends StatefulWidget {
  const SalesDocumentForm({
    required this.title,
    required this.customers,
    required this.items,
    required this.unitNames,
    this.quotationActions = false,
    this.onCreateCustomer,
    super.key,
  });
  final String title;
  final List<Customer> customers;
  final List<StockItemOption> items;
  final Map<String, String> unitNames;
  final bool quotationActions;
  final Future<Customer?> Function()? onCreateCustomer;

  @override
  State<SalesDocumentForm> createState() => _SalesDocumentFormState();
}

class _SalesDocumentFormState extends State<SalesDocumentForm> {
  late Customer customer = widget.customers.first;
  late final List<Customer> availableCustomers = [...widget.customers];
  late final List<_SalesLineDraft> lines = [
    _SalesLineDraft(product: widget.items.first),
  ];
  final customerSearch = TextEditingController();
  final productSearch = TextEditingController();
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final Map<String, List<ProductUnitConversion>> unitConversions = {};

  List<Customer> get filteredCustomers {
    final query = customerSearch.text.trim().toLowerCase();
    final base = availableCustomers.where((value) {
      if (query.isEmpty) return true;
      final haystack = [
        value.name,
        value.code,
        value.phone ?? '',
        value.email ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    if (!base.any((value) => value.id == customer.id)) {
      return [customer, ...base].take(10).toList();
    }
    return base;
  }

  List<StockItemOption> get filteredItems {
    final query = productSearch.text.trim().toLowerCase();
    final base = widget.items.where((value) {
      if (query.isEmpty) return true;
      final haystack = [value.name, value.code].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
    return base;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadUnitConversions(0);
      await _syncSuggestedPrice(0);
    });
  }

  @override
  void dispose() {
    customerSearch.dispose();
    productSearch.dispose();
    notesController.dispose();
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _syncSuggestedPrice(int index) async {
    if (index < 0 || index >= lines.length) return;
    final line = lines[index];
    try {
      final resolution = await PricingLocalDataSource().resolvePrice(
        productId: line.product.baseProductId,
        variantId: line.product.variantId,
        customerId: customer.id,
        quantity: line.baseQuantity,
      );
      if (!mounted) return;
      setState(() {
        if (resolution.unitPrice > 0 && line.priceController.text == '0') {
          line.priceController.text =
              (resolution.unitPrice * line.unitConversionFactor)
                  .toStringAsFixed(2);
        }
      });
    } catch (_) {
      // Ignore missing or inactive price data and let the user edit the value.
    }
  }

  Future<void> _loadUnitConversions(int index) async {
    if (index < 0 || index >= lines.length) return;
    final line = lines[index];
    try {
      final configured = await RawMaterialsProductsRepositoryImpl()
          .unitConversions(line.product.baseProductId);
      if (!mounted || index >= lines.length || lines[index] != line) return;
      setState(() {
        unitConversions[line.product.baseProductId] = configured
            .where((conversion) => conversion.active)
            .toList();
        if (line.unitId != line.product.unitId &&
            !unitConversions[line.product.baseProductId]!.any(
              (conversion) => conversion.unitId == line.unitId,
            )) {
          line.unitId = line.product.unitId;
          line.unitConversionFactor = 1;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => unitConversions[line.product.baseProductId] = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = lines.fold<double>(
      0,
      (sum, line) => sum + line.quantity * line.unitPrice,
    );
    final discount = lines.fold<double>(0, (sum, line) => sum + line.discount);
    final tax = lines.fold<double>(0, (sum, line) => sum + line.tax);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('إلغاء'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: () => _save(sendNow: false),
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ كمسودة'),
          ),
          if (widget.quotationActions) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _save(sendNow: true),
              icon: const Icon(Icons.send_outlined),
              label: const Text('حفظ وإرسال'),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SalesSection(
              title: 'بيانات المستند',
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _DocumentValue(
                    label: 'تاريخ الإنشاء',
                    value: _dateText(DateTime.now()),
                  ),
                  _DocumentValue(
                    label: 'رقم المرجع',
                    value: 'يُنشأ تلقائياً عند الحفظ',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SalesSection(
              title: 'العميل',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: customerSearch,
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم العميل أو الكود أو الهاتف...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth > 740
                              ? 520
                              : constraints.maxWidth,
                          child: DropdownButtonFormField<Customer>(
                            value: customer,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'اختر العميل',
                              border: OutlineInputBorder(),
                            ),
                            items: filteredCustomers
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      '${value.name} • ${value.code}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => customer = value);
                              for (
                                var index = 0;
                                index < lines.length;
                                index++
                              ) {
                                _syncSuggestedPrice(index);
                              }
                            },
                          ),
                        ),
                        if (widget.onCreateCustomer != null)
                          OutlinedButton.icon(
                            onPressed: _createCustomer,
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('إضافة عميل'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 6,
                      children: [
                        _DocumentValue(
                          label: 'العميل المحدد',
                          value: customer.name,
                        ),
                        _DocumentValue(label: 'الكود', value: customer.code),
                        if (customer.phone?.trim().isNotEmpty == true)
                          _DocumentValue(
                            label: 'الهاتف',
                            value: customer.phone!,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SalesSection(
              title: 'الأصناف',
              trailing: FilledButton.tonalIcon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('إضافة صنف'),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: productSearch,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن منتج بالاسم أو الكود...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  for (var index = 0; index < lines.length; index++)
                    _lineEditor(index),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SalesSection(
              title: 'ملاحظات',
              child: TextFormField(
                controller: notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'أضف ملاحظات المستند عند الحاجة',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SalesSection(
              title: 'ملخص الإجماليات',
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      _TotalLine(label: 'الإجمالي الفرعي', value: subtotal),
                      _TotalLine(label: 'الخصم', value: discount),
                      _TotalLine(label: 'الضريبة', value: tax),
                      const Divider(),
                      _TotalLine(
                        label: 'الإجمالي النهائي',
                        value: subtotal - discount + tax,
                        prominent: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineEditor(int index) {
    final line = lines[index];
    final options = <StockItemOption>[
      line.product,
      ...filteredItems.where(
        (item) =>
            item.selectionId != line.product.selectionId &&
            !lines.asMap().entries.any(
              (entry) =>
                  entry.key != index &&
                  entry.value.product.selectionId == item.selectionId,
            ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1050;
          final narrowFieldWidth = wide
              ? 150.0
              : (constraints.maxWidth - 12) / 2;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'بند ${index + 1}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (lines.length > 1)
                      IconButton(
                        tooltip: 'حذف الصنف',
                        onPressed: () =>
                            setState(() => lines.removeAt(index).dispose()),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: wide ? 340 : constraints.maxWidth,
                      child: DropdownButtonFormField<StockItemOption>(
                        value: line.product,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المنتج',
                          border: OutlineInputBorder(),
                        ),
                        items: options
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  '${item.name} • ${item.code}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            line.product = value;
                            line.unitId = value.unitId;
                            line.unitConversionFactor = 1;
                            line.priceController.text = '0';
                          });
                          _loadUnitConversions(index);
                          _syncSuggestedPrice(index);
                        },
                      ),
                    ),
                    SizedBox(
                      width: narrowFieldWidth,
                      child: TextFormField(
                        controller: line.quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الكمية',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          return parsed == null ||
                                  !parsed.isFinite ||
                                  parsed <= 0
                              ? 'أدخل كمية صحيحة'
                              : null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: wide ? 120 : narrowFieldWidth,
                      child: DropdownButtonFormField<String>(
                        initialValue: line.unitId,
                        decoration: const InputDecoration(
                          labelText: 'الوحدة',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: line.product.unitId,
                            child: Text(
                              widget.unitNames[line.product.unitId] ??
                                  'غير متاح',
                            ),
                          ),
                          ...(unitConversions[line.product.baseProductId] ?? [])
                              .map(
                                (conversion) => DropdownMenuItem(
                                  value: conversion.unitId,
                                  child: Text(
                                    widget.unitNames[conversion.unitId] ??
                                        conversion.unitId,
                                  ),
                                ),
                              ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            line.unitId = value;
                            line.unitConversionFactor =
                                value == line.product.unitId
                                ? 1
                                : unitConversions[line.product.baseProductId]!
                                      .singleWhere(
                                        (conversion) =>
                                            conversion.unitId == value,
                                      )
                                      .factorToBase;
                            line.priceController.text = '0';
                          });
                          _syncSuggestedPrice(index);
                        },
                      ),
                    ),
                    SizedBox(
                      width: narrowFieldWidth,
                      child: TextFormField(
                        controller: line.priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'سعر الوحدة',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            _nonNegativeNumber(value, 'أدخل سعراً صحيحاً'),
                      ),
                    ),
                    SizedBox(
                      width: narrowFieldWidth,
                      child: TextFormField(
                        controller: line.discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الخصم',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            _nonNegativeNumber(value, 'أدخل خصماً صحيحاً'),
                      ),
                    ),
                    SizedBox(
                      width: narrowFieldWidth,
                      child: TextFormField(
                        controller: line.taxController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الضريبة',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            _nonNegativeNumber(value, 'أدخل ضريبة صحيحة'),
                      ),
                    ),
                    SizedBox(
                      width: wide ? 150 : constraints.maxWidth,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'إجمالي البند',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(line.lineTotal.toStringAsFixed(2)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _nonNegativeNumber(String? value, String error) {
    final parsed = double.tryParse(value?.trim() ?? '');
    return parsed == null || !parsed.isFinite || parsed < 0 ? error : null;
  }

  Future<void> _createCustomer() async {
    final created = await widget.onCreateCustomer?.call();
    if (!mounted || created == null) return;
    setState(() {
      availableCustomers.add(created);
      customer = created;
      customerSearch.clear();
    });
    for (var index = 0; index < lines.length; index++) {
      _syncSuggestedPrice(index);
    }
  }

  void _addLine() {
    final next = widget.items.firstWhereOrNull(
      (item) =>
          !lines.any((line) => line.product.selectionId == item.selectionId),
    );
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة جميع المنتجات المتاحة')),
      );
      return;
    }
    setState(() => lines.add(_SalesLineDraft(product: next)));
    _loadUnitConversions(lines.length - 1);
    _syncSuggestedPrice(lines.length - 1);
  }

  void _save({required bool sendNow}) {
    if (!formKey.currentState!.validate()) return;
    final selectedProductIds = lines
        .map((line) => line.product.selectionId)
        .toSet();
    if (selectedProductIds.length != lines.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تكرار المنتج في المستند نفسه')),
      );
      return;
    }
    final items = lines.asMap().entries.map((entry) {
      return entry.value.toSalesItem(
        id: 'item-${DateTime.now().microsecondsSinceEpoch}-${entry.key}',
      );
    }).toList();
    Navigator.pop(
      context,
      _SalesDocumentDraft(
        customer: customer,
        items: items,
        notes: notesController.text.trim(),
        sendNow: sendNow,
      ),
    );
  }
}

class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({
    required this.title,
    required this.customers,
    this.current,
    super.key,
  });

  final String title;
  final List<Customer> customers;
  final Customer? current;

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final formKey = GlobalKey<FormState>();
  late final nameController = TextEditingController(
    text: widget.current?.name ?? '',
  );
  late final codeController = TextEditingController(
    text: widget.current?.code ?? '',
  );
  late final phoneController = TextEditingController(
    text: widget.current?.phone ?? '',
  );
  late final emailController = TextEditingController(
    text: widget.current?.email ?? '',
  );

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: MediaQuery.sizeOf(context).width >= 680
          ? 620
          : MediaQuery.sizeOf(context).width - 48,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fieldWidth = constraints.maxWidth > 500
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: nameController,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: 'اسم العميل',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    value?.trim().isEmpty ?? true
                                    ? 'اسم العميل مطلوب'
                                    : null,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: codeController,
                                decoration: const InputDecoration(
                                  labelText: 'كود العميل',
                                  border: OutlineInputBorder(),
                                ),
                                validator: _validateCode,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'رقم الهاتف',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final phone = value?.trim() ?? '';
                                  if (phone.isNotEmpty &&
                                      !RegExp(
                                        r'^[0-9+()\-\s]{7,20}$',
                                      ).hasMatch(phone)) {
                                    return 'رقم الهاتف غير صحيح';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'البريد الإلكتروني',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isNotEmpty &&
                                      !RegExp(
                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                      ).hasMatch(email)) {
                                    return 'البريد الإلكتروني غير صحيح';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('حفظ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';
    if (code.isEmpty) return 'كود العميل مطلوب';
    final duplicate = widget.customers.any(
      (customer) =>
          customer.id != widget.current?.id &&
          customer.code.trim().toLowerCase() == code.toLowerCase(),
    );
    return duplicate ? 'كود العميل مستخدم بالفعل' : null;
  }

  void _save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': nameController.text.trim(),
      'code': codeController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
    });
  }
}
