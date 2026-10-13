import 'package:flutter/material.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
