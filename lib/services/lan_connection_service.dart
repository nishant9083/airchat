// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:airchat/services/encryption_service.dart';
import 'package:flutter/foundation.dart';
import 'lan_peer.dart';
import 'base_connection_service.dart';
import 'package:uuid/uuid.dart';

import 'package:path_provider/path_provider.dart';

Future<String> getReceivedFilesDir() async {
  if (Platform.isAndroid) {
    // Use app document directory for mobile
    final dir = await getExternalStorageDirectory();
    return '${dir?.path}/received_files';
  } else if (Platform.isIOS) {
    // Use app document directory for mobile
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/received_files';
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Use user's home directory for desktop
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/received_files';
  } else {
    // Fallback to current directory
    return './received_files';
  }
}

// TLV type indicators
const int TYPE_CONN_INIT = 0x01;
const int TYPE_CHAT_MSG = 0x02;
const int TYPE_FILE_HEADER = 0x03;
const int TYPE_FILE_DATA = 0x04;
const int TYPE_FILE_END = 0x05;
const int TYPE_KEY_HANDSHAKE = 0x06;

class LanConnectionService implements BaseConnectionService {
  static final LanConnectionService _instance =
      LanConnectionService._internal();
  factory LanConnectionService() => _instance;
  LanConnectionService._internal();

  // Directory to save received files (set this from UI or use a default)
  late final Future<String> receivedFilesDir = getReceivedFilesDir();

  // UDP settings
  static const int udpPort = 40401;
  static const Duration broadcastInterval = Duration(seconds: 2);
  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;

  // Peer list
  final ValueNotifier<List<LanPeer>> discoveredPeers = ValueNotifier([]);

  // Local peer info
  late String userId;
  late String name;
  late int tcpPort;

  bool _isDiscovering = false;

  // TCP server
  ServerSocket? _serverSocket;
  final List<Socket> _clientSockets = [];
  final ValueNotifier<Map<String, dynamic>?> fileTransferProgress =
      ValueNotifier(null);

  // Persistent connections: userId -> Socket
  final Map<String, Socket> _connectedPeers = {};

  final _uuid = Uuid();

  // StreamControllers for new message and file events
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _fileController =
      StreamController.broadcast();

  // Expose streams for UI
  Stream<Map<String, dynamic>> get messageEventStream =>
      _messageController.stream;
  Stream<Map<String, dynamic>> get fileEventStream => _fileController.stream;

  // Expose connected peers
  List<LanPeer> get connectedPeers => _connectedPeers.keys.map((id) {
        return discoveredPeers.value.firstWhere((p) => p.userId == id,
            orElse: () => LanPeer(userId: id, name: id, ip: '', port: 0));
      }).toList();

  // Set of available peers (discovered, not connected)
  Set<String> get availablePeerIds =>
      Set.from(discoveredPeers.value.map((p) => p.userId))
        ..removeAll(_connectedPeers.keys);

  String? _cachedLocalIp;
  String? _cachedBroadcastIp;

