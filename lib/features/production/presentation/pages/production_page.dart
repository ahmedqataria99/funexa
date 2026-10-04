import 'package:flutter/material.dart';

import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/production/data/repositories/production_repository_impl.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/production/domain/repositories/production_repository.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';

class ProductionPage extends StatefulWidget {
  const ProductionPage({super.key, this.initialOrderId});

  final String? initialOrderId;
  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage>
    with SingleTickerProviderStateMixin {
  final ProductionRepository repository = ProductionRepositoryImpl();
  late final TabController tabs;
  List<Product> products = [];
  List<ProductionStage> stages = [];
  List<ProductionRoute> routes = [];
  List<ProductionOrder> orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
    load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final result = await Future.wait([
      repository.activeProducts(),
      repository.activeStages(),
      repository.routes(),
      repository.orders(),
    ]);
    if (!mounted) return;
    setState(() {
      products = result[0] as List<Product>;
      stages = result[1] as List<ProductionStage>;
      routes = result[2] as List<ProductionRoute>;
      orders = result[3] as List<ProductionOrder>;
      loading = false;
    });
    final selected = widget.initialOrderId == null
        ? null
        : orders
              .where((value) => value.id == widget.initialOrderId)
              .firstOrNull;
    if (selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openOrder(selected);
      });
    }
  }

  void error(Object value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value.toString())));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('الإنتاج'),
      bottom: TabBar(
        controller: tabs,
        tabs: const [
          Tab(text: 'أوامر الإنتاج'),
          Tab(text: 'مسارات الإنتاج'),
        ],
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(controller: tabs, children: [ordersView(), routesView()]),
  );

  Widget ordersView() => _panel(
    title: 'أوامر الإنتاج',
    action: 'أمر إنتاج جديد',
    onAdd: createOrder,
    children: orders
        .map(
          (order) => ListTile(
            title: Text(
              '${order.orderNumber} • ${order.productName ?? order.productId}',
            ),
            subtitle: Text(
              'المخطط ${order.plannedQuantity} • المنتج ${order.producedQuantity} • ${order.status.name}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (order.status == ProductionOrderStatus.draft)
                  IconButton(
                    tooltip: 'تخطيط',
                    icon: const Icon(Icons.event_available_outlined),
                    onPressed: () =>
                        change(() => repository.planOrder(order.id)),
                  ),
                if (order.status == ProductionOrderStatus.planned)
                  IconButton(
                    tooltip: 'بدء',
                    icon: const Icon(Icons.play_arrow_outlined),
                    onPressed: () =>
                        change(() => repository.startOrder(order.id)),
                  ),
                if (order.status == ProductionOrderStatus.draft ||
                    order.status == ProductionOrderStatus.planned)
                  IconButton(
                    tooltip: 'إلغاء',
                    icon: const Icon(Icons.cancel_outlined),
                    onPressed: () =>
                        change(() => repository.cancelOrder(order.id)),
                  ),
              ],
            ),
            onTap: () => openOrder(order),
          ),
        )
        .toList(),
  );

  Widget routesView() => _panel(
    title: 'مسارات الإنتاج',
    action: 'مسار جديد',
    onAdd: () => editRoute(),
    children: routes.map((route) {
      final product = products
          .where((value) => value.id == route.productId)
          .firstOrNull;
      return ListTile(
        title: Text(product?.name ?? route.productId),
        subtitle: Text(
          route.stages
              .map((stage) => '${stage.sequence}. ${stage.stageName}')
              .join('  ←  '),
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => editRoute(route),
      );
    }).toList(),
  );

  Widget _panel({
    required String title,
    required String action,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) => Padding(
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
              onPressed: onAdd,
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

  Future<void> change(Future<void> Function() action) async {
    try {
      await action();
      await load();
    } catch (value) {
      error(value);
    }
  }

  Future<void> createOrder() async {
    if (products.isEmpty) {
      error('لا توجد منتجات نشطة');
      return;
    }
    final draft = await showDialog<_OrderDraft>(
      context: context,
      builder: (_) => ProductionOrderForm(products: products),
    );
    if (draft == null) return;
    try {
      await repository.createOrder(
        productId: draft.product.id,
        plannedQuantity: draft.quantity,
        notes: draft.notes,
      );
      await load();
    } catch (value) {
      error(value);
    }
  }

  Future<void> editRoute([ProductionRoute? current]) async {
    if (products.isEmpty || stages.isEmpty) {
      error('أضف منتجاً ومرحلة إنتاج نشطة أولاً');
      return;
    }
    final selected = current == null
        ? <ProductionStage>[]
        : current.stages
              .map(
                (item) => stages
                    .where((stage) => stage.id == item.productionStageId)
                    .firstOrNull,
              )
              .whereType<ProductionStage>()
              .toList();
    final result = await showDialog<_RouteFormResult>(
      context: context,
      builder: (_) => RouteForm(
        products: products,
        product: current == null
            ? null
            : products
                  .where((value) => value.id == current.productId)
                  .firstOrNull,
        stages: stages,
        selected: selected,
        onProductSelected: current == null
            ? (product) async {
                final existing = await repository.routeForProduct(product.id);
                if (existing == null || !mounted) {
                  return const RouteProductSelection.accepted();
                }
                final openCurrent = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('مسار إنتاج موجود'),
                    content: const Text(
                      'هذا المنتج لديه مسار إنتاج نشط بالفعل.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('اختيار منتج آخر'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('فتح المسار الحالي'),
                      ),
                    ],
                  ),
                );
                return openCurrent == true
                    ? RouteProductSelection.openExisting(existing)
                    : const RouteProductSelection.chooseAnother();
              }
            : null,
      ),
    );
    if (result == null) return;
    if (result.existing != null) {
      return editRoute(result.existing);
    }
    final product = result.product;
    if (product == null) return;
    try {
      await repository.saveRoute(product.id, result.stageIds);
      await load();
    } catch (value) {
      error(value);
    }
  }

  Future<void> openOrder(ProductionOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProductionOrderDetailsPage(repository: repository, order: order),
      ),
    );
    await load();
  }
}

