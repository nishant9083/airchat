import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final bool isMe;

  const AudioPlayerWidget(
      {super.key, required this.filePath, required this.isMe});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final Player _player;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playingSubscription;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;

    try {
      // Listen to streams with proper error handling
      _positionSubscription = _player.stream.position.listen(
        (pos) {
          if (mounted) {
            setState(() => _position = pos);
          }
        },
        onError: (e) => log("Position stream error: $e"),
      );

      _durationSubscription = _player.stream.duration.listen(
        (dur) {
          if (mounted) {
            setState(() => _duration = dur);
          }
        },
        onError: (e) => log("Duration stream error: $e"),
      );

      _playingSubscription = _player.stream.playing.listen(
        (isPlaying) {
          if (mounted) {
            setState(() => _playing = isPlaying);
          }
        },
        onError: (e) => log("Playing stream error: $e"),
      );

      // Open audio file
      await _player.open(Media(widget.filePath), play: false);

      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      log("Error initializing audio player: $e");
      if (mounted) {
        setState(() {
          _isReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isReady) return;
    try {
      _playing ? _player.pause() : _player.play();
    } catch (e) {
      log("Error toggling play/pause: $e");
    }
  }

  void _seek(double seconds) {
    if (!_isReady) return;
    try {
      _player.seek(Duration(seconds: seconds.toInt()));
    } catch (e) {
      log("Error seeking: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return _buildFallback();

    return Card(
      color: widget.isMe ? Theme.of(context).primaryColor : Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(
                _playing ? Icons.pause_circle : Icons.play_circle,
                size: 40,
                color: Colors.white,
              ),
            ),
            Expanded(
              child: Slider(
                value: _position.inSeconds.toDouble(),
                max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
                onChanged: _seek,
                activeColor: Colors.blueAccent,
                inactiveColor: Colors.white30,
              ),
            ),
            Text(
              "${_format(_position)} / ${_format(_duration)}",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Widget _buildFallback() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.audiotrack, color: Colors.white54, size: 24),
          SizedBox(width: 12),
          Text('Loading...', style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}
