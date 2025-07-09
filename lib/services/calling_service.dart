// 📞 LAN Calling Service in Dart (WhatsApp-like Flow)
// Dependencies: record, just_audio, dart:io

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class LanCallService {
  final _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  RawDatagramSocket? _udpSocket;
  InternetAddress? _targetAddress;
  int _port = 5555;
  File? _recordingFile;
  IOSink? _sink;
  bool _isCalling = false;
  bool _isReceiving = false;

  /// Caller initiates the call
  Future<void> startCall(String targetIp) async {
    _targetAddress = InternetAddress(targetIp);
    _isCalling = true;
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    await _startRecording();
  }

  /// Callee listens for incoming call
  Future<void> listenForCalls() async {
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
    _isReceiving = true;
    _recordingFile = await _createTempWavFile();
    _sink = _recordingFile!.openWrite(mode: FileMode.write);

    // Write WAV header placeholder
    _sink!.add(_generateWavHeader(0));

    _udpSocket!.listen((event) async {
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket!.receive();
        if (datagram != null) {
          _sink!.add(datagram.data);
        }
      }
    });
  }

  /// Stop recording and close the call
  Future<void> endCall() async {
    _isCalling = false;
    await _recorder.stop();
    _udpSocket?.close();
  }

  /// Stop receiving and play received audio
  Future<void> stopReceiving() async {
    _isReceiving = false;
    await _sink?.flush();
    await _sink?.close();
    _udpSocket?.close();

    // Rewrite WAV header with actual data length
    final file = _recordingFile!;
    final data = await file.readAsBytes();
    final header = _generateWavHeader(data.length - 44);
    final updated = BytesBuilder()
      ..add(header)
      ..add(data.sublist(44));
    await file.writeAsBytes(updated.toBytes(), flush: true);

    // Play
    await _player.setFilePath(file.path);
    await _player.play();
  }

  /// Start microphone capture and send data to target
  Future<void> _startRecording() async {
    await _recorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits)).then((stream) {
      stream.listen((chunk) {
        if (_isCalling && _targetAddress != null) {
          _udpSocket?.send(chunk, _targetAddress!, _port);
        }
      });
    });
  }

  /// Create temporary WAV file
  Future<File> _createTempWavFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/incoming.wav');
    if (await file.exists()) await file.delete();
    return file;
  }

  /// Generate WAV header (PCM 16bit, 1ch, 44100Hz)
  List<int> _generateWavHeader(int dataLength) {
    const sampleRate = 44100;
    const bitsPerSample = 16;
    const channels = 1;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final totalLength = 36 + dataLength;

    final header = BytesBuilder();
    header.add(ascii.encode('RIFF'));
    header.add(_intToBytes(totalLength));
    header.add(ascii.encode('WAVE'));
    header.add(ascii.encode('fmt '));
    header.add(_intToBytes(16)); // Subchunk1Size
    header.add([1, 0]); // PCM
    header.add([channels, 0]);
    header.add(_intToBytes(sampleRate));
    header.add(_intToBytes(byteRate));
    header.add([blockAlign, 0]);
    header.add([bitsPerSample, 0]);
    header.add(ascii.encode('data'));
    header.add(_intToBytes(dataLength));
    return header.toBytes();
  }

  List<int> _intToBytes(int value) {
    return [
      value & 0xff,
      (value >> 8) & 0xff,
      (value >> 16) & 0xff,
      (value >> 24) & 0xff,
    ];
  }
}

// 🎯 UI layer can now call `LanCallService().startCall(ip)` and `stopReceiving()`
// Example UI flow:
// - Show 'Incoming Call' button: triggers `listenForCalls()`
// - Show 'Call [user]' button: triggers `startCall()`
// - Add 'Hang up' button: triggers `endCall()` or `stopReceiving()`
