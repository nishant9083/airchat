import 'dart:async';
import 'package:airchat/models/chat_message.dart';
import 'package:airchat/models/chat_user.dart';
import 'package:airchat/services/calling_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'lan_connection_service.dart';
import 'lan_peer.dart';

class ConnectionService {
  static final LanConnectionService _lan = LanConnectionService();

  // Call signaling
  static final StreamController<Map<String, dynamic>> _callEventsController =
      StreamController.broadcast();
  static Stream<Map<String, dynamic>> get callEventsStream =>
      _callEventsController.stream;

  static Future<void> sendCallInvite(String userId, String id) async {
    await sendMessage(id, userId, '__CALL_INVITE__', 'call');
    _callEventsController
        .add({'type': 'call_outgoing', 'from': userId, 'id': id});
  }

  static Future<void> sendCallAccept(String userId) async {
    final id = DateTime.now().toIso8601String();
    await sendMessage(id, userId, '__CALL_ACCEPT__', 'call');
    _callEventsController
        .add({'type': 'call_accept_incoming', 'from': userId, 'id': id});
    final peer = await _findConnectedPeerById(userId);
    await LanCallService().startBidirectionalCall(peer!.ip);
  }

  static Future<void> sendCallReject(String userId) async {
    final id = DateTime.now().toIso8601String();
    await sendMessage(id, userId, '__CALL_REJECT__', 'call');
    // _callEventsController
    //     .add({'type': 'call_reject', 'from': userId, 'id': id});
  }

  static Future<void> sendCallEnd(String userId, String id) async {
    await sendMessage(id, userId, '__CALL_END__', 'call');
    // _callEventsController.add({'type': 'call_end', 'from': userId, 'id': id});
  }

  static Future<void> updateCallDuration(
      String userId, String id, String? duration, String message) async {
    final box = Hive.box<ChatUser>('chat_users');
    ChatUser? user = box.get(userId);
    if (user == null) {
      final peer = await _findConnectedPeerById(userId);
      user = ChatUser(
        id: userId,
        name: peer!.name,
        lastSeen: DateTime.now(),
        messages: [],
      );
      box.put(userId, user);
    }

    final msg = ChatMessage(
        id: id,
        senderId: message == 'Outgoing'? 'me': userId,
        text: message,
        timestamp: DateTime.now(),
        isMe: message == 'Outgoing'? true: false,
        type: 'call',
        isRead: true);
    if (duration != null) {
      msg.duration = duration;
    }
    user.messages.add(msg);
    user.lastSeen = DateTime.now();
    user.save();
  }

  // Listen for incoming call messages and add to callEventsStream
  static void listenForCallEvents() {
    messageEventsStream.listen((event) async {
      final msg = event['message'] as String?;
      final from = event['from'] as String?;
      final id = event['timestamp'] as String?;
      if (msg == '__CALL_INVITE__') {
        _callEventsController
            .add({'type': 'call_invite', 'from': from, 'id': id});
      } else if (msg == '__CALL_ACCEPT__') {
        final peer = await _findConnectedPeerById(from!);
        _callEventsController
            .add({'type': 'call_accept', 'from': from, 'id': id});
        await LanCallService().startBidirectionalCall(peer!.ip);
      } else if (msg == '__CALL_REJECT__') {          
        _callEventsController
            .add({'type': 'call_reject', 'from': from, 'id': id});
      } else if (msg == '__CALL_END__') {
        await LanCallService().endCall();
        _callEventsController.add({'type': 'call_end', 'from': from, 'id': id});
      }
    });
  }

  // Streams for UI compatibility
  static Stream<Map<String, dynamic>> get discoveredDevicesStream =>
      _lan.discoveredPeersStream.asyncExpand((peers) {
        if (peers.isEmpty) {
          return Stream.value({'type': 'off'});
        }
        return Stream.fromIterable(peers.map((peer) => {
              'type': 'found',
              'id': peer.userId,
              'name': peer.name,
              'ip': peer.ip,
              'port': peer.port,
            }));
      });

  static Stream<Map<String, dynamic>> get messageEventsStream =>
      _lan.messageEventStream;

  static Stream<Map<String, dynamic>> get fileEventsStream =>
      _lan.fileEventStream;

  static Stream<Map<String, dynamic>> get fileTransferProgressStream =>
      _lan.fileTransferProgressStream;

  // Discovery/Advertising (LAN: only discovery is needed)
  static Future<void> startDiscovery() async {
    final settingsBox = Hive.box('settings');
    final userId = settingsBox.get('userId');
    final displayName =
        settingsBox.get('displayName', defaultValue: 'AirChatUser');
    // Use a fixed port or generate one if needed
    final tcpPort = settingsBox.get('tcpPort', defaultValue: 40402);
    await _lan.startService(
        userId: userId, name: displayName, tcpPort: tcpPort);
  }

  static Future<void> startServer() async {
    await _lan.startServer();
  }

  static Future<void> stopDiscovery() async {
    _lan.stopService();
  }

  // Advertising is not needed for LAN, but keep for UI compatibility
  static Future<void> startAdvertising() async {
    // No-op for LAN
  }

  static Future<void> stopAdvertising() async {
    // No-op for LAN
  }

  // Connect to device (not needed for LAN, but keep for UI compatibility)
  static Future<void> connectToDevice(String userId) async {
    final peer = await _findPeerById(userId);
    if (peer == null) return;
    await _lan.connectToPeer(peer);
  }

  // Send a message to a peer
  static Future<String> sendMessage(
      String id, String userId, String message, String type) async {
    final peer = await _findConnectedPeerById(userId);
    if (peer == null) throw Exception('Peer not found');
    await _lan.sendMessage(id, peer, message, type);
    // Return a timestamp as a fake message ID for compatibility
    return DateTime.now().toIso8601String();
  }

  // Send a file to a peer
  static Future<String> sendFile(
      String id, String userId, String filePath, String fileName) async {
    final peer = await _findConnectedPeerById(userId);
    if (peer == null) throw Exception('Peer not found');
    await _lan.sendFile(id, peer, filePath, fileName: fileName);
    // Return a timestamp as a fake file ID for compatibility
    return DateTime.now().toIso8601String();
  }

  // Get connected users (for UI refresh)
  static Future<List<Map<String, dynamic>>> getConnectedUsers() async {
    // For LAN, all discovered peers are considered available
    final peers = _lan.discoveredPeers.value;
    return peers.map((p) => {'id': p.userId, 'name': p.name}).toList();
  }

  // Get discovered users (for UI refresh)
  static Future<List<Map<String, dynamic>>> getDiscoveredUsers() async {
    final peers = _lan.discoveredPeers.value;
    return peers.map((p) => {'id': p.userId, 'name': p.name}).toList();
  }

  // Helper to find a peer by userId
  static Future<LanPeer?> _findPeerById(String userId) async {
    final peers = _lan.discoveredPeers.value;
    try {
      return peers.firstWhere((p) => p.userId == userId);
    } catch (_) {
      return null;
    }
  }

  static Future<LanPeer?> _findConnectedPeerById(String userId) async {
    final peers = _lan.connectedPeers;
    try {
      return peers.firstWhere((p) => p.userId == userId);
    } catch (_) {
      return null;
    }
  }
}
