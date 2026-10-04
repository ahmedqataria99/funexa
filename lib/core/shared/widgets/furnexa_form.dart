import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';
import 'package:furnexa/core/theme/app_spacing.dart';

class FurnexaFormShell extends StatelessWidget {
  const FurnexaFormShell({
    super.key,
    required this.formKey,
    required this.sections,
    required this.onCancel,
    required this.onSave,
    required this.cancelLabel,
    required this.saveLabel,
    this.title,
    this.subtitle,
    this.saveLoading = false,
    this.readOnly = false,
  });

  final GlobalKey<FormState> formKey;
  final List<FurnexaFormSection> sections;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String cancelLabel;
  final String saveLabel;
  final String? title;
  final String? subtitle;
  final bool saveLoading;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Form(
    key: formKey,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
          ...sections,
          if (!readOnly) ...[
            const SizedBox(height: AppSpacing.lg),
            FurnexaFormActions(
              cancelLabel: cancelLabel,
              saveLabel: saveLabel,
              onCancel: onCancel,
              onSave: onSave,
              saveLoading: saveLoading,
            ),
          ],
        ],
      ),
    ),
  );
}

class FurnexaFormSection extends StatelessWidget {
  const FurnexaFormSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(description!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        FurnexaFormGrid(children: children),
      ],
    ),
  );
}

class FurnexaFormGrid extends StatelessWidget {
  const FurnexaFormGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 560
          ? 2
          : 1;
      final gap = AppSpacing.md;
      final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: AppSpacing.md,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class FurnexaFormActions extends StatelessWidget {
  const FurnexaFormActions({
    super.key,
    required this.cancelLabel,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
    this.saveLoading = false,
  });

  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool saveLoading;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      FurnexaButton(
        label: cancelLabel,
        variant: FurnexaButtonVariant.text,
        onPressed: saveLoading ? null : onCancel,
      ),
      FurnexaButton(
        label: saveLabel,
        icon: Icons.save_outlined,
        onPressed: onSave,
        isLoading: saveLoading,
      ),
    ],
  );
}
