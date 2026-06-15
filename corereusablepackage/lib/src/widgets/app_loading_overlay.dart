import 'package:flutter/material.dart';

/// Full-area loading spinner. Used as a body placeholder or as an overlay.
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({super.key, this.dim = false});

  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: dim ? Colors.black.withValues(alpha: 0.35) : null,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}
