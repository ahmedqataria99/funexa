import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_form.dart';
import 'package:furnexa/core/shared/widgets/furnexa_states.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class UsersRolesPage extends StatefulWidget {
  const UsersRolesPage({
    super.key,
    required this.security,
    required this.onLogout,
  });

  final SecurityLocalDataSource security;
  final VoidCallback onLogout;

  @override
  State<UsersRolesPage> createState() => _UsersRolesPageState();
}

class _UsersRolesPageState extends State<UsersRolesPage> {
  bool _loading = true;
  String? _error;
  List<SecurityUser> _users = [];
  List<SecurityRole> _roles = [];
  List<AuditLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await widget.security.users();
      final roles = await widget.security.roles();
      final logs = widget.security.can('AUDIT_VIEW')
          ? await widget.security.auditLogs()
          : <AuditLog>[];
      if (!mounted) return;
      setState(() {
        _users = users;
        _roles = roles;
        _logs = logs;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _openUserForm([SecurityUser? user]) async {
    final roleList = _roles
        .where((role) => role.active || role.id == user?.roleId)
        .toList();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _UserForm(security: widget.security, user: user, roles: roleList),
    );
    if (result == true) await _load();
  }

  Future<void> _openRoleForm([SecurityRole? role]) async {
    if (!widget.security.can('ROLES_EDIT')) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RoleForm(security: widget.security, role: role),
    );
    if (result == true) await _load();
  }

