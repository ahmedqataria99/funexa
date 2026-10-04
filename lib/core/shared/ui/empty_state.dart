import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_states.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title = 'No data available',
    this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      FurnexaEmptyState(title: title, description: message, icon: icon);
}
