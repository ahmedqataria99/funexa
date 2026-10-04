import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/shared/widgets/furnexa_card.dart';
import 'package:furnexa/core/shared/widgets/furnexa_states.dart';
import 'package:furnexa/core/shared/widgets/furnexa_status_badge.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/features/backup_restore/data/repositories/backup_restore_repository_impl.dart';
import 'package:furnexa/features/backup_restore/domain/entities/backup_restore_entities.dart';
import 'package:furnexa/features/backup_restore/domain/repositories/backup_restore_repository.dart';
import 'package:furnexa/features/backup_restore/presentation/controllers/backup_restore_controller.dart';
import 'package:furnexa/features/users_roles_permissions/data/datasources/security_local_data_source.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({
    super.key,
    required this.security,
    this.repository,
    this.onRestoreCompleted,
  });

  final SecurityLocalDataSource security;
  final BackupRestoreRepository? repository;
  final VoidCallback? onRestoreCompleted;

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  late final BackupRestoreController _controller = BackupRestoreController(
    repository: widget.repository ?? BackupRestoreRepositoryImpl(),
  );
  String? _selectedPath;

  bool get _canView => widget.security.session?.can('BACKUP_VIEW') ?? false;
  bool get _canCreate => widget.security.session?.can('BACKUP_CREATE') ?? false;
  bool get _canRestore =>
      widget.security.session?.can('BACKUP_RESTORE') ?? false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    if (_canView) _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _createBackup() async {
    final localizations = AppLocalizations.of(context);
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: localizations.chooseDestination,
      fileName:
          'furnexa_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.furnexa',
      type: FileType.custom,
      allowedExtensions: ['furnexa'],
    );
    if (!mounted || destination == null || destination.isEmpty) return;
    final metadata = await _controller.createBackup(
      destination.toLowerCase().endsWith('.furnexa')
          ? destination
          : '$destination.furnexa',
    );
    if (!mounted || metadata == null) return;
    _showFeedback(localizations.backupCreatedSuccessfully, isError: false);
  }

  Future<void> _chooseRestoreFile() async {
    final localizations = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: localizations.chooseBackup,
      type: FileType.custom,
      allowedExtensions: ['furnexa'],
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    setState(() => _selectedPath = path);
    await _controller.validateBackup(path);
  }

  Future<void> _confirmRestore() async {
    final metadata = _controller.selectedBackup;
    final path = _selectedPath;
    if (metadata == null || path == null || !mounted) return;
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(localizations.restoreBackup),
        content: Text(
          '${localizations.currentDataWillBeReplaced}\n\n${localizations.safetyBackupWillBeCreated}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock_reset_outlined),
            label: Text(localizations.createSafetyBackupAndRestore),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final restored = await _controller.restoreBackup(path);
    if (!mounted || !restored) return;
    _showFeedback(localizations.backupRestoredSuccessfully, isError: false);
    widget.onRestoreCompleted?.call();
  }

  void _showFeedback(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (!_canView) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.backupRestore)),
        body: _EmptyPanel(
          icon: Icons.lock_outline,
          title: localizations.backupRestore,
          description: localizations.noBackupHistoryDescription,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.backupRestore),
        actions: [
          IconButton(
            tooltip: localizations.retry,
            onPressed: _controller.busy ? null : _controller.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              localizations.backupRestoreDescription,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 820;
                final cards = [
                  _BackupCard(
                    title: localizations.backupSection,
                    description: localizations.createBackupDescription,
                    icon: Icons.cloud_upload_outlined,
                    accent: AppTheme.navy,
                    actionLabel: localizations.createBackup,
                    enabled: _canCreate && !_controller.busy,
                    onPressed: _createBackup,
                    metadata: _controller.lastBackup,
                    emptyLabel: localizations.noBackupYet,
                  ),
                  _BackupCard(
                    title: localizations.restoreSection,
                    description: localizations.restoreBackupDescription,
                    icon: Icons.restore_outlined,
                    accent: Theme.of(context).colorScheme.error,
                    actionLabel: localizations.restoreBackup,
                    enabled: _canRestore && !_controller.busy,
                    onPressed: _chooseRestoreFile,
                    metadata: _controller.selectedBackup,
                    emptyLabel: localizations.chooseBackup,
                    destructive: true,
                  ),
                ];
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cards
                        .map(
                          (card) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: card,
                          ),
                        )
                        .toList(),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cards
                      .map(
                        (card) => Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: card,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            if (_controller.selectedBackup != null) ...[
              const SizedBox(height: 8),
              _ValidationPreview(
                metadata: _controller.selectedBackup!,
                onRestore: _canRestore ? _confirmRestore : null,
              ),
            ],
            if (_controller.error != null) ...[
              const SizedBox(height: 12),
              _FeedbackPanel(
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                message: switch (_controller.error) {
                  'create' => localizations.backupCreationFailed,
                  'restore' => localizations.backupRestoreFailed,
                  'validate' => localizations.invalidBackup,
                  _ => localizations.searchFailed,
                },
                actionLabel: _controller.error == 'validate'
                    ? localizations.chooseAnotherFile
                    : localizations.retry,
                onPressed: _controller.error == 'validate'
                    ? _chooseRestoreFile
                    : _controller.load,
              ),
            ],
            if (_controller.success != null) ...[
              const SizedBox(height: 12),
              _FeedbackPanel(
                icon: Icons.check_circle_outline,
                color: AppTheme.success,
                message: _controller.success == 'created'
                    ? localizations.backupCreatedSuccessfully
                    : localizations.backupRestoredSuccessfully,
              ),
            ],
            const SizedBox(height: 24),
            _HistorySection(
              entries: _controller.history,
              onCreate: _canCreate && !_controller.busy ? _createBackup : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.actionLabel,
    required this.enabled,
    required this.onPressed,
    required this.metadata,
    required this.emptyLabel,
    this.destructive = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onPressed;
  final BackupMetadata? metadata;
  final String emptyLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) => FurnexaCard(
    child: Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 32),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(description),
          const SizedBox(height: 16),
          if (metadata == null)
            Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall)
          else
            _MetadataLine(metadata: metadata!),
          const SizedBox(height: 18),
          FurnexaButton(
            label: actionLabel,
            onPressed: enabled ? onPressed : null,
            icon: icon,
            variant: destructive
                ? FurnexaButtonVariant.destructive
                : FurnexaButtonVariant.primary,
          ),
        ],
      ),
    ),
  );
}

