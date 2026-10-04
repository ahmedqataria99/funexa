import 'package:furnexa/features/notifications/domain/repositories/notifications_repository.dart';

class ArchiveNotification {
  const ArchiveNotification(this.repository);
  final NotificationsRepository repository;
  Future<void> call(String id) => repository.archive(id);
}
