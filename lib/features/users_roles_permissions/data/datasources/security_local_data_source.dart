import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/users_roles_permissions/domain/entities/security_entities.dart';

class SecuritySession {
  const SecuritySession({
    required this.user,
    required this.role,
    required this.permissions,
    required this.scopes,
  });

  final SecurityUser user;
  final SecurityRole role;
  final Set<String> permissions;
  final List<UserScope> scopes;

  bool get isSystemAdmin => role.isSystemRole;
  bool can(String permission) =>
      isSystemAdmin ||
      (permission != 'SYSTEM_ADMIN' && permissions.contains(permission));
  bool canAccess(ScopeType type, String resourceId) =>
      isSystemAdmin ||
      scopes.any((scope) => scope.type == type && scope.scopeId == resourceId);
}

class SecurityLocalDataSource {
  static int _sequence = 0;
  static const int _passwordIterations = 120000;
  static const int minimumInitialAdminPasswordLength = 12;
  static SecuritySession? _activeSession;

  SecuritySession? get session => _activeSession;

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  Future<void> ensureInitialAdmin() async {
    final db = await _db;
    final setup = await db.query('app_setup_state', limit: 1);
    if (setup.isEmpty) {
      final admins = await db.query(
        'users',
        columns: ['id'],
        where: 'roleId = ?',
        whereArgs: ['role-system-admin'],
        limit: 1,
      );
      await db.insert('app_setup_state', {
        'id': 1,
        'completed': admins.isNotEmpty ? 1 : 0,
      });
    }
  }

  Future<bool> initialAdminSetupRequired() async {
    await ensureInitialAdmin();
    final rows = await (await _db).query(
      'app_setup_state',
      columns: ['completed'],
      where: 'id = 1',
      limit: 1,
    );
    return rows.isEmpty || rows.single['completed'] != 1;
  }

