import 'package:flutter/material.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/detail/furnexa_detail.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/sales/domain/repositories/sales_repository.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

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
  late final TabController tabs;
  List<Customer> customers = [];
  List<Quotation> quotations = [];
  List<SalesOrder> orders = [];
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
    super.dispose();
  }

  Future<void> load() async {
    final result = await Future.wait([
      repository.customers(),
      repository.quotations(),
      repository.orders(),
    ]);
    if (!mounted) return;
    setState(() {
      customers = result[0] as List<Customer>;
      quotations = result[1] as List<Quotation>;
      orders = result[2] as List<SalesOrder>;
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

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
  Widget customerList() => panel(
    'العملاء',
    'إضافة عميل',
    customerForm,
    customers
        .map(
          (customer) => ListTile(
            title: Text('${customer.name} • ${customer.code}'),
            subtitle: Text(customer.phone ?? '-'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: customer.active ? 'تعطيل' : 'تفعيل',
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
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => customerForm(customer),
                ),
              ],
            ),
            onTap: () => openCustomerProfile(customer),
          ),
        )
        .toList(),
  );
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
            subtitle: Text(quotation.status.name),
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
            subtitle: Text(order.status.name),
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
                    tooltip: 'تسليم',
                    icon: const Icon(Icons.local_shipping_outlined),
                    onPressed: () => deliveryForm(order),
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
  Future<void> customerForm([Customer? current]) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => SimpleSalesForm(
        title: current == null ? 'إضافة عميل' : 'تعديل العميل',
        fields: const ['name', 'code', 'phone', 'email'],
      ),
    );
    if (values == null) return;
    final now = DateTime.now();
    try {
      await repository.saveCustomer(
        Customer(
          id: current?.id ?? 'customer-${now.microsecondsSinceEpoch}',
          name: values['name']!,
          code: values['code']!,
          phone: values['phone'],
          email: values['email'],
          active: current?.active ?? true,
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      await load();
    } catch (e) {
      message(e.toString());
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
    final value = await showDialog<_SalesDocumentDraft>(
      context: context,
      builder: (_) => SalesDocumentForm(
        title: 'عرض سعر جديد',
        customers: activeCustomers,
        items: items,
      ),
    );
    if (value == null) return;
    final now = DateTime.now();
    try {
      await repository.saveQuotation(
        Quotation(
          id: 'quotation-${now.microsecondsSinceEpoch}',
          quotationNumber: 'QT-${now.millisecondsSinceEpoch}',
          customerId: value.customer.id,
          quotationDate: now,
          status: QuotationStatus.draft,
          subtotal: value.subtotal,
          discount: value.discount,
          tax: value.tax,
          grandTotal: value.grandTotal,
          createdAt: now,
          updatedAt: now,
          items: [value.item],
        ),
      );
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
    final value = await showDialog<_SalesDocumentDraft>(
      context: context,
      builder: (_) => SalesDocumentForm(
        title: 'أمر بيع جديد',
        customers: activeCustomers,
        items: items,
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
          createdAt: now,
          updatedAt: now,
          items: [value.item],
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
    final value = await showDialog<_DeliveryDraft>(
      context: context,
      builder: (_) => DeliveryForm(warehouses: warehouses, items: items),
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
          ),
        ],
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuotationDetailsPage(
          repository: repository,
          quotation: quotation,
          customerName: customer?.name ?? '-',
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
                          '${_dateText(value.quotationDate)} • ${value.status.name}',
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
                          '${_dateText(value.orderDate)} • ${value.status.name}',
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
    super.key,
  });
  final SalesRepository repository;
  final Quotation quotation;
  final String customerName;

  @override
  State<QuotationDetailsPage> createState() => _QuotationDetailsPageState();
}

class _QuotationDetailsPageState extends State<QuotationDetailsPage> {
  bool working = false;

  bool get canConvert => widget.quotation.status == QuotationStatus.accepted;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('تفاصيل ${widget.quotation.quotationNumber}'),
      actions: [
        if (canConvert)
          IconButton(
            tooltip: 'تحويل إلى أمر بيع',
            icon: const Icon(Icons.transform_outlined),
            onPressed: working ? null : convert,
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.quotation.quotationNumber,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('العميل: ${widget.customerName}'),
                Text('التاريخ: ${_dateText(widget.quotation.quotationDate)}'),
                Text(
                  'صالح حتى: ${widget.quotation.validUntil == null ? '-' : _dateText(widget.quotation.validUntil!)}',
                ),
                Text('الحالة: ${widget.quotation.status.name}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              const ListTile(title: Text('الأصناف')),
              ...widget.quotation.items.map(
                (item) => ListTile(
                  title: Text(item.itemId),
                  subtitle: Text(
                    'الكمية: ${item.quantity} • الوحدة: ${item.unitId}',
                  ),
                  trailing: Text(
                    'سعر ${item.unitPrice} • خصم ${item.discount} • ضريبة ${item.tax}\nالإجمالي ${item.lineTotal}',
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المجموع الفرعي: ${widget.quotation.subtotal}'),
                Text('الخصم: ${widget.quotation.discount}'),
                Text('الضريبة: ${widget.quotation.tax}'),
                Text(
                  'الإجمالي النهائي: ${widget.quotation.grandTotal}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (widget.quotation.notes?.isNotEmpty == true)
                  Text('ملاحظات: ${widget.quotation.notes}'),
              ],
            ),
          ),
        ),
        if (canConvert)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: FilledButton.icon(
              onPressed: working ? null : convert,
              icon: const Icon(Icons.transform_outlined),
              label: const Text('تحويل إلى أمر بيع'),
            ),
          ),
      ],
    ),
  );

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
      await widget.repository.convertQuotationToOrder(widget.quotation, order);
      if (!mounted) return;
      setState(() => working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء أمر البيع والحفاظ على عرض السعر'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => working = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر التحويل: $error')));
    }
  }
}

