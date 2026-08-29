
import 'package:flutter/material.dart';

class LoggerService {
  LoggerService._();

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('🛑 [ERROR] $message');
    if (error != null) {
      debugPrint('   Details: $error');
    }
    if (stackTrace != null) {
      debugPrint('   StackTrace:\n$stackTrace');
    }
    // TODO: Send to Crashlytics or Askaria backend in production
  }

  static void warning(String message, [dynamic error]) {
    debugPrint('⚠️ [WARN] $message');
    if (error != null) {
      debugPrint('   Details: $error');
    }
  }

  static void info(String message) {
    debugPrint('ℹ️ [INFO] $message');
  }

  /// Affiche un SnackBar en cas d'erreur bloquante pour l'utilisateur
  static void showUserError(BuildContext context, String userMessage) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userMessage),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