class _OrderDraft {
  const _OrderDraft(this.product, this.quantity, this.notes);
  final Product product;
  final double quantity;
  final String? notes;
}

class ProductionOrderForm extends StatefulWidget {
  const ProductionOrderForm({required this.products, super.key});
  final List<Product> products;
  @override
  State<ProductionOrderForm> createState() => _ProductionOrderFormState();
}

class _ProductionOrderFormState extends State<ProductionOrderForm> {
  late Product product = widget.products.first;
  final quantity = TextEditingController(text: '1');
  final notes = TextEditingController();
  final keyForm = GlobalKey<FormState>();
  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('أمر إنتاج جديد'),
    content: Form(
      key: keyForm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Product>(
            initialValue: product,
            decoration: const InputDecoration(labelText: 'المنتج'),
            items: widget.products
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('${value.name} • ${value.code}'),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => product = value!),
          ),
          TextFormField(
            controller: quantity,
            decoration: const InputDecoration(labelText: 'الكمية المخططة'),
            keyboardType: TextInputType.number,
            validator: (value) =>
                double.tryParse(value ?? '') == null ||
                    double.parse(value!) <= 0
                ? 'أدخل كمية موجبة'
                : null,
          ),
          TextFormField(
            controller: notes,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
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
          if (!keyForm.currentState!.validate()) return;
          Navigator.pop(
            context,
            _OrderDraft(
              product,
              double.parse(quantity.text),
              notes.text.trim().isEmpty ? null : notes.text.trim(),
            ),
          );
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}

class RouteForm extends StatefulWidget {
  const RouteForm({
    required this.products,
    required this.product,
    required this.stages,
    required this.selected,
    this.onProductSelected,
    super.key,
  });
  final List<Product> products;
  final Product? product;
  final List<ProductionStage> stages;
  final List<ProductionStage> selected;
  final Future<RouteProductSelection> Function(Product product)?
  onProductSelected;
  @override
  State<RouteForm> createState() => _RouteFormState();
}

class _RouteFormState extends State<RouteForm> {
  Product? product;
  late final List<ProductionStage> selected = [...widget.selected];
  ProductionStage? candidate;

