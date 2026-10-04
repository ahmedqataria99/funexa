import 'package:furnexa/features/sales/domain/entities/sales_entities.dart';

enum CrmCustomerStatus { lead, prospect, customer, inactive }

enum LeadSource { website, facebook, instagram, referral, walkIn, other }

enum LeadStatus { newLead, contacted, qualified, converted, lost }

enum ActivityType { call, meeting, whatsapp, email, visit, note, other }

enum FollowUpPriority { low, medium, high }

enum FollowUpStatus { pending, completed, cancelled }

enum TaskPriority { low, medium, high }

enum TaskStatus { pending, completed, cancelled }

extension CrmCustomerStatusValue on CrmCustomerStatus {
  String get value => switch (this) {
    CrmCustomerStatus.lead => 'LEAD',
    CrmCustomerStatus.prospect => 'PROSPECT',
    CrmCustomerStatus.customer => 'CUSTOMER',
    CrmCustomerStatus.inactive => 'INACTIVE',
  };
}

extension LeadSourceValue on LeadSource {
  String get value => switch (this) {
    LeadSource.website => 'WEBSITE',
    LeadSource.facebook => 'FACEBOOK',
    LeadSource.instagram => 'INSTAGRAM',
    LeadSource.referral => 'REFERRAL',
    LeadSource.walkIn => 'WALK_IN',
    LeadSource.other => 'OTHER',
  };
}

extension LeadStatusValue on LeadStatus {
  String get value => switch (this) {
    LeadStatus.newLead => 'NEW',
    LeadStatus.contacted => 'CONTACTED',
    LeadStatus.qualified => 'QUALIFIED',
    LeadStatus.converted => 'CONVERTED',
    LeadStatus.lost => 'LOST',
  };
}

extension ActivityTypeValue on ActivityType {
  String get value => switch (this) {
    ActivityType.call => 'CALL',
    ActivityType.meeting => 'MEETING',
    ActivityType.whatsapp => 'WHATSAPP',
    ActivityType.email => 'EMAIL',
    ActivityType.visit => 'VISIT',
    ActivityType.note => 'NOTE',
    ActivityType.other => 'OTHER',
  };
}

extension FollowUpPriorityValue on FollowUpPriority {
  String get value => switch (this) {
    FollowUpPriority.low => 'LOW',
    FollowUpPriority.medium => 'MEDIUM',
    FollowUpPriority.high => 'HIGH',
  };
}

extension FollowUpStatusValue on FollowUpStatus {
  String get value => switch (this) {
    FollowUpStatus.pending => 'PENDING',
    FollowUpStatus.completed => 'COMPLETED',
    FollowUpStatus.cancelled => 'CANCELLED',
  };
}

extension TaskPriorityValue on TaskPriority {
  String get value => switch (this) {
    TaskPriority.low => 'LOW',
    TaskPriority.medium => 'MEDIUM',
    TaskPriority.high => 'HIGH',
  };
}

extension TaskStatusValue on TaskStatus {
  String get value => switch (this) {
    TaskStatus.pending => 'PENDING',
    TaskStatus.completed => 'COMPLETED',
    TaskStatus.cancelled => 'CANCELLED',
  };
}

class Lead {
  const Lead({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.company,
    this.address,
    required this.source,
    this.notes,
    required this.status,
    required this.assignedUserId,
    required this.createdAt,
    required this.updatedAt,
    this.convertedAt,
    this.convertedCustomerId,
  });

  final String id, name;
  final String? phone, email, company, address, notes;
  final LeadSource source;
  final LeadStatus status;
  final String assignedUserId;
  final DateTime createdAt, updatedAt;
  final DateTime? convertedAt;
  final String? convertedCustomerId;

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'company': company,
    'address': address,
    'source': source.value,
    'notes': notes,
    'status': status.value,
    'assignedUserId': assignedUserId,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'convertedAt': convertedAt?.millisecondsSinceEpoch,
    'convertedCustomerId': convertedCustomerId,
  };

  factory Lead.fromMap(Map<String, Object?> row) => Lead(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String?,
    email: row['email'] as String?,
    company: row['company'] as String?,
    address: row['address'] as String?,
    source: _leadSource(row['source'] as String?),
    notes: row['notes'] as String?,
    status: _leadStatus(row['status'] as String?),
    assignedUserId: row['assignedUserId'] as String,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
    convertedAt: row['convertedAt'] == null ? null : _date(row['convertedAt']),
    convertedCustomerId: row['convertedCustomerId'] as String?,
  );
}

class CrmActivity {
  const CrmActivity({
    required this.id,
    this.customerId,
    this.leadId,
    required this.type,
    required this.title,
    required this.description,
    required this.activityDate,
    required this.createdBy,
    this.relatedDocumentId,
    required this.createdAt,
  });

  final String id;
  final String? customerId;
  final String? leadId;
  final ActivityType type;
  final String title, description, createdBy;
  final DateTime activityDate, createdAt;
  final String? relatedDocumentId;

