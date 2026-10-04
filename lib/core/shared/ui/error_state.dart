import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_states.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      FurnexaErrorState(title: 'Error', message: message);
}
