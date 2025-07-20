import 'package:flutter/material.dart';

class SnackbarUtil {
  /// Shows a [SnackBar] with the given [message].
  ///
  /// [context] is required. Optionally customize [backgroundColor], [duration], and [action].
  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    final isDesktop = [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ].contains(Theme.of(context).platform);

    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontSize: isDesktop ? 14 : null,
          color: Colors.white
        ),
      ),
      backgroundColor: backgroundColor ?? Colors.indigo[600],
      duration: duration,
      action: action,
      behavior: SnackBarBehavior.floating,
      margin: isDesktop
          ? const EdgeInsets.symmetric(horizontal: 400, vertical: 24)
          : null,
      shape: isDesktop
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      elevation: isDesktop ? 8 : null,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
} 