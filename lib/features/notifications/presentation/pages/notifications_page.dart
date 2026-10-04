import 'package:flutter/material.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:furnexa/features/notifications/domain/entities/notification_entity.dart';
import 'package:furnexa/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:furnexa/features/notifications/presentation/widgets/notification_card.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.security,
    this.onNavigate,
    this.repository,
  });

  final SecurityLocalDataSource security;
  final ValueChanged<String>? onNavigate;
  final NotificationsRepository? repository;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationsRepository _repository =
      widget.repository ?? NotificationsRepositoryImpl();
  List<NotificationEntity> _notifications = const [];
  int _filter = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repository.refresh();
      final values = await _repository.getNotifications(
        unreadOnly: _filter == 1,
        alertsOnly: _filter == 2,
      );
      if (!mounted) return;
      setState(() {
        _notifications = values;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleRead(NotificationEntity notification) async {
    if (notification.isRead) {
      await _repository.markUnread(notification.id);
    } else {
      await _repository.markRead(notification.id);
    }
    await _load();
  }

  Future<void> _open(NotificationEntity notification) async {
    if (!notification.isRead) await _repository.markRead(notification.id);
    if (notification.actionKey != null)
      widget.onNavigate?.call(notification.actionKey!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        actions: [
          TextButton.icon(
            onPressed: _loading
                ? null
                : () async {
                    await _repository.markAllRead();
                    await _load();
                  },
            icon: const Icon(Icons.done_all),
            label: Text(l.markAllNotificationsRead),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(l.allNotifications)),
                      ButtonSegment(
                        value: 1,
                        label: Text(l.unreadNotifications),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text(l.notificationAlerts),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (value) {
                      setState(() => _filter = value.first);
                      _load();
                    },
                  ),
                ),
                Expanded(
                  child: _notifications.isEmpty
                      ? Center(child: Text(l.noNotifications))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _notifications.length,
                            itemBuilder: (context, index) {
                              final notification = _notifications[index];
                              return NotificationCard(
                                notification: notification,
                                onRead: () => _toggleRead(notification),
                                onArchive: () async {
                                  await _repository.archive(notification.id);
                                  await _load();
                                },
                                onOpen: () => _open(notification),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
