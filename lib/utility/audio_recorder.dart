import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderWidget extends StatefulWidget {
  final Function(String filePath, String fileName) onRecordingComplete;
  final bool isConnected;

  const AudioRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.isConnected,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;
  late ValueNotifier<bool> _recNotifier;
  late ValueNotifier<bool> _pauseNotifier;
  late ValueNotifier<Duration> _durationNotifier;

  @override
  void initState() {
    super.initState();
    _recNotifier = ValueNotifier(_isRecording);
    _pauseNotifier = ValueNotifier(_isPaused);
    _durationNotifier = ValueNotifier(_recordingDuration);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _timer?.cancel();
    _recNotifier.dispose();
    _pauseNotifier.dispose();
    _durationNotifier.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.storage,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.storage] != PermissionStatus.granted) {
      throw Exception('Microphone and storage permissions are required');
    }
  }

  Future<void> _startRecording() async {
    if (!widget.isConnected) return;

    try {
      await _requestPermissions();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = '${directory.path}/$fileName';

      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      _isRecording = true;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _recNotifier.value = _isRecording;
      _pauseNotifier.value = _isPaused;
      _durationNotifier.value = _recordingDuration;

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (_isRecording && !_isPaused) {
          _recordingDuration += const Duration(seconds: 1);
          _durationNotifier.value = _recordingDuration;
        }
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _showErrorSnackBar('Failed to start recording');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      _timer?.cancel();

      _isRecording = false;
      _isPaused = false;
      _recNotifier.value = _isRecording;
      _pauseNotifier.value = _isPaused;

      if (path != null && _recordingPath != null) {
        final fileName = _recordingPath!.split('/').last;
        widget.onRecordingComplete(_recordingPath!, fileName);
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _showErrorSnackBar('Failed to stop recording');
    }
  }

  Future<void> _pauseRecording() async {
    if (!_isRecording || _isPaused) return;

    try {
      await _audioRecorder.pause();
      _isPaused = true;
      _pauseNotifier.value = _isPaused;
    } catch (e) {
      debugPrint('Error pausing recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    if (!_isRecording || !_isPaused) return;

    try {
      await _audioRecorder.resume();
      _isPaused = false;
      _pauseNotifier.value = _isPaused;
    } catch (e) {
      debugPrint('Error resuming recording: $e');
    }
  }

  void _cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.stop();
      _timer?.cancel();

      _isRecording = false;
      _isPaused = false;
      _recordingDuration = Duration.zero;
      _recNotifier.value = _isRecording;
      _pauseNotifier.value = _isPaused;
      _durationNotifier.value = _recordingDuration;

      // Delete the recording file
      if (_recordingPath != null && File(_recordingPath!).existsSync()) {
        await File(_recordingPath!).delete();
      }
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showRecordingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mic,
                  color: Colors.red[400],
                  size: 48,
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<Duration>(
                  valueListenable: _durationNotifier,
                  builder: (context, value, _) {
                    return Text(
                      _formatDuration(value),
                      style: TextStyle(
                        color: Colors.red[200],
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        letterSpacing: 2,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: _pauseNotifier,
                      builder: (context, isPaused, _) {
                        return IconButton(
                          tooltip: isPaused ? "Resume" : "Pause",
                          icon: Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: isPaused ? _resumeRecording : _pauseRecording,
                        );
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      tooltip: "Stop & Send",
                      icon: const Icon(
                        Icons.send,
                        color: Colors.greenAccent,
                        size: 32,
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _stopRecording();
                      },
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      tooltip: "Cancel",
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.redAccent,
                        size: 32,
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _cancelRecording();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Text(
                //   "Recording... Slide down to dismiss",
                //   style: TextStyle(
                //     color: Colors.grey[400],
                //     fontSize: 13,
                //   ),
                // ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      // If user dismisses the sheet, cancel recording if still active
      if (_isRecording) {
        _cancelRecording();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _recNotifier,
      builder: (context, isRecording, _) {
        return 
        ElevatedButton(
          style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                            ),
          onPressed: (Platform.isWindows && widget.isConnected && !isRecording)
              ? () async {
                  await _startRecording();
                  if (mounted) _showRecordingBottomSheet();
                }
              : null,
          onLongPress:widget.isConnected && !isRecording
              ? () async {
                  await _startRecording();
                  if (mounted) _showRecordingBottomSheet();
                }
              : null,
              
               child: Icon(
              Icons.mic,
              color: widget.isConnected ? Colors.white : Colors.grey,
              size: 28,
            ));
        
       },
    );
  }
}