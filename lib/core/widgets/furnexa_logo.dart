import 'package:flutter/material.dart';

class FurnexaLogo extends StatelessWidget {
  const FurnexaLogo({
    super.key,
    this.compact = false,
    this.showText = true,
    this.color,
  });

  final bool compact;
  final bool showText;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoColor = color ?? theme.colorScheme.primary;

    final mark = SizedBox(
      width: compact ? 32 : 56,
      height: compact ? 32 : 56,
      child: Image.asset(
        'assets/logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );

    if (!showText) {
      return mark;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        if (!compact) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FURNEXA',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: logoColor,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'FURNITURE ERP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
