import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:furnexa/core/database/furnexa_database.dart';
import 'package:furnexa/features/crm/domain/entities/crm_entities.dart';
import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class CrmLocalDataSource {
  CrmLocalDataSource();

  Future<Database> get _db async => FurnexaDatabase.instance.database;

  void assertPermission(String permission) {
    SecurityLocalDataSource().require(permission);
  }

  Future<Lead> saveLead(Lead lead) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    await db.insert(
      'crm_leads',
      lead.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _audit('CREATE', 'CRM', 'Lead', lead.id, 'Lead created');
    return lead;
  }

  Future<Lead> updateLeadStatus(String leadId, LeadStatus status) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    final existing = await getLeadById(leadId);
    if (existing == null) throw Exception('العميل المتوقع غير موجود');
    final now = DateTime.now();
    final updated = Lead(
      id: existing.id,
      name: existing.name,
      phone: existing.phone,
      email: existing.email,
      company: existing.company,
      address: existing.address,
      source: existing.source,
      notes: existing.notes,
      status: status,
      assignedUserId: existing.assignedUserId,
      createdAt: existing.createdAt,
      updatedAt: now,
      convertedAt: existing.convertedAt,
      convertedCustomerId: existing.convertedCustomerId,
    );
    await db.update(
      'crm_leads',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [leadId],
    );
    await _audit('STATUS_CHANGE', 'CRM', 'Lead', leadId, 'Lead status changed');
    return updated;
  }

  Future<Lead?> getLeadById(String id) async {
    SecurityLocalDataSource().require('CRM_VIEW');
    final db = await _db;
    final rows = await db.query(
      'crm_leads',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Lead.fromMap(rows.first);
  }

  Future<LeadConversionResult> convertLead({
    required String leadId,
    required Customer customerData,
  }) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    return db.transaction((txn) async {
      final leadRows = await txn.query(
        'crm_leads',
        where: 'id = ?',
        whereArgs: [leadId],
        limit: 1,
      );
      if (leadRows.isEmpty) throw Exception('العميل المتوقع غير موجود');
      final lead = Lead.fromMap(leadRows.single);
      if (lead.status == LeadStatus.converted) {
        final customerId = lead.convertedCustomerId;
        if (customerId == null)
          throw Exception('بيانات تحويل العميل غير مكتملة');
        final customerRows = await txn.query(
          'customers',
          where: 'id = ? AND active = 1',
          whereArgs: [customerId],
          limit: 1,
        );
        if (customerRows.isEmpty) throw Exception('العميل المحول غير موجود');
        return LeadConversionResult(
          leadId: lead.id,
          customerId: customerId,
          customer: Customer.fromMap(customerRows.single),
          lead: lead,
          status: lead.status,
          convertedCustomerId: customerId,
        );
      }
      if (lead.status == LeadStatus.lost) {
        throw Exception('لا يمكن تحويل عميل محتمل مفقود');
      }

      final existingCustomer = await _findMatchingCustomer(
        txn,
        phone: customerData.phone,
        email: customerData.email,
        name: customerData.name,
      );
      final customer =
          existingCustomer ?? await _createCustomer(txn, customerData);
      final now = DateTime.now();
      final convertedLead = Lead(
        id: lead.id,
        name: lead.name,
        phone: lead.phone,
        email: lead.email,
        company: lead.company,
        address: lead.address,
        source: lead.source,
        notes: lead.notes,
        status: LeadStatus.converted,
        assignedUserId: lead.assignedUserId,
        createdAt: lead.createdAt,
        updatedAt: now,
        convertedAt: now,
        convertedCustomerId: customer.id,
      );
      final changed = await txn.update(
        'crm_leads',
        convertedLead.toMap(),
        where: 'id = ? AND status != ?',
        whereArgs: [leadId, LeadStatus.converted.value],
      );
      if (changed != 1) throw Exception('تم تحويل العميل المحتمل بالفعل');
      await txn.insert('crm_activities', {
        'id': 'activity-convert-$leadId',
        'customerId': customer.id,
        'leadId': lead.id,
        'type': ActivityType.other.value,
        'title': 'تحويل عميل محتمل',
        'description': 'تم تحويل العميل المحتمل إلى عميل فعلي',
        'activityDate': now.millisecondsSinceEpoch,
        'createdBy': SecurityLocalDataSource().session?.user.id ?? 'system',
        'relatedDocumentId': null,
        'createdAt': now.millisecondsSinceEpoch,
      });
      await _audit(
        'CONVERT',
        'CRM',
        'Lead',
        leadId,
        'Lead converted to customer',
        executor: txn,
      );
      return LeadConversionResult(
        leadId: leadId,
        customerId: customer.id,
        customer: customer,
        lead: convertedLead,
        status: convertedLead.status,
        convertedCustomerId: customer.id,
      );
    });
  }

  Future<List<CrmActivity>> activities({
    String? customerId,
    String? leadId,
  }) async {
    SecurityLocalDataSource().require('CRM_VIEW');
    final db = await _db;
    final rows = await db.query(
      'crm_activities',
      where: customerId == null
          ? (leadId == null ? null : 'leadId = ?')
          : 'customerId = ?',
      whereArgs: customerId == null && leadId != null
          ? [leadId]
          : (customerId == null ? null : [customerId]),
      orderBy: 'activityDate DESC',
    );
    return rows.map(CrmActivity.fromMap).toList();
  }

  Future<List<CrmFollowUp>> followUps({
    String? customerId,
    String? leadId,
  }) async {
    SecurityLocalDataSource().require('CRM_VIEW');
    final db = await _db;
    final rows = await db.query(
      'crm_follow_ups',
      where: customerId == null
          ? (leadId == null ? null : 'leadId = ?')
          : 'customerId = ?',
      whereArgs: customerId == null && leadId != null
          ? [leadId]
          : (customerId == null ? null : [customerId]),
      orderBy: 'dueDate ASC',
    );
    return rows.map(CrmFollowUp.fromMap).toList();
  }

  Future<List<CrmTask>> tasks({String? customerId, String? leadId}) async {
    SecurityLocalDataSource().require('CRM_VIEW');
    final db = await _db;
    final rows = await db.query(
      'crm_tasks',
      where: customerId == null
          ? (leadId == null ? null : 'leadId = ?')
          : 'customerId = ?',
      whereArgs: customerId == null && leadId != null
          ? [leadId]
          : (customerId == null ? null : [customerId]),
      orderBy: 'dueDate ASC',
    );
    return rows.map(CrmTask.fromMap).toList();
  }

  Future<List<CrmNote>> notes({String? customerId, String? leadId}) async {
    SecurityLocalDataSource().require('CRM_VIEW');
    final db = await _db;
    final rows = await db.query(
      'crm_notes',
      where: customerId == null
          ? (leadId == null ? null : 'leadId = ?')
          : 'customerId = ?',
      whereArgs: customerId == null && leadId != null
          ? [leadId]
          : (customerId == null ? null : [customerId]),
      orderBy: 'createdAt DESC',
    );
    return rows.map(CrmNote.fromMap).toList();
  }

  Future<CrmActivity> createActivity(CrmActivity activity) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    await db.insert('crm_activities', activity.toMap());
    await _audit('CREATE', 'CRM', 'Activity', activity.id, 'Activity created');
    return activity;
  }

  Future<CrmNote> addNote(CrmNote note) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    await db.insert('crm_notes', note.toMap());
    await _audit('CREATE', 'CRM', 'Note', note.id, 'CRM note created');
    return note;
  }

  Future<CrmFollowUp> createFollowUp(CrmFollowUp followUp) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    await db.insert('crm_follow_ups', followUp.toMap());
    await _audit('CREATE', 'CRM', 'FollowUp', followUp.id, 'Follow-up created');
    return followUp;
  }

  Future<CrmFollowUp> completeFollowUp(String followUpId) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    final existing = await _fetchFollowUpById(db, followUpId);
    if (existing == null) throw Exception('المتابعة غير موجودة');
    final completedAt = DateTime.now();
    final updated = CrmFollowUp(
      id: existing.id,
      customerId: existing.customerId,
      leadId: existing.leadId,
      title: existing.title,
      description: existing.description,
      dueDate: existing.dueDate,
      assignedUserId: existing.assignedUserId,
      priority: existing.priority,
      status: FollowUpStatus.completed,
      completedAt: completedAt,
      createdAt: existing.createdAt,
      updatedAt: completedAt,
    );
    await db.update(
      'crm_follow_ups',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [followUpId],
    );
    await _audit(
      'COMPLETE',
      'CRM',
      'FollowUp',
      followUpId,
      'Follow-up completed',
    );
    return updated;
  }

  Future<CrmFollowUp> cancelFollowUp(String followUpId) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    final existing = await _fetchFollowUpById(db, followUpId);
    if (existing == null) throw Exception('المتابعة غير موجودة');
    final updated = CrmFollowUp(
      id: existing.id,
      customerId: existing.customerId,
      leadId: existing.leadId,
      title: existing.title,
      description: existing.description,
      dueDate: existing.dueDate,
      assignedUserId: existing.assignedUserId,
      priority: existing.priority,
      status: FollowUpStatus.cancelled,
      completedAt: existing.completedAt,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await db.update(
      'crm_follow_ups',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [followUpId],
    );
    await _audit(
      'CANCEL',
      'CRM',
      'FollowUp',
      followUpId,
      'Follow-up cancelled',
    );
    return updated;
  }

  Future<bool> isOverdueFollowUp(String followUpId) async {
    SecurityLocalDataSource().require('CRM_VIEW');
    final db = await _db;
    final followUp = await _fetchFollowUpById(db, followUpId);
    if (followUp == null) return false;
    if (followUp.status == FollowUpStatus.completed ||
        followUp.status == FollowUpStatus.cancelled) {
      return false;
    }
    return followUp.dueDate.isBefore(DateTime.now());
  }

  Future<CrmTask> createTask(CrmTask task) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    await db.insert('crm_tasks', task.toMap());
    await _audit('CREATE', 'CRM', 'Task', task.id, 'Task created');
    return task;
  }

  Future<CrmTask> completeTask(String taskId) async {
    SecurityLocalDataSource().require('CRM_EDIT');
    final db = await _db;
    final existing = await _fetchTaskById(db, taskId);
    if (existing == null) throw Exception('المهمة غير موجودة');
    final completedAt = DateTime.now();
    final updated = CrmTask(
      id: existing.id,
      customerId: existing.customerId,
      leadId: existing.leadId,
      title: existing.title,
      description: existing.description,
      assignedUserId: existing.assignedUserId,
      dueDate: existing.dueDate,
      priority: existing.priority,
      status: TaskStatus.completed,
      completedAt: completedAt,
      createdAt: existing.createdAt,
      updatedAt: completedAt,
    );
    await db.update(
      'crm_tasks',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [taskId],
    );
    await _audit('COMPLETE', 'CRM', 'Task', taskId, 'Task completed');
    return updated;
  }

  Future<List<CrmNote>> customerNotes(String customerId) async {
    return notes(customerId: customerId);
  }

  Future<Customer360Profile> customer360(String customerId) async {
    SecurityLocalDataSource().require('CRM_VIEW');
    final db = await _db;
    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('العميل غير موجود');
    final customer = Customer.fromMap(rows.first);
    final activities = await this.activities(customerId: customerId);
    final followUps = await this.followUps(customerId: customerId);
    final tasks = await this.tasks(customerId: customerId);
    final notes = await this.notes(customerId: customerId);
    final salesHistory = await db.query(
      'sales_orders',
      where: 'customerId = ?',
      whereArgs: [customerId],
      orderBy: 'orderDate DESC',
    );
    return Customer360Profile(
      customer: customer,
      activities: activities,
      followUps: followUps,
      tasks: tasks,
      notes: notes,
      salesHistory: salesHistory,
    );
  }

  Future<List<Map<String, Object?>>> auditLogs() async {
    SecurityLocalDataSource().require('AUDIT_VIEW');
    final db = await _db;
    return db.query('audit_logs', orderBy: 'timestamp DESC', limit: 50);
  }

  Future<Customer?> _findMatchingCustomer(
    DatabaseExecutor db, {
    String? phone,
    String? email,
    String? name,
  }) async {
    final candidatePhone = phone?.trim();
    final candidateEmail = email?.trim();
    final candidateName = name?.trim();
    final strongMatches = <String, Map<String, Object?>>{};
    if (candidatePhone != null && candidatePhone.isNotEmpty) {
      final rows = await db.query(
        'customers',
        where: 'active = 1 AND TRIM(phone) = ?',
        whereArgs: [candidatePhone],
      );
      for (final row in rows) {
        strongMatches[row['id'] as String] = row;
      }
    }
    if (candidateEmail != null && candidateEmail.isNotEmpty) {
      final rows = await db.query(
        'customers',
        where: 'active = 1 AND LOWER(TRIM(email)) = LOWER(?)',
        whereArgs: [candidateEmail],
      );
      for (final row in rows) {
        strongMatches[row['id'] as String] = row;
      }
    }
    if (strongMatches.length > 1) {
      throw Exception('توجد نتائج عملاء متعارضة؛ يجب اختيار العميل يدوياً');
    }
    if (strongMatches.isNotEmpty) {
      return Customer.fromMap(strongMatches.values.single);
    }
    if (candidateName == null || candidateName.isEmpty) return null;
    final nameMatches = await db.query(
      'customers',
      where: 'active = 1 AND LOWER(TRIM(name)) = LOWER(?)',
      whereArgs: [candidateName],
    );
    if (nameMatches.length > 1) {
      throw Exception('اسم العميل يطابق أكثر من سجل؛ يجب اختياره يدوياً');
    }
    return nameMatches.isEmpty ? null : Customer.fromMap(nameMatches.single);
  }

  Future<Customer> _createCustomer(
    DatabaseExecutor db,
    Customer customerData,
  ) async {
    if (!customerData.active) {
      throw Exception('لا يمكن تحويل العميل المحتمل إلى عميل غير نشط');
    }
    final candidate = Customer(
      id: customerData.id,
      name: customerData.name,
      code: customerData.code,
      phone: customerData.phone,
      email: customerData.email,
      address: customerData.address,
      taxNumber: customerData.taxNumber,
      notes: customerData.notes,
      active: customerData.active,
      createdAt: customerData.createdAt,
      updatedAt: customerData.updatedAt,
    );
    await db.insert(
      'customers',
      candidate.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [candidate.id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('فشل إنشاء العميل');
    await _audit(
      'CREATE',
      'CRM',
      'Customer',
      candidate.id,
      'Customer created from lead',
      executor: db,
    );
    return Customer.fromMap(rows.first);
  }

  Future<CrmFollowUp?> _fetchFollowUpById(
    Database db,
    String followUpId,
  ) async {
    final rows = await db.query(
      'crm_follow_ups',
      where: 'id = ?',
      whereArgs: [followUpId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CrmFollowUp.fromMap(rows.first);
  }

  Future<CrmTask?> _fetchTaskById(Database db, String taskId) async {
    final rows = await db.query(
      'crm_tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CrmTask.fromMap(rows.first);
  }

  Future<void> _audit(
    String action,
    String module,
    String entityType,
    String entityId,
    String description, {
    DatabaseExecutor? executor,
  }) async {
    final security = SecurityLocalDataSource();
    if (executor == null) {
      await security.audit(
        action: action,
        module: module,
        entityType: entityType,
        entityId: entityId,
        description: description,
      );
      return;
    }
    final session = security.session;
    final now = DateTime.now().millisecondsSinceEpoch;
    await executor.insert('audit_logs', {
      'id':
          'audit-$entityType-$entityId-$action-${DateTime.now().microsecondsSinceEpoch}',
      'userId': session?.user.id,
      'usernameSnapshot': session?.user.username ?? 'SYSTEM',
      'action': action,
      'module': module,
      'entityType': entityType,
      'entityId': entityId,
      'timestamp': now,
      'oldValue': null,
      'newValue': null,
      'description': description,
    });
  }
}