String _dateText(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

class _SalesDocumentDraft {
  const _SalesDocumentDraft({required this.customer, required this.item});
  final Customer customer;
  final SalesItem item;
  double get subtotal => item.quantity * item.unitPrice;
  double get discount => item.discount;
  double get tax => item.tax;
  double get grandTotal => subtotal - discount + tax;
}

class _DeliveryDraft {
  const _DeliveryDraft({
    required this.warehouse,
    required this.item,
    required this.quantity,
  });
  final Warehouse warehouse;
  final SalesItem item;
  final double quantity;
}

class DeliveryForm extends StatefulWidget {
  const DeliveryForm({
    required this.warehouses,
    required this.items,
    super.key,
  });
  final List<Warehouse> warehouses;
  final List<SalesItem> items;

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
                      '${value.itemId} (متبقي ${value.remainingQuantity})',
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
    super.key,
  });
  final String title;
  final List<Customer> customers;
  final List<StockItemOption> items;

  @override
  State<SalesDocumentForm> createState() => _SalesDocumentFormState();
}

class _SalesDocumentFormState extends State<SalesDocumentForm> {
  late Customer customer = widget.customers.first;
  late StockItemOption item = widget.items.first;
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController(text: '0');
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Customer>(
              initialValue: customer,
              decoration: const InputDecoration(labelText: 'العميل'),
              items: widget.customers
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.name)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => customer = value!),
            ),
            DropdownButtonFormField<StockItemOption>(
              initialValue: item,
              decoration: const InputDecoration(labelText: 'الصنف'),
              items: widget.items
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('${value.name} • ${value.code}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => item = value!),
            ),
            TextFormField(
              controller: quantity,
              decoration: const InputDecoration(labelText: 'الكمية'),
              keyboardType: TextInputType.number,
              validator: _positive,
            ),
            TextFormField(
              controller: price,
              decoration: const InputDecoration(labelText: 'سعر الوحدة'),
              keyboardType: TextInputType.number,
              validator: _nonNegative,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: save, child: const Text('حفظ مسودة')),
    ],
  );

  String? _positive(String? value) {
    final parsed = double.tryParse(value ?? '');
    return parsed == null || parsed <= 0 ? 'أدخل كمية صحيحة' : null;
  }

  String? _nonNegative(String? value) {
    final parsed = double.tryParse(value ?? '');
    return parsed == null || parsed < 0 ? 'أدخل سعراً صحيحاً' : null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SalesDocumentDraft(
        customer: customer,
        item: SalesItem(
          id: 'item-${DateTime.now().microsecondsSinceEpoch}',
          itemId: item.id,
          itemType: item.type == StockItemType.product
              ? SalesItemType.product
              : SalesItemType.rawMaterial,
          quantity: double.parse(quantity.text),
          unitId: item.unitId,
          unitPrice: double.parse(price.text),
        ),
      ),
    );
  }
}

class SimpleSalesForm extends StatefulWidget {
  const SimpleSalesForm({required this.title, required this.fields, super.key});
  final String title;
  final List<String> fields;
  @override
  State<SimpleSalesForm> createState() => _SimpleSalesFormState();
}

class _SimpleSalesFormState extends State<SimpleSalesForm> {
  final keyForm = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      controllers[field] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: keyForm,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.fields
              .map(
                (field) => TextFormField(
                  controller: controllers[field],
                  decoration: InputDecoration(
                    labelText: field,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'هذا الحقل مطلوب'
                      : null,
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (!keyForm.currentState!.validate()) return;
            Navigator.pop(context, {
              for (final entry in controllers.entries)
                entry.key: entry.value.text.trim(),
            });
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
