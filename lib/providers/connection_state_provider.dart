import 'package:flutter/material.dart';

class ConnectionStateProvider extends ChangeNotifier {
  final Map<String, String> discovered = {}; // userId -> name
  final Set<String> connected = {}; // userIds currently connected
  final Set<String> connecting = {}; // userIds currently connecting
  bool discovering = false;
  bool advertising = false;
  String? inChatUserId;


  void setInChatUserId(String? userId) {
    inChatUserId = userId;
    notifyListeners();
  }

  void setDiscovering(bool value) {
    discovering = value;
    notifyListeners();
  }

  void setAdvertising(bool value) {
    advertising = value;
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

  void setConnected(String userId) {
    connected.add(userId);
    connecting.remove(userId);
    notifyListeners();
  }

  void setConnecting(String userId) {
    connecting.add(userId);
    notifyListeners();
  }

  void setDisconnected(String userId) {
    connected.remove(userId);
    connecting.remove(userId);
    notifyListeners();
  }

  void clearAll() {
    discovered.clear();
    connected.clear();
    connecting.clear();
    notifyListeners();
  }
} 