class _ValidationPreview extends StatelessWidget {
  const _ValidationPreview({required this.metadata, required this.onRestore});
  final BackupMetadata metadata;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return FurnexaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: AppTheme.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localizations.validBackup,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _MetadataGrid(metadata: metadata),
          const SizedBox(height: 16),
          if (onRestore != null)
            FurnexaButton(
              onPressed: onRestore,
              label: localizations.restoreBackup,
              icon: Icons.lock_reset_outlined,
              variant: FurnexaButtonVariant.destructive,
            ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.entries, required this.onCreate});
  final List<BackupHistoryEntry> entries;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return FurnexaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  localizations.backupHistory,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (entries.isNotEmpty)
                Text(
                  '${entries.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            _EmptyPanel(
              icon: Icons.history_toggle_off,
              title: localizations.noBackupHistory,
              description: localizations.noBackupHistoryDescription,
              actionLabel: onCreate == null ? null : localizations.createBackup,
              onPressed: onCreate,
            )
          else
            ...entries.map((entry) => _HistoryTile(entry: entry)),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});
  final BackupHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final fileAvailable =
        entry.filePath.isNotEmpty && File(entry.filePath).existsSync();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.archive_outlined),
      title: Text(entry.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${DateFormat('dd/MM/yyyy HH:mm').format(entry.createdAt)} • ${localizations.databaseVersion}: ${entry.databaseVersion}',
      ),
      trailing: FurnexaStatusBadge(
        label: fileAvailable ? entry.status : localizations.fileUnavailable,
        semantic: switch (entry.status) {
          'RESTORED' => FurnexaStatusSemantic.info,
          'FAILED' || 'INVALID' => FurnexaStatusSemantic.error,
          _ => FurnexaStatusSemantic.success,
        },
      ),
    );
  }
}

class _MetadataLine extends StatelessWidget {
  const _MetadataLine({required this.metadata});
  final BackupMetadata metadata;

  @override
  Widget build(BuildContext context) => Text(
    '${metadata.fileName} • ${DateFormat('dd/MM/yyyy HH:mm').format(metadata.createdAt)}',
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall,
  );
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({required this.metadata});
  final BackupMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final values = [
      (localizations.factoryName, metadata.factoryName),
      (localizations.factoryCode, metadata.factoryCode),
      (
        localizations.backupDate,
        DateFormat('dd/MM/yyyy HH:mm').format(metadata.createdAt),
      ),
      (localizations.appVersion, metadata.appVersion),
      (localizations.databaseVersion, '${metadata.databaseVersion}'),
      (localizations.backupFormatVersion, '${metadata.backupFormatVersion}'),
      (localizations.records, '${metadata.recordCount}'),
      (localizations.fileName, metadata.fileName),
    ];
    return Wrap(
      spacing: 24,
      runSpacing: 14,
      children: values
          .map(
            (value) => SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.$1, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value.$2.isEmpty ? '—' : value.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });
  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(message),
      trailing: actionLabel == null
          ? null
          : TextButton(onPressed: onPressed, child: Text(actionLabel!)),
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onPressed,
  });
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FurnexaEmptyState(
    title: title,
    description: description,
    icon: icon,
    actionLabel: actionLabel,
    onAction: onPressed,
  );
}