  Future<String?> _getLocalIp() async {
    if (_cachedLocalIp != null) return _cachedLocalIp;
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          _cachedLocalIp = addr.address;
          return _cachedLocalIp;
        }
      }
    }
    return null;
  }

  Future<String?> _getBroadcastAddress() async {
    if (_cachedBroadcastIp != null) return _cachedBroadcastIp;

    final localIp = await _getLocalIp();
    if (localIp == null) {
      _cachedBroadcastIp = '255.255.255.255';
      log('No local IP found, using fallback broadcast: $_cachedBroadcastIp');
      return _cachedBroadcastIp;
    }

    // Parse the local IP to determine the subnet
    final ipParts = localIp.split('.');
    if (ipParts.length != 4) {
      _cachedBroadcastIp = '255.255.255.255';
      log('Invalid IP format, using fallback broadcast: $_cachedBroadcastIp');
      return _cachedBroadcastIp;
    }

    String broadcastIp;

    final thirdOctet = int.parse(ipParts[2]);
    broadcastIp = '${ipParts[0]}.${ipParts[1]}.$thirdOctet.255'; // assumes /24

    _cachedBroadcastIp = broadcastIp;
    log('Calculated broadcast address: $_cachedBroadcastIp for local IP: $localIp');
    return _cachedBroadcastIp;
  }

  Future<void> startDiscovery({
    required String userId,
    required String name,
    required int tcpPort,
  }) async {
    if (_isDiscovering) return;
    this.userId = userId;
    this.name = name;
    this.tcpPort = tcpPort;
    _isDiscovering = true;

    // Reset network cache when starting discovery
    _resetNetworkCache();

    // if (Platform.isAndroid || Platform.isIOS) {
    // Start UDP socket for listening
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort,
        reuseAddress: true);
    _udpSocket!.broadcastEnabled = true;
    _udpSocket!.listen(_onUdpPacket);
    // } else {
    //   // Start UDP socket for listening
    //   _udpSocket = await RawDatagramSocket.bind(
    //       InternetAddress.anyIPv4, udpPort,
    //       reuseAddress: true, reusePort: true);
    //   _udpSocket!.broadcastEnabled = true;
    //   _udpSocket!.listen(_onUdpPacket);
    // }

    // Start periodic broadcast
    _broadcastTimer =
        Timer.periodic(broadcastInterval, (_) => _broadcastPresence());
    log('Started Discovery');
  }

  void stopDiscovery() async {
    await _broadcastOff();
    _isDiscovering = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _udpSocket?.close();
    _udpSocket = null;
    discoveredPeers.value = [];
    log('Stopped Discovery');
  }

  void _broadcastPresence() async {
    try {
      if (_udpSocket == null) return;
      final data = jsonEncode({
        'type': 'discovery',
        'userId': userId,
        'name': name,
        'port': tcpPort,
      });
      final bytes = utf8.encode(data);

      // Get dynamic broadcast address
      final broadcastAddress = await _getBroadcastAddress();

      // Broadcast to local network
      _udpSocket!.send(bytes, InternetAddress(broadcastAddress!), udpPort);
    } catch (e) {
      log('Error in broadcasting: $e');
    }
  }

  Future<void> _broadcastOff() async {
    try {
      if (_udpSocket == null) return;
      final data = jsonEncode({
        'type': 'off',
        'userId': userId,
        'name': name,
        'port': tcpPort,
      });
      final bytes = utf8.encode(data);

      // Get dynamic broadcast address
      final broadcastAddress = await _getBroadcastAddress();

      // Broadcast to local network
      _udpSocket!.send(bytes, InternetAddress(broadcastAddress!), udpPort);
    } catch (e) {
      log('Error in broadcasting connection-off: $e');
    }
  }

  void _onUdpPacket(RawSocketEvent event) {
    try {
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket!.receive();
        if (datagram == null) return;
        try {
          final message = utf8.decode(datagram.data);
          final map = jsonDecode(message) as Map<String, dynamic>;
          if (map['type'] == 'discovery') {
            final peerUserId = map['userId'] as String;
            final peerName = map['name'] as String;
            final peerPort = map['port'] as int;
            final peerIp = datagram.address.address;

            _getLocalIp().then((localIp) async {
              if (peerUserId == userId && peerIp == localIp) {
                return;
              }
              final peer = LanPeer(
                  userId: peerUserId,
                  name: peerName,
                  ip: peerIp,
                  port: peerPort);
              final peers = List<LanPeer>.from(discoveredPeers.value);
              final existing = peers
                  .indexWhere((p) => p.userId == peerUserId && p.ip == peerIp);
              if (existing >= 0) {
                peers[existing] = peer;
              } else {
                peers.add(peer);
              }
              discoveredPeers.value = peers;
              // DO NOT connect here! Only add to available set.
            });
          } else if (map['type'] == 'off') {
            // Remove the peer from discoveredPeers whose userId matches map['userId']
            final peerUserId = map['userId'] as String?;
            if (peerUserId != null) {
              final peers = List<LanPeer>.from(discoveredPeers.value);
              peers.removeWhere((p) => p.userId == peerUserId);
              discoveredPeers.value = peers;
            }
          }
        } catch (e) {
          log('Error parsing UDP packet: $e');
        }
      }
    } catch (e) {
      log('Error in UDP Parsing: $e');
    }
  }

  // Method to clear cached broadcast address (call this when network changes)
  void _clearCachedBroadcastAddress() {
    _cachedBroadcastIp = null;
    _cachedLocalIp = null;
    log('Cleared cached broadcast and local IP addresses');
  }

  // Call this when network changes or when starting discovery
  void _resetNetworkCache() {
    _clearCachedBroadcastAddress();
  }

  Future<void> startServer() async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);
      _serverSocket!.listen((client) {
        final myTimestamp = DateTime.now().millisecondsSinceEpoch;
        _arbitrateAndHandleSocket(client, isOutgoing: false, myTimestamp: myTimestamp);
      });
      log('Started Server');
    } catch (e) {
      log("Error in Starting Server: $e");
    }
  }

  void stopServer() {
    _serverSocket?.close();
    _serverSocket = null;
    for (var socket in _clientSockets) {
      socket.destroy();
    }
    _clientSockets.clear();
    log('Stopped Server');
  }

  // Unified arbitration and socket handler (single listen)
  Future<void> _arbitrateAndHandleSocket(Socket socket,
      {required bool isOutgoing, LanPeer? peer, required int  myTimestamp}) async {
    try {      
      print(myTimestamp);
      final myConnId = _uuid.v4();
      final myInit = {
        'type': 'connection-init',
        'userId': userId,
        'connectionId': myConnId,
        'timestamp': myTimestamp,
      };
      _sendTLV(socket, TYPE_CONN_INIT, utf8.encode(jsonEncode(myInit)));

      List<int> buffer = [];      
      String? theirUserId;
      IOSink? fileSink;
      int? fileSize;
      int received = 0;
      String? receivingFileId;
      String? fileName;
      String? nonce;
      String? mac;
      File? tempFile;
      File? outFile;
      bool receivingFile = false;

      socket.listen((data) async {
        buffer.addAll(data);
        while (buffer.length >= 5) {
          // At least type + length
          int type = buffer[0];
          int len = (buffer[1] << 24) |
              (buffer[2] << 16) |
              (buffer[3] << 8) |
              buffer[4];
          if (buffer.length < 5 + len) break; // Wait for more data
          List<int> value = buffer.sublist(5, 5 + len);
          buffer = buffer.sublist(5 + len);
          if (type == TYPE_CONN_INIT) {
            final map = jsonDecode(utf8.decode(value)) as Map<String, dynamic>;
            
            theirUserId = map['userId'] as String;
            
            if (!_connectedPeers.containsKey(theirUserId)) {
              _connectedPeers[theirUserId!] = socket;

              // ECDH key pair + public key
              await EncryptionService().generateKeyPair();
              final myPublicKey =
                  await EncryptionService().getPublicKeyBase64();
              log('pubkey: $myPublicKey');
              _sendTLV(socket, TYPE_KEY_HANDSHAKE, utf8.encode(myPublicKey));
            } else {
              socket.destroy();
              return;
            }
          } else if (type == TYPE_KEY_HANDSHAKE) {
            final peerKey = utf8.decode(value);
            EncryptionService().setPeerPublicKeyFromBase64(peerKey);
            await EncryptionService().deriveSharedKey();
          } else if (type == TYPE_CHAT_MSG) {
            final enc = jsonDecode(utf8.decode(value)) as Map<String, dynamic>;
            final decrypted = await EncryptionService().decrypt(
              nonce: enc['nonce']!,
              cipherText: enc['cipherText']!,
              mac: enc['mac']!,
            );
            final map = jsonDecode(utf8.decode(decrypted));
            // Emit only the new message event
            _messageController.add(map);
          } else if (type == TYPE_FILE_HEADER) {
            final map = jsonDecode(utf8.decode(value)) as Map<String, dynamic>;
            fileName = map['fileName'] as String;
            fileSize = map['fileSize'] as int;
            receivingFileId = map['timestamp'] as String;
            nonce = map['nonce'];
            mac = map['mac'];
            // Temp File
            final dir = Directory.systemTemp;
            if (!await dir.exists()) await dir.create(recursive: true);
            tempFile = File('${dir.path}/$fileName');
            fileSink = tempFile!.openWrite();
            receivingFile = true;
            received = 0;
            //Output file
            final outDir = Directory(await receivedFilesDir);
            if (!await outDir.exists()) await outDir.create(recursive: true);
            outFile = File('${outDir.path}/$fileName');
            map.addEntries([MapEntry('filePath', outFile!.path)]);
            // Emit only the new file event
            _fileController.add(map);
          } else if (type == TYPE_FILE_DATA) {
            if (fileSink != null && receivingFile) {
              fileSink!.add(value);
              received += value.length;
              if (fileSize != null && fileSize! > 0) {
                fileTransferProgress.value = {
                  'id': receivingFileId!,
                  'progress': received / fileSize!,
                  'status': 3
                };
              }
            }
          } else if (type == TYPE_FILE_END) {
            await fileSink?.flush();
            await fileSink?.close();

            final encryptedBytes = await tempFile!.readAsBytes();

            // Call decrypt
            try {
              final decryptedBytes = await EncryptionService().decrypt(
                nonce: nonce!,
                cipherText: base64Encode(encryptedBytes),
                mac: mac!,
              );

              // Save decrypted file
              await outFile!.writeAsBytes(decryptedBytes);
              fileTransferProgress.value = {
                'id': receivingFileId!,
                'progress': 1.0,
                'status': 1
              };
            } catch (e) {
              fileTransferProgress.value = {
                'id': receivingFileId!,
                'progress': 0,
                'status': 2
              };
            }
            // Delete temp file
            await tempFile!.delete();
            fileSink = null;
            tempFile = null;
            outFile = null;
            receivingFile = false;
            fileSize = null;
            fileName = null;
            received = 0;
            receivingFileId = null;
            mac = null;
            nonce = null;
            fileTransferProgress.value = null;
          }
        }
      }, onDone: () async {
        if (fileSink != null) await fileSink!.close();
        _clientSockets.remove(socket);
        if (theirUserId != null) _connectedPeers.remove(theirUserId);
        socket.destroy();
      }, onError: (_) async {
        if (fileSink != null) await fileSink!.close();
        _clientSockets.remove(socket);
        if (theirUserId != null) _connectedPeers.remove(theirUserId);
        socket.destroy();
      });
    } catch (e) {
      log('Error in packet parsing: $e');
    }
  }

  // Helper to convert ValueNotifier to Stream (for discoveredPeers, fileTransferProgress, etc.)
  Stream<T> _notifierStream<T>(ValueNotifier<T> notifier) {
    final controller = StreamController<T>.broadcast();
    controller.add(notifier.value);
    void listener() => controller.add(notifier.value);
    notifier.addListener(listener);
    controller.onCancel = () => notifier.removeListener(listener);
    return controller.stream;
  }

  // Send a message to a peer over persistent connection
  Future<void> _sendMessageInternal(
      String id, LanPeer peer, Map<String, dynamic> message) async {
    final socket = _connectedPeers[peer.userId];
    if (socket != null) {
      final encryptedMap =
          await EncryptionService().encrypt(utf8.encode(jsonEncode(message)));
      final encryptedJson = jsonEncode(encryptedMap);
      _sendTLV(socket, TYPE_CHAT_MSG, utf8.encode(encryptedJson));
      log('Sent message to ${peer.userId}: ${message['message']}');
    } else {
      // Optionally, try to connect and resend
      throw Exception('Not connected to peer');
    }
  }

  // Send a file to a peer over persistent connection
  Future<void> _sendFileInternal(String id, LanPeer peer, String filePath,
      {String? fileName}) async {
    final socket = _connectedPeers[peer.userId];
    if (socket == null) throw Exception('Not connected to peer');
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File does not exist');
    final fName = fileName ?? file.uri.pathSegments.last;

    final plainBytes = await file.readAsBytes();
    final encryptedMap = await EncryptionService().encrypt(plainBytes);

    final encryptedBytes = base64Decode(encryptedMap['cipherText']!);
    final nonce = encryptedMap['nonce']!;
    final mac = encryptedMap['mac']!;

    final size = encryptedBytes.length;
    final header = {
      'type': 'file',
      'from': userId,
      'name': name,
      'fileName': fName,
      'fileSize': size,
      'nonce': nonce,
      'mac': mac,
      'fileType': getFileTypeFromPath(filePath),
      'timestamp': DateTime.now().toIso8601String(),
    };
    _sendTLV(socket, TYPE_FILE_HEADER, utf8.encode(jsonEncode(header)));
    // final raf = file.openRead();
    int sent = 0;
    const chunkSize = 8192;
    for (int i = 0; i < encryptedBytes.length; i += chunkSize) {
      final end = (i + chunkSize < encryptedBytes.length)
          ? i + chunkSize
          : encryptedBytes.length;
      final chunk = encryptedBytes.sublist(i, end);
      _sendTLV(socket, TYPE_FILE_DATA, chunk);

      sent += chunk.length;
      Map<String, dynamic> progressMap = {
        'id': id,
        'progress': sent / size,
        'status': 3
      };

      fileTransferProgress.value = progressMap;
    }
    _sendTLV(socket, TYPE_FILE_END, []);
    fileTransferProgress.value = {'id': id, 'progress': 1.0, 'status': 1};
    fileTransferProgress.value = null;
  }

  // Call this when starting the service
  Future<void> startLanService({
    required String userId,
    required String name,
    required int tcpPort,
  }) async {
    await startDiscovery(userId: userId, name: name, tcpPort: tcpPort);
    // await startServer(); // Added this line to start TCP server
  }

  void stopLanService() {
    stopDiscovery();
    // stopServer();
  }

  // BaseConnectionService interface implementation
  @override
  Future<void> startService(
      {required String userId,
      required String name,
      required int tcpPort}) async {
    await startLanService(userId: userId, name: name, tcpPort: tcpPort);
  }

  @override
  void stopService() {
    stopLanService();
  }

  @override
  Stream<List<dynamic>> get discoveredPeersStream =>
      _notifierStream(discoveredPeers);

  @override
  Stream<Map<String, dynamic>?> get fileTransferProgressStream =>
      _notifierStream(fileTransferProgress);

  @override
  Future<void> sendMessage(String id, dynamic peer, String message, String? type) async {
    if (peer is LanPeer) {
      await _sendMessageInternal(id, peer, {
        'type': type??'message',
        'from': userId,
        'name': name,
        'message': message,
        'timestamp': id,
      });
    } else {
      throw Exception('Invalid peer type');
    }
  }

  @override
  Future<void> sendFile(String id, dynamic peer, String filePath,
      {String? fileName}) async {
    if (peer is LanPeer) {
      await _sendFileInternal(id, peer, filePath, fileName: fileName);
    } else {
      throw Exception('Invalid peer type');
    }
  }

  // Connect to a peer (called when user opens chat)
  Future<void> connectToPeer(LanPeer peer) async {
    if (_connectedPeers.containsKey(peer.userId)) return; // Already connected
    try {
      final myTimestamp = DateTime.now().millisecondsSinceEpoch;
      final socket = await Socket.connect(peer.ip, peer.port);
      await _arbitrateAndHandleSocket(socket,
          isOutgoing: true, peer: peer, myTimestamp: myTimestamp);
    } catch (e) {
      log('Error in connection: $e');
    }
  }

  // Helper to send TLV message
  void _sendTLV(Socket socket, int type, List<int> value) {
    final lenBytes = [
      (value.length >> 24) & 0xFF,
      (value.length >> 16) & 0xFF,
      (value.length >> 8) & 0xFF,
      value.length & 0xFF,
    ];
    socket.add([type, ...lenBytes, ...value]);
  }

  String getFileTypeFromPath(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    const imageExts = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'heic',
      'heif',
      'tiff'
    ];
    const videoExts = [
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
      'flv',
      'wmv',
      '3gp',
      'm4v'
    ];
    const audioExts = [
      'mp3',
      'wav',
      'aac',
      'ogg',
      'm4a',
      'flac',
      'amr',
      'opus',
      'wma',
      'aiff',
      'alac'
    ];
    if (imageExts.contains(ext)) {
      return 'image';
    } else if (videoExts.contains(ext)) {
      return 'video';
    } else if (audioExts.contains(ext)) {
      return 'audio';
    } else {
      return 'file';
    }
  }

  @override
  Stream<Map<String, dynamic>> get messageStream => messageEventStream;
}