  Future<void> setupInitialAdmin({
    required String username,
    required String displayName,
    required String password,
  }) async {
    await ensureInitialAdmin();
    final cleanUsername = username.trim();
    final cleanName = displayName.trim();
    if (cleanUsername.isEmpty || cleanName.isEmpty) {
      throw Exception('بيانات مدير النظام مطلوبة');
    }
    if (password.length < minimumInitialAdminPasswordLength ||
        password.toLowerCase() == 'admin') {
      throw Exception('كلمة المرور يجب أن تتكون من 12 حرفاً على الأقل');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final setup = await txn.query(
        'app_setup_state',
        columns: ['completed'],
        where: 'id = 1',
        limit: 1,
      );
      if (setup.isNotEmpty && setup.single['completed'] == 1) {
        throw Exception('تم إعداد مدير النظام مسبقاً');
      }
      final duplicate = await txn.query(
        'users',
        where: 'username = ? AND roleId != ?',
        whereArgs: [cleanUsername, 'role-system-admin'],
        limit: 1,
      );
      if (duplicate.isNotEmpty) throw Exception('اسم المستخدم مستخدم مسبقاً');
      final existingAdmin = await txn.query(
        'users',
        where: 'roleId = ?',
        whereArgs: ['role-system-admin'],
        orderBy: 'createdAt ASC',
        limit: 1,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      if (existingAdmin.isEmpty) {
        await txn.insert('users', {
          'id': _id('user'),
          'username': cleanUsername,
          'displayName': cleanName,
          'passwordHash': _hash(password),
          'roleId': 'role-system-admin',
          'active': 1,
          'createdAt': now,
          'updatedAt': now,
        });
      } else {
        await txn.update(
          'users',
          {
            'username': cleanUsername,
            'displayName': cleanName,
            'passwordHash': _hash(password),
            'active': 1,
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [existingAdmin.single['id']],
        );
      }
      await txn.update('app_setup_state', {'completed': 1}, where: 'id = 1');
    });
    _activeSession = null;
    await _auditRaw(
      userId: null,
      username: 'SYSTEM',
      action: 'INITIAL_ADMIN_SETUP',
      module: 'Auth',
      entityType: 'User',
      description: 'Initial system administrator configured',
    );
  }

  Future<SecuritySession> login(String username, String password) async {
    await ensureInitialAdmin();
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isNotEmpty &&
        username.trim() == 'admin' &&
        password == 'admin' &&
        _verify(password, rows.first['passwordHash'] as String)) {
      await db.update('app_setup_state', {'completed': 0}, where: 'id = 1');
      _activeSession = null;
      throw Exception('Initial administrator setup required');
    }
    if (await initialAdminSetupRequired()) {
      throw Exception('Initial administrator setup required');
    }
    if (rows.isEmpty ||
        rows.first['active'] != 1 ||
        !_verify(password, rows.first['passwordHash'] as String)) {
      await _auditRaw(
        userId: rows.isEmpty ? null : rows.first['id'] as String,
        username: username.trim(),
        action: 'LOGIN_FAILURE',
        module: 'Auth',
        entityType: 'User',
        description: 'Invalid credentials',
      );
      throw Exception('اسم المستخدم أو كلمة المرور غير صحيحة');
    }
    final storedHash = rows.first['passwordHash'] as String;
    if (!storedHash.startsWith('pbkdf2-sha256\$')) {
      await db.update(
        'users',
        {
          'passwordHash': _hash(password),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    }
    final user = _user(rows.first);
    final roleRows = await db.query(
      'roles',
      where: 'id = ? AND active = 1',
      whereArgs: [user.roleId],
      limit: 1,
    );
    if (roleRows.isEmpty) throw Exception('دور المستخدم غير نشط');
    final role = _role(roleRows.first);
    final permissionRows = await db.rawQuery(
      'SELECT p.code FROM permissions p JOIN role_permissions rp ON rp.permissionId = p.id WHERE rp.roleId = ?',
      [role.id],
    );
    final scopes = await _scopes(db, user.id);
    final loggedInAt = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'users',
      {'lastLoginAt': loggedInAt},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    final loggedUser = SecurityUser(
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      roleId: user.roleId,
      active: user.active,
      createdAt: user.createdAt,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(loggedInAt),
      lastLoginAt: DateTime.fromMillisecondsSinceEpoch(loggedInAt),
    );
    _activeSession = SecuritySession(
      user: loggedUser,
      role: role,
      permissions: permissionRows.map((row) => row['code'] as String).toSet(),
      scopes: scopes,
    );
    await _auditRaw(
      userId: user.id,
      username: user.username,
      action: 'LOGIN_SUCCESS',
      module: 'Auth',
      entityType: 'User',
      entityId: user.id,
      description: 'Login succeeded',
    );
    return _activeSession!;
  }

  void logout() => _activeSession = null;

  Future<List<SecurityUser>> users() async {
    require('USERS_VIEW');
    return (await (await _db).query(
      'users',
      orderBy: 'displayName ASC',
    )).map(_user).toList();
  }

  Future<List<SecurityRole>> roles() async {
    require('USERS_VIEW');
    return (await (await _db).query(
      'roles',
      orderBy: 'name ASC',
    )).map(_role).toList();
  }

  Future<List<Map<String, Object?>>> permissions() async {
    require('ROLES_EDIT');
    return (await (await _db).query(
      'permissions',
      orderBy: 'module ASC, code ASC',
    )).map((row) => Map<String, Object?>.from(row)).toList();
  }

  Future<Set<String>> rolePermissionCodes(String roleId) async {
    require('ROLES_EDIT');
    final rows = await (await _db).rawQuery(
      'SELECT p.code FROM permissions p JOIN role_permissions rp ON rp.permissionId = p.id WHERE rp.roleId = ?',
      [roleId],
    );
    return rows.map((row) => row['code'] as String).toSet();
  }

  Future<List<UserScope>> userScopes(String userId) async {
    require('USERS_VIEW');
    return _scopes(await _db, userId);
  }

  Future<List<Map<String, Object?>>> scopeResources(ScopeType type) async {
    require('USERS_VIEW');
    final table = switch (type) {
      ScopeType.section => 'sections',
      ScopeType.workshop => 'workshops',
      ScopeType.warehouse => 'warehouses',
      ScopeType.productionStage => 'production_stages',
    };
    return (await (await _db).query(
      table,
      columns: ['id', 'name'],
      orderBy: 'name ASC',
    )).map((row) => Map<String, Object?>.from(row)).toList();
  }

  Future<SecurityUser> createUser({
    required String username,
    required String displayName,
    required String password,
    required String roleId,
    String? phone,
    String? email,
  }) async {
    require('USERS_EDIT');
    if (username.trim().isEmpty ||
        displayName.trim().isEmpty ||
        password.isEmpty)
      throw Exception('بيانات المستخدم مطلوبة');
    final db = await _db;
    final roleRows = await db.query(
      'roles',
      where: 'id = ? AND active = 1',
      whereArgs: [roleId],
      limit: 1,
    );
    if (roleRows.isEmpty) throw Exception('دور المستخدم غير موجود أو غير نشط');
    if (roleRows.first['isSystemRole'] == 1 &&
        !(_activeSession?.isSystemAdmin ?? false)) {
      throw Exception('لا يمكن تعيين دور مدير النظام');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _id('user');
    await db.insert('users', {
      'id': id,
      'username': username.trim(),
      'displayName': displayName.trim(),
      'phone': phone,
      'email': email,
      'passwordHash': _hash(password),
      'roleId': roleId,
      'active': 1,
      'createdAt': now,
      'updatedAt': now,
    });
    final created = _user(
      (await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      )).single,
    );
    await audit(
      action: 'CREATE',
      module: 'Users',
      entityType: 'User',
      entityId: id,
      description: 'User created',
    );
    return created;
  }

  Future<void> changeCredentials({
    required String userId,
    String? username,
    String? password,
  }) async {
    require('USERS_EDIT');
    if (username == null && password == null)
      throw Exception('أدخل اسم مستخدم أو كلمة مرور جديدة');
    final db = await _db;
    final existing = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (existing.isEmpty) throw Exception('المستخدم غير موجود');
    final values = <String, Object?>{
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (username != null && username.trim().isNotEmpty)
      values['username'] = username.trim();
    if (password != null) {
      if (password.isEmpty) throw Exception('كلمة المرور مطلوبة');
      values['passwordHash'] = _hash(password);
    }
    await db.update('users', values, where: 'id = ?', whereArgs: [userId]);
    await audit(
      action: 'UPDATE_CREDENTIALS',
      module: 'Users',
      entityType: 'User',
      entityId: userId,
      description: 'Credentials changed',
    );
  }

  Future<void> updateUser({
    required String userId,
    String? displayName,
    String? phone,
    String? email,
    String? roleId,
  }) async {
    require('USERS_EDIT');
    final db = await _db;
    final existing = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (existing.isEmpty) throw Exception('المستخدم غير موجود');
    final current = _activeSession;
    if (current != null &&
        current.user.id == userId &&
        roleId != null &&
        !current.isSystemAdmin) {
      throw Exception('لا يمكن للمستخدم تغيير دوره بنفسه');
    }
    if (displayName != null && displayName.trim().isEmpty)
      throw Exception('اسم العرض مطلوب');
    if (roleId != null) {
      final roles = await db.query(
        'roles',
        where: 'id = ? AND active = 1',
        whereArgs: [roleId],
        limit: 1,
      );
      if (roles.isEmpty) throw Exception('دور المستخدم غير موجود أو غير نشط');
      if (roles.first['isSystemRole'] == 1 &&
          !(current?.isSystemAdmin ?? false)) {
        throw Exception('لا يمكن تعيين دور مدير النظام');
      }
    }
    final values = <String, Object?>{
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (displayName != null) values['displayName'] = displayName.trim();
    if (phone != null) values['phone'] = phone;
    if (email != null) values['email'] = email;
    if (roleId != null) values['roleId'] = roleId;
    await db.update('users', values, where: 'id = ?', whereArgs: [userId]);
    if (current?.user.id == userId && roleId != null) {
      _activeSession = null;
    }
    await audit(
      action: 'UPDATE',
      module: 'Users',
      entityType: 'User',
      entityId: userId,
      description: 'User updated',
    );
  }

  Future<void> setUserActive(String userId, bool active) async {
    require('USERS_EDIT');
    final db = await _db;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('المستخدم غير موجود');
    if (!active && rows.first['roleId'] == 'role-system-admin') {
      final countRows = await db.rawQuery(
        "SELECT COUNT(*) AS count FROM users WHERE active = 1 AND roleId = 'role-system-admin'",
      );
      final count = (countRows.first['count'] as num?)?.toInt() ?? 0;
      if (count <= 1) throw Exception('لا يمكن تعطيل آخر مدير نظام');
    }
    await db.update(
      'users',
      {
        'active': active ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (_activeSession?.user.id == userId) _activeSession = null;
    await audit(
      action: active ? 'ACTIVATE' : 'DEACTIVATE',
      module: 'Users',
      entityType: 'User',
      entityId: userId,
      description: 'User status changed',
    );
  }

  Future<SecurityRole> createRole({
    required String name,
    String? description,
  }) async {
    require('ROLES_EDIT');
    if (name.trim().isEmpty) throw Exception('اسم الدور مطلوب');
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _id('role');
    await db.insert('roles', {
      'id': id,
      'name': name.trim(),
      'description': description,
      'active': 1,
      'isSystemRole': 0,
      'createdAt': now,
      'updatedAt': now,
    });
    await audit(
      action: 'CREATE',
      module: 'Roles',
      entityType: 'Role',
      entityId: id,
      description: 'Role created',
    );
    return _role(
      (await db.query(
        'roles',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      )).single,
    );
  }

  Future<void> setRoleActive(String roleId, bool active) async {
    require('ROLES_EDIT');
    final db = await _db;
    final rows = await db.query(
      'roles',
      where: 'id = ?',
      whereArgs: [roleId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('الدور غير موجود');
    if (!active && rows.first['isSystemRole'] == 1)
      throw Exception('لا يمكن تعطيل دور مدير النظام');
    await db.update(
      'roles',
      {
        'active': active ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [roleId],
    );
    if (_activeSession?.role.id == roleId) _activeSession = null;
    await audit(
      action: active ? 'ACTIVATE' : 'DEACTIVATE',
      module: 'Roles',
      entityType: 'Role',
      entityId: roleId,
      description: 'Role status changed',
    );
  }

  Future<void> setRolePermissions(
    String roleId,
    Iterable<String> permissionCodes,
  ) async {
    require('ROLES_EDIT');
    if (permissionCodes.contains('SYSTEM_ADMIN') &&
        !(_activeSession?.isSystemAdmin ?? false)) {
      throw Exception('لا يمكن منح صلاحية مدير النظام');
    }
    final db = await _db;
    final roleRows = await db.query(
      'roles',
      where: 'id = ?',
      whereArgs: [roleId],
      limit: 1,
    );
    if (roleRows.isEmpty) throw Exception('الدور غير موجود');
    if (roleRows.first['isSystemRole'] == 1)
      throw Exception('لا يمكن تعديل صلاحيات دور مدير النظام');
    if (_activeSession?.role.id == roleId) {
      throw Exception('لا يمكن للمستخدم تعديل صلاحيات دوره الحالي');
    }
    await db.transaction((txn) async {
      await txn.delete(
        'role_permissions',
        where: 'roleId = ?',
        whereArgs: [roleId],
      );
      for (final code in permissionCodes) {
        final rows = await txn.query(
          'permissions',
          where: 'code = ?',
          whereArgs: [code],
          limit: 1,
        );
        if (rows.isEmpty) throw Exception('الصلاحية غير موجودة');
        await txn.insert('role_permissions', {
          'roleId': roleId,
          'permissionId': rows.first['id'],
        });
      }
    });
    await audit(
      action: 'PERMISSION_CHANGE',
      module: 'Roles',
      entityType: 'Role',
      entityId: roleId,
      description: 'Role permissions changed',
    );
    if (_activeSession?.role.id == roleId) _activeSession = null;
  }

  Future<void> setUserScopes(String userId, Iterable<UserScope> scopes) async {
    require('USERS_EDIT');
    final db = await _db;
    final userRows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (userRows.isEmpty) throw Exception('المستخدم غير موجود');
    if (_activeSession?.user.id == userId &&
        !(_activeSession?.isSystemAdmin ?? false)) {
      throw Exception('لا يمكن للمستخدم تغيير نطاقه بنفسه');
    }
    final requestedScopes = scopes.toList();
    await _validateScopes(db, requestedScopes);
    await db.transaction((txn) async {
      await txn.delete('user_scopes', where: 'userId = ?', whereArgs: [userId]);
      for (final scope in requestedScopes)
        await txn.insert('user_scopes', {
          'id': _id('scope'),
          'userId': userId,
          'scopeType': _scopeValue(scope.type),
          'scopeId': scope.scopeId,
        });
    });
    await audit(
      action: 'SCOPE_CHANGE',
      module: 'Users',
      entityType: 'User',
      entityId: userId,
      description: 'User scopes changed',
    );
    if (_activeSession?.user.id == userId) _activeSession = null;
  }

  bool can(String permission) => _activeSession?.can(permission) ?? false;

  Future<void> requireFresh(String permission) async {
    await refreshSession();
    require(permission);
  }

  Future<void> refreshSession() async {
    final current = _activeSession;
    if (current == null) throw Exception('يجب تسجيل الدخول');
    final db = await _db;
    final userRows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [current.user.id],
      limit: 1,
    );
    if (userRows.isEmpty || userRows.first['active'] != 1) {
      _activeSession = null;
      throw Exception('يجب تسجيل الدخول');
    }
    final user = _user(userRows.first);
    final roleRows = await db.query(
      'roles',
      where: 'id = ? AND active = 1',
      whereArgs: [user.roleId],
      limit: 1,
    );
    if (roleRows.isEmpty) {
      _activeSession = null;
      throw Exception('الدور غير نشط');
    }
    final role = _role(roleRows.first);
    final permissionRows = await db.rawQuery(
      'SELECT p.code FROM permissions p JOIN role_permissions rp ON rp.permissionId = p.id WHERE rp.roleId = ?',
      [role.id],
    );
    _activeSession = SecuritySession(
      user: user,
      role: role,
      permissions: permissionRows.map((row) => row['code'] as String).toSet(),
      scopes: await _scopes(db, user.id),
    );
  }

  void require(String permission) {
    final current = _activeSession;
    if (current == null) throw Exception('يجب تسجيل الدخول');
    if (!current.user.active ||
        !current.role.active ||
        !current.can(permission))
      throw Exception('ليس لديك صلاحية لتنفيذ هذا الإجراء');
  }

  void requireIfAuthenticated(String permission) {
    require(permission);
  }

  void requireScope(ScopeType type, String resourceId) {
    final current = _activeSession;
    if (current == null) throw Exception('يجب تسجيل الدخول');
    if (!current.canAccess(type, resourceId))
      throw Exception('النطاق المسموح لا يشمل هذا المورد');
  }

  Future<void> requireResourceScope(ScopeType type, String resourceId) async {
    requireScope(type, resourceId);
  }

  Future<void> _validateScopes(Database db, List<UserScope> scopes) async {
    for (final scope in scopes) {
      final table = switch (scope.type) {
        ScopeType.section => 'sections',
        ScopeType.workshop => 'workshops',
        ScopeType.warehouse => 'warehouses',
        ScopeType.productionStage => 'production_stages',
      };
      final rows = await db.query(
        table,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [scope.scopeId],
        limit: 1,
      );
      if (rows.isEmpty) {
        final dimensionRows = await db.query(table, columns: ['id'], limit: 1);
        if (dimensionRows.isNotEmpty)
          throw Exception('النطاق المحدد غير موجود');
      }
    }
    final sections = scopes
        .where((scope) => scope.type == ScopeType.section)
        .map((scope) => scope.scopeId)
        .toSet();
    if (sections.isEmpty) return;
    for (final scope in scopes.where(
      (scope) => scope.type == ScopeType.workshop,
    )) {
      final rows = await db.query(
        'workshops',
        columns: ['sectionId'],
        where: 'id = ?',
        whereArgs: [scope.scopeId],
        limit: 1,
      );
      if (rows.isNotEmpty && !sections.contains(rows.first['sectionId']))
        throw Exception('الورشة يجب أن تتبع قسمًا مسموحًا');
    }
  }

  Future<void> audit({
    required String action,
    required String module,
    required String entityType,
    String? entityId,
    String? oldValue,
    String? newValue,
    String? description,
  }) async {
    final current = _activeSession;
    await _auditRaw(
      userId: current?.user.id,
      username: current?.user.username ?? 'SYSTEM',
      action: action,
      module: module,
      entityType: entityType,
      entityId: entityId,
      oldValue: _safeValue(oldValue),
      newValue: _safeValue(newValue),
      description: description,
    );
  }

  Future<List<AuditLog>> auditLogs({
    String? module,
    String? action,
    String? userId,
  }) async {
    require('AUDIT_VIEW');
    final db = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    if (module != null) {
      clauses.add('module = ?');
      args.add(module);
    }
    if (action != null) {
      clauses.add('action = ?');
      args.add(action);
    }
    if (userId != null) {
      clauses.add('userId = ?');
      args.add(userId);
    }
    final rows = await db.query(
      'audit_logs',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
    );
    return rows.map(_audit).toList();
  }

  Future<void> _auditRaw({
    required String? userId,
    required String username,
    required String action,
    required String module,
    required String entityType,
    String? entityId,
    String? oldValue,
    String? newValue,
    String? description,
  }) async {
    final db = await _db;
    await db.insert('audit_logs', {
      'id': _id('audit'),
      'userId': userId,
      'usernameSnapshot': username,
      'action': action,
      'module': module,
      'entityType': entityType,
      'entityId': entityId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'oldValue': _safeValue(oldValue),
      'newValue': _safeValue(newValue),
      'description': description,
    });
  }

  String? _safeValue(String? value) =>
      value == null || value.toLowerCase().contains('password') ? null : value;
  String _hash(String password) {
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final derived = _pbkdf2(password, salt, _passwordIterations);
    return 'pbkdf2-sha256\$$_passwordIterations\$${base64UrlEncode(salt)}\$${base64UrlEncode(derived)}';
  }

  bool _verify(String password, String stored) {
    if (stored.startsWith('pbkdf2-sha256\$')) {
      final parts = stored.split('\$');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1) return false;
      try {
        final expectedSalt = base64Url.decode(parts[2]);
        final expected = base64Url.decode(parts[3]);
        return _constantTimeEquals(
          _pbkdf2(password, expectedSalt, iterations),
          expected,
        );
      } catch (_) {
        return false;
      }
    }
    return _verifyLegacy(password, stored);
  }

  bool _verifyLegacy(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final salt = base64Url.decode(parts[0]);
    final expected = sha256.convert([...salt, ...utf8.encode(password)]).bytes;
    final actual = _decodeHex(parts[1]);
    return _constantTimeEquals(actual, expected);
  }

  List<int> _decodeHex(String value) {
    if (value.length.isOdd) throw const FormatException('Invalid hex digest');
    return [
      for (var index = 0; index < value.length; index += 2)
        int.parse(value.substring(index, index + 2), radix: 16),
    ];
  }

  List<int> _pbkdf2(String password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(block);
    for (var index = 1; index < iterations; index++) {
      block = hmac.convert(block).bytes;
      for (var byte = 0; byte < result.length; byte++) {
        result[byte] ^= block[byte];
      }
    }
    return Uint8List.fromList(result);
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final length = max(left.length, right.length);
    for (var index = 0; index < length; index++) {
      difference |=
          (index < left.length ? left[index] : 0) ^
          (index < right.length ? right[index] : 0);
    }
    return difference == 0;
  }

  Future<List<UserScope>> _scopes(Database db, String userId) async =>
      (await db.query(
        'user_scopes',
        where: 'userId = ?',
        whereArgs: [userId],
      )).map(_scope).toList();
  SecurityUser _user(Map<String, Object?> row) => SecurityUser(
    id: row['id'] as String,
    username: row['username'] as String,
    displayName: row['displayName'] as String,
    roleId: row['roleId'] as String,
    active: row['active'] == 1,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
    lastLoginAt: row['lastLoginAt'] == null ? null : _date(row['lastLoginAt']),
  );
  SecurityRole _role(Map<String, Object?> row) => SecurityRole(
    id: row['id'] as String,
    name: row['name'] as String,
    description: row['description'] as String?,
    active: row['active'] == 1,
    isSystemRole: row['isSystemRole'] == 1,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
  UserScope _scope(Map<String, Object?> row) => UserScope(
    id: row['id'] as String,
    userId: row['userId'] as String,
    type: ScopeType.values.firstWhere(
      (value) => _scopeValue(value) == row['scopeType'],
    ),
    scopeId: row['scopeId'] as String,
  );
  AuditLog _audit(Map<String, Object?> row) => AuditLog(
    id: row['id'] as String,
    userId: row['userId'] as String?,
    usernameSnapshot: row['usernameSnapshot'] as String,
    action: row['action'] as String,
    module: row['module'] as String,
    entityType: row['entityType'] as String,
    entityId: row['entityId'] as String?,
    timestamp: _date(row['timestamp']),
    oldValue: row['oldValue'] as String?,
    newValue: row['newValue'] as String?,
    description: row['description'] as String?,
  );
  String _scopeValue(ScopeType value) => value.name
      .replaceAll('productionStage', 'PRODUCTION_STAGE')
      .toUpperCase();
  DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
}
