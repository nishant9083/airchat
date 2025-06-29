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
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: backgroundColor ?? Colors.indigo[600],
      duration: duration,
      action: action,
      behavior: SnackBarBehavior.floating,
    );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
} 