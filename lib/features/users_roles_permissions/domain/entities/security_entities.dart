enum ScopeType { section, workshop, warehouse, productionStage }

class SecurityUser {
  const SecurityUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.roleId,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String roleId;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
}

class SecurityRole {
  const SecurityRole({
    required this.id,
    required this.name,
    required this.description,
    required this.active,
    required this.isSystemRole,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final bool active;
  final bool isSystemRole;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class UserScope {
  const UserScope({
    required this.id,
    required this.userId,
    required this.type,
    required this.scopeId,
  });

  final String id;
  final String userId;
  final ScopeType type;
  final String scopeId;
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.userId,
    required this.usernameSnapshot,
    required this.action,
    required this.module,
    required this.entityType,
    required this.entityId,
    required this.timestamp,
    this.oldValue,
    this.newValue,
    this.description,
  });

  final String id;
  final String? userId;
  final String usernameSnapshot;
  final String action;
  final String module;
  final String entityType;
  final String? entityId;
  final DateTime timestamp;
  final String? oldValue;
  final String? newValue;
  final String? description;
}