  Future<void> _toggleUser(SecurityUser user) async {
    try {
      await widget.security.setUserActive(user.id, !user.active);
      await _load();
    } catch (error) {
      if (mounted) _message(error.toString());
    }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value.replaceFirst('Exception: ', ''))),
  );

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.security.can('USERS_EDIT');
    return Scaffold(
      appBar: AppBar(
        title: const Text('المستخدمون والصلاحيات'),
        actions: [
          if (canEdit)
            FilledButton.icon(
              onPressed: () => _openUserForm(),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('إضافة مستخدم'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const FurnexaLoading()
          : _error != null
          ? FurnexaErrorState(
              title: 'تعذر تحميل المستخدمين',
              message: _error!,
              onRetry: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(
                      widget.security.session?.user.displayName ?? '',
                    ),
                    subtitle: Text(widget.security.session?.role.name ?? ''),
                    trailing: IconButton(
                      tooltip: 'تسجيل الخروج',
                      icon: const Icon(Icons.logout),
                      onPressed: () {
                        widget.security.logout();
                        widget.onLogout();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'المستخدمون',
                  icon: Icons.people_outline,
                  child: _users.isEmpty
                      ? const FurnexaEmptyState(title: 'لا يوجد مستخدمون')
                      : Column(
                          children: _users.map((user) {
                            final role = _roles
                                .where((item) => item.id == user.roleId)
                                .firstOrNull;
                            final current =
                                user.id == widget.security.session?.user.id;
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(user.displayName.characters.first),
                              ),
                              title: Text(
                                '${user.displayName}${current ? ' (الحساب الحالي)' : ''}',
                              ),
                              subtitle: Text(
                                '@${user.username} • ${role?.name ?? 'دور غير معروف'}',
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  Chip(
                                    label: Text(
                                      user.active ? 'نشط' : 'غير نشط',
                                    ),
                                  ),
                                  if (canEdit) ...[
                                    IconButton(
                                      tooltip: 'تعديل',
                                      onPressed: () => _openUserForm(user),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: user.active ? 'تعطيل' : 'تفعيل',
                                      onPressed: () => _toggleUser(user),
                                      icon: Icon(
                                        user.active
                                            ? Icons.toggle_on
                                            : Icons.toggle_off,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'الأدوار',
                  icon: Icons.admin_panel_settings_outlined,
                  child: Column(
                    children: [
                      if (widget.security.can('ROLES_EDIT'))
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            onPressed: () => _openRoleForm(),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة دور مخصص'),
                          ),
                        ),
                      ..._roles.map(
                        (role) => ListTile(
                          title: Text(role.name),
                          subtitle: Text(
                            role.isSystemRole
                                ? 'دور نظامي'
                                : (role.description ?? 'دور مخصص'),
                          ),
                          trailing: Wrap(
                            children: [
                              Chip(
                                label: Text(role.active ? 'نشط' : 'غير نشط'),
                              ),
                              if (widget.security.can('ROLES_EDIT'))
                                IconButton(
                                  tooltip: 'تعديل الصلاحيات',
                                  onPressed: () => _openRoleForm(role),
                                  icon: const Icon(Icons.tune_outlined),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'سجل التدقيق',
                  icon: Icons.history,
                  child: Column(
                    children: _logs
                        .take(50)
                        .map(
                          (log) => ListTile(
                            dense: true,
                            title: Text('${log.action} • ${log.module}'),
                            subtitle: Text(
                              '${log.usernameSnapshot} • ${log.description ?? ''}',
                            ),
                            trailing: Text(
                              log.timestamp.toString().substring(0, 16),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Card(
    child: ExpansionTile(
      leading: Icon(icon),
      title: Text(title),
      initiallyExpanded: true,
      children: [child],
    ),
  );
}

class _UserForm extends StatefulWidget {
  const _UserForm({required this.security, required this.roles, this.user});

  final SecurityLocalDataSource security;
  final List<SecurityRole> roles;
  final SecurityUser? user;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _key = GlobalKey<FormState>();
  late final _username = TextEditingController(
    text: widget.user?.username ?? '',
  );
  late final _name = TextEditingController(
    text: widget.user?.displayName ?? '',
  );
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _roleId;
  bool _active = true;
  bool _saving = false;
  String? _error;
  final _selectedScopes = <ScopeType, Set<String>>{};
  final _resources = <ScopeType, List<Map<String, Object?>>>{};

  @override
  void initState() {
    super.initState();
    _roleId =
        widget.user?.roleId ??
        (widget.roles.isEmpty ? null : widget.roles.first.id);
    _active = widget.user?.active ?? true;
    _loadScopes();
  }

  Future<void> _loadScopes() async {
    for (final type in ScopeType.values) {
      try {
        _resources[type] = await widget.security.scopeResources(type);
      } catch (_) {}
    }
    if (widget.user != null) {
      try {
        final scopes = await widget.security.userScopes(widget.user!.id);
        for (final scope in scopes) {
          (_selectedScopes[scope.type] ??= {}).add(scope.scopeId);
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      late final SecurityUser saved;
      if (widget.user == null) {
        saved = await widget.security.createUser(
          username: _username.text.trim(),
          displayName: _name.text.trim(),
          password: _password.text,
          roleId: _roleId!,
        );
      } else {
        saved = widget.user!;
        await widget.security.updateUser(
          userId: saved.id,
          displayName: _name.text.trim(),
          roleId: _roleId!,
        );
        if (_username.text.trim() != saved.username ||
            _password.text.isNotEmpty) {
          await widget.security.changeCredentials(
            userId: saved.id,
            username: _username.text.trim() == saved.username
                ? null
                : _username.text.trim(),
            password: _password.text.isEmpty ? null : _password.text,
          );
        }
      }
      if (_active != saved.active) {
        await widget.security.setUserActive(saved.id, _active);
      }
      final scopes = [
        for (final entry in _selectedScopes.entries)
          for (final id in entry.value)
            UserScope(id: '', userId: saved.id, type: entry.key, scopeId: id),
      ];
      await widget.security.setUserScopes(saved.id, scopes);
      if (mounted) Navigator.pop(context, true);
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
    title: Text(widget.user == null ? 'إضافة مستخدم' : 'تعديل المستخدم'),
    content: SizedBox(
      width: 820,
      child: FurnexaFormShell(
        formKey: _key,
        title: 'بيانات المستخدم',
        cancelLabel: 'إلغاء',
        saveLabel: 'حفظ المستخدم',
        onCancel: () => Navigator.pop(context),
        onSave: _save,
        saveLoading: _saving,
        sections: [
          FurnexaFormSection(
            title: 'الحساب',
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'اسم المستخدم *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'هذا الحقل مطلوب'
                    : null,
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'الاسم المعروض *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'هذا الحقل مطلوب'
                    : null,
              ),
              if (widget.user == null) ...[
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور *'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'كلمة المرور مطلوبة'
                      : null,
                ),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور *',
                  ),
                  validator: (value) => value != _password.text
                      ? 'كلمتا المرور غير متطابقتين'
                      : null,
                ),
              ] else ...[
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة مرور جديدة (اختياري)',
                  ),
                  validator: (value) =>
                      value != null && value.isNotEmpty && value.length < 4
                      ? 'كلمة المرور قصيرة'
                      : null,
                ),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                  ),
                  validator: (value) => value != _password.text
                      ? 'كلمتا المرور غير متطابقتين'
                      : null,
                ),
              ],
              DropdownButtonFormField<String>(
                initialValue: _roleId,
                decoration: const InputDecoration(labelText: 'الدور *'),
                items: widget.roles
                    .map(
                      (role) => DropdownMenuItem(
                        value: role.id,
                        child: Text(role.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _roleId = value),
                validator: (value) => value == null ? 'اختر دوراً' : null,
              ),
              SwitchListTile(
                title: const Text('الحساب نشط'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
          FurnexaFormSection(
            title: 'النطاقات',
            description: 'اختر الموارد المسموح بها للمستخدم.',
            children: [
              for (final type in ScopeType.values) _scopeSelector(type),
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

  Widget _scopeSelector(ScopeType type) {
    final resources = _resources[type] ?? const <Map<String, Object?>>[];
    return ExpansionTile(
      title: Text(_scopeLabel(type)),
      children: resources.isEmpty
          ? [const ListTile(title: Text('لا توجد موارد متاحة'))]
          : resources.map((resource) {
              final id = resource['id'] as String;
              final selected = _selectedScopes[type]?.contains(id) ?? false;
              return CheckboxListTile(
                value: selected,
                title: Text(resource['name'] as String),
                onChanged: (value) => setState(
                  () =>
                      (_selectedScopes[type] ??= {}).toggle(id, value ?? false),
                ),
              );
            }).toList(),
    );
  }

  String _scopeLabel(ScopeType type) => switch (type) {
    ScopeType.section => 'الأقسام',
    ScopeType.workshop => 'الورش',
    ScopeType.warehouse => 'المخازن',
    ScopeType.productionStage => 'مراحل الإنتاج',
  };
}

class _RoleForm extends StatefulWidget {
  const _RoleForm({required this.security, this.role});

  final SecurityLocalDataSource security;
  final SecurityRole? role;

  @override
  State<_RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends State<_RoleForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.role?.name ?? '');
  late final _description = TextEditingController(
    text: widget.role?.description ?? '',
  );
  List<Map<String, Object?>> _permissions = [];
  final _selected = <String>{};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _permissions = await widget.security.permissions();
      if (widget.role != null) {
        _selected.addAll(
          await widget.security.rolePermissionCodes(widget.role!.id),
        );
      }
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final role =
          widget.role ??
          await widget.security.createRole(
            name: _name.text.trim(),
            description: _description.text.trim(),
          );
      if (!role.isSystemRole) {
        await widget.security.setRolePermissions(role.id, _selected);
      }
      if (mounted) Navigator.pop(context, true);
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
    title: Text(widget.role == null ? 'إضافة دور' : 'صلاحيات الدور'),
    content: SizedBox(
      width: 760,
      child: _loading
          ? const FurnexaLoading(compact: true)
          : FurnexaFormShell(
              formKey: _key,
              cancelLabel: 'إلغاء',
              saveLabel: 'حفظ الدور',
              onCancel: () => Navigator.pop(context),
              onSave: widget.role?.isSystemRole == true ? () {} : _save,
              saveLoading: _saving,
              sections: [
                FurnexaFormSection(
                  title: 'بيانات الدور',
                  children: [
                    TextFormField(
                      controller: _name,
                      readOnly: widget.role?.isSystemRole == true,
                      decoration: const InputDecoration(
                        labelText: 'اسم الدور *',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'هذا الحقل مطلوب'
                          : null,
                    ),
                    TextFormField(
                      controller: _description,
                      readOnly: widget.role?.isSystemRole == true,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                  ],
                ),
                FurnexaFormSection(
                  title: 'الصلاحيات',
                  description: widget.role?.isSystemRole == true
                      ? 'صلاحيات مدير النظام محمية.'
                      : 'حدد الصلاحيات الممنوحة لهذا الدور.',
                  children: [
                    for (final permission in _permissions)
                      CheckboxListTile(
                        value: _selected.contains(permission['code']),
                        title: Text(permission['code'] as String),
                        subtitle: Text(
                          '${permission['module']} • ${permission['action']}',
                        ),
                        onChanged: widget.role?.isSystemRole == true
                            ? null
                            : (value) => setState(() {
                                final code = permission['code'] as String;
                                if (value == true) {
                                  _selected.add(code);
                                } else {
                                  _selected.remove(code);
                                }
                              }),
                      ),
                  ],
                ),
                if (_error != null)
                  FurnexaFormSection(
                    title: 'تعذر الحفظ',
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

extension on Set<String> {
  void toggle(String value, bool selected) {
    if (selected) {
      add(value);
    } else {
      remove(value);
    }
  }
}
