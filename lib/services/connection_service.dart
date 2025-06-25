import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:hive/hive.dart';

class ConnectionService {
  static const MethodChannel _channel = MethodChannel('airchat/connection');
  static const EventChannel _discoveryEvents = EventChannel('airchat/discoveryEvents');
  static const EventChannel _messageEvents = EventChannel('airchat/messageEvents');
  static const EventChannel _connectionEvents = EventChannel('airchat/connectionEvents');

  static Stream<Map<dynamic, dynamic>> get discoveredDevicesStream {
    return _discoveryEvents.receiveBroadcastStream().map((event) => Map<dynamic, dynamic>.from(event));
  }

  static Stream<Map<dynamic, dynamic>> get messageEventsStream {
    return _messageEvents.receiveBroadcastStream().map((event) => Map<dynamic, dynamic>.from(event));
  }

  static Stream<Map<dynamic, dynamic>> get connectionEventsStream {
    return _connectionEvents.receiveBroadcastStream().map((event) => Map<dynamic, dynamic>.from(event));
  }

  static Future<void> _ensurePermissions() async {
    final status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      final result = await Permission.locationWhenInUse.request();
      if (!result.isGranted) {
        throw Exception('Location permission is required for device discovery.');
      }
    }
    // Optionally check Bluetooth/Wi-Fi permissions if needed
  }

  static Future<void> startDiscovery() async {
    await _ensurePermissions();
    final settingsBox = Hive.box('settings');
    final userId = settingsBox.get('userId');
    final displayName = settingsBox.get('displayName', defaultValue: 'AirChatUser');
    await _channel.invokeMethod('startDiscovery', {'userId': userId, 'name': displayName});
  }

  static Future<void> stopDiscovery() async {
    await _channel.invokeMethod('stopDiscovery');
  }

  static Future<void> startAdvertising() async {
    await _ensurePermissions();
    final settingsBox = Hive.box('settings');
    final userId = settingsBox.get('userId');
    final displayName = settingsBox.get('displayName', defaultValue: 'AirChatUser');
    final endpointInfo = jsonEncode({'name': displayName, 'userId': userId});
    await _channel.invokeMethod('startAdvertising', {'endpointInfo': endpointInfo});
  }

  static Future<void> stopAdvertising() async {
    await _channel.invokeMethod('stopAdvertising');
  }

  static Future<void> connectToDevice(String userId) async {
    await _channel.invokeMethod('connectToDevice', {'userId': userId});
  }

  static Future<void> sendMessage(String userId, String message) async {
    await _channel.invokeMethod('sendMessage', {'userId': userId, 'message': message});
  }

  static Future<String?> testNative() async {
    return await _channel.invokeMethod<String>('testNative');
  }
} 