import 'package:flutter/material.dart';

class SnackbarUtils {
  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.red.shade700, Icons.error_outline);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, Colors.orange.shade800, Icons.warning_amber_rounded);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green.shade700, Icons.check_circle_outline);
  }

  // 🔥 ДОДАНО: Метод для інформаційних повідомлень (для чату)
  static void showInfo(BuildContext context, String message) {
    _show(context, message, Colors.blue.shade700, Icons.info_outline);
  }

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(16),
          elevation: 6,
          duration: const Duration(seconds: 2), // Трохи зменшив час (було 4), щоб не заважало в чаті
        ),
      );
    } catch (e) {
      debugPrint("Snackbar error: $e");
    }
  }
}