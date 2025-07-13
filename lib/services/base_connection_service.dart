abstract class BaseConnectionService {
  Future<void> startService(
      {required String userId, required String name, required int tcpPort});
  void stopService();

  Stream<List<dynamic>> get discoveredPeersStream;
  Stream<Map<String, dynamic>> get messageStream;
  Stream<Map<String, dynamic>?> get fileTransferProgressStream;

  Future<void> sendMessage(String id, dynamic peer, String message, String? type);
  Future<void> sendFile(String id, dynamic peer, String filePath, {String? fileName});
}
