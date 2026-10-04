import 'package:flutter/material.dart';
import 'package:furnexa/core/shared/widgets/furnexa_states.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message, this.size = 24});

  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) => FurnexaLoading(message: message);
}
