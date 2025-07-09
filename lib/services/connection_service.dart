import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import 'lan_connection_service.dart';
import 'lan_peer.dart';

class ConnectionService {
  static final LanConnectionService _lan = LanConnectionService();
  

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

  static Stream<Map<String, dynamic
  >?> get fileTransferProgressStream =>
      _lan.fileTransferProgressStream;

  // Discovery/Advertising (LAN: only discovery is needed)
  static Future<void> startDiscovery() async {
    final settingsBox = Hive.box('settings');
    final userId = settingsBox.get('userId');
    final displayName = settingsBox.get('displayName', defaultValue: 'AirChatUser');
    // Use a fixed port or generate one if needed
    final tcpPort = settingsBox.get('tcpPort', defaultValue: 40402);
    await _lan.startService(userId: userId, name: displayName, tcpPort: tcpPort);
  }

  static Future<void> startServer()async{
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
  static Future<String> sendMessage(String id, String userId, String message) async {
    final peer = await _findConnectedPeerById(userId);
    if (peer == null) throw Exception('Peer not found');
    await _lan.sendMessage(id, peer, message);
    // Return a timestamp as a fake message ID for compatibility
    return DateTime.now().toIso8601String();
  }

  // Send a file to a peer
  static Future<String> sendFile(String id, String userId, String filePath, String fileName) async {
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