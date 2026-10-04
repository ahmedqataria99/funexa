import 'package:furnexa/features/notifications/domain/repositories/notifications_repository.dart';

class MarkNotificationRead {
  const MarkNotificationRead(this.repository);
  final NotificationsRepository repository;
  Future<void> call(String id) => repository.markRead(id);
}
