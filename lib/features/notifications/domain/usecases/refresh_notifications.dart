import 'package:furnexa/features/notifications/domain/repositories/notifications_repository.dart';

class RefreshNotifications {
  const RefreshNotifications(this.repository);
  final NotificationsRepository repository;
  Future<void> call() => repository.refresh();
}
