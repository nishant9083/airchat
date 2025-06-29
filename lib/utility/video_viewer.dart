import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<int, Future<void>> _initFutures = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    for (int i = 0; i < widget.filePaths.length; i++) {
      final controller = VideoPlayerController.file(File(widget.filePaths[i]));
      _controllers[i] = controller;
      _initFutures[i] = controller.initialize();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _playPause(int index) {
    final controller = _controllers[index]!;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha:0.4),
        elevation: 0,
        title: const Text('Video Viewer'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.filePaths.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final filePath = widget.filePaths[index];
          final controller = _controllers[index]!;
          final initFuture = _initFutures[index]!;
          return Hero(
            tag: (widget.tag != null && index == widget.initialIndex)
                ? widget.tag!
                : filePath,
            transitionOnUserGestures: true,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.velocity.pixelsPerSecond.dy > 200) {
                  Navigator.of(context).pop();
                }
              },
              child: Center(
                child: FutureBuilder(
                  future: initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const CircularProgressIndicator();
                    }
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                        GestureDetector(
                          onTap: () => _playPause(index),
                          child: AnimatedOpacity(
                            opacity: controller.value.isPlaying ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              color: Colors.black26,
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 64),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 24,
                          right: 24,
                          child: VideoProgressIndicator(
                            controller,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: Colors.blue,
                              backgroundColor: Colors.white24,
                              bufferedColor: Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
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
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.pause();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: VideoPlayer(_controller),
      );
    } else {
      return Container(
        color: Colors.black12,
        child: const Center(
          child: Icon(Icons.videocam, color: Colors.grey, size: 48),
        ),
      );
    }
  }
} 