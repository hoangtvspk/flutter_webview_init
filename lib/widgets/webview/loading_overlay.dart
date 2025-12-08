import 'package:flutter/material.dart';

/// Loading overlay widget with simple circular progress indicator
class LoadingOverlay extends StatelessWidget {
  final double progress;
  final Animation<double> animation;

  const LoadingOverlay({
    super.key,
    required this.progress,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

