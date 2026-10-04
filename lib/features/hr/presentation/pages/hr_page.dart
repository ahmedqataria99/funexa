import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_form.dart';
import 'package:furnexa/features/factory_structure/data/repositories/factory_structure_repository_impl.dart';
import 'package:furnexa/features/factory_structure/domain/entities/production_stage.dart';
import 'package:furnexa/features/factory_structure/domain/entities/section.dart';
import 'package:furnexa/features/factory_structure/domain/entities/workshop.dart';
import 'package:furnexa/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:furnexa/features/hr/domain/entities/hr_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class HrPage extends StatefulWidget {
  const HrPage({super.key, required this.security, this.initialWorkerId});

  final SecurityLocalDataSource security;
  final String? initialWorkerId;

  @override
  State<HrPage> createState() => _HrPageState();
}

class _HrPageState extends State<HrPage> {
  final HrRepositoryImpl repository = HrRepositoryImpl();
  final FactoryStructureRepositoryImpl factoryRepository =
      FactoryStructureRepositoryImpl();
  bool loading = true;
  List<Worker> workers = [];
  List<Shift> shifts = [];
  List<Section> sections = [];
  List<Workshop> workshops = [];
  List<ProductionStage> stages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        repository.workers(),
        repository.shifts(),
        factoryRepository.getSections(),
        factoryRepository.getWorkshops(),
        factoryRepository.getProductionStages(),
      ]);
      if (!mounted) return;
      setState(() {
        workers = results[0] as List<Worker>;
        shifts = results[1] as List<Shift>;
        sections = results[2] as List<Section>;
        workshops = results[3] as List<Workshop>;
        stages = results[4] as List<ProductionStage>;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _addWorker() async {
    if (!widget.security.can('HR_EDIT')) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _WorkerForm(
        repository: repository,
        sections: sections,
        workshops: workshops,
        stages: stages,
      ),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموارد البشرية'),
        actions: [
          if (widget.security.can('HR_EDIT'))
            FilledButton.icon(
              onPressed: _addWorker,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('إضافة عامل'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statCard('إجمالي العاملين', workers.length.toString()),
                      _statCard('الحاضرون', _count(AttendanceStatus.present)),
                      _statCard('الغياب', _count(AttendanceStatus.absent)),
                      _statCard('الإجازات', _count(AttendanceStatus.leave)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          const Text(
                            'العاملون',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...workers.map(
                            (worker) => ListTile(
                              selected: worker.id == widget.initialWorkerId,
                              title: Text(worker.name),
                              subtitle: Text(
                                '${worker.employeeCode} • ${worker.sectionId != null ? 'قسم' : 'بدون قسم'} • ${worker.basicSalary}',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  Text(worker.active ? 'نشط' : 'غير نشط'),
                                  if (widget.security.can('HR_EDIT'))
                                    IconButton(
                                      tooltip: 'تعطيل العامل',
                                      onPressed: worker.active
                                          ? () async {
                                              await repository.deactivateWorker(
                                                worker.id,
                                              );
                                              await _load();
                                            }
                                          : null,
                                      icon: const Icon(
                                        Icons.pause_circle_outline,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (workers.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('لا توجد بيانات للموظفين بعد.'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _count(AttendanceStatus status) {
    return workers.length.toString();
  }

  Widget _statCard(String title, String value) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerForm extends StatefulWidget {
  const _WorkerForm({
    required this.repository,
    required this.sections,
    required this.workshops,
    required this.stages,
  });

  final HrRepositoryImpl repository;
  final List<Section> sections;
  final List<Workshop> workshops;
  final List<ProductionStage> stages;

  @override
  State<_WorkerForm> createState() => _WorkerFormState();
}

class _WorkerFormState extends State<_WorkerForm> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _salary = TextEditingController();
  final _overtime = TextEditingController();
  final _notes = TextEditingController();
  DateTime _hireDate = DateTime.now();
  String? _sectionId;
  String? _workshopId;
  String? _stageId;
  SalaryType _salaryType = SalaryType.monthly;
  bool _active = true;
  bool _overtimeEnabled = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _phone,
      _email,
      _address,
      _salary,
      _overtime,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createWorker(
        employeeCode: _code.text,
        name: _name.text,
        phone: _phone.text,
        email: _email.text,
        address: _address.text,
        hireDate: _hireDate,
        sectionId: _sectionId,
        workshopId: _workshopId,
        productionStageId: _stageId,
        active: _active,
        basicSalary: double.parse(_salary.text),
        salaryType: _salaryType,
        overtimeEnabled: _overtimeEnabled,
        overtimeRateOverride: _overtime.text.trim().isEmpty
            ? null
            : double.parse(_overtime.text),
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = error.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableWorkshops = widget.workshops
        .where(
          (workshop) => workshop.sectionId == _sectionId && workshop.active,
        )
        .toList();
    return AlertDialog(
      title: const Text('إضافة عامل'),
      content: SizedBox(
        width: 760,
        child: FurnexaFormShell(
          formKey: _formKey,
          title: 'بيانات العامل',
          cancelLabel: 'إلغاء',
          saveLabel: 'حفظ',
          onCancel: () => Navigator.pop(context),
          onSave: _save,
          saveLoading: _saving,
          sections: [
            FurnexaFormSection(
              title: 'البيانات الأساسية',
              children: [
                _field(_code, 'كود الموظف', required: true),
                _field(_name, 'الاسم', required: true),
                _field(_phone, 'الهاتف'),
                _field(_email, 'البريد الإلكتروني'),
                _field(_address, 'العنوان'),
                TextFormField(
                  readOnly: true,
                  controller: TextEditingController(
                    text:
                        '${_hireDate.year}/${_hireDate.month}/${_hireDate.day}',
                  ),
                  decoration: const InputDecoration(labelText: 'تاريخ التعيين'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: _hireDate,
                    );
                    if (date != null) setState(() => _hireDate = date);
                  },
                ),
              ],
            ),
            FurnexaFormSection(
              title: 'التعيين والراتب',
              children: [
                DropdownButtonFormField<String>(
                  value: _sectionId,
                  decoration: const InputDecoration(labelText: 'القسم'),
                  items: widget.sections
                      .where((item) => item.active)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _sectionId = value;
                    _workshopId = null;
                  }),
                ),
                DropdownButtonFormField<String>(
                  value: _workshopId,
                  decoration: const InputDecoration(labelText: 'الورشة'),
                  items: availableWorkshops
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: _sectionId == null
                      ? null
                      : (value) => setState(() => _workshopId = value),
                ),
                DropdownButtonFormField<String>(
                  value: _stageId,
                  decoration: const InputDecoration(
                    labelText: 'مرحلة الإنتاج الأساسية',
                  ),
                  items: widget.stages
                      .where((item) => item.active)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _stageId = value),
                ),
                _field(_salary, 'الراتب الأساسي', required: true, number: true),
                DropdownButtonFormField<SalaryType>(
                  value: _salaryType,
                  decoration: const InputDecoration(labelText: 'نوع الراتب'),
                  items: SalaryType.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _salaryType = value!),
                ),
                SwitchListTile(
                  title: const Text('نشط'),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                ),
                SwitchListTile(
                  title: const Text('الساعات الإضافية'),
                  value: _overtimeEnabled,
                  onChanged: (value) =>
                      setState(() => _overtimeEnabled = value),
                ),
                _field(_overtime, 'سعر الإضافي', number: true),
                _field(_notes, 'ملاحظات'),
              ],
            ),
            if (_error != null)
              FurnexaFormSection(
                title: 'خطأ',
                children: [
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  TextFormField _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty))
          return 'هذا الحقل مطلوب';
        if (number &&
            value != null &&
            value.trim().isNotEmpty &&
            double.tryParse(value) == null)
          return 'أدخل قيمة صحيحة';
        if (controller == _salary &&
            value != null &&
            double.tryParse(value) != null &&
            double.parse(value) < 0)
          return 'القيمة لا يمكن أن تكون سالبة';
        if (controller == _overtime &&
            value != null &&
            value.trim().isNotEmpty &&
            double.tryParse(value) != null &&
            double.parse(value) <= 0)
          return 'يجب أن تكون القيمة أكبر من صفر';
        return null;
      },
    );
  }
}
