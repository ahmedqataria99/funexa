import 'package:furnexa/features/notifications/domain/entities/notification_entity.dart';
import 'package:furnexa/features/notifications/domain/repositories/notifications_repository.dart';

class GetNotifications {
  const GetNotifications(this.repository);
  final NotificationsRepository repository;
  Future<List<NotificationEntity>> call({
    bool unreadOnly = false,
    bool alertsOnly = false,
  }) => repository.getNotifications(
    unreadOnly: unreadOnly,
    alertsOnly: alertsOnly,
  );
}
