import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

class NotificationUtil {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Call this once in main() before runApp
  static Future<void> initialize() async {
    if (_initialized) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
      windows: WindowsInitializationSettings(
          appName: 'AirChat',
          appUserModelId: 'com.airchat.app',
          guid: Uuid().v4(),
          iconPath: 'assets/icon/icon.png'),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap if needed
      },
    );
    _initialized = true;
  }

  /// Show a simple notification (e.g., for message)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'default_channel',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      color: Color(0xFF0072CE),

    );
    final WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails(
      // images: [
      //   WindowsImage(WindowsImage.getAssetUri('assets/icon/icon.png'), altText: 'icon'),
      // ],
    );
    final NotificationDetails details =
        NotificationDetails(android: androidDetails, windows: windowsDetails);
    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// Show an incoming call notification (optionally full-screen on Android)
  static Future<void> showIncomingCall({
    required int id,
    required String callerName,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'call_channel',
      'Calls',
      channelDescription: 'Incoming call notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      fullScreenIntent: true,      
    );
    final WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails(
      duration: WindowsNotificationDuration.long
    );
    final NotificationDetails details =
        NotificationDetails(android: androidDetails, windows: windowsDetails);
    await _plugin.show(id, 'Incoming Call', 'Call from $callerName', details,
        payload: payload);
  }

  /// Cancel a notification by id
  static Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
