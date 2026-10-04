import 'package:furnexa/features/notifications/domain/entities/notification_entity.dart';

abstract class NotificationsRepository {
  Future<List<NotificationEntity>> getNotifications({
    bool unreadOnly = false,
    bool alertsOnly = false,
  });
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markUnread(String id);
  Future<void> markAllRead();
  Future<void> archive(String id);
  Future<void> refresh();
  Future<void> setMinimumStock({
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double minimumQuantity,
  });
}
