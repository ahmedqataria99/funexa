import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/core/shared/ui/error_state.dart';
import 'package:furnexa/core/shared/ui/loading_state.dart';
import 'package:furnexa/core/shared/widgets/furnexa_form.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/features/factory_structure/data/repositories/factory_structure_repository_impl.dart';
import 'package:furnexa/features/factory_structure/domain/entities/factory_profile.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/section.dart';
import 'package:furnexa/features/factory_structure/domain/entities/warehouse.dart';
import 'package:furnexa/features/factory_structure/domain/entities/workshop.dart';
import 'package:furnexa/features/factory_structure/domain/repositories/factory_structure_repository.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class FactoryStructurePage extends StatefulWidget {
  const FactoryStructurePage({
    super.key,
    this.security,
    this.initialSelectedId,
  });

  final SecurityLocalDataSource? security;
  final String? initialSelectedId;

  @override
  State<FactoryStructurePage> createState() => _FactoryStructurePageState();
}

class _FactoryStructurePageState extends State<FactoryStructurePage> {
  final FactoryStructureRepository _repository =
      FactoryStructureRepositoryImpl();
  bool _loading = true;
  bool _saving = false;
  bool _error = false;
  FactoryProfile? _factory;
  List<Section> _sections = [];
  List<Workshop> _workshops = [];
  List<ProductionStage> _stages = [];
  List<Warehouse> _warehouses = [];
  String _sectionQuery = '';
  String _workshopQuery = '';
  String _stageQuery = '';
  String _warehouseQuery = '';
  String _workshopSection = '';
  final _sectionsScrollController = ScrollController();
  final _workshopsScrollController = ScrollController();
  final _stagesScrollController = ScrollController();
  final _warehousesScrollController = ScrollController();

