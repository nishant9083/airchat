import 'package:airchat/models/chat_user.dart';
import 'package:airchat/ui/calling_screen.dart';
import 'package:flutter/material.dart';

// Global service to manage the overlay
class DraggableOverlayService {
  static final DraggableOverlayService _instance =
      DraggableOverlayService._internal();
  factory DraggableOverlayService() => _instance;
  DraggableOverlayService._internal();

  OverlayEntry? _overlayEntry;
  Offset _position = Offset(900, 400);
  bool _isVisible = false;

  static GlobalKey<NavigatorState>? _navigatorKey;

  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  void showOverlay(ChatUser user) {
    if (_isVisible || _navigatorKey?.currentContext == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => DraggableOverlayPositioned(
        user: user,
        position: _position,
        onPositionChanged: (newPosition) {
          _position = newPosition;
          // Rebuild overlay to update position
          _overlayEntry?.markNeedsBuild();
        },
        onClose: hideOverlay,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey!.currentState!.overlay?.insert(_overlayEntry!);
      _isVisible = true;
    });
  }

  void hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isVisible = false;
  }
}
