import 'dart:async';

import 'package:flutter/material.dart';
import 'package:furnexa/core/database/furnexa_database_diagnostics.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/shared/widgets/furnexa_states.dart';
import 'package:furnexa/core/theme/app_spacing.dart';

class FurnexaTableColumn {
  const FurnexaTableColumn({
    required this.key,
    required this.label,
    this.flex = 1,
    this.alignment = AlignmentDirectional.centerStart,
    this.sortable = false,
    this.cellBuilder,
  });

  final String key;
  final String label;
  final int flex;
  final AlignmentGeometry alignment;
  final bool sortable;
  final Widget Function(BuildContext context, Map<String, Object?> row)?
  cellBuilder;
}

class FurnexaTableAction {
  const FurnexaTableAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
  final bool destructive;
}

class FurnexaDataTable extends StatefulWidget {
  const FurnexaDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.diagnosticFeature,
    this.diagnosticPageStateCount,
    this.rowId,
    this.actionsBuilder,
    this.selectedIds = const <String>{},
    this.onSelectionChanged,
    this.onSort,
    this.sortKey,
    this.sortAscending = true,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    this.emptyTitle,
    this.emptyDescription,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.pagination,
  });

  final List<FurnexaTableColumn> columns;
  final List<Map<String, Object?>> rows;
  final String? diagnosticFeature;
  final int? diagnosticPageStateCount;
  final String Function(Map<String, Object?> row)? rowId;
  final List<FurnexaTableAction> Function(Map<String, Object?> row)?
  actionsBuilder;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final ValueChanged<String>? onSort;
  final String? sortKey;
  final bool sortAscending;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String? emptyTitle;
  final String? emptyDescription;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;
  final FurnexaTablePagination? pagination;

  @override
  State<FurnexaDataTable> createState() => _FurnexaDataTableState();
}

class _FurnexaDataTableState extends State<FurnexaDataTable> {
  bool _selectAll = false;
  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _verticalController = ScrollController();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  String _id(Map<String, Object?> row) =>
      widget.rowId?.call(row) ?? '${row.hashCode}';

  void _toggle(String id, bool selected) {
    final next = {...widget.selectedIds};
    if (selected) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.onSelectionChanged?.call(next);
  }

  void _toggleAll(bool? selected) {
    _selectAll = selected ?? false;
    final ids = _selectAll ? widget.rows.map(_id).toSet() : <String>{};
    widget.onSelectionChanged?.call(ids);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (widget.loading) {
      _recordDiagnostic(
        state: 'loading',
        reason: 'table loading flag is true',
        renderedRowCount: 0,
      );
      return const FurnexaLoading(compact: true);
    }
    if (widget.errorMessage != null) {
      _recordDiagnostic(
        state: 'error',
        reason: 'table received an error message',
        renderedRowCount: 0,
      );
      return FurnexaErrorState(
        title: localizations.tableLoadFailed,
        message: widget.errorMessage!,
        onRetry: widget.onRetry,
        retryLabel: localizations.retryTable,
      );
    }
    if (widget.rows.isEmpty) {
      _recordDiagnostic(
        state: 'empty',
        reason: 'table received zero rows',
        renderedRowCount: 0,
      );
      return FurnexaEmptyState(
        title: widget.emptyTitle ?? localizations.noResults,
        description: widget.emptyDescription,
        actionLabel: widget.emptyActionLabel,
        onAction: widget.onEmptyAction,
      );
    }

    final hasSelection = widget.onSelectionChanged != null;
    final hasActions = widget.actionsBuilder != null;
    final dataRows = widget.rows.map((row) {
      final id = _id(row);
      final selected = widget.selectedIds.contains(id);
      return DataRow(
        selected: selected,
        onSelectChanged: hasSelection
            ? (value) => _toggle(id, value ?? false)
            : null,
        cells: [
          ...widget.columns.map(
            (column) => DataCell(
              Align(
                alignment: column.alignment,
                child:
                    column.cellBuilder?.call(context, row) ??
                    Text(
                      '${row[column.key] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
            ),
          ),
          if (hasActions)
            DataCell(_ActionMenu(actions: widget.actionsBuilder!(row))),
        ],
      );
    }).toList();
    _recordDiagnostic(
      state: 'success',
      reason: 'DataRow widgets generated from received table rows',
      renderedRowCount: dataRows.length,
    );
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 160, maxHeight: 560),
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalController,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.depth == 0,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 680),
                    child: DataTable(
                      showCheckboxColumn: hasSelection,
                      onSelectAll: hasSelection ? _toggleAll : null,
                      headingRowColor: WidgetStatePropertyAll(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 72,
                      sortColumnIndex: widget.sortKey == null
                          ? null
                          : widget.columns.indexWhere(
                              (column) => column.key == widget.sortKey,
                            ),
                      sortAscending: widget.sortAscending,
                      columns: [
                        ...widget.columns.map(
                          (column) => DataColumn(
                            label: Align(
                              alignment: column.alignment,
                              child: Text(column.label),
                            ),
                            onSort: column.sortable && widget.onSort != null
                                ? (_, ascending) {
                                    widget.onSort!(column.key);
                                  }
                                : null,
                          ),
                        ),
                        if (hasActions)
                          DataColumn(label: Text(localizations.actions)),
                      ],
                      rows: dataRows,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.pagination != null)
          _PaginationFooter(config: widget.pagination!),
      ],
    );
  }

  void _recordDiagnostic({
    required String state,
    required String reason,
    required int renderedRowCount,
  }) {
    final feature = widget.diagnosticFeature;
    if (feature == null) return;
    unawaited(
      FurnexaDatabaseDiagnostics.recordUiPipeline(
        feature: feature,
        layer: 'table',
        state: state,
        reason: reason,
        pageStateCount: widget.diagnosticPageStateCount,
        receivedItemCount: widget.rows.length,
        renderedRowCount: renderedRowCount,
      ),
    );
  }
}

