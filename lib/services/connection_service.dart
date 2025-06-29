import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class ConnectionService {
  static const MethodChannel _channel = MethodChannel('airchat/connection');
  static const EventChannel _discoveryChannel = EventChannel('airchat/discoveryEvents');
  static const EventChannel _messageChannel = EventChannel('airchat/messageEvents');
  static const EventChannel _connectionChannel = EventChannel('airchat/connectionEvents');
  static const EventChannel _fileChannel = EventChannel('airchat/fileEvents');
  static const EventChannel _fileProgressChannel = EventChannel('airchat/fileTransferProgressEvents');

  static Stream<Map<String, dynamic>> get discoveredDevicesStream => _discoveryChannel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event));
  static Stream<Map<String, dynamic>> get messageEventsStream => _messageChannel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event));
  static Stream<Map<String, dynamic>> get connectionEventsStream => _connectionChannel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event));
  static Stream<Map<String, dynamic>> get fileEventsStream => _fileChannel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event));
  static Stream<Map<String, dynamic>> get fileTransferProgressStream => _fileProgressChannel.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event));

  static bool _isRequestingPermission = false;

  static Future<void> _ensurePermissions() async {
    if (_isRequestingPermission) return; // Prevent multiple requests
    try{
    _isRequestingPermission = true;
    final status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      final result = await Permission.locationWhenInUse.request();
      if (!result.isGranted) {
        throw Exception('Location permission is required for device discovery.');
      }
    }}
    catch (e) {
      // Handle any exceptions that occur during permission request
      if (kDebugMode) {
        print('Error requesting permissions: $e');
      }
      throw Exception('Failed to request necessary permissions.');
    }
    finally {
      _isRequestingPermission = false;
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

  static Future<int> sendMessage(String userId, String message) async {
    final result = await _channel.invokeMethod('sendMessage', {'userId': userId, 'message': message});
    return result as int;
  }

  static Future<int> sendFile(String userId, String filePath, String fileName) async {
    final result = await _channel.invokeMethod('sendFile', {'userId': userId, 'filePath': filePath, 'fileName': fileName});
    return result as int;
  }

  static Future<String?> getEndpointIdForUserId(String userId) async {
    final result = await _channel.invokeMethod('getEndpointIdForUserId', {'userId': userId});
    return result as String?;
  }

  // New methods for getting connection state
  static Future<List<Map<String, dynamic>>> getConnectedUsers() async {
    try {
      final result = await _channel.invokeMethod('getConnectedUsers');
      print('Connected users: $result');
      if (result != null) {
        return List<Map<String, dynamic>>.from(
            (result as List).map((e) => Map<String, dynamic>.from(e as Map))
        );
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting connected users: $e');
      }
      return [];
    }
  }

 static Future<List<Map<String, dynamic>>> getDiscoveredUsers() async {
    try {
      final result = await _channel.invokeMethod('getDiscoveredUsers');
      print(result);
      if (result != null) {
        return List<Map<String, dynamic>>.from(
          (result as List).map((e) => Map<String, dynamic>.from(e as Map))
        );
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting discovered users: $e');
      }
      return [];
    }
  }
} 