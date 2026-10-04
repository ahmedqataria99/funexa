import 'package:furnexa/features/notifications/data/datasources/notifications_local_data_source.dart';
import 'package:furnexa/features/notifications/domain/entities/notification_entity.dart';
import 'package:furnexa/features/notifications/domain/repositories/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({NotificationsLocalDataSource? dataSource})
    : dataSource = dataSource ?? NotificationsLocalDataSource();

  final NotificationsLocalDataSource dataSource;

  @override
  Future<List<NotificationEntity>> getNotifications({
    bool unreadOnly = false,
    bool alertsOnly = false,
  }) => dataSource.getNotifications(
    unreadOnly: unreadOnly,
    alertsOnly: alertsOnly,
  );

  @override
  Future<int> unreadCount() => dataSource.unreadCount();
  @override
  Future<void> markRead(String id) => dataSource.markRead(id);
  @override
  Future<void> markUnread(String id) => dataSource.markUnread(id);
  @override
  Future<void> markAllRead() => dataSource.markAllRead();
  @override
  Future<void> archive(String id) => dataSource.archive(id);
  @override
  Future<void> refresh() => dataSource.refresh();
  @override
  Future<void> setMinimumStock({
    required String warehouseId,
    required String itemId,
    required String itemType,
    required double minimumQuantity,
  }) => dataSource.setMinimumStock(
    warehouseId: warehouseId,
    itemId: itemId,
    itemType: itemType,
    minimumQuantity: minimumQuantity,
  );
}
