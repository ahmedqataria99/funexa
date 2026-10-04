import 'package:flutter/material.dart';
import 'package:furnexa/core/theme/app_spacing.dart';

class FurnexaCard extends StatelessWidget {
  const FurnexaCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.elevation = AppElevation.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      elevation: elevation,
      child: Padding(padding: padding, child: child),
    );
    return onTap == null
        ? card
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: card,
          );
  }
}

class FurnexaKpiCard extends StatelessWidget {
  const FurnexaKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accent,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.secondary;
    return FurnexaCard(
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
