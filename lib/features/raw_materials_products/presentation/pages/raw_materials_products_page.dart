import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/ui/form_field.dart';
import 'package:furnexa/core/shared/widgets/furnexa_form.dart';
import 'package:furnexa/core/shared/widgets/detail/furnexa_detail.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/features/raw_materials_products/data/repositories/raw_materials_products_repository_impl.dart';
import 'package:furnexa/features/raw_materials_products/domain/entities/item_entities.dart';
import 'package:furnexa/features/raw_materials_products/domain/repositories/raw_materials_products_repository.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class RawMaterialsProductsPage extends StatefulWidget {
  const RawMaterialsProductsPage({
    super.key,
    required this.security,
    this.initialProductId,
  });

  final SecurityLocalDataSource security;
  final String? initialProductId;
  @override
  State<RawMaterialsProductsPage> createState() =>
      _RawMaterialsProductsPageState();
}

class _RawMaterialsProductsPageState extends State<RawMaterialsProductsPage>
    with SingleTickerProviderStateMixin {
  final RawMaterialsProductsRepository _repository =
      RawMaterialsProductsRepositoryImpl();
  late final TabController _tabs;
  bool _loading = true;
  List<Category> _categories = [];
  List<UnitEntity> _units = [];
  List<ItemColor> _colors = [];
  List<RawMaterial> _materials = [];
  List<Product> _products = [];
  String _materialQuery = '', _productQuery = '';
  String? _materialCategory, _productCategory;
  ProductState? _productState;
  final ScrollController _categoryScrollController = ScrollController();
  final ScrollController _unitScrollController = ScrollController();
  final ScrollController _colorScrollController = ScrollController();
  final ScrollController _materialScrollController = ScrollController();
  final ScrollController _productScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _categoryScrollController.dispose();
    _unitScrollController.dispose();
    _colorScrollController.dispose();
    _materialScrollController.dispose();
    _productScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _repository.categories(),
        _repository.units(),
        _repository.colors(),
        _repository.rawMaterials(_materialQuery, _materialCategory),
        _repository.products(_productQuery, _productCategory, _productState),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = values[0] as List<Category>;
        _units = values[1] as List<UnitEntity>;
        _colors = values[2] as List<ItemColor>;
        _materials = values[3] as List<RawMaterial>;
        _products = values[4] as List<Product>;
      });
      final selected = widget.initialProductId == null
          ? null
          : _products
                .where((value) => value.id == widget.initialProductId)
                .firstOrNull;
      if (selected != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _productProfile(selected);
        });
      }
    } catch (error) {
      if (mounted) _message('تعذر تحميل بيانات الأصناف', error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  Future<void> _save(Future<void> Function() action) async {
    try {
      await action();
      await _load();
      if (mounted) _message('تم الحفظ بنجاح');
    } catch (error) {
      if (mounted) _message(_databaseMessage(error), null);
    }
  }

  String _databaseMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('unique') || text.contains('code')) {
      return 'الكود أو القيمة مستخدمة مسبقاً';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _message(String message, [Object? error]) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error == null ? AppTheme.success : AppTheme.error,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأصناف والمواد'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'التصنيفات'),
            Tab(text: 'الوحدات'),
            Tab(text: 'الألوان'),
            Tab(text: 'الخامات'),
            Tab(text: 'المنتجات'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _catalogCategories(),
                _catalogUnits(),
                _catalogColors(),
                _materialsView(),
                _productsView(),
              ],
            ),
    );
  }

  Widget _catalogCategories() => _catalogPanel<Category>(
    title: 'التصنيفات',
    add: () => _categoryForm(),
    scrollController: _categoryScrollController,
    items: _categories,
    search: (q) async => setState(
      () => _categories = _categories
          .where((v) => '${v.name} ${v.code}'.contains(q))
          .toList(),
    ),
    row: (v) => _row(
      '${v.name} • ${v.code}',
      v.description ?? '',
      v.active,
      () => _categoryForm(v),
      () => _toggle('categories', v.id, v.active),
    ),
  );
  Widget _catalogUnits() => _catalogPanel<UnitEntity>(
    title: 'الوحدات',
    add: () => _unitForm(),
    scrollController: _unitScrollController,
    items: _units,
    search: (q) async => setState(
      () => _units = _units
          .where((v) => '${v.name} ${v.abbreviation}'.contains(q))
          .toList(),
    ),
    row: (v) => _row(
      '${v.name} (${v.abbreviation})',
      '',
      v.active,
      () => _unitForm(v),
      () => _toggle('units', v.id, v.active),
    ),
  );
  Widget _catalogColors() => _catalogPanel<ItemColor>(
    title: 'الألوان',
    add: () => _colorForm(),
    scrollController: _colorScrollController,
    items: _colors,
    search: (q) async => setState(
      () => _colors = _colors
          .where((v) => '${v.name} ${v.code}'.contains(q))
          .toList(),
    ),
    row: (v) => _row(
      '${v.name} • ${v.code}',
      '',
      v.active,
      () => _colorForm(v),
      () => _toggle('colors', v.id, v.active),
    ),
  );
  Widget _catalogPanel<T>({
    required String title,
    required VoidCallback add,
    required ScrollController scrollController,
    required List<T> items,
    required Widget Function(T) row,
    Future<void> Function(String)? search,
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
              runSpacing: 8,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.icon(
                  onPressed: add,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (search != null)
              TextField(
                onChanged: (v) => search(v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 10),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('لا توجد بيانات بعد. أضف أول سجل.'),
                    )
                  : Scrollbar(
                      controller: scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: items.length,
                        itemBuilder: (_, i) => row(items[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _row(
    String title,
    String subtitle,
    bool active,
    VoidCallback edit,
    VoidCallback toggle,
  ) => ListTile(
    dense: true,
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: subtitle.isEmpty ? null : Text(subtitle),
    leading: Icon(
      active ? Icons.check_circle_outline : Icons.pause_circle_outline,
      color: active
          ? AppTheme.success
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    trailing: Wrap(
      children: [
        IconButton(
          tooltip: 'تعديل',
          onPressed: edit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: active ? 'تعطيل' : 'تفعيل',
          onPressed: toggle,
          icon: Icon(active ? Icons.toggle_on : Icons.toggle_off),
        ),
      ],
    ),
  );

  Widget _materialsView() => _entityPanel(
    title: 'الخامات',
    scrollController: _materialScrollController,
    add: () => _materialForm(),
    query: _materialQuery,
    onQuery: (v) {
      _materialQuery = v;
      _load();
    },
    filter: DropdownButton<String?>(
      value: _materialCategory,
      hint: const Text('كل التصنيفات'),
      items: [
        const DropdownMenuItem(value: null, child: Text('كل التصنيفات')),
        ..._categories.map(
          (v) => DropdownMenuItem(value: v.id, child: Text(v.name)),
        ),
      ],
      onChanged: (v) {
        _materialCategory = v;
        _load();
      },
    ),
    items: _materials.map((v) {
      final category = _categories
          .where((c) => c.id == v.categoryId)
          .firstOrNull;
      final unit = _units.where((u) => u.id == v.unitId).firstOrNull;
      return _row(
        '${v.name} • ${v.code}',
        '${category?.name ?? '-'} | ${unit?.name ?? '-'}${v.description == null ? '' : ' | ${v.description}'}',
        v.active,
        () => _materialForm(v),
        () => _toggle('raw_materials', v.id, v.active),
      );
    }).toList(),
  );
  Widget _productsView() => _entityPanel(
    title: 'المنتجات',
    scrollController: _productScrollController,
    add: () => _productForm(),
    showAdd: widget.security.can('PRODUCTS_EDIT'),
    query: _productQuery,
    onQuery: (v) {
      _productQuery = v;
      _load();
    },
    filter: Wrap(
      spacing: 8,
      children: [
        DropdownButton<String?>(
          value: _productCategory,
          hint: const Text('كل التصنيفات'),
          items: [
            const DropdownMenuItem(value: null, child: Text('كل التصنيفات')),
            ..._categories.map(
              (v) => DropdownMenuItem(value: v.id, child: Text(v.name)),
            ),
          ],
          onChanged: (v) {
            _productCategory = v;
            _load();
          },
        ),
        DropdownButton<ProductState?>(
          value: _productState,
          hint: const Text('كل الحالات'),
          items: const [
            DropdownMenuItem(value: null, child: Text('كل الحالات')),
            DropdownMenuItem(
              value: ProductState.unfinished,
              child: Text('غير متشطب'),
            ),
            DropdownMenuItem(
              value: ProductState.finished,
              child: Text('متشطب'),
            ),
          ],
          onChanged: (v) {
            _productState = v;
            _load();
          },
        ),
      ],
    ),
    items: _products.map((v) {
      final category = _categories
          .where((c) => c.id == v.categoryId)
          .firstOrNull;
      final unit = _units.where((u) => u.id == v.unitId).firstOrNull;
      return ListTile(
        selected: v.id == widget.initialProductId,
        dense: true,
        title: Text(
          '${v.name} • ${v.code}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${category?.name ?? '-'} | ${unit?.name ?? '-'} | ${v.state == ProductState.finished ? 'متشطب' : 'غير متشطب'}',
        ),
        leading: Icon(
          v.active ? Icons.inventory_2_outlined : Icons.pause_circle_outline,
          color: v.active
              ? AppTheme.success
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        trailing: Wrap(
          children: [
            if (widget.security.can('PRODUCTS_EDIT'))
              IconButton(
                tooltip: 'التفاصيل',
                onPressed: () => _productProfile(v),
                icon: const Icon(Icons.open_in_new),
              ),
            if (widget.security.can('PRODUCTS_EDIT'))
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => _productForm(v),
                icon: const Icon(Icons.edit_outlined),
              ),
            IconButton(
              tooltip: v.active ? 'تعطيل' : 'تفعيل',
              onPressed: () => _toggle('products', v.id, v.active),
              icon: Icon(v.active ? Icons.toggle_on : Icons.toggle_off),
            ),
          ],
        ),
      );
    }).toList(),
  );
  Widget _entityPanel({
    required String title,
    required ScrollController scrollController,
    required VoidCallback add,
    required String query,
    required ValueChanged<String> onQuery,
    required Widget filter,
    required List<Widget> items,
    bool showAdd = true,
  }) {
    return Padding(
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
                runSpacing: 8,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (showAdd)
                    FilledButton.icon(
                      onPressed: add,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      onChanged: onQuery,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'بحث',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  filter,
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text('لا توجد بيانات بعد. أضف أول سجل.'),
                      )
                    : Scrollbar(
                        controller: scrollController,
                        thumbVisibility: true,
                        child: ListView(
                          controller: scrollController,
                          children: items,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(String table, String id, bool active) =>
      _save(() => _repository.setActive(table, id, !active));
  Future<void> _categoryForm([Category? current]) async {
    final v = await _form('التصنيف', [
      ('name', 'اسم التصنيف', current?.name),
      ('code', 'الكود', current?.code),
      ('description', 'الوصف', current?.description),
    ]);
    if (v == null) return;
    final now = DateTime.now();
    await _save(
      () => _repository.saveCategory(
        Category(
          id: current?.id ?? _id('category'),
          name: v['name']!,
          code: v['code']!,
          description: _optional(v['description']),
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
  }

  Future<void> _unitForm([UnitEntity? current]) async {
    final v = await _form('الوحدة', [
      ('name', 'اسم الوحدة', current?.name),
      ('abbreviation', 'الاختصار', current?.abbreviation),
    ]);
    if (v == null) return;
    final now = DateTime.now();
    await _save(
      () => _repository.saveUnit(
        UnitEntity(
          id: current?.id ?? _id('unit'),
          name: v['name']!,
          abbreviation: v['abbreviation']!,
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
  }

  Future<void> _colorForm([ItemColor? current]) async {
    final v = await _form('اللون', [
      ('name', 'اسم اللون', current?.name),
      ('code', 'الكود', current?.code),
    ]);
    if (v == null) return;
    final now = DateTime.now();
    await _save(
      () => _repository.saveColor(
        ItemColor(
          id: current?.id ?? _id('color'),
          name: v['name']!,
          code: v['code']!,
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
  }

  Future<void> _materialForm([RawMaterial? current]) async {
    final v = await _form(
      'الخامة',
      [
        ('name', 'اسم الخامة', current?.name),
        ('code', 'الكود', current?.code),
        ('description', 'الوصف', current?.description),
      ],
      selects: [
        _SelectData('categoryId', 'التصنيف', {
          for (final x in _categories.where(
            (x) => x.active || x.id == current?.categoryId,
          ))
            x.id: x.name,
        }, current?.categoryId),
        _SelectData('unitId', 'الوحدة', {
          for (final x in _units.where(
            (x) => x.active || x.id == current?.unitId,
          ))
            x.id: x.name,
        }, current?.unitId),
      ],
    );
    if (v == null) return;
    final now = DateTime.now();
    await _save(
      () => _repository.saveRawMaterial(
        RawMaterial(
          id: current?.id ?? _id('material'),
          name: v['name']!,
          code: v['code']!,
          categoryId: v['categoryId']!,
          unitId: v['unitId']!,
          description: _optional(v['description']),
          active: current?.active ?? true,
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
  }

  Future<void> _productForm([Product? current]) async {
    await showDialog(
      context: context,
      builder: (_) => _ProductFormDialog(
        current: current,
        categories: _categories,
        units: _units,
        repository: _repository,
        id: _id,
        onSaved: _load,
      ),
    );
  }

  String? _optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  Future<void> _productProfile(Product product) async {
    await showDialog(
      context: context,
      builder: (_) => _ProductProfileDialog(
        product: product,
        repository: _repository,
        colors: _colors,
        materials: _materials,
        units: _units,
        canEdit: widget.security.can('PRODUCTS_EDIT'),
        onSaved: _load,
      ),
    );
  }

  Future<Map<String, String>?> _form(
    String title,
    List<(String, String, String?)> fields, {
    List<_SelectData> selects = const [],
  }) => showDialog<Map<String, String>>(
    context: context,
    builder: (_) => _ItemForm(title: title, fields: fields, selects: selects),
  );
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({
    required this.current,
    required this.categories,
    required this.units,
    required this.repository,
    required this.id,
    required this.onSaved,
  });

  final Product? current;
  final List<Category> categories;
  final List<UnitEntity> units;
  final RawMaterialsProductsRepository repository;
  final String Function(String) id;
  final Future<void> Function() onSaved;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.current?.name ?? '',
  );
  late final TextEditingController _code = TextEditingController(
    text: widget.current?.code ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.current?.description ?? '',
  );
  String? _categoryId;
  String? _unitId;
  late ProductState _state = widget.current?.state ?? ProductState.unfinished;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.current?.categoryId;
    _unitId = widget.current?.unitId;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      await widget.repository.saveProduct(
        Product(
          id: widget.current?.id ?? widget.id('product'),
          name: _name.text.trim(),
          code: _code.text.trim(),
          categoryId: _categoryId!,
          unitId: _unitId!,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          state: _state,
          active: widget.current?.active ?? true,
          createdAt: widget.current?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      await widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.current == null ? 'إضافة منتج' : 'تعديل المنتج'),
    content: SizedBox(
      width: 820,
      child: FurnexaFormShell(
        formKey: _formKey,
        title: 'بيانات المنتج',
        subtitle: 'أدخل البيانات الأساسية ثم حدد حالة المنتج.',
        cancelLabel: 'إلغاء',
        saveLabel: 'حفظ المنتج',
        onCancel: () => Navigator.pop(context),
        onSave: _save,
        saveLoading: _saving,
        sections: [
          FurnexaFormSection(
            title: 'معلومات المنتج',
            children: [
              FurnexaFormField(
                controller: _name,
                labelText: 'اسم المنتج *',
                required: true,
              ),
              FurnexaFormField(
                controller: _code,
                labelText: 'كود المنتج *',
                required: true,
              ),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'التصنيف *'),
                items: widget.categories
                    .where((item) => item.active || item.id == _categoryId)
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) => value == null ? 'هذا الحقل مطلوب' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _unitId,
                decoration: const InputDecoration(labelText: 'الوحدة *'),
                items: widget.units
                    .where((item) => item.active || item.id == _unitId)
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _unitId = value),
                validator: (value) => value == null ? 'هذا الحقل مطلوب' : null,
              ),
              FurnexaFormField(
                controller: _description,
                labelText: 'الوصف',
                maxLines: 3,
                required: false,
              ),
            ],
          ),
          FurnexaFormSection(
            title: 'حالة المنتج',
            children: [
              DropdownButtonFormField<ProductState>(
                initialValue: _state,
                decoration: const InputDecoration(labelText: 'حالة المنتج *'),
                items: const [
                  DropdownMenuItem(
                    value: ProductState.unfinished,
                    child: Text('غير متشطب'),
                  ),
                  DropdownMenuItem(
                    value: ProductState.finished,
                    child: Text('متشطب'),
                  ),
                ],
                onChanged: (value) => setState(() => _state = value!),
              ),
            ],
          ),
          if (_error != null)
            FurnexaFormSection(
              title: 'تعذر الحفظ',
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _SelectData {
  const _SelectData(
    this.key,
    this.label,
    this.items,
    this.value, {
    this.required = true,
  });
  final String key, label;
  final Map<String, String> items;
  final String? value;
  final bool required;
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({
    required this.title,
    required this.fields,
    required this.selects,
    this.optionalFields = const {},
  });
  final String title;
  final List<(String, String, String?)> fields;
  final List<_SelectData> selects;
  final Set<String> optionalFields;
  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _key = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _values = <String, String?>{};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field.$1] = TextEditingController(text: field.$3 ?? '');
    }
    for (final select in widget.selects) {
      _values[select.key] = select.value;
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
        width: 760,
        child: FurnexaFormShell(
          formKey: _key,
          cancelLabel: 'إلغاء',
          saveLabel: 'حفظ',
          onCancel: () => Navigator.pop(context),
          onSave: () {
            if (!(_key.currentState?.validate() ?? false)) return;
            final result = <String, String>{
              for (final entry in _controllers.entries)
                entry.key: entry.value.text.trim(),
              for (final entry in _values.entries)
                if (entry.value != null) entry.key: entry.value!,
            };
            Navigator.pop(context, result);
          },
          sections: [
            FurnexaFormSection(
              title: widget.title,
              children: [
                ...widget.fields.map(
                  (field) => FurnexaFormField(
                    controller: _controllers[field.$1],
                    maxLines: field.$1 == 'description' ? 3 : 1,
                    required: !widget.optionalFields.contains(field.$1),
                    labelText: field.$2,
                    validator: (value) {
                      if (widget.optionalFields.contains(field.$1) &&
                          (value == null || value.trim().isEmpty)) {
                        return null;
                      }
                      if (value == null || value.trim().isEmpty) {
                        return 'هذا الحقل مطلوب';
                      }
                      if (const {
                        'length',
                        'width',
                        'height',
                      }.contains(field.$1)) {
                        final numeric = double.tryParse(value.trim());
                        if (numeric == null || numeric <= 0) {
                          return 'أدخل رقماً موجباً';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                ...widget.selects.map(
                  (select) => DropdownButtonFormField<String>(
                    initialValue: _values[select.key],
                    decoration: InputDecoration(
                      labelText: select.required
                          ? '${select.label} *'
                          : select.label,
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
                    validator: (value) => select.required && value == null
                        ? 'هذا الحقل مطلوب'
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductProfileDialog extends StatefulWidget {
  const _ProductProfileDialog({
    required this.product,
    required this.repository,
    required this.colors,
    required this.materials,
    required this.units,
    required this.canEdit,
    required this.onSaved,
  });
  final Product product;
  final RawMaterialsProductsRepository repository;
  final List<ItemColor> colors;
  final List<RawMaterial> materials;
  final List<UnitEntity> units;
  final bool canEdit;
  final Future<void> Function() onSaved;
  @override
  State<_ProductProfileDialog> createState() => _ProductProfileDialogState();
}

class _ProductProfileDialogState extends State<_ProductProfileDialog> {
  List<ProductVariant> variants = [];
  List<ProductAlternative> alternatives = [];
  List<ProductDimension> dimensions = [];
  List<BomItem> bom = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await Future.wait([
      widget.repository.variants(widget.product.id),
      widget.repository.getAlternatives(widget.product.id),
      widget.repository.dimensions(widget.product.id),
      widget.repository.bom(widget.product.id),
    ]);
    if (mounted) {
      setState(() {
        variants = result[0] as List<ProductVariant>;
        alternatives = result[1] as List<ProductAlternative>;
        dimensions = result[2] as List<ProductDimension>;
        bom = result[3] as List<BomItem>;
        loading = false;
      });
    }
  }

  String _id(String p) => '$p-${DateTime.now().microsecondsSinceEpoch}';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('ملف المنتج: ${widget.product.name}'),
    content: SizedBox(
      width: 720,
      height: 520,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'البيانات الأساسية'),
                      Tab(text: 'المتغيرات'),
                      Tab(text: 'البدائل'),
                      Tab(text: 'الأبعاد'),
                      Tab(text: 'مكونات المنتج'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _summary(),
                        _variantsView(),
                        _alternativesView(),
                        _dimensionsView(),
                        _bomView(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إغلاق'),
      ),
    ],
  );
  Widget _summary() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      FurnexaInfoSection(
        title: 'البيانات الأساسية',
        items: [
          FurnexaInfoItem(label: 'الاسم', value: widget.product.name),
          FurnexaInfoItem(label: 'الكود', value: widget.product.code),
          FurnexaInfoItem(
            label: 'الحالة',
            value: widget.product.state == ProductState.finished
                ? 'متشطب'
                : 'غير متشطب',
          ),
          FurnexaInfoItem(
            label: 'الوصف',
            value: widget.product.description ?? '-',
          ),
        ],
      ),
    ],
  );
  Widget _variantsView() => _profileList(
    'المتغيرات',
    variants
        .map(
          (v) => ListTile(
            title: Text('${v.name} • ${v.code}'),
            subtitle: Text(
              widget.colors.where((c) => c.id == v.colorId).firstOrNull?.name ??
                  'بدون لون',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _variantForm(v),
                ),
                IconButton(
                  icon: Icon(v.active ? Icons.toggle_on : Icons.toggle_off),
                  onPressed: () async {
                    await widget.repository.setActive(
                      'product_variants',
                      v.id,
                      !v.active,
                    );
                    await _load();
                  },
                ),
              ],
            ),
          ),
        )
        .toList(),
    () => _variantForm(),
  );
  Future<void> _variantForm([ProductVariant? current]) async {
    final v = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ItemForm(
        title: current == null ? 'متغير جديد' : 'تعديل المتغير',
        fields: [
          ('name', 'اسم المتغير', current?.name),
          ('code', 'الكود', current?.code),
          ('description', 'الوصف', current?.description),
        ],
        selects: [
          _SelectData(
            'colorId',
            'اللون (اختياري)',
            {
              for (final x in widget.colors.where(
                (x) => x.active || x.id == current?.colorId,
              ))
                x.id: x.name,
            },
            current?.colorId,
            required: false,
          ),
        ],
      ),
    );
    if (v == null) return;
    try {
      final now = DateTime.now();
      await widget.repository.saveVariant(
        ProductVariant(
          id: current?.id ?? _id('variant'),
          productId: widget.product.id,
          name: v['name']!,
          code: v['code']!,
          colorId: v['colorId'],
          description: v['description'],
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      await _load();
      await widget.onSaved();
    } catch (_) {}
  }

  Widget _alternativesView() => _profileList(
    'البدائل',
    alternatives
        .map(
          (alternative) => ListTile(
            title: Text(
              '${alternative.target.product.name} • ${alternative.target.product.code}',
            ),
            subtitle: Text(
              '${alternative.target.categoryName} • ${_stateLabel(alternative.target.product.state)}'
              '${alternative.target.colorNames == null ? '' : ' • ${alternative.target.colorNames}'}'
              '${alternative.target.product.active ? '' : ' • غير نشط'}',
            ),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 92,
                  child: DropdownButton<int>(
                    value: alternative.priority,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (
                        var priority = 1;
                        priority <= alternatives.length;
                        priority++
                      )
                        DropdownMenuItem(
                          value: priority,
                          child: Text('الأولوية $priority'),
                        ),
                    ],
                    onChanged:
                        widget.canEdit &&
                            widget.product.active &&
                            alternative.target.product.active
                        ? (priority) {
                            if (priority != null) {
                              _updateAlternativePriority(alternative, priority);
                            }
                          }
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'إزالة البديل',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.canEdit
                      ? () => _confirmRemoveAlternative(alternative)
                      : null,
                ),
              ],
            ),
          ),
        )
        .toList(),
    widget.canEdit && widget.product.active ? _addAlternative : null,
  );

  Future<void> _addAlternative() async {
    final selection = await showDialog<_AlternativeSelection>(
      context: context,
      builder: (_) => _ProductAlternativePickerDialog(
        repository: widget.repository,
        sourceProduct: widget.product,
        initialPriority: alternatives.length + 1,
      ),
    );
    if (selection == null) return;
    try {
      await widget.repository.addAlternative(
        widget.product.id,
        selection.targetProductId,
        selection.priority,
      );
      await _load();
      await widget.onSaved();
    } catch (error) {
      if (mounted) _showAlternativeMessage(error.toString());
    }
  }

  Future<void> _updateAlternativePriority(
    ProductAlternative alternative,
    int priority,
  ) async {
    try {
      await widget.repository.updateAlternativePriority(
        alternative.id,
        priority,
      );
      await _load();
      await widget.onSaved();
    } catch (error) {
      if (mounted) _showAlternativeMessage(error.toString());
    }
  }

  Future<void> _confirmRemoveAlternative(ProductAlternative alternative) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إزالة البديل'),
        content: Text(
          'هل تريد إزالة ${alternative.target.product.name} من بدائل هذا المنتج؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.removeAlternative(alternative.id);
      await _load();
      await widget.onSaved();
    } catch (error) {
      if (mounted) _showAlternativeMessage(error.toString());
    }
  }

  void _showAlternativeMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.replaceFirst('Exception: ', ''))),
      );

  String _stateLabel(ProductState state) =>
      state == ProductState.finished ? 'متشطب' : 'غير متشطب';

  Widget _dimensionsView() => _profileList(
    'الأبعاد',
    dimensions
        .map(
          (d) => ListTile(
            title: Text(
              'الطول: ${d.length ?? '-'} | العرض: ${d.width ?? '-'} | الارتفاع: ${d.height ?? '-'}',
            ),
            subtitle: Text(d.unit ?? 'بدون وحدة'),
          ),
        )
        .toList(),
    () async {
      final v = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => _ItemForm(
          title: 'الأبعاد',
          fields: [
            ('length', 'الطول', null),
            ('width', 'العرض', null),
            ('height', 'الارتفاع', null),
            ('unit', 'وحدة القياس', null),
          ],
          selects: const [],
          optionalFields: const {'length', 'width', 'height', 'unit'},
        ),
      );
      if (v == null) return;
      try {
        await widget.repository.saveDimensions(
          ProductDimension(
            id: dimensions.firstOrNull?.id ?? _id('dimension'),
            productId: widget.product.id,
            length: double.tryParse(v['length'] ?? ''),
            width: double.tryParse(v['width'] ?? ''),
            height: double.tryParse(v['height'] ?? ''),
            unit: v['unit'],
          ),
        );
        await _load();
      } catch (_) {}
    },
  );
  Widget _bomView() => _profileList(
    'مكونات المنتج',
    bom.map((b) {
      final material = widget.materials
          .where((m) => m.id == b.rawMaterialId)
          .firstOrNull;
      final unit = widget.units
          .where((u) => u.id == material?.unitId)
          .firstOrNull;
      return ListTile(
        title: Text(
          '${material?.name ?? '-'} • ${b.quantity} ${unit?.name ?? ''}',
        ),
        subtitle: Text(b.notes ?? ''),
        trailing: Wrap(
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _bomForm(b),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await widget.repository.deleteBomItem(b.id);
                await _load();
              },
            ),
          ],
        ),
      );
    }).toList(),
    () => _bomForm(),
  );
  Future<void> _bomForm([BomItem? current]) async {
    final v = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ItemForm(
        title: current == null ? 'مكون جديد' : 'تعديل المكون',
        fields: [
          ('quantity', 'الكمية', current?.quantity.toString()),
          ('notes', 'الملاحظات', current?.notes),
        ],
        selects: [
          _SelectData('rawMaterialId', 'الخامة', {
            for (final x in widget.materials.where(
              (x) => x.active || x.id == current?.rawMaterialId,
            ))
              x.id: x.name,
          }, current?.rawMaterialId),
        ],
      ),
    );
    if (v == null) return;
    try {
      await widget.repository.saveBomItem(
        BomItem(
          id: current?.id ?? _id('bom'),
          productId: widget.product.id,
          rawMaterialId: v['rawMaterialId']!,
          quantity: double.parse(v['quantity']!),
          notes: v['notes'],
        ),
      );
      await _load();
    } catch (_) {}
  }

  Widget _profileList(String title, List<Widget> children, VoidCallback? add) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: Text('إضافة $title'),
            ),
          ),
          Expanded(
            child: children.isEmpty
                ? Center(child: Text('لا توجد $title بعد'))
                : ListView(children: children),
          ),
        ],
      );
}

typedef _AlternativeSelection = ({String targetProductId, int priority});

class _ProductAlternativePickerDialog extends StatefulWidget {
  const _ProductAlternativePickerDialog({
    required this.repository,
    required this.sourceProduct,
    required this.initialPriority,
  });

  final RawMaterialsProductsRepository repository;
  final Product sourceProduct;
  final int initialPriority;

  @override
  State<_ProductAlternativePickerDialog> createState() =>
      _ProductAlternativePickerDialogState();
}

class _ProductAlternativePickerDialogState
    extends State<_ProductAlternativePickerDialog> {
  final _searchController = TextEditingController();
  List<ProductAlternativeCandidate> _candidates = [];
  String? _selectedProductId;
  late int _priority = widget.initialPriority;
  int _requestId = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCandidates('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final candidates = await widget.repository
          .getEligibleAlternativeCandidates(widget.sourceProduct.id, query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _candidates = candidates;
        _loading = false;
        if (_selectedProductId != null &&
            !candidates.any(
              (candidate) => candidate.product.id == _selectedProductId,
            )) {
          _selectedProductId = null;
        }
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('اختيار منتج بديل'),
    content: SizedBox(
      width: 560,
      height: 440,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'ابحث عن منتج بديل...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _loadCandidates,
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!)))
          else if (_candidates.isEmpty)
            const Expanded(
              child: Center(
                child: Text('لا توجد منتجات بديلة نشطة في تصنيف هذا المنتج.'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _candidates.length,
                itemBuilder: (context, index) {
                  final candidate = _candidates[index];
                  final selected = candidate.product.id == _selectedProductId;
                  final colors = candidate.colorNames;
                  return ListTile(
                    selected: selected,
                    onTap: () => setState(
                      () => _selectedProductId = candidate.product.id,
                    ),
                    title: Text(
                      '${candidate.product.name} • ${candidate.product.code}',
                    ),
                    subtitle: Text(
                      '${candidate.categoryName} • ${_productStateLabel(candidate.product.state)}'
                      '${colors == null ? '' : ' • $colors'}',
                    ),
                    trailing: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'الأولوية'),
            items: [
              for (
                var priority = 1;
                priority <= widget.initialPriority;
                priority++
              )
                DropdownMenuItem(value: priority, child: Text('$priority')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _priority = value);
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
        onPressed: _selectedProductId == null
            ? null
            : () => Navigator.pop(context, (
                targetProductId: _selectedProductId!,
                priority: _priority,
              )),
        child: const Text('إضافة البديل'),
      ),
    ],
  );
}

String _productStateLabel(ProductState state) =>
    state == ProductState.finished ? 'متشطب' : 'غير متشطب';
