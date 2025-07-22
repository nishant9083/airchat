import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video_controls/media_kit_video_controls.dart'
    as media_kit_video_controls;

class VideoViewer extends StatefulWidget {
  final List<String> filePaths;
  final int initialIndex;
  final String? tag;

  const VideoViewer({
    super.key,
    required this.filePaths,
    this.initialIndex = 0,
    this.tag,
  });

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  final Map<int, Player> _players = {};
  final Map<int, VideoController> _controllers = {};

  // Track play state for each video to sync UI and keyboard
  final Map<int, ValueNotifier<bool>> _playingNotifiers = {};

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    for (int i = 0; i < widget.filePaths.length; i++) {
      final player = Player();
      final controller = VideoController(player);
      player.open(Media(widget.filePaths[i]), play: false);
      _players[i] = player;
      _controllers[i] = controller;
      _playingNotifiers[i] = ValueNotifier<bool>(false);

      // Listen to player state to update notifier
      player.stream.playing.listen((playing) {
        if (mounted) {
          _playingNotifiers[i]!.value = playing;
        }
      });
    }
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _pageController.dispose();
    for (final notifier in _playingNotifiers.values) {
      notifier.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _playPause(int index) {
    final player = _players[index];
    if (player != null) {
      final playing = _playingNotifiers[index]?.value ?? false;
      if (playing) {
        player.pause();
      } else {
        player.play();
      }
    }
  }

  // Handle keyboard events for play/pause
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Space or 'k' for play/pause
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.keyK) {
        _playPause(_currentIndex);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: .4),
        elevation: 0,
        title: const Text('Video Viewer',style: TextStyle(color: Colors.white),),
      ),
      body: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.filePaths.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final filePath = widget.filePaths[index];
            final controller = _controllers[index];
            final tag = widget.tag;

            return Hero(
              tag: (tag != null && index == widget.initialIndex)
                  ? tag
                  : '$filePath-$index',
              transitionOnUserGestures: true,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.velocity.pixelsPerSecond.dy > 200) {
                    Navigator.of(context).pop();
                  }
                },
                child: Center(
                  child: controller == null
                      ? _buildFallback(filePath)
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Video(controller: controller),
                            // Use ValueListenableBuilder to sync play/pause icon with state
                            if (_playingNotifiers[index] != null)
                              ValueListenableBuilder<bool>(
                                valueListenable: _playingNotifiers[index]!,
                                builder: (context, isPlaying, _) {
                                  return GestureDetector(
                                    onTap: () => _playPause(index),
                                    child: Container(
                                      color: Colors.transparent,
                                      child: isPlaying
                                          ? const SizedBox.shrink()
                                          : const Icon(
                                              Icons.play_arrow,
                                              color: Colors.white,
                                              size: 64,
                                            ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallback(String filePath) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
        const SizedBox(height: 8),
        Text(
          'Unsupported or failed to load',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 8),
        Text(
          'File: ${filePath.split('/').last}',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

class VideoThumbnailWidget extends StatefulWidget {
  final String filePath;
  const VideoThumbnailWidget({super.key, required this.filePath});

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Create the player and controller
    _player = Player();
    _controller = VideoController(_player);

    // Open the video file
    _player.open(Media(widget.filePath), play: false).then((_) {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _player.pause(); // Don't auto-play
      }
    }).catchError((e) {
      // No controls, so just log and fallback
      log('Error loading video thumbnail: $e');
      if (mounted) {
        setState(() {
          _initialized = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return _buildThumbnailFallback();
    }

    // final width = _player.state.width;
    // final height = _player.state.height;
    // double aspectRatio;
    // if (width != null && height != null && width > 0 && height > 0) {
    //   aspectRatio = width / height;
    // } else {
    //   aspectRatio = 16 / 9;
    // }
    // No controls, just the video (paused)
    return SizedBox(
        // height: 120,
        // child: AbsorbPointer(
          child: Video(controller: _controller, controls: media_kit_video_controls.NoVideoControls,
        ));
        // );
  }

  Widget _buildThumbnailFallback() {
    return Container(
      color: Colors.black12,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, color: Colors.grey, size: 32),
            SizedBox(height: 4),
            Text(
              'Video',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
