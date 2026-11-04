import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:furnexa/features/accounting/domain/entities/accounting_entities.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/purchasing/domain/entities/purchasing_entities.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PurchaseRequestDocumentPage extends StatelessWidget {
  const PurchaseRequestDocumentPage({
    super.key,
    required this.suppliers,
    required this.items,
    required this.unitNames,
    required this.createId,
    required this.createNumber,
  });

  final List<Supplier> suppliers;
  final List<StockItemOption> items;
  final Map<String, String> unitNames;
  final String Function(String) createId;
  final String Function(String) createNumber;

  @override
  Widget build(BuildContext context) => _PurchaseDocumentEditorPage(
    title: 'طلب شراء جديد',
    numberLabel: 'رقم الطلب',
    number: createNumber('PR'),
    suppliers: suppliers,
    items: items
        .where((item) => item.type == StockItemType.rawMaterial)
        .toList(),
    unitNames: unitNames,
    createId: createId,
    onSave: (documentId, number, date, supplierId, notes, lines) {
      final now = DateTime.now();
      return PurchaseRequest(
        id: documentId,
        requestNumber: number,
        requestDate: date,
        supplierId: supplierId,
        requestedBy: 'مقدم الطلب',
        notes: notes.isEmpty ? null : notes,
        status: PurchaseRequestStatus.draft,
        createdAt: now,
        updatedAt: now,
        items: lines,
      );
    },
  );
}

class PurchaseOrderDocumentPage extends StatelessWidget {
  const PurchaseOrderDocumentPage({
    super.key,
    required this.suppliers,
    required this.items,
    required this.unitNames,
    required this.createId,
    required this.createNumber,
    this.initialOrder,
  });

  final List<Supplier> suppliers;
  final List<StockItemOption> items;
  final Map<String, String> unitNames;
  final String Function(String) createId;
  final String Function(String) createNumber;
  final PurchaseOrder? initialOrder;

  @override
  Widget build(BuildContext context) => _PurchaseDocumentEditorPage(
    title: initialOrder == null ? 'أمر شراء جديد' : 'تسعير أمر الشراء',
    numberLabel: 'رقم الأمر',
    number: initialOrder?.orderNumber ?? createNumber('PO'),
    suppliers: suppliers,
    items: items
        .where((item) => item.type == StockItemType.rawMaterial)
        .toList(),
    unitNames: unitNames,
    createId: createId,
    initialOrder: initialOrder,
    showFinancials: true,
    onSave: (documentId, number, date, supplierId, notes, lines) {
      final now = DateTime.now();
      final subtotal = lines.fold<double>(
        0,
        (sum, line) => sum + line.quantity * line.unitPrice,
      );
      final discount = lines.fold<double>(
        0,
        (sum, line) => sum + line.discount,
      );
      final tax = lines.fold<double>(0, (sum, line) => sum + line.tax);
      final updatedOrder = PurchaseOrder(
        id: documentId,
        orderNumber: number,
        supplierId: supplierId,
        orderDate: date,
        status: PurchaseOrderStatus.draft,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        grandTotal: subtotal - discount + tax,
        notes: notes.isEmpty ? null : notes,
        createdAt: now,
        updatedAt: now,
        items: lines,
      );
      return initialOrder?.copyWith(
            orderNumber: number,
            orderDate: date,
            status: initialOrder?.status == PurchaseOrderStatus.approved
                ? PurchaseOrderStatus.draft
                : initialOrder?.status ?? PurchaseOrderStatus.draft,
            notes: notes.isEmpty ? null : notes,
            updatedAt: now,
            items: lines,
            subtotal: subtotal,
            discount: discount,
            tax: tax,
            grandTotal: subtotal - discount + tax,
          ) ??
          updatedOrder;
    },
  );
}

typedef _SaveDocument =
    Object Function(
      String documentId,
      String number,
      DateTime date,
      String supplierId,
      String notes,
      List<PurchasingItem> lines,
    );

class _PurchaseDocumentEditorPage extends StatefulWidget {
  const _PurchaseDocumentEditorPage({
    required this.title,
    required this.numberLabel,
    required this.number,
    required this.suppliers,
    required this.items,
    required this.unitNames,
    required this.createId,
    required this.onSave,
    this.initialOrder,
    this.showFinancials = false,
  });

