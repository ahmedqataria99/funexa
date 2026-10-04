import 'package:flutter/material.dart';
import 'package:furnexa/core/theme/app_theme.dart';
import 'package:furnexa/core/theme/app_spacing.dart';

class FurnexaStatusBadge extends StatelessWidget {
  const FurnexaStatusBadge({
    super.key,
    required this.label,
    this.semantic = FurnexaStatusSemantic.neutral,
  });

  final String label;
  final FurnexaStatusSemantic semantic;

  @override
  Widget build(BuildContext context) {
    final color = switch (semantic) {
      FurnexaStatusSemantic.success => AppTheme.success,
      FurnexaStatusSemantic.warning => AppTheme.warning,
      FurnexaStatusSemantic.error => Theme.of(context).colorScheme.error,
      FurnexaStatusSemantic.info => AppTheme.info,
      FurnexaStatusSemantic.neutral => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum FurnexaStatusSemantic { success, warning, error, info, neutral }
