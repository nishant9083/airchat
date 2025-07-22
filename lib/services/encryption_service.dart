import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

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
  Future<Map<String, dynamic>> encrypt(Uint8List plainBytes,
      {bool inNewThread = false}) async {
    if (_sharedAesKey == null) throw Exception('AES key not derived');

    final aes = AesGcm.with256bits();

    Future<SecretBox> encryptInIsolate() async {
      return await aes.encrypt(
        plainBytes,
        secretKey: _sharedAesKey!,
      );
    }

    final encrypted = inNewThread
        ? await Isolate.run(() => encryptInIsolate())
        : await aes.encrypt(plainBytes, secretKey: _sharedAesKey!);

    return {
      'nonce': base64Encode(encrypted.nonce),
      'cipherText': encrypted.cipherText,
      'mac': base64Encode(encrypted.mac.bytes),
    };
  }

  /// Encrypt a stream message (text or file bytes) and return a stream of encrypted bytes.
  /// The returned stream emits the encrypted bytes as they become available.
  /// The nonce is returned immediately, and the MAC is provided via the [onMac] callback when available.
  ///
  /// Usage:
  ///   final stream = encryptStream(
  ///     plainBytes,
  ///     onMac: (mac, nonce) {
  ///       // Use mac and nonce when available
  ///     },
  ///   );
  ///   // stream is Stream`<List<int>>`
  Stream<List<int>> encryptStream(
    Stream<List<int>> plainBytes, {
    required void Function(String mac, String nonce) onMac,
  }) {
    if (_sharedAesKey == null) throw Exception('AES key not derived');

    final aes = AesGcm.with256bits();
    final nonce = aes.newNonce();

    final secretBoxStream = aes.encryptStream(
      plainBytes,
      secretKey: _sharedAesKey!,
      nonce: nonce,
      onMac: (Mac m) {
        onMac(base64Encode(m.bytes), base64Encode(nonce));
      },
    );

    // The stream emits List<int> (cipherText chunks)
    return secretBoxStream;
  }

  /// Decrypt a received message
  Future<List<int>> decrypt(
      {required String nonce,
      required List<int> cipherText,
      required String mac,
      bool isNewThread = false}) async {
    if (_sharedAesKey == null) throw Exception('AES key not derived');

    final aes = AesGcm.with256bits();
    final box = SecretBox(
      cipherText,
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );

    Future<List<int>> decryptInIsolate() async {
      return await aes.decrypt(box, secretKey: _sharedAesKey!);
    }

    return isNewThread
        ? await Isolate.run(() => decryptInIsolate())
        : await aes.decrypt(box, secretKey: _sharedAesKey!);
  }

  /// Decrypts a stream of encrypted data chunks (cipherText) using the current shared AES key.
  ///
  /// [cipherTextStream] is a stream of encrypted bytes (cipherText).
  /// [nonce] and [mac] are required for decryption and should be provided as base64 strings.
  /// Returns a stream of decrypted bytes.
  Stream<List<int>> decryptStream({
    required Stream<List<int>> cipherTextStream,
    required String nonce,
    required String mac,
  }) {
    if (_sharedAesKey == null) throw Exception('AES key not derived');

    final aes = AesGcm.with256bits();
    return aes.decryptStream(
      cipherTextStream,
      secretKey: _sharedAesKey!,
      nonce: base64Decode(nonce),
      mac: Mac(base64Decode(mac)),
    );
  }

  /// Reset state (for testing or re-handshake)
  void reset() {
    _keyPair = null;
    _peerPublicKey = null;
    _sharedAesKey = null;
  }
}
