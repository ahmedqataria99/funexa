import 'package:furnexa/features/notifications/domain/repositories/notifications_repository.dart';

class MarkNotificationUnread {
  const MarkNotificationUnread(this.repository);
  final NotificationsRepository repository;
  Future<void> call(String id) => repository.markUnread(id);
}