  @override
  void initState() {
    super.initState();
    product = widget.product;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(product == null ? 'مسار إنتاج جديد' : 'مسار ${product!.name}'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Product>(
            initialValue: product,
            hint: const Text('اختر المنتج'),
            decoration: const InputDecoration(labelText: 'المنتج'),
            items: widget.products
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('${value.name} • ${value.code}'),
                  ),
                )
                .toList(),
            onChanged: widget.product != null
                ? null
                : (value) async {
                    if (value == null) return;
                    final selection =
                        await widget.onProductSelected?.call(value) ??
                        const RouteProductSelection.accepted();
                    if (!mounted) return;
                    if (selection.existing != null) {
                      Navigator.pop(
                        context,
                        _RouteFormResult.existing(selection.existing!),
                      );
                      return;
                    }
                    setState(
                      () => product = selection.chooseAnother ? null : value,
                    );
                  },
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ProductionStage>(
                  initialValue: candidate,
                  decoration: const InputDecoration(labelText: 'إضافة مرحلة'),
                  items: widget.stages
                      .where(
                        (stage) =>
                            !selected.any((value) => value.id == stage.id),
                      )
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => candidate = value),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: candidate == null
                    ? null
                    : () => setState(() {
                        selected.add(candidate!);
                        candidate = null;
                      }),
              ),
            ],
          ),
          if (selected.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('أضف مراحل مرتبة للمسار'),
            ),
          if (selected.isNotEmpty)
            SizedBox(
              height: 260,
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: selected.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final stage = selected.removeAt(oldIndex);
                    selected.insert(newIndex, stage);
                  });
                },
                itemBuilder: (_, index) => ListTile(
                  key: ValueKey(selected[index].id),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(selected[index].name),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => selected.removeAt(index)),
                  ),
                ),
              ),
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
        onPressed: product == null || selected.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                _RouteFormResult(
                  product: product,
                  stageIds: selected.map((value) => value.id).toList(),
                ),
              ),
        child: const Text('حفظ المسار'),
      ),
    ],
  );
}

class _RouteFormResult {
  const _RouteFormResult({required this.product, this.stageIds = const []})
    : existing = null;
  const _RouteFormResult.existing(ProductionRoute route)
    : product = null,
      stageIds = const [],
      existing = route;

  final Product? product;
  final List<String> stageIds;
  final ProductionRoute? existing;
}

class RouteProductSelection {
  const RouteProductSelection.accepted()
    : chooseAnother = false,
      existing = null;
  const RouteProductSelection.chooseAnother()
    : chooseAnother = true,
      existing = null;
  const RouteProductSelection.openExisting(ProductionRoute route)
    : chooseAnother = false,
      existing = route;

  final bool chooseAnother;
  final ProductionRoute? existing;
}

class ProductionOrderDetailsPage extends StatefulWidget {
  const ProductionOrderDetailsPage({
    required this.repository,
    required this.order,
    super.key,
  });
  final ProductionRepository repository;
  final ProductionOrder order;
  @override
  State<ProductionOrderDetailsPage> createState() =>
      _ProductionOrderDetailsPageState();
}

