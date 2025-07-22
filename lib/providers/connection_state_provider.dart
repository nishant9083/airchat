import 'package:flutter/material.dart';
import '../services/lan_connection_service.dart';
import '../services/lan_peer.dart';

class ConnectionStateProvider extends ChangeNotifier {
  final Map<String, String> discovered = {}; // userId -> name
  String? inChatUserId;
  bool discovering = false;
  AppLifecycleState appState = AppLifecycleState.resumed;

  // Use LAN backend's connected peers
  List<LanPeer> get connectedPeers => LanConnectionService().connectedPeers;

  void setAppState(AppLifecycleState state){
    appState = state;
    notifyListeners();
  }

  void setInChatUserId(String? userId) {
    inChatUserId = userId;
    notifyListeners();
  }

  void setDiscovering(bool value) {
    discovering = value;
    notifyListeners();
  }

  void setDiscovered(String userId, String name) {
    discovered[userId] = name;
    notifyListeners();
  }

  void removeDiscovered(String userId) {
    discovered.remove(userId);
    notifyListeners();
  }

  void clearAll() {
    discovered.clear();
    notifyListeners();
  }
} 