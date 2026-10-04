import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/shared/widgets/furnexa_card.dart';
import 'package:furnexa/core/shared/widgets/furnexa_states.dart';
import 'package:furnexa/core/shared/widgets/furnexa_status_badge.dart';
import 'package:furnexa/core/theme/app_spacing.dart';

class FurnexaDetailPage extends StatelessWidget {
  const FurnexaDetailPage({super.key, required this.header, required this.children});
  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding: AppSpacing.page,
        children: [header, const SizedBox(height: AppSpacing.xl), ...children],
      );
}

class FurnexaDetailHeader extends StatelessWidget {
  const FurnexaDetailHeader({
    super.key,
    required this.title,
    this.code,
    this.subtitle,
    this.status,
    this.actions = const [],
  });

  final String title;
  final String? code;
  final String? subtitle;
  final Widget? status;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                if (code != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(code!, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
                if (status != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  status!,
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.md),
            Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: actions),
          ],
        ],
      );
}

class FurnexaInfoSection extends StatelessWidget {
  const FurnexaInfoSection({super.key, required this.title, required this.items, this.description});
  final String title;
  final String? description;
  final List<FurnexaInfoItem> items;

  @override
  Widget build(BuildContext context) => FurnexaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(description!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 760 ? 3 : constraints.maxWidth >= 480 ? 2 : 1;
                final width = (constraints.maxWidth - ((count - 1) * AppSpacing.lg)) / count;
                return Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.md,
                  children: items.map((item) => SizedBox(width: width, child: item)).toList(),
                );
              },
            ),
          ],
        ),
      );
}

class FurnexaInfoItem extends StatelessWidget {
  const FurnexaInfoItem({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(value.isEmpty ? '-' : value, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      );
}

class FurnexaDetailSection extends StatelessWidget {
  const FurnexaDetailSection({super.key, required this.title, required this.child, this.empty = false, this.emptyTitle});
  final String title;
  final Widget child;
  final bool empty;
  final String? emptyTitle;

  @override
  Widget build(BuildContext context) => FurnexaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (empty) FurnexaEmptyState(title: emptyTitle ?? 'No records') else child,
          ],
        ),
      );
}

class FurnexaDetailActionBar extends StatelessWidget {
  const FurnexaDetailActionBar({super.key, this.onEdit, this.editLabel = 'Edit', this.onMore, this.moreLabel = 'More'});
  final VoidCallback? onEdit;
  final String editLabel;
  final VoidCallback? onMore;
  final String moreLabel;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.xs,
        children: [
          if (onEdit != null) FurnexaButton(label: editLabel, icon: Icons.edit_outlined, onPressed: onEdit),
          if (onMore != null) FurnexaIconButton(icon: Icons.more_horiz, tooltip: moreLabel, onPressed: onMore),
        ],
      );
}

FurnexaStatusBadge furnexaActiveStatus(BuildContext context, bool active) => FurnexaStatusBadge(
      label: active ? 'ACTIVE' : 'INACTIVE',
      semantic: active ? FurnexaStatusSemantic.success : FurnexaStatusSemantic.neutral,
    );