class FurnexaTablePagination {
  const FurnexaTablePagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.pageSizes = const [10, 20, 50],
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final List<int> pageSizes;
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.config});
  final FurnexaTablePagination config;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final start = config.total == 0 ? 0 : config.page * config.pageSize + 1;
    final end = (start + config.pageSize - 1).clamp(0, config.total);
    final lastPage = config.total == 0
        ? 0
        : (config.total - 1) ~/ config.pageSize;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          Text('$start–$end / ${config.total}'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations.rowsPerPage),
              const SizedBox(width: AppSpacing.xs),
              DropdownButton<int>(
                value: config.pageSize,
                items: {...config.pageSizes, config.pageSize}
                    .map(
                      (size) =>
                          DropdownMenuItem(value: size, child: Text('$size')),
                    )
                    .toList(),
                onChanged: config.onPageSizeChanged == null
                    ? null
                    : (value) {
                        if (value != null) config.onPageSizeChanged!(value);
                      },
              ),
              FurnexaIconButton(
                icon: Icons.first_page,
                tooltip: localizations.first,
                onPressed: config.page > 0
                    ? () => config.onPageChanged(0)
                    : null,
              ),
              FurnexaIconButton(
                icon: Icons.chevron_left,
                tooltip: localizations.previous,
                onPressed: config.page > 0
                    ? () => config.onPageChanged(config.page - 1)
                    : null,
              ),
              FurnexaIconButton(
                icon: Icons.chevron_right,
                tooltip: localizations.next,
                onPressed: config.page < lastPage
                    ? () => config.onPageChanged(config.page + 1)
                    : null,
              ),
              FurnexaIconButton(
                icon: Icons.last_page,
                tooltip: localizations.last,
                onPressed: config.page < lastPage
                    ? () => config.onPageChanged(lastPage)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({required this.actions});
  final List<FurnexaTableAction> actions;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (actions.length == 1) {
      final action = actions.first;
      return FurnexaIconButton(
        icon: action.icon,
        tooltip: action.label,
        onPressed: action.enabled ? action.onPressed : null,
      );
    }
    return PopupMenuButton<int>(
      tooltip: localizations.actions,
      onSelected: (index) => actions[index].onPressed(),
      itemBuilder: (context) => actions.asMap().entries.map((entry) {
        final action = entry.value;
        return PopupMenuItem<int>(
          value: entry.key,
          enabled: action.enabled,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              action.icon,
              color: action.destructive
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
            title: Text(action.label),
          ),
        );
      }).toList(),
      child: const Icon(Icons.more_horiz),
    );
  }
}
