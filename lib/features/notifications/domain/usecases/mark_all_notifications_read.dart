import 'package:furnexa/features/notifications/domain/repositories/notifications_repository.dart';

class MarkAllNotificationsRead {
  const MarkAllNotificationsRead(this.repository);
  final NotificationsRepository repository;
  Future<void> call() => repository.markAllRead();
}
