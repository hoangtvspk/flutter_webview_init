import 'package:flutter/material.dart';

/// Loading overlay widget with simple circular progress indicator
class LoadingOverlay extends StatelessWidget {
  final double progress;

  const LoadingOverlay({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }
}
