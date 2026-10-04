import 'package:flutter/material.dart';
import 'package:furnexa/core/theme/app_spacing.dart';

class FurnexaTableToolbar extends StatelessWidget {
  const FurnexaTableToolbar({
    super.key,
    required this.title,
    this.count,
    this.search,
    this.filters = const [],
    this.actions = const [],
  });

  final String title;
  final int? count;
  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            ...?(count == null
                ? null
                : [
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '($count)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
          ],
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ...?(search == null ? null : [search!]),
            ...filters,
            ...actions,
          ],
        ),
      ],
    ),
  );
}
