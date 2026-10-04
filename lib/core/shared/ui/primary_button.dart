import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_button.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) =>
      FurnexaButton(label: text, onPressed: onPressed, isLoading: isLoading);
}