  bool get _canEditFactory => widget.security?.can('FACTORY_EDIT') ?? false;
  bool get _canEditWarehouse =>
      widget.security?.can('WAREHOUSE_STOCK_EDIT') ?? false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _sectionsScrollController.dispose();
    _workshopsScrollController.dispose();
    _stagesScrollController.dispose();
    _warehousesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      final factory = await _repository.getFactory();
      final sections = await _repository.searchSections(_sectionQuery);
      final workshops = await _repository.searchWorkshops(_workshopQuery);
      final stages = await _repository.searchProductionStages(_stageQuery);
      final warehouses = await _repository.searchWarehouses(_warehouseQuery);
      if (!mounted) return;
      setState(() {
        _factory = factory;
        _sections = sections;
        _workshops = workshops;
        _stages = stages;
        _warehouses = warehouses;
      });
      await FurnexaDatabaseDiagnostics.capture(
        source: 'page.factoryStructure.stateCommitted',
        factoryWarehouseRepositoryRows: warehouses.length,
        stageCounts: {
          'viewModelWarehouseRows': warehouses.length,
          'viewModelSectionRows': sections.length,
          'viewModelWorkshopRows': workshops.length,
          'viewModelStageRows': stages.length,
          'factoryContextId': factory?.id,
          'committedToState': true,
        },
      );
    } catch (error, stackTrace) {
      await FurnexaDatabaseDiagnostics.reportFailure(
        source: 'page.factoryStructure.load',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editFactory() async {
    final current = _factory;
    final values = await _form(
      title: current == null ? 'إعداد بيانات المصنع' : 'تعديل بيانات المصنع',
      fields: [
        _Field('name', 'اسم المصنع', current?.name),
        _Field('code', 'كود المصنع', current?.code),
        _Field(
          'phone',
          'الهاتف',
          current?.phone,
          keyboardType: TextInputType.phone,
        ),
        _Field(
          'email',
          'البريد الإلكتروني',
          current?.email,
          keyboardType: TextInputType.emailAddress,
        ),
        _Field(
          'address',
          'العنوان',
          current?.address,
          maxLines: 2,
          optional: true,
        ),
      ],
    );
    if (values == null) return;
    final now = DateTime.now();
    final saved = await _save(
      () => _repository.saveFactory(
        FactoryProfile(
          id: current?.id ?? _id('factory'),
          name: values['name']!,
          code: values['code']!,
          phone: _optional(values['phone']),
          email: _optional(values['email']),
          address: _optional(values['address']),
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
    if (saved) await _saved('تم حفظ بيانات المصنع بنجاح');
  }

  Future<void> _editSection([Section? current]) async {
    final values = await _form(
      title: current == null ? 'إضافة قسم' : 'تعديل القسم',
      fields: [
        _Field('name', 'اسم القسم', current?.name),
        _Field('code', 'كود القسم', current?.code),
        _Field(
          'description',
          'الوصف',
          current?.description,
          maxLines: 2,
          optional: true,
        ),
      ],
    );
    if (values == null) return;
    final factoryId = _factory?.id;
    if (factoryId == null) {
      return _errorMessage('يجب إعداد بيانات المصنع أولاً');
    }
    final now = DateTime.now();
    final saved = await _save(
      () => _repository.saveSection(
        Section(
          id: current?.id ?? _id('section'),
          factoryId: factoryId,
          name: values['name']!,
          code: values['code']!,
          description: _optional(values['description']),
          active: current?.active ?? true,
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
    if (saved) await _saved('تم حفظ القسم بنجاح');
  }

  Future<void> _editWorkshop([Workshop? current]) async {
    final activeSections = _sections
        .where((section) => section.active)
        .toList();
    if (activeSections.isEmpty) {
      return _errorMessage('أضف قسماً نشطاً قبل إنشاء ورشة');
    }
    final values = await _form(
      title: current == null ? 'إضافة ورشة' : 'تعديل الورشة',
      fields: [
        _Field('name', 'اسم الورشة', current?.name),
        _Field('code', 'كود الورشة', current?.code),
        _Field(
          'description',
          'الوصف',
          current?.description,
          maxLines: 2,
          optional: true,
        ),
      ],
      select: _Select(
        'sectionId',
        'القسم',
        {
          for (final section in activeSections)
            section.id: '${section.name} (${section.code})',
        },
        current?.sectionId,
        required: true,
      ),
    );
    if (values == null) return;
    final section = _section(values['sectionId']);
    if (section == null || !section.active) {
      return _errorMessage('اختر قسماً نشطاً صالحاً');
    }
    final now = DateTime.now();
    final saved = await _save(
      () => _repository.saveWorkshop(
        Workshop(
          id: current?.id ?? _id('workshop'),
          factoryId: section.factoryId,
          sectionId: section.id,
          name: values['name']!,
          code: values['code']!,
          description: _optional(values['description']),
          active: current?.active ?? true,
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
    if (saved) await _saved('تم حفظ الورشة بنجاح');
  }

  Future<void> _editStage([ProductionStage? current]) async {
    final values = await _form(
      title: current == null ? 'إضافة مرحلة' : 'تعديل المرحلة',
      fields: [
        _Field('name', 'اسم المرحلة', current?.name),
        _Field('code', 'كود المرحلة', current?.code),
        _Field(
          'sequence',
          'الترتيب',
          current?.sequence.toString(),
          keyboardType: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        _Field(
          'description',
          'الوصف',
          current?.description,
          maxLines: 2,
          optional: true,
        ),
      ],
    );
    if (values == null) return;
    final sequence = int.tryParse(values['sequence'] ?? '');
    if (sequence == null || sequence <= 0) {
      return _errorMessage('الترتيب يجب أن يكون رقماً صحيحاً موجباً');
    }
    final factoryId = _factory?.id;
    if (factoryId == null) {
      return _errorMessage('يجب إعداد بيانات المصنع أولاً');
    }
    final now = DateTime.now();
    final saved = await _save(
      () => _repository.saveProductionStage(
        ProductionStage(
          id: current?.id ?? _id('stage'),
          factoryId: factoryId,
          name: values['name']!,
          code: values['code']!,
          description: _optional(values['description']),
          sequence: sequence,
          active: current?.active ?? true,
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
    if (saved) await _saved('تم حفظ مرحلة الإنتاج بنجاح');
  }

  Future<void> _editWarehouse([Warehouse? current]) async {
    final values = await _form(
      title: current == null ? 'إضافة مخزن' : 'تعديل المخزن',
      fields: [
        _Field('name', 'اسم المخزن', current?.name),
        _Field('code', 'كود المخزن', current?.code),
        _Field('type', 'النوع (اختياري)', current?.type, optional: true),
        _Field(
          'notes',
          'الملاحظات',
          current?.notes,
          maxLines: 2,
          optional: true,
        ),
      ],
      select: _Select('state', 'الحالة', const {
        'active': 'نشط',
        'inactive': 'غير نشط',
      }, current?.state ?? 'active'),
    );
    if (values == null) return;
    final factoryId = _factory?.id;
    if (factoryId == null) {
      return _errorMessage('يجب إعداد بيانات المصنع أولاً');
    }
    final now = DateTime.now();
    final saved = await _save(
      () => _repository.saveWarehouse(
        Warehouse(
          id: current?.id ?? _id('warehouse'),
          factoryId: factoryId,
          name: values['name']!,
          code: values['code']!,
          type: _optional(values['type']),
          state: values['state'] ?? 'active',
          notes: _optional(values['notes']),
          createdAt: current?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
    if (saved) await _saved('تم حفظ المخزن بنجاح');
  }

  Future<void> _toggleSection(Section value) async {
    if (await _save(
      () => _repository.saveSection(
        value.copyWith(active: !value.active, updatedAt: DateTime.now()),
      ),
    )) {
      await _loadData();
    }
  }

  Future<void> _toggleWorkshop(Workshop value) async {
    if (await _save(
      () => _repository.saveWorkshop(
        value.copyWith(active: !value.active, updatedAt: DateTime.now()),
      ),
    )) {
      await _loadData();
    }
  }

  Future<void> _toggleStage(ProductionStage value) async {
    if (await _save(
      () => _repository.saveProductionStage(
        value.copyWith(active: !value.active, updatedAt: DateTime.now()),
      ),
    )) {
      await _loadData();
    }
  }

  Future<void> _toggleWarehouse(Warehouse value) async {
    final state = value.state == 'active' ? 'inactive' : 'active';
    if (await _save(
      () => _repository.saveWarehouse(
        value.copyWith(state: state, updatedAt: DateTime.now()),
      ),
    )) {
      await _loadData();
    }
  }

  Future<bool> _save(Future<void> Function() action) async {
    if (mounted) setState(() => _saving = true);
    try {
      await action();
      return true;
    } catch (error) {
      final text = error.toString().toLowerCase();
      _errorMessage(
        text.contains('unique') || text.contains('code')
            ? 'هذا الكود مستخدم مسبقاً، اختر كوداً آخر'
            : 'تعذر حفظ البيانات، حاول مرة أخرى',
      );
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saved(String message) async {
    _success(message);
    await _loadData();
  }

  Future<Map<String, String>?> _form({
    required String title,
    required List<_Field> fields,
    _Select? select,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EntityForm(title: title, fields: fields, select: select),
    );
  }

  Section? _section(String? id) =>
      _sections.where((value) => value.id == id).isEmpty
      ? null
      : _sections.firstWhere((value) => value.id == id);
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  String? _optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
  void _success(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppTheme.success),
  );
  void _errorMessage(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.error),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Furnexa ERP')),
      body: Stack(
        children: [
          _loading
              ? const LoadingState(message: 'جارٍ تحميل هيكل المصنع...')
              : _error
              ? const ErrorState(message: 'حدث خطأ أثناء تحميل هيكل المصنع.')
              : SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Furnexa',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _panel(
                            'بيانات المصنع',
                            _factory == null ? 'إعداد بيانات المصنع' : 'تعديل',
                            _canEditFactory ? _editFactory : null,
                            _factory == null
                                ? const Text(
                                    'لم يتم إعداد المصنع بعد. أدخل بيانات المصنع للبدء.',
                                  )
                                : Wrap(
                                    spacing: 24,
                                    runSpacing: 8,
                                    children: [
                                      Text('الاسم: ${_factory!.name}'),
                                      Text('الكود: ${_factory!.code}'),
                                      Text('الهاتف: ${_factory!.phone ?? '-'}'),
                                      Text('البريد: ${_factory!.email ?? '-'}'),
                                      Text(
                                        'العنوان: ${_factory!.address ?? '-'}',
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: constraints.maxWidth >= 1100
                                ? 2
                                : 1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: constraints.maxWidth >= 1100
                                ? 2.2
                                : 1.7,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _sectionsPanel(),
                              _workshopsPanel(),
                              _stagesPanel(),
                              _warehousesPanel(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          if (_saving)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('جارٍ الحفظ...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionsPanel() => _panel(
    'الأقسام',
    'إضافة قسم',
    _factory == null || !_canEditFactory ? null : () => _editSection(),
    _sections.isEmpty
        ? const Text('لا توجد أقسام. أضف أول قسم إلى هيكل المصنع.')
        : Column(
            children: _sections
                .map(
                  (value) => _record(
                    value.id,
                    value.name,
                    '${value.code}${value.description == null ? '' : ' • ${value.description}'}',
                    value.active,
                    () => _editSection(value),
                    () => _toggleSection(value),
                  ),
                )
                .toList(),
          ),
    search: 'بحث في الأقسام',
    scrollController: _sectionsScrollController,
    onSearch: (value) {
      _sectionQuery = value;
      _loadData();
    },
  );

  Widget _workshopsPanel() {
    final visible = _workshops
        .where(
          (value) =>
              _workshopSection.isEmpty || value.sectionId == _workshopSection,
        )
        .toList();
    return _panel(
      'الورش',
      'إضافة ورشة',
      _factory == null || !_canEditFactory ? null : () => _editWorkshop(),
      visible.isEmpty
          ? const Text('لا توجد ورش. أضف ورشة واربطها بقسم نشط.')
          : Column(
              children: visible.map((value) {
                final section = _section(value.sectionId);
                return _record(
                  value.id,
                  value.name,
                  '${value.code} • ${section?.name ?? 'قسم غير معروف'}',
                  value.active,
                  () => _editWorkshop(value),
                  () => _toggleWorkshop(value),
                );
              }).toList(),
            ),
      search: 'بحث في الورش',
      scrollController: _workshopsScrollController,
      onSearch: (value) {
        _workshopQuery = value;
        _loadData();
      },
      filter: DropdownButton<String>(
        value: _workshopSection,
        underline: const SizedBox.shrink(),
        items: [
          const DropdownMenuItem(value: '', child: Text('كل الأقسام')),
          ..._sections.map(
            (value) =>
                DropdownMenuItem(value: value.id, child: Text(value.name)),
          ),
        ],
        onChanged: (value) => setState(() => _workshopSection = value ?? ''),
      ),
    );
  }

  Widget _stagesPanel() => _panel(
    'مراحل الإنتاج',
    'إضافة مرحلة',
    _factory == null || !_canEditFactory ? null : () => _editStage(),
    _stages.isEmpty
        ? const Text('لا توجد مراحل إنتاج. أضف مراحل مرتبة لمسار المصنع.')
        : Column(
            children: _stages
                .map(
                  (value) => _record(
                    value.id,
                    value.name,
                    '${value.code} • الترتيب ${value.sequence}',
                    value.active,
                    () => _editStage(value),
                    () => _toggleStage(value),
                  ),
                )
                .toList(),
          ),
    search: 'بحث في المراحل',
    scrollController: _stagesScrollController,
    onSearch: (value) {
      _stageQuery = value;
      _loadData();
    },
  );

  Widget _warehousesPanel() => _panel(
    'المخازن',
    'إضافة مخزن',
    _factory == null || !_canEditWarehouse ? null : () => _editWarehouse(),
    _warehouses.isEmpty
        ? const Text('لا توجد مخازن. أضف مخزناً لتجهيز هيكل المصنع.')
        : Column(
            children: _warehouses
                .map(
                  (value) => _record(
                    value.id,
                    value.name,
                    '${value.code} • ${value.type ?? 'بدون نوع'}',
                    value.state == 'active',
                    _canEditWarehouse ? () => _editWarehouse(value) : null,
                    _canEditWarehouse ? () => _toggleWarehouse(value) : null,
                    canEdit: _canEditWarehouse,
                  ),
                )
                .toList(),
          ),
    search: 'بحث في المخازن',
    scrollController: _warehousesScrollController,
    onSearch: (value) {
      _warehouseQuery = value;
      _loadData();
    },
  );

  Widget _panel(
    String title,
    String action,
    VoidCallback? onAction,
    Widget child, {
    String? search,
    ValueChanged<String>? onSearch,
    Widget? filter,
    ScrollController? scrollController,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(action),
              ),
            ],
          ),
          if (search != null || filter != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (search != null)
                  SizedBox(
                    width: 230,
                    child: TextField(
                      onChanged: onSearch,
                      decoration: InputDecoration(
                        hintText: search,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ?filter,
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (scrollController == null)
            child
          else
            Expanded(
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: child,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _record(
    String id,
    String title,
    String subtitle,
    bool active,
    VoidCallback? edit,
    VoidCallback? toggle, {
    bool? canEdit,
  }) {
    final editable = canEdit ?? _canEditFactory;
    final color = active
        ? AppTheme.success
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      selected: id == widget.initialSelectedId,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      leading: Chip(
        label: Text(active ? 'نشط' : 'غير نشط'),
        backgroundColor: color.withAlpha(28),
        side: BorderSide(color: color),
      ),
      trailing: Wrap(
        spacing: 0,
        children: [
          IconButton(
            tooltip: 'تعديل',
            onPressed: editable ? edit : null,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: active ? 'تعطيل' : 'تفعيل',
            onPressed: editable ? toggle : null,
            icon: Icon(active ? Icons.toggle_on : Icons.toggle_off),
          ),
        ],
      ),
    );
  }
}

class _Field {
  const _Field(
    this.key,
    this.label,
    this.initial, {
    this.keyboardType,
    this.formatters,
    this.maxLines = 1,
    this.optional = false,
  });
  final String key;
  final String label;
  final String? initial;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final int maxLines;
  final bool optional;
}

class _Select {
  const _Select(
    this.key,
    this.label,
    this.items,
    this.value, {
    this.required = false,
  });
  final String key;
  final String label;
  final Map<String, String> items;
  final String? value;
  final bool required;
}

class _EntityForm extends StatefulWidget {
  const _EntityForm({required this.title, required this.fields, this.select});
  final String title;
  final List<_Field> fields;
  final _Select? select;

  @override
  State<_EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<_EntityForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  String? _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.select?.value;
    for (final field in widget.fields) {
      _controllers[field.key] = TextEditingController(
        text: field.initial ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final values = <String, String>{
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    if (widget.select != null && _selection != null) {
      values[widget.select!.key] = _selection!;
    }
    Navigator.of(context).pop(values);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 760,
        child: FurnexaFormShell(
          formKey: _formKey,
          cancelLabel: 'إلغاء',
          saveLabel: 'حفظ',
          onCancel: () => Navigator.of(context).pop(),
          onSave: _submit,
          sections: [
            FurnexaFormSection(
              title: widget.title,
              children: [
                ...widget.fields.map(
                  (field) => TextFormField(
                    controller: _controllers[field.key],
                    autofocus: field == widget.fields.first,
                    keyboardType: field.keyboardType,
                    inputFormatters: field.formatters,
                    maxLines: field.maxLines,
                    decoration: InputDecoration(
                      labelText: field.optional
                          ? field.label
                          : '${field.label} *',
                    ),
                    validator: field.optional
                        ? null
                        : (value) => value == null || value.trim().isEmpty
                              ? 'هذا الحقل مطلوب'
                              : null,
                  ),
                ),
                if (widget.select != null)
                  DropdownButtonFormField<String>(
                    initialValue: _selection,
                    decoration: InputDecoration(
                      labelText: widget.select!.required
                          ? '${widget.select!.label} *'
                          : widget.select!.label,
                    ),
                    items: widget.select!.items.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selection = value),
                    validator: widget.select!.required
                        ? (value) => value == null ? 'هذا الحقل مطلوب' : null
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
