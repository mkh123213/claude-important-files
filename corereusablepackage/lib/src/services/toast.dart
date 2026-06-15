import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ToastType { info, success, error }

/// Shows a lightweight toast/snackbar. UI layer calls this after translating
/// a message or error key.
void showToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
}) {
  final color = switch (type) {
    ToastType.success => AppColors.success,
    ToastType.error => AppColors.danger,
    ToastType.info => AppColors.darkCard,
  };
  final icon = switch (type) {
    ToastType.success => Icons.check_circle_outline,
    ToastType.error => Icons.error_outline,
    ToastType.info => Icons.info_outline,
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        elevation: 2,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
}
