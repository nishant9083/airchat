import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final X25519 _keyExchangeAlgorithm = X25519();
  SimpleKeyPair? _keyPair;
  SimplePublicKey? _peerPublicKey;
  SecretKey? _sharedAesKey;

  /// Step 1: Generate a new ECDH key pair
  Future<SimpleKeyPair> generateKeyPair() async {
    _keyPair = await _keyExchangeAlgorithm.newKeyPair();
    return _keyPair!;
  }

  /// Step 2: Export public key for sharing
  Future<String> getPublicKeyBase64() async {
    final publicKey = await _keyPair!.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Step 3: Receive and set the peer's public key
  void setPeerPublicKeyFromBase64(String base64Key) {
    final bytes = base64Decode(base64Key);
    _peerPublicKey = SimplePublicKey(bytes, type: KeyPairType.x25519);
  }

  /// Step 4: Derive the shared AES key (256-bit)
  Future<void> deriveSharedKey() async {
    if (_keyPair == null || _peerPublicKey == null) {
      throw Exception('Missing key pair or peer public key');
    }

    final sharedSecret = await _keyExchangeAlgorithm.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: _peerPublicKey!,
    );

    // Extract the bytes of the shared secret
    final sharedSecretBytes = await sharedSecret.extractBytes();
    if (sharedSecretBytes.isEmpty) {
      throw Exception('Derived shared secret is empty');
    }

    _sharedAesKey = await Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    ).deriveKey(
      secretKey: SecretKey(sharedSecretBytes),
      nonce: [1], // Use a non-empty nonce to avoid ArgumentError
    );
  }

  /// Encrypt a message (text or file bytes)
  Future<Map<String, String>> encrypt(Uint8List plainBytes) async {
    if (_sharedAesKey == null) throw Exception('AES key not derived');

    final aes = AesGcm.with256bits();
    final encrypted = await aes.encrypt(
      plainBytes,
      secretKey: _sharedAesKey!,
    );

    return {
      'nonce': base64Encode(encrypted.nonce),
      'cipherText': base64Encode(encrypted.cipherText),
      'mac': base64Encode(encrypted.mac.bytes),
    };
  }

  /// Decrypt a received message
  Future<List<int>> decrypt({
    required String nonce,
    required String cipherText,
    required String mac,
  }) async {
    if (_sharedAesKey == null) throw Exception('AES key not derived');

    final aes = AesGcm.with256bits();
    final box = SecretBox(
      base64Decode(cipherText),
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );

    return await aes.decrypt(box, secretKey: _sharedAesKey!);
  }

  /// Reset state (for testing or re-handshake)
  void reset() {
    _keyPair = null;
    _peerPublicKey = null;
    _sharedAesKey = null;
  }
}