  Map<String, Object?> toMap() => {
    'id': id,
    'customerId': customerId,
    'leadId': leadId,
    'type': type.value,
    'title': title,
    'description': description,
    'activityDate': activityDate.millisecondsSinceEpoch,
    'createdBy': createdBy,
    'relatedDocumentId': relatedDocumentId,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory CrmActivity.fromMap(Map<String, Object?> row) => CrmActivity(
    id: row['id'] as String,
    customerId: row['customerId'] as String?,
    leadId: row['leadId'] as String?,
    type: _activityType(row['type'] as String?),
    title: row['title'] as String,
    description: row['description'] as String,
    activityDate: _date(row['activityDate']),
    createdBy: row['createdBy'] as String,
    relatedDocumentId: row['relatedDocumentId'] as String?,
    createdAt: _date(row['createdAt']),
  );
}

class CrmFollowUp {
  const CrmFollowUp({
    required this.id,
    this.customerId,
    this.leadId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.assignedUserId,
    required this.priority,
    required this.status,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? customerId, leadId;
  final String title, description, assignedUserId;
  final DateTime dueDate, createdAt, updatedAt;
  final FollowUpPriority priority;
  final FollowUpStatus status;
  final DateTime? completedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'customerId': customerId,
    'leadId': leadId,
    'title': title,
    'description': description,
    'dueDate': dueDate.millisecondsSinceEpoch,
    'assignedUserId': assignedUserId,
    'priority': priority.value,
    'status': status.value,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory CrmFollowUp.fromMap(Map<String, Object?> row) => CrmFollowUp(
    id: row['id'] as String,
    customerId: row['customerId'] as String?,
    leadId: row['leadId'] as String?,
    title: row['title'] as String,
    description: row['description'] as String,
    dueDate: _date(row['dueDate']),
    assignedUserId: row['assignedUserId'] as String,
    priority: _followUpPriority(row['priority'] as String?),
    status: _followUpStatus(row['status'] as String?),
    completedAt: row['completedAt'] == null ? null : _date(row['completedAt']),
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class CrmTask {
  const CrmTask({
    required this.id,
    this.customerId,
    this.leadId,
    required this.title,
    required this.description,
    required this.assignedUserId,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? customerId, leadId;
  final String title, description, assignedUserId;
  final DateTime dueDate, createdAt, updatedAt;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? completedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'customerId': customerId,
    'leadId': leadId,
    'title': title,
    'description': description,
    'assignedUserId': assignedUserId,
    'dueDate': dueDate.millisecondsSinceEpoch,
    'priority': priority.value,
    'status': status.value,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory CrmTask.fromMap(Map<String, Object?> row) => CrmTask(
    id: row['id'] as String,
    customerId: row['customerId'] as String?,
    leadId: row['leadId'] as String?,
    title: row['title'] as String,
    description: row['description'] as String,
    assignedUserId: row['assignedUserId'] as String,
    dueDate: _date(row['dueDate']),
    priority: _taskPriority(row['priority'] as String?),
    status: _taskStatus(row['status'] as String?),
    completedAt: row['completedAt'] == null ? null : _date(row['completedAt']),
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class CrmNote {
  const CrmNote({
    required this.id,
    this.customerId,
    this.leadId,
    required this.content,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? customerId, leadId;
  final String content, createdBy;
  final DateTime createdAt, updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'customerId': customerId,
    'leadId': leadId,
    'content': content,
    'createdBy': createdBy,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory CrmNote.fromMap(Map<String, Object?> row) => CrmNote(
    id: row['id'] as String,
    customerId: row['customerId'] as String?,
    leadId: row['leadId'] as String?,
    content: row['content'] as String,
    createdBy: row['createdBy'] as String,
    createdAt: _date(row['createdAt']),
    updatedAt: _date(row['updatedAt']),
  );
}

class LeadConversionResult {
  const LeadConversionResult({
    required this.leadId,
    required this.customerId,
    required this.customer,
    required this.lead,
    required this.status,
    required this.convertedCustomerId,
  });

  final String leadId, customerId;
  final Customer customer;
  final Lead lead;
  final LeadStatus status;
  final String convertedCustomerId;
}

class Customer360Profile {
  const Customer360Profile({
    required this.customer,
    required this.activities,
    required this.followUps,
    required this.tasks,
    required this.notes,
    required this.salesHistory,
  });

  final Customer customer;
  final List<CrmActivity> activities;
  final List<CrmFollowUp> followUps;
  final List<CrmTask> tasks;
  final List<CrmNote> notes;
  final List<Map<String, Object?>> salesHistory;
}

class CrmDashboardSnapshot {
  const CrmDashboardSnapshot({
    required this.newLeads,
    required this.openLeads,
    required this.convertedLeads,
    required this.pendingFollowUps,
    required this.overdueFollowUps,
    required this.todaysTasks,
    required this.newCustomers,
    required this.recentActivities,
    required this.upcomingFollowUps,
    required this.recentLeads,
  });

  final int newLeads;
  final int openLeads;
  final int convertedLeads;
  final int pendingFollowUps;
  final int overdueFollowUps;
  final int todaysTasks;
  final int newCustomers;
  final List<CrmActivity> recentActivities;
  final List<CrmFollowUp> upcomingFollowUps;
  final List<Lead> recentLeads;
}

DateTime _date(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(value as int);

LeadSource _leadSource(String? value) => LeadSource.values.firstWhere(
  (source) => source.value == value,
  orElse: () => LeadSource.other,
);

LeadStatus _leadStatus(String? value) => LeadStatus.values.firstWhere(
  (status) => status.value == value,
  orElse: () => LeadStatus.newLead,
);

ActivityType _activityType(String? value) => ActivityType.values.firstWhere(
  (type) => type.value == value,
  orElse: () => ActivityType.other,
);

FollowUpPriority _followUpPriority(String? value) =>
    FollowUpPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => FollowUpPriority.medium,
    );

FollowUpStatus _followUpStatus(String? value) =>
    FollowUpStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => FollowUpStatus.pending,
    );

TaskPriority _taskPriority(String? value) => TaskPriority.values.firstWhere(
  (priority) => priority.value == value,
  orElse: () => TaskPriority.medium,
);

TaskStatus _taskStatus(String? value) => TaskStatus.values.firstWhere(
  (status) => status.value == value,
  orElse: () => TaskStatus.pending,
);
