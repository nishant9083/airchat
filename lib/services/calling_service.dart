import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:audio_session/audio_session.dart';

// --- LivePcmAudioSource for real-time streaming ---
class LivePcmAudioSource extends StreamAudioSource {
  final int sampleRate;
  final int channels;
  final bool forStreaming;
  bool _headerInjected = false;
  final StreamController<List<int>> _streamController =
      StreamController<List<int>>.broadcast();

  LivePcmAudioSource({
    this.sampleRate = 44100,
    this.channels = 2,
    this.forStreaming = true,
  });

  /// Call this to inject a new chunk of PCM data.
  void addData(Uint8List pcmChunk) {
    if (!_headerInjected) {
      final header = _createWavHeader(
        sampleRate: sampleRate,
        channels: channels,
        bitsPerSample: 16,
        pcmDataLength: pcmChunk.length, // can be 0 or placeholder for streaming
        forStreaming: true,
      );
      _streamController.add(Uint8List.fromList([...header, ...pcmChunk]));
      _headerInjected = true;
      return;
    }

    _streamController.add(pcmChunk);
  }

  /// Generates a standard WAV header (RFC-compliant).
  List<int> _createWavHeader({
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
    required int pcmDataLength,
    bool forStreaming = false,
  }) {
    final byteRate = (sampleRate * channels * bitsPerSample) ~/ 8;
    final blockAlign = (channels * bitsPerSample) ~/ 8;
    final dataSize = forStreaming ? 0xFFFFFFFF : pcmDataLength;
    final fileSize = forStreaming ? 0xFFFFFFFF : (pcmDataLength + 36);

    return [
      ...ascii.encode('RIFF'),
      ..._intToLE(fileSize, 4),
      ...ascii.encode('WAVE'),
      ...ascii.encode('fmt '),
      ..._intToLE(16, 4),
      ..._intToLE(1, 2),
      ..._intToLE(channels, 2),
      ..._intToLE(sampleRate, 4),
      ..._intToLE(byteRate, 4),
      ..._intToLE(blockAlign, 2),
      ..._intToLE(bitsPerSample, 2),
      ...ascii.encode('data'),
      ..._intToLE(dataSize, 4),
    ];
  }

  List<int> _intToLE(int value, int length) {
    return List.generate(length, (i) => (value >> (8 * i)) & 0xFF);
  }

  Future<void> close() async {
    await _streamController.close();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: null,
      stream: _streamController.stream,
      contentType: 'audio/wav',
    );
  }
}

class LanCallService {
// 1. Private constructor
  LanCallService._privateConstructor();

  // 2. The single instance
  static final LanCallService _instance = LanCallService._privateConstructor();

  // 3. Factory constructor returns the same instance
  factory LanCallService() {
    return _instance;
  }

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  RawDatagramSocket? _udpSocket;
  InternetAddress? _targetAddress;
  RawDatagramSocket? _receiveSocket;
  RawDatagramSocket? _sendSocket;
  final int _port = 5555;
  bool _isActive = false;
  LivePcmAudioSource? _liveSource;
  StreamSubscription? _micSub;

  /// Request microphone permission, throw if denied
  Future<void> _ensureMicPermission() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<void> startBidirectionalCall(String targetIp) async {
    try {
      await _ensureMicPermission();
      _targetAddress = InternetAddress(targetIp);
      _sendSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _receiveSocket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);

      _isActive = true;

      // Start recording and sending
      _recorder
          .startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits))
          .then((stream) {
        _micSub = stream.listen(
          (chunk) {
            if (_isActive && _targetAddress != null) {
              _sendSocket?.send(chunk, _targetAddress!, _port);
            }
          },
          onDone: () => log('done streaming'),
        );
      });

      _liveSource = LivePcmAudioSource();

      // Start receiving and playing
      _receiveSocket!.listen((event) async {
        if (event == RawSocketEvent.read) {
          final datagram = _receiveSocket!.receive();
          if (datagram != null) {
            _liveSource?.addData(datagram.data);
          }
        }
      });
      await _player.setAudioSource(
        _liveSource!,
        preload: false,
      );
      await _player.play();
    } catch (e) {
      log('Error: $e');
    }
  }

  /// Mute or unmute the microphone (stop sending audio)
  void setMuted(bool muted) {
    if (muted) {
      _micSub?.pause();
    } else {
      _micSub?.resume();
    }
  }

  /// Returns true if the microphone is currently muted (not sending audio)
  bool get isMuted => _micSub?.isPaused ?? false;

  /// Enable or disable speaker output (if supported)
  /// Note: This is platform-dependent and may require additional plugins for full support.
  Future<void> setSpeakerOn(bool enabled) async {
    _player.setVolume(1);
    // If using just_audio, you may need to use platform channels or a plugin like flutter_audio_manager
    // This is a placeholder for actual speaker control logic.
    // For now, this does nothing.
    // Example (if using flutter_audio_manager):
    // await AudioManager.instance.changeToSpeaker(enabled);
  }

  /// Stop recording and close the call
  Future<void> endCall() async {
    _isActive = false;
    await _micSub?.cancel();
    await _recorder.stop();
    await _player.stop();
    await _liveSource?.close();
    _sendSocket?.close();
    _receiveSocket?.close();
    _udpSocket?.close();
  }

  Future<void> setSpeakerMode(bool enable) async {
    final session = await AudioSession.instance;

    // Configure for playback (forces speaker on Android/iOS)
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory:
            AVAudioSessionCategory.playAndRecord, // For call-like routing
        avAudioSessionCategoryOptions: enable
            ? AVAudioSessionCategoryOptions.defaultToSpeaker // Speaker
            : AVAudioSessionCategoryOptions.mixWithOthers, // Earpiece
        androidAudioAttributes: AndroidAudioAttributes(
          usage: enable
              ? 
              AndroidAudioUsage.media:AndroidAudioUsage
                  .voiceCommunication, // Default routing
          contentType: AndroidAudioContentType.speech,
        ),
      ),
    );

    // Activate session (required for routing changes)
    await session.setActive(true);
  }
}