  final String title;
  final String numberLabel;
  final String number;
  final List<Supplier> suppliers;
  final List<StockItemOption> items;
  final Map<String, String> unitNames;
  final String Function(String) createId;
  final _SaveDocument onSave;
  final PurchaseOrder? initialOrder;
  final bool showFinancials;

  @override
  State<_PurchaseDocumentEditorPage> createState() =>
      _PurchaseDocumentEditorPageState();
}

class _PurchaseDocumentEditorPageState
    extends State<_PurchaseDocumentEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberController;
  late final TextEditingController _notesController;
  final List<_DraftPurchaseLine> _lines = [];
  DateTime _date = DateTime.now();
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    final initialOrder = widget.initialOrder;
    _numberController = TextEditingController(
      text: initialOrder?.orderNumber ?? widget.number,
    );
    _notesController = TextEditingController(text: initialOrder?.notes ?? '');
    _date = initialOrder?.orderDate ?? _date;
    _supplierId = initialOrder?.supplierId;
    if (initialOrder == null) {
      _addLine();
    } else {
      for (final item in initialOrder.items) {
        final catalogItem = widget.items
            .where((candidate) => candidate.id == item.itemId)
            .firstOrNull;
        _lines.add(
          _DraftPurchaseLine(
            item: catalogItem,
            id: item.id,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            discount: item.discount,
            tax: item.tax,
            receivedQuantity: item.receivedQuantity,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addLine() => setState(() => _lines.add(_DraftPurchaseLine()));

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أضف خامة واحدة على الأقل')));
      return;
    }
    if (_supplierId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر المورد قبل الحفظ')));
      return;
    }
    final selectedIds = _lines.map((line) => line.item!.id).toSet();
    if (selectedIds.length != _lines.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تكرار الخامة في المستند نفسه')),
      );
      return;
    }
    final documentId =
        widget.initialOrder?.id ??
        widget.createId(widget.showFinancials ? 'order' : 'request');
    final lines = <PurchasingItem>[];
    for (var index = 0; index < _lines.length; index++) {
      final line = _lines[index];
      final item = line.item!;
      final quantity = double.parse(line.quantity.text.trim());
      final price = widget.showFinancials
          ? double.tryParse(line.unitPrice.text.trim()) ?? 0.0
          : 0.0;
      lines.add(
        PurchasingItem(
          id: line.id ?? purchasingDocumentItemId(documentId, index),
          itemId: item.id,
          itemType: PurchasingItemType.rawMaterial,
          quantity: quantity,
          unitId: item.unitId,
          unitPrice: price,
          discount: line.discount,
          tax: line.tax,
          receivedQuantity: line.receivedQuantity,
          lineTotal: quantity * price - line.discount + line.tax,
        ),
      );
    }
    final result = widget.onSave(
      documentId,
      _numberController.text.trim(),
      _date,
      _supplierId!,
      _notesController.text.trim(),
      lines,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _lines.fold<double>(0, (sum, line) {
      final quantity = double.tryParse(line.quantity.text) ?? 0;
      final price = double.tryParse(line.unitPrice.text) ?? 0;
      return sum + quantity * price - line.discount + line.tax;
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'إلغاء والعودة',
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
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ المستند'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DocumentSection(
              title: 'بيانات المستند',
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth > 760
                          ? 240
                          : constraints.maxWidth,
                      child: TextFormField(
                        controller: _numberController,
                        decoration: InputDecoration(
                          labelText: widget.numberLabel,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'رقم المستند مطلوب'
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth > 760
                          ? 240
                          : constraints.maxWidth,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'التاريخ',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(_formatDate(_date))),
                            IconButton(
                              tooltip: 'اختيار التاريخ',
                              onPressed: _chooseDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth > 760
                          ? 360
                          : constraints.maxWidth,
                      child: DropdownButtonFormField<String>(
                        initialValue: _supplierId,
                        onChanged: widget.initialOrder == null
                            ? (value) => setState(() => _supplierId = value)
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'المورد',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.suppliers
                            .map(
                              (supplier) => DropdownMenuItem(
                                value: supplier.id,
                                child: Text(
                                  '${supplier.name}  •  ${supplier.code}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (value) =>
                            value == null ? 'اختر المورد' : null,
                      ),
                    ),
                    SizedBox(
                      width: constraints.maxWidth,
                      child: TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DocumentSection(
              title: 'المواد المطلوبة',
              trailing: FilledButton.tonalIcon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('إضافة خامة'),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < _lines.length; index++)
                    _lineEditor(index),
                  if (widget.showFinancials)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'الإجمالي: ${grandTotal.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineEditor(int index) {
    final line = _lines[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth > 850
                      ? 360
                      : constraints.maxWidth,
                  child: DropdownButtonFormField<StockItemOption>(
                    initialValue: line.item,
                    decoration: InputDecoration(
                      labelText: 'اسم الخامة',
                      border: const OutlineInputBorder(),
                      helperText: line.item == null
                          ? 'اختر بالاسم، والكود مرجع ثانوي'
                          : 'الكود: ${line.item!.code}',
                    ),
                    items: widget.items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.code,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => line.item = value),
                    validator: (value) => value == null ? 'اختر الخامة' : null,
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    controller: line.quantity,
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
                      return parsed == null || !parsed.isFinite || parsed <= 0
                          ? 'أدخل كمية صحيحة'
                          : null;
                    },
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'الوحدة',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      line.item == null
                          ? '—'
                          : widget.unitNames[line.item!.unitId] ??
                                line.item!.unitId,
                    ),
                  ),
                ),
                if (widget.showFinancials) ...[
                  SizedBox(
                    width: 145,
                    child: TextFormField(
                      controller: line.unitPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر الوحدة',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) return null;
                        final parsed = double.tryParse(value!.trim());
                        return parsed == null || !parsed.isFinite || parsed < 0
                            ? 'أدخل سعراً صحيحاً'
                            : null;
                      },
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'الإجمالي',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        ((double.tryParse(line.quantity.text) ?? 0) *
                                    (double.tryParse(line.unitPrice.text) ??
                                        0) -
                                line.discount +
                                line.tax)
                            .toStringAsFixed(2),
                      ),
                    ),
                  ),
                ],
                IconButton(
                  tooltip: 'حذف الخامة',
                  onPressed: () => setState(() {
                    _lines.removeAt(index).dispose();
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftPurchaseLine {
  _DraftPurchaseLine({
    this.item,
    this.id,
    double quantity = 0,
    double? unitPrice,
    this.discount = 0,
    this.tax = 0,
    this.receivedQuantity = 0,
  }) {
    this.quantity.text = quantity == 0 ? '' : quantity.toString();
    this.unitPrice.text = unitPrice == null || !unitPrice.isFinite
        ? ''
        : unitPrice.toString();
  }

  StockItemOption? item;
  final String? id;
  final double discount, tax, receivedQuantity;
  final TextEditingController quantity = TextEditingController();
  final TextEditingController unitPrice = TextEditingController();
  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
  }
}

class PurchaseDocumentDetailsPage extends StatelessWidget {
  const PurchaseDocumentDetailsPage({
    super.key,
    this.request,
    this.order,
    this.generatedOrder,
    this.purchaseRequestNumber,
    this.receipts = const [],
    this.receiptJournalEntries = const {},
    required this.supplier,
    required this.items,
    required this.unitNames,
    this.warehouses = const [],
    required this.onPrint,
    this.onOpenAccountingEntry,
    this.onEditOrder,
    this.onOpenOrder,
  }) : assert(request != null || order != null);

  final PurchaseRequest? request;
  final PurchaseOrder? order;
  final PurchaseOrder? generatedOrder;
  final String? purchaseRequestNumber;
  final List<PurchaseReceipt> receipts;
  final Map<String, JournalEntry> receiptJournalEntries;
  final Supplier? supplier;
  final List<StockItemOption> items;
  final Map<String, String> unitNames;
  final List<Warehouse> warehouses;
  final Future<void> Function() onPrint;
  final ValueChanged<JournalEntry>? onOpenAccountingEntry;
  final VoidCallback? onEditOrder;
  final VoidCallback? onOpenOrder;

  String get _title =>
      request == null ? 'تفاصيل أمر الشراء' : 'تفاصيل طلب الشراء';
  String get _number => request?.requestNumber ?? order!.orderNumber;
  String get _date => _formatDate(request?.requestDate ?? order!.orderDate);
  String get _status => request == null
      ? _orderStatus(order!.status)
      : _requestStatus(request!.status);
  List<PurchasingItem> get _lines => request?.items ?? order!.items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () async {
              try {
                await onPrint();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.print_outlined),
            label: const Text('طباعة'),
          ),
          if ((order?.status == PurchaseOrderStatus.draft ||
                  order?.status == PurchaseOrderStatus.approved) &&
              onEditOrder != null) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onEditOrder,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('إدخال الأسعار'),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _DocumentSection(
            title: 'بيانات المستند',
            child: Wrap(
              spacing: 32,
              runSpacing: 18,
              children: [
                _DetailValue(label: 'الرقم', value: _number),
                _DetailValue(label: 'التاريخ', value: _date),
                _DetailValue(
                  label: 'المورد',
                  value: supplier?.name ?? 'غير متاح',
                ),
                _DetailValue(label: 'حالة المستند', value: _status),
                if (request != null)
                  _DetailValue(
                    label: 'مقدم الطلب',
                    value: request!.requestedBy,
                  ),
                if (purchaseRequestNumber != null)
                  _DetailValue(
                    label: 'مرجع طلب الشراء',
                    value: purchaseRequestNumber!,
                  ),
                if (supplier?.code != null)
                  _DetailValue(label: 'كود المورد', value: supplier!.code),
                if (supplier?.phone != null)
                  _DetailValue(label: 'الهاتف', value: supplier!.phone!),
              ],
            ),
          ),
          if (generatedOrder != null) ...[
            const SizedBox(height: 16),
            _DocumentSection(
              title: 'أمر الشراء الناتج',
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _DetailValue(
                    label: 'رقم أمر الشراء',
                    value: generatedOrder!.orderNumber,
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onOpenOrder,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('فتح أمر الشراء'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _DocumentSection(
            title: 'المواد',
            child: Column(
              children: [
                for (var index = 0; index < _lines.length; index++)
                  _detailLine(index, _lines[index]),
                if (request == null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          Text(
                            'الإجمالي الفرعي: ${order!.subtotal.toStringAsFixed(2)}',
                          ),
                          Text('الخصم: ${order!.discount.toStringAsFixed(2)}'),
                          Text('الضريبة: ${order!.tax.toStringAsFixed(2)}'),
                          Text(
                            'الإجمالي الكلي: ${order!.grandTotal.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (request == null && receipts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DocumentSection(
              title: 'إيصالات الاستلام',
              child: Column(
                children: [
                  for (final receipt in receipts)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(receipt.receiptNumber),
                      subtitle: Text(
                        '${_formatDate(receipt.receiptDate)} | المخزن ${_warehouseName(receipt.warehouseId)}',
                      ),
                      trailing:
                          receiptJournalEntries[receipt.id] == null ||
                              onOpenAccountingEntry == null
                          ? null
                          : TextButton.icon(
                              onPressed: () => onOpenAccountingEntry!(
                                receiptJournalEntries[receipt.id]!,
                              ),
                              icon: const Icon(Icons.menu_book_outlined),
                              label: const Text('عرض القيد المحاسبي'),
                            ),
                    ),
                ],
              ),
            ),
          ],
          if ((request?.notes ?? order?.notes)?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _DocumentSection(
              title: 'ملاحظات',
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(request?.notes ?? order!.notes!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailLine(int index, PurchasingItem line) {
    final itemType = line.itemType == PurchasingItemType.product
        ? StockItemType.product
        : StockItemType.rawMaterial;
    final material = items
        .where((item) => item.id == line.itemId && item.type == itemType)
        .firstOrNull;
    final name = material?.name ?? 'غير معروف';
    final code = material?.code ?? 'غير معروف';
    final unit = unitNames[line.unitId] ?? 'غير معروف';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: [
          SizedBox(width: 28, child: Text('${index + 1}')),
          SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  'الكود: $code',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Text('الكمية: ${_numberFormat(line.quantity)}'),
          Text('الوحدة: $unit'),
          if (order != null) ...[
            Text('سعر الوحدة: ${line.unitPrice.toStringAsFixed(2)}'),
            Text('الخصم: ${line.discount.toStringAsFixed(2)}'),
            Text('الضريبة: ${line.tax.toStringAsFixed(2)}'),
            Text('الإجمالي: ${line.lineTotal.toStringAsFixed(2)}'),
          ],
        ],
      ),
    );
  }

  String _warehouseName(String warehouseId) =>
      warehouses
          .where((warehouse) => warehouse.id == warehouseId)
          .firstOrNull
          ?.name ??
      'غير معروف';
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.title,
    required this.child,
    this.trailing,
  });
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}

Future<void> printPurchaseDocument({
  required String factoryName,
  required String title,
  required String number,
  required DateTime date,
  required Supplier? supplier,
  required String? notes,
  required List<PurchasingItem> items,
  required List<StockItemOption> catalog,
  required Map<String, String> unitNames,
  bool showFinancials = false,
  double? subtotal,
  double? discount,
  double? tax,
  double? grandTotal,
}) async {
  final bytes = await generatePurchaseDocumentPdf(
    factoryName: factoryName,
    title: title,
    number: number,
    date: date,
    supplier: supplier,
    notes: notes,
    items: items,
    catalog: catalog,
    unitNames: unitNames,
    showFinancials: showFinancials,
    subtotal: subtotal,
    discount: discount,
    tax: tax,
    grandTotal: grandTotal,
  );
  await Printing.layoutPdf(onLayout: (_) async => bytes);
}

Future<Uint8List> generatePurchaseDocumentPdf({
  required String factoryName,
  required String title,
  required String number,
  required DateTime date,
  required Supplier? supplier,
  required String? notes,
  required List<PurchasingItem> items,
  required List<StockItemOption> catalog,
  required Map<String, String> unitNames,
  bool showFinancials = false,
  double? subtotal,
  double? discount,
  double? tax,
  double? grandTotal,
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
  final logo = pw.MemoryImage(
    (await rootBundle.load('assets/logo.png')).buffer.asUint8List(),
  );
  final navy = PdfColor.fromHex('#17324D');
  final wood = PdfColor.fromHex('#A66A3F');
  final amber = PdfColor.fromHex('#D29A5A');
  final cream = PdfColor.fromHex('#F6F1E8');
  final format = DateFormat('yyyy/MM/dd');
  final headers = showFinancials
      ? ['اسم المادة', 'الكود', 'الوحدة', 'الكمية', 'سعر الوحدة', 'الإجمالي']
      : ['اسم المادة', 'الكود', 'الوحدة', 'الكمية'];
  final rows = items.map((line) {
    final itemType = line.itemType == PurchasingItemType.product
        ? StockItemType.product
        : StockItemType.rawMaterial;
    final material = catalog
        .where((item) => item.id == line.itemId && item.type == itemType)
        .firstOrNull;
    final values = <String>[
      material?.name ?? 'غير معروف',
      material?.code ?? 'غير معروف',
      unitNames[line.unitId] ?? 'غير معروف',
      _numberFormat(line.quantity),
    ];
    if (showFinancials) {
      values.add(line.unitPrice.toStringAsFixed(2));
      values.add(line.lineTotal.toStringAsFixed(2));
    }
    return values;
  }).toList();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 30),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(top: 7),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: cream, width: 1.2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'FURNEXA  |  $factoryName',
                style: pw.TextStyle(font: regular, fontSize: 7, color: navy),
              ),
              pw.Text(
                '$number  |  ${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(font: regular, fontSize: 7, color: navy),
              ),
            ],
          ),
        ),
      ),
      build: (context) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.fromLTRB(13, 11, 13, 11),
                decoration: pw.BoxDecoration(
                  color: cream,
                  border: pw.Border(
                    bottom: pw.BorderSide(color: wood, width: 2),
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(
                      logo,
                      width: 68,
                      height: 68,
                      fit: pw.BoxFit.contain,
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            factoryName,
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 19,
                              color: navy,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            title,
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 15,
                              color: wood,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 13),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FAF8F4'),
                  border: pw.Border.all(color: cream, width: 1),
                ),
                child: pw.Table(
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1),
                    1: pw.FlexColumnWidth(1),
                  },
                  children: [
                    _pdfInfoRow(
                      'رقم أمر الشراء',
                      number,
                      'التاريخ',
                      format.format(date),
                    ),
                    _pdfInfoRow(
                      'المورد',
                      supplier?.name ?? 'غير معروف',
                      'كود المورد',
                      supplier?.code ?? '—',
                    ),
                    _pdfInfoRow(
                      'الهاتف',
                      supplier?.phone ?? '—',
                      'العنوان',
                      supplier?.address ?? '—',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 13),
              pw.Row(
                children: [
                  pw.Container(width: 3, height: 15, color: amber),
                  pw.SizedBox(width: 6),
                  pw.Text(
                    'تفاصيل المواد',
                    style: pw.TextStyle(font: bold, fontSize: 11, color: navy),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                columnWidths: showFinancials
                    ? const {
                        0: pw.FlexColumnWidth(2.7),
                        1: pw.FlexColumnWidth(1.1),
                        2: pw.FlexColumnWidth(0.9),
                        3: pw.FlexColumnWidth(0.8),
                        4: pw.FlexColumnWidth(1.15),
                        5: pw.FlexColumnWidth(1.15),
                      }
                    : const {
                        0: pw.FlexColumnWidth(3),
                        1: pw.FlexColumnWidth(1.3),
                        2: pw.FlexColumnWidth(1),
                        3: pw.FlexColumnWidth(1),
                      },
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
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: .6),
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 5,
                ),
              ),
              if (showFinancials)
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    width: 230,
                    margin: const pw.EdgeInsets.only(top: 10),
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
                        _pdfTotalLine('الإجمالي الفرعي', subtotal),
                        _pdfTotalLine('الخصم', discount),
                        _pdfTotalLine('الضريبة', tax),
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 4),
                          padding: const pw.EdgeInsets.only(top: 5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(color: wood, width: .8),
                            ),
                          ),
                          child: _pdfTotalLine(
                            'الإجمالي الكلي',
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
              pw.SizedBox(height: 26),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _signatureBox('إعداد'),
                  _signatureBox('مراجعة'),
                  _signatureBox('اعتماد'),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return Uint8List.fromList(await pdf.save());
}

pw.Widget _pdfTotalLine(
  String label,
  double? value, {
  bool prominent = false,
}) => pw.Padding(
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
        value?.toStringAsFixed(2) ?? '—',
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
    _pdfInfoCell(labelOne, valueOne),
    _pdfInfoCell(labelTwo, valueTwo),
  ],
);

pw.Widget _pdfInfoCell(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
  child: pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(text: value),
      ],
    ),
  ),
);

pw.Widget _signatureBox(String label) => pw.Container(
  width: 135,
  height: 48,
  padding: const pw.EdgeInsets.only(top: 7),
  decoration: pw.BoxDecoration(
    border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#A66A3F'))),
  ),
  child: pw.Center(child: pw.Text(label, style: pw.TextStyle(fontSize: 8))),
);

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _numberFormat(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

String _requestStatus(PurchaseRequestStatus status) => switch (status) {
  PurchaseRequestStatus.draft => 'مسودة',
  PurchaseRequestStatus.pending => 'قيد الاعتماد',
  PurchaseRequestStatus.approved => 'معتمد',
  PurchaseRequestStatus.rejected => 'مرفوض',
  PurchaseRequestStatus.converted => 'محول',
  PurchaseRequestStatus.cancelled => 'ملغى',
};

String _orderStatus(PurchaseOrderStatus status) => switch (status) {
  PurchaseOrderStatus.draft => 'مسودة',
  PurchaseOrderStatus.approved => 'معتمد',
  PurchaseOrderStatus.partiallyReceived => 'مستلم جزئياً',
  PurchaseOrderStatus.fullyReceived => 'مستلم بالكامل',
  PurchaseOrderStatus.cancelled => 'ملغى',
};