class _ProductionOrderDetailsPageState
    extends State<ProductionOrderDetailsPage> {
  late ProductionOrder order = widget.order;
  List<ProductionMaterialRequirement> requirements = [];
  List<ProductionMaterialRecord> consumptions = [];
  List<ProductionWasteRecord> waste = [];
  List<ProductionOutputRecord> outputs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final result = await Future.wait([
      widget.repository.getOrder(order.id),
      widget.repository.requirements(order.id),
      widget.repository.consumptions(order.id),
      widget.repository.waste(order.id),
      widget.repository.outputs(order.id),
    ]);
    if (!mounted) return;
    setState(() {
      order = result[0] as ProductionOrder;
      requirements = result[1] as List<ProductionMaterialRequirement>;
      consumptions = result[2] as List<ProductionMaterialRecord>;
      waste = result[3] as List<ProductionWasteRecord>;
      outputs = result[4] as List<ProductionOutputRecord>;
      loading = false;
    });
  }

  void error(Object value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value.toString())));

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (order.status == ProductionOrderStatus.draft) {
      actions.add(
        FilledButton(
          onPressed: () => change(() => widget.repository.planOrder(order.id)),
          child: const Text('تخطيط'),
        ),
      );
    }
    if (order.status == ProductionOrderStatus.planned) {
      actions.add(
        FilledButton(
          onPressed: () => change(() => widget.repository.startOrder(order.id)),
          child: const Text('بدء الإنتاج'),
        ),
      );
    }
    if (order.status == ProductionOrderStatus.inProgress) {
      actions.addAll([
        FilledButton.icon(
          onPressed: recordOutput,
          icon: const Icon(Icons.add),
          label: const Text('إنتاج'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: recordWaste, child: const Text('تسجيل هالك')),
      ]);
    }

    return Scaffold(
      appBar: AppBar(title: Text(order.orderNumber)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productName ?? order.productId,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('الحالة: ${order.status.name}'),
                        Text(
                          'المخطط: ${order.plannedQuantity} • المنتج: ${order.producedQuantity} • المتبقي: ${order.remainingQuantity}',
                        ),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    ),
                  ),
                ),
                _section(
                  'مراحل الإنتاج',
                  order.stages
                      .map(
                        (stage) => ListTile(
                          leading: CircleAvatar(
                            child: Text('${stage.sequence}'),
                          ),
                          title: Text(stage.stageName),
                          subtitle: Text(stage.status.name),
                          trailing:
                              stage.status == ProductionStageStatus.pending
                              ? IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () => change(
                                    () =>
                                        widget.repository.startStage(stage.id),
                                  ),
                                )
                              : stage.status == ProductionStageStatus.inProgress
                              ? IconButton(
                                  icon: const Icon(Icons.check),
                                  onPressed: () => change(
                                    () => widget.repository.completeStage(
                                      stage.id,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      )
                      .toList(),
                ),
                _section(
                  'متطلبات المواد',
                  requirements
                      .map(
                        (requirement) => ListTile(
                          title: Text(requirement.rawMaterialName),
                          subtitle: Text(
                            'المطلوب ${requirement.requiredQuantity} • المستهلك ${requirement.consumedQuantity} • المتبقي ${requirement.remainingQuantity}',
                          ),
                          trailing:
                              order.status ==
                                      ProductionOrderStatus.inProgress &&
                                  requirement.remainingQuantity > 0
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => consume(requirement),
                                )
                              : null,
                        ),
                      )
                      .toList(),
                ),
                _section(
                  'الاستهلاك',
                  consumptions
                      .map(
                        (item) => ListTile(
                          title: Text(item.rawMaterialName),
                          subtitle: Text('${item.quantity} • ${item.date}'),
                        ),
                      )
                      .toList(),
                ),
                _section(
                  'الهالك',
                  waste
                      .map(
                        (item) => ListTile(
                          title: Text(item.rawMaterialName),
                          subtitle: Text('${item.quantity} • ${item.reason}'),
                        ),
                      )
                      .toList(),
                ),
                _section(
                  'الإنتاج المرحل',
                  outputs
                      .map(
                        (item) => ListTile(
                          title: Text('${item.quantity}'),
                          subtitle: Text(
                            '${item.date} • مخزن ${item.warehouseId}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Text(title),
      children: children.isEmpty
          ? [const ListTile(title: Text('لا توجد سجلات'))]
          : children,
    ),
  );
  Future<void> change(Future<void> Function() action) async {
    try {
      await action();
      await load();
    } catch (value) {
      error(value);
    }
  }

  Future<void> consume(ProductionMaterialRequirement requirement) async {
    final data = await _showMovement(
      title: 'استهلاك ${requirement.rawMaterialName}',
      max: requirement.remainingQuantity,
    );
    if (data == null) return;
    try {
      await widget.repository.consumeMaterial(
        orderId: order.id,
        rawMaterialId: requirement.rawMaterialId,
        warehouseId: data.warehouseId,
        quantity: data.quantity,
        date: DateTime.now(),
      );
      await load();
    } catch (value) {
      error(value);
    }
  }

  Future<void> recordWaste() async {
    final materials = await widget.repository.activeRawMaterials();
    final warehouses = await widget.repository.activeWarehouses();
    if (!mounted || materials.isEmpty || warehouses.isEmpty) return;
    final data = await showDialog<_WasteDraft>(
      context: context,
      builder: (_) => WasteForm(materials: materials, warehouses: warehouses),
    );
    if (data == null) return;
    try {
      await widget.repository.recordWaste(
        orderId: order.id,
        rawMaterialId: data.material.id,
        warehouseId: data.warehouseId,
        quantity: data.quantity,
        reason: data.reason,
        date: DateTime.now(),
      );
      await load();
    } catch (value) {
      error(value);
    }
  }

  Future<void> recordOutput() async {
    final data = await _showMovement(
      title: 'إنتاج مرحل',
      max: order.remainingQuantity,
    );
    if (data == null) return;
    try {
      await widget.repository.recordOutput(
        orderId: order.id,
        warehouseId: data.warehouseId,
        quantity: data.quantity,
        date: DateTime.now(),
      );
      await load();
    } catch (value) {
      error(value);
    }
  }

  Future<_MovementDraft?> _showMovement({
    required String title,
    required double max,
  }) async {
    final warehouses = await widget.repository.activeWarehouses();
    if (!mounted || warehouses.isEmpty) return null;
    return showDialog<_MovementDraft>(
      context: context,
      builder: (_) =>
          MovementForm(title: title, warehouses: warehouses, max: max),
    );
  }
}

class _MovementDraft {
  const _MovementDraft(this.warehouseId, this.quantity);
  final String warehouseId;
  final double quantity;
}

class MovementForm extends StatefulWidget {
  const MovementForm({
    required this.title,
    required this.warehouses,
    required this.max,
    super.key,
  });
  final String title;
  final List<dynamic> warehouses;
  final double max;
  @override
  State<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<MovementForm> {
  late dynamic warehouse = widget.warehouses.first;
  final quantity = TextEditingController(text: '1');
  final keyForm = GlobalKey<FormState>();
  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: keyForm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<dynamic>(
            initialValue: warehouse,
            decoration: const InputDecoration(labelText: 'المخزن'),
            items: widget.warehouses
                .map(
                  (value) => DropdownMenuItem<dynamic>(
                    value: value,
                    child: Text(value.name as String),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => warehouse = value),
          ),
          TextFormField(
            controller: quantity,
            decoration: InputDecoration(
              labelText: 'الكمية (المتبقي ${widget.max})',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              final parsed = double.tryParse(value ?? '');
              return parsed == null || parsed <= 0 || parsed > widget.max
                  ? 'كمية غير صالحة'
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
          if (!keyForm.currentState!.validate()) return;
          Navigator.pop(
            context,
            _MovementDraft(warehouse.id as String, double.parse(quantity.text)),
          );
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}

class _WasteDraft {
  const _WasteDraft(
    this.material,
    this.warehouseId,
    this.quantity,
    this.reason,
  );
  final dynamic material;
  final String warehouseId;
  final double quantity;
  final String reason;
}

class WasteForm extends StatefulWidget {
  const WasteForm({
    required this.materials,
    required this.warehouses,
    super.key,
  });
  final List<dynamic> materials;
  final List<Warehouse> warehouses;
  @override
  State<WasteForm> createState() => _WasteFormState();
}

class _WasteFormState extends State<WasteForm> {
  late dynamic material = widget.materials.first;
  late Warehouse warehouse = widget.warehouses.first;
  final quantity = TextEditingController(text: '1');
  final reason = TextEditingController();
  final keyForm = GlobalKey<FormState>();
  @override
  void dispose() {
    quantity.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تسجيل هالك'),
    content: Form(
      key: keyForm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<dynamic>(
            initialValue: material,
            decoration: const InputDecoration(labelText: 'الخامة'),
            items: widget.materials
                .map(
                  (value) => DropdownMenuItem<dynamic>(
                    value: value,
                    child: Text(value.name as String),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => material = value),
          ),
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
          TextFormField(
            controller: quantity,
            decoration: const InputDecoration(labelText: 'الكمية'),
            keyboardType: TextInputType.number,
            validator: (value) =>
                double.tryParse(value ?? '') == null ||
                    double.parse(value!) <= 0
                ? 'أدخل كمية موجبة'
                : null,
          ),
          TextFormField(
            controller: reason,
            decoration: const InputDecoration(labelText: 'السبب'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'السبب مطلوب' : null,
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
          if (!keyForm.currentState!.validate()) return;
          Navigator.pop(
            context,
            _WasteDraft(
              material,
              warehouse.id,
              double.parse(quantity.text),
              reason.text.trim(),
            ),
          );
        },
        child: const Text('حفظ'),
      ),
    ],
  );
}
