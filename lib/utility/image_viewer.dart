import 'dart:io';
import 'package:flutter/material.dart';

class FullScreenImageViewer extends StatefulWidget {
  final List<String> filePaths;
  final int initialIndex;
  final String? tag;

  const FullScreenImageViewer({
    super.key,
    required this.filePaths,
    this.initialIndex = 0,
    this.tag,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _controllers = {};
  final Map<int, bool> _isZoomed = {};

  static const double _minScale = 0.8;
  static const double _maxScale = 5.0;
  static const double _doubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    for (int i = 0; i < widget.filePaths.length; i++) {
      _controllers[i] = TransformationController();
      _isZoomed[i] = false;
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

  void _handleDoubleTap(int index, Offset position) {
    final controller = _controllers[index]!;

    if (_isZoomed[index]!) {
      // Reset zoom
      controller.value = Matrix4.identity();
      _isZoomed[index] = false;
    } else {
      // Calculate focal point for zooming where user tapped
      final scale = _doubleTapScale;

      final Matrix4 matrix = Matrix4.identity()
        ..translate(position.dx, position.dy)
        ..scale(scale)
        ..translate(-position.dx, -position.dy);

      controller.value = matrix;
      _isZoomed[index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        title: const Text('Image Viewer'),
      ),
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        physics: _isZoomed[_currentIndex] == true
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        itemCount: widget.filePaths.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final filePath = widget.filePaths[index];
          final controller = _controllers[index]!;

          return Hero(
            tag: (widget.tag != null && index == widget.initialIndex)
                ? widget.tag!
                : '$filePath-$index',
            transitionOnUserGestures: true,
            child: GestureDetector(
              onDoubleTapDown: (details) {
                final position = details.localPosition;
                _handleDoubleTap(index, position);
              },
              onVerticalDragEnd: (details) {
                if (!_isZoomed[index]! &&
                    details.velocity.pixelsPerSecond.dy > 200) {
                  Navigator.of(context).pop();
                }
              },
              child: InteractiveViewer(
                transformationController: controller,
                minScale: _minScale,
                maxScale: _maxScale,
                // boundaryMargin: const EdgeInsets.all(double.infinity),
                panEnabled: true,
                scaleEnabled: true,
                onInteractionStart: (details) {
                  if (details.pointerCount >= 2) {
                    setState(() => _isZoomed[index] = true);
                  }
                },
                onInteractionEnd: (details) {
                  final scale = controller.value.getMaxScaleOnAxis();
                  setState(() => _isZoomed[index] = scale > 1.05);
                },
                child: Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    'Error Occurred: ${error.toString()}',
                    style: TextStyle(color: Colors.red[300]),
                  )),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}