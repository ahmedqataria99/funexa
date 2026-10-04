import 'package:flutter/material.dart';
import 'package:furnexa/core/localization/app_localizations.dart';
import 'package:furnexa/features/global_search/domain/entities/global_search_entities.dart';
import 'package:furnexa/features/global_search/presentation/controllers/global_search_controller.dart';

class GlobalSearchControl extends StatefulWidget {
  const GlobalSearchControl({
    super.key,
    required this.controller,
    required this.onResultSelected,
    required this.onViewAll,
  });

  final GlobalSearchController controller;
  final ValueChanged<GlobalSearchResultItem> onResultSelected;
  final ValueChanged<GlobalSearchEntityCategory> onViewAll;

  @override
  State<GlobalSearchControl> createState() => _GlobalSearchControlState();
}

class _GlobalSearchControlState extends State<GlobalSearchControl> {
  final _fieldKey = GlobalKey();
  final _layerLink = LayerLink();
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocus);
    widget.controller.addListener(_refreshOverlay);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refreshOverlay);
    _removeOverlay();
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (_focusNode.hasFocus) {
      widget.controller.open();
      _showOverlay();
    } else {
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!_focusNode.hasFocus) _removeOverlay();
      });
    }
  }

  void _refreshOverlay() {
    if (_overlay != null) _overlay!.markNeedsBuild();
  }

  void _showOverlay() {
    if (_overlay != null) return;
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: _panelWidth(context),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 52),
          child: _SearchPanel(
            controller: widget.controller,
            onResultSelected: _selectResult,
            onViewAll: _viewAll,
            onRecentSelected: _selectRecent,
            onClearRecent: widget.controller.clearRecent,
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  double _panelWidth(BuildContext context) {
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final fieldWidth = renderBox?.size.width ?? 420;
    return fieldWidth.clamp(320.0, MediaQuery.sizeOf(context).width - 32);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _selectResult(GlobalSearchResultItem item) {
    _removeOverlay();
    _focusNode.unfocus();
    widget.onResultSelected(item);
  }

  void _viewAll(GlobalSearchEntityCategory category) {
    _removeOverlay();
    _focusNode.unfocus();
    widget.onViewAll(category);
  }

  void _selectRecent(String value) {
    _textController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    widget.controller.setQuery(value);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return CompositedTransformTarget(
      key: _fieldKey,
      link: _layerLink,
      child: SizedBox(
        width: 420,
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          textDirection: Directionality.of(context),
          onChanged: (value) {
            setState(() {});
            widget.controller.setQuery(value);
          },
          onSubmitted: (_) => widget.controller.search(),
          decoration: InputDecoration(
            isDense: true,
            labelText: localizations.globalSearch,
            hintText: localizations.globalSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _textController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: localizations.clearSearch,
                    onPressed: () {
                      _textController.clear();
                      widget.controller.setQuery('');
                    },
                    icon: const Icon(Icons.close),
                  ),
            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.onResultSelected,
    required this.onViewAll,
    required this.onRecentSelected,
    required this.onClearRecent,
  });

  final GlobalSearchController controller;
  final ValueChanged<GlobalSearchResultItem> onResultSelected;
  final ValueChanged<GlobalSearchEntityCategory> onViewAll;
  final ValueChanged<String> onRecentSelected;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final grouped =
        <GlobalSearchEntityCategory, List<GlobalSearchResultItem>>{};
    for (final item in controller.visibleResults) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CategoryFilters(controller: controller),
                const SizedBox(height: 8),
                if (controller.loading)
                  const LinearProgressIndicator(minHeight: 2),
                if (controller.error != null)
                  _ErrorSearchState(
                    message: localizations.searchFailed,
                    retryLabel: localizations.retrySearch,
                    onRetry: controller.retry,
                  )
                else if (controller.query.trim().isEmpty)
                  _RecentSearches(
                    searches: controller.recent,
                    loading: controller.loadingRecent,
                    onSelected: onRecentSelected,
                    onClear: onClearRecent,
                  )
                else if (!controller.loading && grouped.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localizations.searchNoResultsFor(controller.query),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...grouped.entries.map(
                    (entry) => _ResultGroup(
                      category: entry.key,
                      results: entry.value,
                      onResultSelected: onResultSelected,
                      onViewAll: onViewAll,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({required this.controller});
  final GlobalSearchController controller;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final filters = <(GlobalSearchEntityCategory, String)>[
      (GlobalSearchEntityCategory.all, localizations.allSearchCategories),
      (GlobalSearchEntityCategory.products, localizations.searchProducts),
      (GlobalSearchEntityCategory.customers, localizations.searchCustomers),
      (GlobalSearchEntityCategory.salesOrders, localizations.searchSales),
      (
        GlobalSearchEntityCategory.productionOrders,
        localizations.searchProduction,
      ),
      (GlobalSearchEntityCategory.workers, localizations.searchWorkers),
      (GlobalSearchEntityCategory.warehouses, localizations.searchInventory),
      (GlobalSearchEntityCategory.sections, localizations.searchFactory),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ChoiceChip(
                  label: Text(filter.$2),
                  selected: controller.filter == filter.$1,
                  onSelected: (_) => controller.setFilter(filter.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ResultGroup extends StatelessWidget {
  const _ResultGroup({
    required this.category,
    required this.results,
    required this.onResultSelected,
    required this.onViewAll,
  });

  final GlobalSearchEntityCategory category;
  final List<GlobalSearchResultItem> results;
  final ValueChanged<GlobalSearchResultItem> onResultSelected;
  final ValueChanged<GlobalSearchEntityCategory> onViewAll;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final label = switch (category) {
      GlobalSearchEntityCategory.products => localizations.searchProducts,
      GlobalSearchEntityCategory.customers => localizations.searchCustomers,
      GlobalSearchEntityCategory.salesOrders => localizations.searchSales,
      GlobalSearchEntityCategory.productionOrders =>
        localizations.searchProduction,
      GlobalSearchEntityCategory.workers => localizations.searchWorkers,
      GlobalSearchEntityCategory.warehouses => localizations.searchInventory,
      _ => localizations.searchFactory,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            if (results.length > 1)
              TextButton(
                onPressed: () => onViewAll(category),
                child: Text(localizations.viewAll),
              ),
          ],
        ),
        ...results.map(
          (item) =>
              _ResultTile(item: item, onTap: () => onResultSelected(item)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, required this.onTap});
  final GlobalSearchResultItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label:
          '${item.title}${item.codeOrNumber == null ? '' : ', ${item.codeOrNumber}'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            textDirection: Directionality.of(context),
            children: [
              Icon(
                _iconFor(item.entityType),
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null || item.codeOrNumber != null)
                      Text(
                        [
                          item.subtitle,
                          item.codeOrNumber,
                        ].whereType<String>().join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Icon(
                isRtl ? Icons.chevron_left : Icons.chevron_right,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(GlobalSearchEntityType type) => switch (type) {
    GlobalSearchEntityType.product => Icons.inventory_2_outlined,
    GlobalSearchEntityType.customer => Icons.person_outline,
    GlobalSearchEntityType.salesOrder => Icons.point_of_sale_outlined,
    GlobalSearchEntityType.productionOrder =>
      Icons.precision_manufacturing_outlined,
    GlobalSearchEntityType.worker => Icons.groups_outlined,
    GlobalSearchEntityType.warehouse => Icons.warehouse_outlined,
    GlobalSearchEntityType.section => Icons.account_tree_outlined,
    GlobalSearchEntityType.workshop => Icons.handyman_outlined,
    GlobalSearchEntityType.productionStage => Icons.alt_route_outlined,
  };
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.searches,
    required this.loading,
    required this.onSelected,
    required this.onClear,
  });

  final List<String> searches;
  final bool loading;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (loading) {
      return const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (searches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.search_outlined, size: 32),
            const SizedBox(height: 8),
            Text(localizations.searchStart),
            const SizedBox(height: 4),
            Text(
              localizations.searchStartDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                localizations.recentSearches,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: localizations.clearRecentSearches,
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline, size: 19),
            ),
          ],
        ),
        ...searches.map(
          (search) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history, size: 19),
            title: Text(search, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => onSelected(search),
          ),
        ),
      ],
    );
  }
}

class _ErrorSearchState extends StatelessWidget {
  const _ErrorSearchState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.error_outline),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(retryLabel),
        ),
      ],
    ),
  );
}
