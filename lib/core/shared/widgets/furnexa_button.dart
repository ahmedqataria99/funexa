import 'package:flutter/material.dart';
import 'package:furnexa/core/theme/app_spacing.dart';

class FurnexaButton extends StatelessWidget {
  const FurnexaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = FurnexaButtonVariant.primary,
    this.isLoading = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final FurnexaButtonVariant variant;
  final bool isLoading;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(label),
            ],
          );
    final button = switch (variant) {
      FurnexaButtonVariant.primary => FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: _content(child),
      ),
      FurnexaButtonVariant.secondary => ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: _content(child),
      ),
      FurnexaButtonVariant.outline => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: _content(child),
      ),
      FurnexaButtonVariant.text => TextButton(
        onPressed: isLoading ? null : onPressed,
        child: _content(child),
      ),
      FurnexaButtonVariant.destructive => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        child: _content(child),
      ),
    };
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }

  Widget _content(Widget child) => isLoading
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : child;
}

enum FurnexaButtonVariant { primary, secondary, outline, text, destructive }

class FurnexaIconButton extends StatelessWidget {
  const FurnexaIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      IconButton(onPressed: onPressed, tooltip: tooltip, icon: Icon(icon));
}
