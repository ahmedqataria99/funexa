import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/theme/app_spacing.dart';

class FurnexaDialog extends StatelessWidget {
  const FurnexaDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.destructive = false,
  });

  final String title;
  final Widget content;
  final List<Widget>? actions;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (destructive)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.sm,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(child: SingleChildScrollView(child: content)),
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    ),
  );

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
    bool destructive = false,
  }) => showDialog<T>(
    context: context,
    builder: (_) => FurnexaDialog(
      title: title,
      content: content,
      actions: actions,
      destructive: destructive,
    ),
  );
}

class FurnexaDialogCancelButton extends StatelessWidget {
  const FurnexaDialogCancelButton({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => FurnexaButton(
    label: label,
    variant: FurnexaButtonVariant.text,
    onPressed: () => Navigator.of(context).pop(false),
  );
}
