import 'package:furnexa/features/notifications/domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.category,
    required super.severity,
    required super.title,
    required super.message,
    required super.isRead,
    required super.isArchived,
    required super.createdAt,
    required super.readAt,
    required super.archivedAt,
    required super.relatedEntityType,
    required super.relatedEntityId,
    required super.actionKey,
    required super.deduplicationKey,
  });

  factory NotificationModel.fromMap(Map<String, Object?> row) {
    return NotificationModel(
      id: row['id'] as String,
      userId: row['userId'] as String,
      type: NotificationType.values.firstWhere(
        (value) => value.value == row['type'],
      ),
      category: NotificationCategory.values.firstWhere(
        (value) => value.value == row['category'],
      ),
      severity: NotificationSeverity.values.firstWhere(
        (value) => value.value == row['severity'],
      ),
      title: row['title'] as String,
      message: row['message'] as String,
      isRead: row['isRead'] == 1,
      isArchived: row['isArchived'] == 1,
      createdAt: _date(row['createdAt']),
      readAt: row['readAt'] == null ? null : _date(row['readAt']),
      archivedAt: row['archivedAt'] == null ? null : _date(row['archivedAt']),
      relatedEntityType: row['relatedEntityType'] as String?,
      relatedEntityId: row['relatedEntityId'] as String?,
      actionKey: row['actionKey'] as String?,
      deduplicationKey: row['deduplicationKey'] as String,
    );
  }

  static DateTime _date(Object? value) =>
      DateTime.fromMillisecondsSinceEpoch(value as int);
}
