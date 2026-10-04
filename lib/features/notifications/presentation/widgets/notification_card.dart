import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/features/notifications/domain/entities/notification_entity.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onRead,
    required this.onArchive,
    required this.onOpen,
  });

  final NotificationEntity notification;
  final VoidCallback onRead;
  final VoidCallback onArchive;
  final VoidCallback onOpen;

  Color _color(BuildContext context) => switch (notification.severity) {
    NotificationSeverity.critical => Theme.of(context).colorScheme.error,
    NotificationSeverity.warning => AppTheme.warning,
    NotificationSeverity.success => AppTheme.success,
    NotificationSeverity.info => Theme.of(context).colorScheme.primary,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      color: notification.isRead
          ? null
          : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .25),
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          backgroundColor: _color(context),
          child: Icon(
            notification.isRead
                ? Icons.notifications_none
                : Icons.notifications_active,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 18,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${notification.message}\n${DateFormat('dd/MM/yyyy HH:mm').format(notification.createdAt)}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'archive' ? onArchive() : onRead(),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'read',
              child: Text(
                notification.isRead
                    ? l.markNotificationUnread
                    : l.markNotificationRead,
              ),
            ),
            PopupMenuItem(value: 'archive', child: Text(l.archiveNotification)),
          ],
        ),
      ),
    );
  }
}
