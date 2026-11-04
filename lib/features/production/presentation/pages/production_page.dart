import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/production/data/repositories/production_repository_impl.dart';
import 'package:furnexa/features/production/domain/entities/production_entities.dart';
import 'package:furnexa/features/production/domain/repositories/production_repository.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/warehouses_stock/data/repositories/warehouses_stock_repository_impl.dart';
import 'package:furnexa/features/warehouses_stock/domain/entities/stock_entities.dart';

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
  final TextEditingController orderSearchController = TextEditingController();
  final TextEditingController routeSearchController = TextEditingController();
  List<Product> products = [];
  List<ProductionStage> stages = [];
  List<ProductionRoute> routes = [];
  List<ProductionOrder> orders = [];
  Map<String, List<ProductVariant>> variantMap = {};
  ProductionOrderStatus? statusFilter;
  Product? productFilter;
  bool loading = true;
  bool newestFirst = true;

  List<ProductionOrder> get filteredOrders {
    final query = orderSearchController.text.trim().toLowerCase();
    final list = orders.where((order) {
      final product = products
          .where((item) => item.id == order.productId)
          .firstOrNull;
      final productText = [
        product?.name,
        product?.code,
        order.orderNumber,
        order.productName,
      ].whereType<String>().join(' ');
      final variant = variantMap[order.productId]
          ?.where((item) => item.id == order.variantId)
          .firstOrNull;
      final variantText = [
        variant?.name,
        variant?.code,
      ].whereType<String>().join(' ');
      final matchesSearch =
          query.isEmpty ||
          '$productText $variantText'.toLowerCase().contains(query);
      final matchesStatus =
          statusFilter == null || order.status == statusFilter;
      final matchesProduct =
          productFilter == null || order.productId == productFilter!.id;
      return matchesSearch && matchesStatus && matchesProduct;
    }).toList();
    list.sort(
      (a, b) => newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return list;
  }

  List<ProductionRoute> get filteredRoutes {
    final query = routeSearchController.text.trim().toLowerCase();
    final list = routes.where((route) {
      final product = products
          .where((item) => item.id == route.productId)
          .firstOrNull;
      final routeText = [
        product?.name,
        product?.code,
        route.stages.map((stage) => stage.stageName).join(' '),
      ].join(' ');
      final matchesSearch =
          query.isEmpty || routeText.toLowerCase().contains(query);
      final matchesProduct =
          productFilter == null || route.productId == productFilter!.id;
      return matchesSearch && matchesProduct;
    }).toList();
    list.sort(
      (a, b) => newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return list;
  }

  void clearAllFilters() {
    orderSearchController.clear();
    routeSearchController.clear();
    statusFilter = null;
    productFilter = null;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
    load();
  }

  @override
  void dispose() {
    tabs.dispose();
    orderSearchController.dispose();
    routeSearchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    final result = await Future.wait([
      repository.activeProducts(),
      repository.activeStages(),
      repository.routes(),
      repository.orders(),
    ]);
    if (!mounted) return;
    final nextProducts = result[0] as List<Product>;
    final nextVariants = <String, List<ProductVariant>>{};
    for (final product in nextProducts) {
      nextVariants[product.id] = await repository.activeVariants(product.id);
    }
    if (!mounted) return;
    setState(() {
      products = nextProducts;
      stages = result[1] as List<ProductionStage>;
      routes = result[2] as List<ProductionRoute>;
      orders = result[3] as List<ProductionOrder>;
      variantMap = nextVariants;
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
  ).showSnackBar(SnackBar(content: Text(_productionActionError(value))));

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

  Widget ordersView() {
    final filtered = filteredOrders;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: orderSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText:
                                'بحث بالمرجع أو المنتج أو الكود أو البديل',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: createOrder,
                        icon: const Icon(Icons.add),
                        label: const Text('أمر جديد'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<ProductionOrderStatus?>(
                          value: statusFilter,
                          decoration: const InputDecoration(
                            labelText: 'الحالة',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('الكل'),
                            ),
                            ...ProductionOrderStatus.values.map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_productionOrderStatusLabel(value)),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => statusFilter = value);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<Product?>(
                          value: productFilter,
                          decoration: const InputDecoration(
                            labelText: 'المنتج',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<Product?>(
                              value: null,
                              child: Text('الكل'),
                            ),
                            ...products.map(
                              (product) => DropdownMenuItem<Product>(
                                value: product,
                                child: Text(
                                  '${product.name} • ${product.code}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => productFilter = value);
                          },
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          statusFilter = null;
                          productFilter = null;
                          orderSearchController.clear();
                        }),
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('مسح الفلاتر'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'النتائج: ${filtered.length}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => newestFirst = !newestFirst),
                        icon: const Icon(Icons.sort),
                        label: Text(
                          newestFirst ? 'الأحدث أولاً' : 'الأقدم أولاً',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? _emptyState(
                    icon: Icons.search_off_rounded,
                    title: 'لا توجد نتائج مطابقة للبحث',
                    message: 'جرّب تغيير كلمة البحث أو مسح الفلاتر.',
                  )
                : ListView(
                    children: filtered.map(_productionOrderCard).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget routesView() {
    final filtered = filteredRoutes;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: routeSearchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'بحث بالمنتج أو الكود أو المراحل',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () => editRoute(),
                        icon: const Icon(Icons.add),
                        label: const Text('مسار جديد'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<Product?>(
                          value: productFilter,
                          decoration: const InputDecoration(
                            labelText: 'المنتج',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<Product?>(
                              value: null,
                              child: Text('الكل'),
                            ),
                            ...products.map(
                              (product) => DropdownMenuItem<Product>(
                                value: product,
                                child: Text(
                                  '${product.name} • ${product.code}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => productFilter = value),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          productFilter = null;
                          routeSearchController.clear();
                        }),
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('مسح الفلاتر'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'النتائج: ${filtered.length}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => newestFirst = !newestFirst),
                        icon: const Icon(Icons.sort),
                        label: Text(
                          newestFirst ? 'الأحدث أولاً' : 'الأقدم أولاً',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? _emptyState(
                    icon: Icons.route_rounded,
                    title: 'لا توجد مسارات مطابقة',
                    message: 'لم يتم العثور على مسار يطابق هذه المعايير.',
                  )
                : ListView(
                    children: filtered.map(_productionRouteCard).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );

  Widget _productionOrderCard(ProductionOrder order) {
    final product = products
        .where((item) => item.id == order.productId)
        .firstOrNull;
    final variant = variantMap[order.productId]
        ?.where((item) => item.id == order.variantId)
        .firstOrNull;
    final currentStage = order.stages.firstWhereOrNull(
      (stage) => stage.status == ProductionStageStatus.inProgress,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => openOrder(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderNumber,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _statusBadge(order.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product?.name ?? 'المنتج غير متاح',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    if (variant != null)
                      Text(
                        '${variant.name} • ${variant.code}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (variant == null && product != null)
                      Text(
                        product.code,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _metricChip(
                          'المخطط',
                          '${_quantityText(order.plannedQuantity)}',
                        ),
                        _metricChip(
                          'المنتج',
                          '${_quantityText(order.producedQuantity)}',
                        ),
                        _metricChip(
                          'المتبقي',
                          order.remainingQuantity == null
                              ? 'غير معروف'
                              : _quantityText(order.remainingQuantity!),
                        ),
                        _metricChip(
                          'المرحلة',
                          currentStage?.stageName ?? 'لا توجد',
                        ),
                        _metricChip(
                          'تاريخ الإنشاء',
                          _dateOnlyText(order.createdAt),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  if (order.status == ProductionOrderStatus.draft)
                    FilledButton.tonal(
                      onPressed: () =>
                          change(() => repository.planOrder(order.id)),
                      child: const Text('تخطيط'),
                    ),
                  if (order.status == ProductionOrderStatus.planned)
                    FilledButton.tonal(
                      onPressed: () =>
                          change(() => repository.startOrder(order.id)),
                      child: const Text('بدء'),
                    ),
                  if (order.status == ProductionOrderStatus.draft ||
                      order.status == ProductionOrderStatus.planned)
                    TextButton(
                      onPressed: () =>
                          change(() => repository.cancelOrder(order.id)),
                      child: const Text('إلغاء'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productionRouteCard(ProductionRoute route) {
    final product = products
        .where((item) => item.id == route.productId)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => editRoute(route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product?.name ?? 'المنتج غير متاح',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.route_rounded),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                product?.code ?? '—',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: route.stages
                    .map(
                      (stage) => Chip(
                        avatar: CircleAvatar(child: Text('${stage.sequence}')),
                        label: Text(stage.stageName),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(ProductionOrderStatus status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: switch (status) {
        ProductionOrderStatus.draft => Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest,
        ProductionOrderStatus.planned => Theme.of(
          context,
        ).colorScheme.primaryContainer,
        ProductionOrderStatus.inProgress => Theme.of(
          context,
        ).colorScheme.tertiaryContainer,
        ProductionOrderStatus.completed => Theme.of(
          context,
        ).colorScheme.primary,
        ProductionOrderStatus.cancelled => Theme.of(
          context,
        ).colorScheme.errorContainer,
      },
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      _productionOrderStatusLabel(status),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: switch (status) {
          ProductionOrderStatus.draft => Theme.of(
            context,
          ).colorScheme.onSurface,
          ProductionOrderStatus.planned => Theme.of(
            context,
          ).colorScheme.onPrimaryContainer,
          ProductionOrderStatus.inProgress => Theme.of(
            context,
          ).colorScheme.onTertiaryContainer,
          ProductionOrderStatus.completed => Theme.of(
            context,
          ).colorScheme.onPrimary,
          ProductionOrderStatus.cancelled => Theme.of(
            context,
          ).colorScheme.onErrorContainer,
        },
      ),
    ),
  );

  Widget _metricChip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text('$label: $value'),
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
    final draft = await Navigator.of(context).push<_OrderDraft>(
      MaterialPageRoute(
        builder: (_) =>
            ProductionOrderForm(products: products, repository: repository),
      ),
    );
    if (draft == null) return;
    try {
      await repository.createOrder(
        productId: draft.product.id,
        variantId: draft.variantId,
        expectedUnitId: draft.product.unitId,
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
  const _OrderDraft({
    required this.product,
    required this.quantity,
    required this.notes,
    required this.variantId,
  });
  final Product product;
  final double quantity;
  final String? notes;
  final String? variantId;
}

class _ProductionFormSection extends StatelessWidget {
  const _ProductionFormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _ProductionInfoValue extends StatelessWidget {
  const _ProductionInfoValue({required this.label, required this.value});

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

class ProductionOrderForm extends StatefulWidget {
  const ProductionOrderForm({
    required this.products,
    required this.repository,
    super.key,
  });
  final List<Product> products;
  final ProductionRepository repository;
  @override
  State<ProductionOrderForm> createState() => _ProductionOrderFormState();
}

class _ProductionOrderFormState extends State<ProductionOrderForm> {
  late Product product = widget.products.first;
  List<ProductVariant> variants = [];
  ProductVariant? variant;
  ProductionRoute? route;
  bool bomValid = false;
  bool loadingContext = true;
  String productSearch = '';
  final productSearchController = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final notes = TextEditingController();
  final keyForm = GlobalKey<FormState>();

  List<Product> get filteredProducts {
    final query = productSearch.trim().toLowerCase();
    final filtered = widget.products
        .where(
          (item) =>
              query.isEmpty ||
              '${item.name} ${item.code}'.toLowerCase().contains(query),
        )
        .toList();
    if (!filtered.any((item) => item.id == product.id)) {
      filtered.insert(0, product);
    }
    return filtered;
  }

  bool get routeValid =>
      route != null &&
      route!.productId == product.id &&
      route!.stages.isNotEmpty &&
      route!.stages.asMap().entries.every(
        (entry) => entry.value.sequence == entry.key + 1,
      );

  @override
  void initState() {
    super.initState();
    _loadProductContext();
  }

  Future<void> _loadProductContext() async {
    setState(() {
      loadingContext = true;
      variants = [];
      variant = null;
      route = null;
      bomValid = false;
    });
    try {
      final values = await Future.wait<Object?>([
        widget.repository.activeVariants(product.id),
        widget.repository.routeForProduct(product.id),
        widget.repository.productBomIsValid(product.id),
      ]);
      if (!mounted) return;
      setState(() {
        variants = values[0] as List<ProductVariant>;
        route = values[1] as ProductionRoute?;
        bomValid = values[2] as bool;
        loadingContext = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingContext = false);
    }
  }

  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    productSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('أمر إنتاج جديد'),
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
        FilledButton.icon(
          onPressed: loadingContext || !routeValid ? null : _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ كمسودة'),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: Form(
          key: keyForm,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ProductionFormSection(
                title: 'المنتج',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: productSearchController,
                      decoration: const InputDecoration(
                        labelText: 'بحث عن منتج',
                        hintText: 'ابحث باسم المنتج أو الكود',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) =>
                          setState(() => productSearch = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Product>(
                      initialValue: product,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'المنتج',
                        border: OutlineInputBorder(),
                      ),
                      items: filteredProducts
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
                        setState(() {
                          product = value;
                          productSearch = '';
                          productSearchController.clear();
                        });
                        _loadProductContext();
                      },
                    ),
                    const SizedBox(height: 12),
                    _ProductionInfoValue(
                      label: 'المنتج المحدد',
                      value: '${product.name} • ${product.code}',
                    ),
                    if (variants.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<ProductVariant>(
                        initialValue: variant,
                        isExpanded: true,
                        hint: const Text('اختر البديل'),
                        decoration: const InputDecoration(
                          labelText: 'البديل (مطلوب)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null ? 'يجب اختيار بديل المنتج' : null,
                        items: variants
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
                        onChanged: (value) => setState(() => variant = value),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ProductionFormSection(
                title: 'مسار الإنتاج',
                child: loadingContext
                    ? const LinearProgressIndicator()
                    : routeValid
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المسار المعتمد لهذا المنتج'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: route!.stages
                                .map(
                                  (stage) => Chip(
                                    avatar: CircleAvatar(
                                      child: Text('${stage.sequence}'),
                                    ),
                                    label: Text(stage.stageName),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      )
                    : const Text('لا يوجد مسار إنتاج صالح لهذا المنتج.'),
              ),
              const SizedBox(height: 16),
              _ProductionFormSection(
                title: 'قائمة الخامات',
                child: loadingContext
                    ? const LinearProgressIndicator()
                    : Row(
                        children: [
                          Icon(
                            bomValid
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            color: bomValid
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bomValid
                                  ? 'قائمة الخامات صالحة للتنفيذ.'
                                  : 'لا يمكن بدء الإنتاج قبل استكمال قائمة الخامات',
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _ProductionFormSection(
                title: 'كمية الإنتاج',
                child: TextFormField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'الكمية المخططة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    return parsed == null || !parsed.isFinite || parsed <= 0
                        ? 'أدخل كمية صالحة أكبر من صفر'
                        : null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              _ProductionFormSection(
                title: 'ملاحظات',
                child: TextFormField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'ملاحظات اختيارية لأمر الإنتاج',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _ProductionFormSection(
                title: 'مواقع المخزون',
                child: const Text(
                  'يتم اختيار مخزن الخامات عند تسجيل الاستهلاك، ومخزن المنتج عند تسجيل الإنتاج المرحل.',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _saveDraft() {
    if (!keyForm.currentState!.validate()) return;
    Navigator.of(context).pop(
      _OrderDraft(
        product: product,
        quantity: double.parse(quantity.text.trim()),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        variantId: variant?.id,
      ),
    );
  }
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
  List<ProductVariant> variants = [];
  List<Warehouse> warehouses = [];
  bool bomValid = false;
  bool loading = true;

  bool get routeSnapshotValid =>
      order.routeId != null &&
      order.stages.isNotEmpty &&
      order.stages.asMap().entries.every(
        (entry) => entry.value.sequence == entry.key + 1,
      );

  ProductionOrderStage? get currentStage {
    for (final stage in order.stages) {
      if (stage.status == ProductionStageStatus.inProgress) return stage;
    }
    for (final stage in order.stages) {
      if (stage.status == ProductionStageStatus.pending) return stage;
    }
    return null;
  }

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
      widget.repository.activeVariants(order.productId),
      widget.repository.activeWarehouses(),
      widget.repository.orderBomIsValid(order.id),
    ]);
    if (!mounted) return;
    setState(() {
      order = result[0] as ProductionOrder;
      requirements = result[1] as List<ProductionMaterialRequirement>;
      consumptions = result[2] as List<ProductionMaterialRecord>;
      waste = result[3] as List<ProductionWasteRecord>;
      outputs = result[4] as List<ProductionOutputRecord>;
      variants = result[5] as List<ProductVariant>;
      warehouses = result[6] as List<Warehouse>;
      bomValid = result[7] as bool;
      loading = false;
    });
  }

  void error(Object value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value.toString())));

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    final selectedVariant = variants
        .where((value) => value.id == order.variantId)
        .firstOrNull;
    final activeStage = currentStage;
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
          onPressed: bomValid && routeSnapshotValid
              ? () => change(() => widget.repository.startOrder(order.id))
              : null,
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
                          order.productName ?? 'المنتج غير متاح',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text('رقم أمر الإنتاج: ${order.orderNumber}'),
                        Text(
                          'الحالة: ${_productionOrderStatusLabel(order.status)}',
                        ),
                        if (order.variantId != null)
                          Text(
                            selectedVariant == null
                                ? 'البديل: غير نشط أو غير متاح'
                                : 'البديل: ${selectedVariant.name} • ${selectedVariant.code}',
                          ),
                        Text(
                          order.hasVerifiedUnitSnapshot
                              ? 'المخطط: ${_quantityText(order.plannedBaseQuantity!)} • المنتج: ${_quantityText(order.producedQuantity)} • المتبقي: ${_quantityText(order.remainingQuantity!)}'
                              : 'لقطة الوحدة التاريخية غير موثقة؛ الكميات تتطلب تسوية.',
                        ),
                        Text(
                          'المسار: ${routeSnapshotValid ? order.stages.map((stage) => '${stage.sequence}. ${stage.stageName}').join(' ← ') : 'غير متاح'}',
                        ),
                        Text(
                          'المرحلة الحالية: ${activeStage?.stageName ?? (order.status == ProductionOrderStatus.completed ? 'اكتمل المسار' : 'لا توجد مرحلة حالية')}',
                        ),
                        Text(
                          'قائمة الخامات: ${bomValid ? 'صالحة' : 'غير مكتملة'}',
                        ),
                        if (order.status == ProductionOrderStatus.planned &&
                            (!bomValid || !routeSnapshotValid))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'لا يمكن بدء الإنتاج قبل استكمال قائمة الخامات والمسار.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (order.notes?.trim().isNotEmpty == true)
                          Text('ملاحظات: ${order.notes}'),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                      ],
                    ),
                  ),
                ),
                _section(
                  'مراحل الإنتاج',
                  order.stages.map(_stageTile).toList(),
                ),
                _section(
                  'متطلبات المواد',
                  requirements
                      .map(
                        (requirement) => ListTile(
                          title: Text(
                            '${requirement.rawMaterialName} • ${requirement.rawMaterialCode}',
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'المطلوب ${_quantityText(requirement.requiredQuantity)} ${requirement.unitName} • المستهلك ${_quantityText(requirement.consumedQuantity)} • المتبقي ${_quantityText(requirement.remainingQuantity)}',
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: requirement.requiredQuantity <= 0
                                    ? 0
                                    : (requirement.consumedQuantity /
                                              requirement.requiredQuantity)
                                          .clamp(0, 1),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(
                                label: Text(
                                  _requirementStatusLabel(requirement.status),
                                ),
                              ),
                              if (order.status ==
                                      ProductionOrderStatus.inProgress &&
                                  requirement.remainingQuantity > 0)
                                IconButton(
                                  tooltip: 'تسجيل استهلاك',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => consume(requirement),
                                ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
                _section(
                  'الاستهلاك',
                  consumptions
                      .map(
                        (item) => ListTile(
                          title: Text(
                            '${item.rawMaterialName} • ${item.rawMaterialCode}',
                          ),
                          subtitle: Text(
                            '${_dateTimeText(item.date)} • ${_quantityText(item.quantity)} ${item.unitName} • ${item.warehouseName} • تكلفة الوحدة ${item.unitCost.toStringAsFixed(2)}${item.operationId == null ? '' : ' • مرجع ${item.operationId}'}',
                          ),
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
                            '${item.date} • مخزن ${warehouses.where((warehouse) => warehouse.id == item.warehouseId).firstOrNull?.name ?? 'غير متاح'}',
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
  Widget _stageTile(ProductionOrderStage stage) {
    final isCurrent = currentStage?.id == stage.id;
    final previousComplete = _previousStagesComplete(stage);
    final canWork =
        order.status == ProductionOrderStatus.inProgress &&
        isCurrent &&
        previousComplete;
    final canStart = canWork && stage.status == ProductionStageStatus.pending;
    final canComplete =
        canWork && stage.status == ProductionStageStatus.inProgress;
    final canSkip =
        canWork &&
        (stage.status == ProductionStageStatus.pending ||
            stage.status == ProductionStageStatus.inProgress);
    final unavailableReason = order.status != ProductionOrderStatus.inProgress
        ? 'يجب أن يكون أمر الإنتاج قيد التنفيذ أولاً'
        : !previousComplete
        ? 'يجب إتمام المرحلة السابقة أولاً'
        : stage.status == ProductionStageStatus.inProgress
        ? 'هذه المرحلة قيد التنفيذ بالفعل'
        : stage.status == ProductionStageStatus.completed
        ? 'هذه المرحلة مكتملة'
        : stage.status == ProductionStageStatus.skipped
        ? 'هذه المرحلة متخطاة'
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isCurrent
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CircleAvatar(child: Text('${stage.sequence}')),
                Text(
                  stage.stageName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Chip(label: Text(_productionStageStatusLabel(stage.status))),
                if (stage.sequence == order.stages.length)
                  const Chip(label: Text('المرحلة النهائية')),
                if (canStart)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        change(() => widget.repository.startStage(stage.id)),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('بدء المرحلة'),
                  ),
                if (canComplete)
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        change(() => widget.repository.completeStage(stage.id)),
                    icon: const Icon(Icons.check),
                    label: const Text('إتمام المرحلة'),
                  ),
                if (canSkip)
                  OutlinedButton.icon(
                    onPressed: () => _skipStage(stage),
                    icon: const Icon(Icons.skip_next),
                    label: const Text('تخطي المرحلة'),
                  ),
              ],
            ),
            if (stage.status == ProductionStageStatus.skipped &&
                stage.notes?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, top: 6),
                child: Text('سبب التخطي: ${stage.notes}'),
              ),
            if (!canStart && !canComplete && unavailableReason != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 48, top: 6),
                child: Text(
                  unavailableReason,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _previousStagesComplete(ProductionOrderStage stage) {
    final previous =
        order.stages
            .where((candidate) => candidate.sequence < stage.sequence)
            .toList()
          ..sort((first, second) => first.sequence.compareTo(second.sequence));
    for (var index = 0; index < previous.length; index++) {
      final item = previous[index];
      if (item.sequence != index + 1 ||
          (item.status != ProductionStageStatus.completed &&
              item.status != ProductionStageStatus.skipped)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _skipStage(ProductionOrderStage stage) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const SkipProductionStageDialog(),
    );
    if (reason == null) return;
    await change(() => widget.repository.skipStage(stage.id, reason));
  }

  Future<void> change(Future<void> Function() action) async {
    try {
      await action();
      await load();
    } catch (value) {
      error(value);
    }
  }

  Future<void> consume(ProductionMaterialRequirement requirement) async {
    final allowedWarehouses = await widget.repository
        .accessibleProductionWarehouses();
    if (!mounted) return;
    if (allowedWarehouses.isEmpty) {
      error('لا توجد مخازن ضمن نطاق صلاحيتك');
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaterialConsumptionPage(
          repository: widget.repository,
          order: order,
          requirements: requirements,
          warehouses: allowedWarehouses,
          initialRequirement: requirement,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
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
    final allowedWarehouses = await widget.repository.outputWarehouses(
      order.id,
    );
    if (!mounted) return;
    if (allowedWarehouses.isEmpty) {
      error('المخزن غير متاح ضمن مصنع المرحلة النهائية أو نطاق صلاحيتك');
      return;
    }
    final remainingBaseQuantity = order.remainingQuantity;
    if (remainingBaseQuantity == null) {
      error(
        'لقطة الوحدة التاريخية غير موثقة؛ يلزم إجراء تسوية قبل تسجيل الإنتاج.',
      );
      return;
    }
    final remaining = remainingBaseQuantity
        .clamp(0, order.plannedBaseQuantity!)
        .toDouble();
    if (remaining <= 0) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductionOutputForm(
          repository: widget.repository,
          order: order,
          variant: variants
              .where((value) => value.id == order.variantId)
              .firstOrNull,
          warehouses: allowedWarehouses,
          remainingQuantity: remaining,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await load();
    } catch (value) {
      error(value);
    }
  }
}

class ProductionOutputForm extends StatefulWidget {
  const ProductionOutputForm({
    required this.repository,
    required this.order,
    required this.variant,
    required this.warehouses,
    required this.remainingQuantity,
    super.key,
  });

  final ProductionRepository repository;
  final ProductionOrder order;
  final ProductVariant? variant;
  final List<Warehouse> warehouses;
  final double remainingQuantity;

  @override
  State<ProductionOutputForm> createState() => _ProductionOutputFormState();
}

class _ProductionOutputFormState extends State<ProductionOutputForm> {
  late Warehouse warehouse = widget.warehouses.first;
  final quantity = TextEditingController();
  final formKey = GlobalKey<FormState>();
  late final String operationId =
      'production-output-${DateTime.now().microsecondsSinceEpoch}';
  bool submitting = false;

  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('إدخال إنتاج تام'),
      leading: IconButton(
        tooltip: 'رجوع',
        onPressed: submitting ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        TextButton.icon(
          onPressed: submitting ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('إلغاء'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: submitting ? null : _confirm,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('تأكيد الإنتاج'),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ProductionFormSection(
                title: 'أمر الإنتاج',
                child: Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    _ProductionInfoValue(
                      label: 'رقم الأمر',
                      value: widget.order.orderNumber,
                    ),
                    _ProductionInfoValue(
                      label: 'المنتج',
                      value:
                          '${widget.order.productName ?? 'المنتج غير متاح'} • ${widget.order.productId}',
                    ),
                    if (widget.variant != null)
                      _ProductionInfoValue(
                        label: 'البديل',
                        value:
                            '${widget.variant!.name} • ${widget.variant!.code}',
                      ),
                    _ProductionInfoValue(
                      label: 'الكمية المخططة',
                      value: _quantityText(widget.order.plannedQuantity),
                    ),
                    _ProductionInfoValue(
                      label: 'الإنتاج السابق',
                      value: _quantityText(widget.order.producedQuantity),
                    ),
                    _ProductionInfoValue(
                      label: 'الكمية المتبقية',
                      value: _quantityText(widget.remainingQuantity),
                    ),
                    _ProductionInfoValue(
                      label: 'المرحلة النهائية',
                      value: widget.order.stages.isEmpty
                          ? 'غير متاحة'
                          : widget.order.stages.last.stageName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ProductionFormSection(
                title: 'بيانات الإنتاج التام',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth > 760
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<Warehouse>(
                            initialValue: warehouse,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'المخزن',
                              border: OutlineInputBorder(),
                            ),
                            items: widget.warehouses
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null)
                                setState(() => warehouse = value);
                            },
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'الكمية المتبقية',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              _quantityText(widget.remainingQuantity),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            controller: quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'الكمية المنتجة',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(
                                value?.trim() ?? '',
                              );
                              if (parsed == null ||
                                  !parsed.isFinite ||
                                  parsed <= 0) {
                                return 'يجب أن تكون الكمية رقماً أكبر من صفر';
                              }
                              if (parsed > widget.remainingQuantity) {
                                return 'الكمية تتجاوز الكمية المتبقية';
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
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _confirm() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الإنتاج التام'),
        content: Text(
          'تسجيل ${_quantityText(double.parse(quantity.text.trim()))} في مخزن ${warehouse.name}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => submitting = true);
    try {
      await widget.repository.recordOutput(
        orderId: widget.order.id,
        warehouseId: warehouse.id,
        quantity: double.parse(quantity.text.trim()),
        date: DateTime.now(),
        operationId: operationId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_productionOutputError(error))));
    }
  }
}

class SkipProductionStageDialog extends StatefulWidget {
  const SkipProductionStageDialog({super.key});

  @override
  State<SkipProductionStageDialog> createState() =>
      _SkipProductionStageDialogState();
}

class _SkipProductionStageDialogState extends State<SkipProductionStageDialog> {
  final reason = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('تخطي المرحلة'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: formKey,
        child: TextFormField(
          controller: reason,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'سبب التخطي',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'سبب تخطي المرحلة مطلوب'
              : null,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.of(context).pop(reason.text.trim());
        },
        child: const Text('تأكيد التخطي'),
      ),
    ],
  );
}

class MaterialConsumptionPage extends StatefulWidget {
  const MaterialConsumptionPage({
    required this.repository,
    required this.order,
    required this.requirements,
    required this.warehouses,
    required this.initialRequirement,
    super.key,
  });

  final ProductionRepository repository;
  final ProductionOrder order;
  final List<ProductionMaterialRequirement> requirements;
  final List<Warehouse> warehouses;
  final ProductionMaterialRequirement initialRequirement;

  @override
  State<MaterialConsumptionPage> createState() =>
      _MaterialConsumptionPageState();
}

class _MaterialConsumptionPageState extends State<MaterialConsumptionPage> {
  late ProductionMaterialRequirement requirement = widget.initialRequirement;
  late Warehouse warehouse = widget.warehouses.first;
  final quantity = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final stockRepository = WarehousesStockRepositoryImpl();
  late final String operationId =
      'production-consumption-${DateTime.now().microsecondsSinceEpoch}';
  double? availableStock;
  bool loadingStock = true;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    setState(() {
      loadingStock = true;
      availableStock = null;
    });
    try {
      final value = await stockRepository.balance(
        warehouse.id,
        requirement.rawMaterialId,
        StockItemType.rawMaterial,
      );
      if (!mounted) return;
      setState(() {
        availableStock = value;
        loadingStock = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingStock = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('تسجيل استهلاك خامة'),
      leading: IconButton(
        tooltip: 'رجوع',
        onPressed: submitting ? null : () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        TextButton.icon(
          onPressed: submitting ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('إلغاء'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: submitting || loadingStock ? null : _submit,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('تأكيد الاستهلاك'),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ProductionFormSection(
                title: 'أمر الإنتاج',
                child: Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    _ProductionInfoValue(
                      label: 'رقم الأمر',
                      value: widget.order.orderNumber,
                    ),
                    _ProductionInfoValue(
                      label: 'المنتج',
                      value: widget.order.productName ?? 'المنتج غير متاح',
                    ),
                    _ProductionInfoValue(
                      label: 'الكمية المخططة',
                      value: _quantityText(widget.order.plannedQuantity),
                    ),
                    _ProductionInfoValue(
                      label: 'الحالة',
                      value: _productionOrderStatusLabel(widget.order.status),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ProductionFormSection(
                title: 'متطلبات المواد',
                child: DropdownButtonFormField<ProductionMaterialRequirement>(
                  initialValue: requirement,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الخامة',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.requirements
                      .where((item) => item.remainingQuantity > 0)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item.rawMaterialName} • ${item.rawMaterialCode}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => requirement = value);
                    _loadStock();
                  },
                ),
              ),
              const SizedBox(height: 12),
              _ProductionFormSection(
                title: requirement.rawMaterialName,
                child: Wrap(
                  spacing: 28,
                  runSpacing: 14,
                  children: [
                    _ProductionInfoValue(
                      label: 'كود الخامة',
                      value: requirement.rawMaterialCode,
                    ),
                    _ProductionInfoValue(
                      label: 'المطلوب',
                      value:
                          '${_quantityText(requirement.requiredQuantity)} ${requirement.unitName}',
                    ),
                    _ProductionInfoValue(
                      label: 'المستهلك',
                      value:
                          '${_quantityText(requirement.consumedQuantity)} ${requirement.unitName}',
                    ),
                    _ProductionInfoValue(
                      label: 'المتبقي',
                      value:
                          '${_quantityText(requirement.remainingQuantity)} ${requirement.unitName}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ProductionFormSection(
                title: 'بيانات الاستهلاك',
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth > 760
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: DropdownButtonFormField<Warehouse>(
                            initialValue: warehouse,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'مخزن الخامات',
                              border: OutlineInputBorder(),
                            ),
                            items: widget.warehouses
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => warehouse = value);
                              _loadStock();
                            },
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'المتاح في المخزن',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              loadingStock
                                  ? 'جارٍ التحقق...'
                                  : availableStock == null
                                  ? 'تعذر قراءة الرصيد'
                                  : '${_quantityText(availableStock!)} ${requirement.unitName}',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: TextFormField(
                            controller: quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'كمية الاستهلاك',
                              helperText:
                                  'المتبقي ${_quantityText(requirement.remainingQuantity)} ${requirement.unitName}',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(
                                value?.trim() ?? '',
                              );
                              if (parsed == null ||
                                  !parsed.isFinite ||
                                  parsed <= 0) {
                                return 'الكمية يجب أن تكون أكبر من صفر';
                              }
                              if (parsed > requirement.remainingQuantity) {
                                return 'الكمية تتجاوز المتبقي من الخامة';
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
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(quantity.text.trim());
    if (availableStock == null || amount > availableStock!) {
      _showError('الكمية غير متاحة في المخزن');
      return;
    }
    setState(() => submitting = true);
    try {
      await widget.repository.consumeMaterial(
        orderId: widget.order.id,
        rawMaterialId: requirement.rawMaterialId,
        warehouseId: warehouse.id,
        quantity: amount,
        date: DateTime.now(),
        operationId: operationId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => submitting = false);
      _showError(_productionConsumptionError(error));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

String _productionOrderStatusLabel(ProductionOrderStatus status) =>
    switch (status) {
      ProductionOrderStatus.draft => 'مسودة',
      ProductionOrderStatus.planned => 'مخطط',
      ProductionOrderStatus.inProgress => 'قيد التنفيذ',
      ProductionOrderStatus.completed => 'مكتمل',
      ProductionOrderStatus.cancelled => 'ملغي',
    };

String _productionStageStatusLabel(ProductionStageStatus status) =>
    switch (status) {
      ProductionStageStatus.pending => 'لم تبدأ',
      ProductionStageStatus.inProgress => 'قيد التنفيذ',
      ProductionStageStatus.completed => 'مكتملة',
      ProductionStageStatus.skipped => 'متخطاة',
    };

String _productionActionError(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '');
  if (message.contains('ليس لديك صلاحية') ||
      message.contains('النطاق المسموح')) {
    return 'لا توجد صلاحية لتنفيذ هذه العملية';
  }
  if (message.contains('يجب إكمال المرحلة السابقة')) {
    return 'يجب إتمام المرحلة السابقة أولاً';
  }
  if (message.contains('المرحلة ليست معلقة')) {
    return 'هذه المرحلة قيد التنفيذ بالفعل';
  }
  if (message.contains('غير قيد التنفيذ'))
    return 'هذه المرحلة ليست قيد التنفيذ';
  return message;
}

String _productionOutputError(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '');
  if (message.contains('ليس لديك صلاحية') ||
      message.contains('النطاق المسموح')) {
    return 'لا توجد صلاحية لتنفيذ العملية';
  }
  if (message.contains('يجب إكمال المرحلة النهائية')) {
    return 'يجب إكمال المرحلة النهائية أولاً';
  }
  if (message.contains('الخامات المطلوبة')) {
    return 'لم يتم استهلاك الخامات المطلوبة بالكامل';
  }
  if (message.contains('تتجاوز الكمية المتبقية')) {
    return 'الكمية تتجاوز الكمية المتبقية';
  }
  if (message.contains('المخزن')) return 'المخزن غير متاح';
  if (message.contains('أكبر من صفر')) return 'يجب أن تكون الكمية أكبر من صفر';
  return message;
}

String _requirementStatusLabel(ProductionRequirementStatus status) =>
    switch (status) {
      ProductionRequirementStatus.notStarted => 'لم يبدأ',
      ProductionRequirementStatus.partial => 'جزئي',
      ProductionRequirementStatus.complete => 'مكتمل',
    };

String _quantityText(double value) => value == value.truncateToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

String _dateOnlyText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _dateTimeText(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _productionConsumptionError(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '');
  if (message.contains('ليس لديك صلاحية')) return 'لا توجد صلاحية';
  if (message.contains('النطاق المسموح')) return 'لا توجد صلاحية لهذا المخزن';
  if (message.contains('الوحدة')) return 'الوحدة غير متوافقة';
  if (message.contains('الخامة غير موجودة') || message.contains('غير نشطة')) {
    return 'الخامة غير متاحة';
  }
  if (message.contains('غير كاف') || message.contains('غير كافية')) {
    return 'الكمية غير متاحة في المخزن';
  }
  if (message.contains('أكبر من صفر')) return 'الكمية يجب أن تكون أكبر من صفر';
  if (message.contains('تتجاوز المتبقي')) {
    return 'الكمية تتجاوز المتبقي من الخامة';
  }
  return message;
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
