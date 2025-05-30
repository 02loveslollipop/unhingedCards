import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A Flutter widget that plays BadApple video using the custom ESP32 codec
class BadAppleVideoPlayer extends StatefulWidget {
  final String assetPath;
  final int width;
  final int height;
  final bool autoPlay;
  final bool loop;
  final VoidCallback? onComplete;

  const BadAppleVideoPlayer({
    super.key,
    required this.assetPath,
    this.width = 120,
    this.height = 75,
    this.autoPlay = true,
    this.loop = false,
    this.onComplete,
  });

  @override
  State<BadAppleVideoPlayer> createState() => _BadAppleVideoPlayerState();
}

class _BadAppleVideoPlayerState extends State<BadAppleVideoPlayer> {
  late BadAppleCodec _codec;
  List<List<bool>>? _currentFrame;
  Timer? _playbackTimer;
  bool _isPlaying = false;
  bool _isInitialized = false;
  int _currentFrameIndex = 0;
  int _totalFrames = 0;

  @override
  void initState() {
    super.initState();
    _initializeCodec();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCodec() async {
    try {
      final byteData = await rootBundle.load(widget.assetPath);
      final bytes = byteData.buffer.asUint8List();

      _codec = BadAppleCodec(bytes, width: widget.width, height: widget.height);

      // Initialize with white frame
      _currentFrame = List.generate(
        widget.height,
        (index) => List.filled(widget.width, true), // true = white
      );

      setState(() {
        _isInitialized = true;
        _totalFrames = _codec.getTotalFrames();
      });

      if (widget.autoPlay) {
        play();
      }
    } catch (e) {
      debugPrint('Error initializing BadApple codec: $e');
    }
  }

  void play() {
    if (!_isInitialized || _isPlaying) return;

    setState(() {
      _isPlaying = true;
    });

    _playbackTimer = Timer.periodic(
      const Duration(milliseconds: 83, microseconds: 333), // ~12 FPS
      (timer) {
        if (_codec.hasNextFrame()) {
          final frame = _codec.getNextFrame();
          if (frame != null) {
            setState(() {
              _currentFrame = frame;
              _currentFrameIndex++;
            });
          }
        } else {
          // End of video
          if (widget.loop) {
            _codec.reset();
            setState(() {
              _currentFrameIndex = 0;
            });
          } else {
            stop();
            widget.onComplete?.call();
          }
        }
      },
    );
  }

  void pause() {
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void stop() {
    _playbackTimer?.cancel();
    _codec.reset();
    setState(() {
      _isPlaying = false;
      _currentFrameIndex = 0;
      // Reset to white frame
      _currentFrame = List.generate(
        widget.height,
        (index) => List.filled(widget.width, true),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return SizedBox(
        width: widget.width.toDouble(),
        height: widget.height.toDouble(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Video frame display
        Container(
          width: widget.width.toDouble(),
          height: widget.height.toDouble(),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
          child: CustomPaint(
            painter: BadAppleFramePainter(_currentFrame),
            size: Size(widget.width.toDouble(), widget.height.toDouble()),
          ),
        ),
        const SizedBox(height: 8),
        // Controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _isPlaying ? pause : play,
            ),
            IconButton(icon: const Icon(Icons.stop), onPressed: stop),
            Text('$_currentFrameIndex / $_totalFrames'),
          ],
        ),
      ],
    );
  }
}

/// Custom painter for rendering the video frame
class BadAppleFramePainter extends CustomPainter {
  final List<List<bool>>? frame;

  BadAppleFramePainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    if (frame == null) return;

    final paint = Paint();
    final pixelWidth = size.width / frame![0].length;
    final pixelHeight = size.height / frame!.length;

    for (int y = 0; y < frame!.length; y++) {
      for (int x = 0; x < frame![y].length; x++) {
        paint.color = frame![y][x] ? Colors.white : Colors.black;
        canvas.drawRect(
          Rect.fromLTWH(
            x * pixelWidth,
            y * pixelHeight,
            pixelWidth,
            pixelHeight,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// BadApple video codec decoder
class BadAppleCodec {
  final Uint8List _byteStream;
  final int width;
  final int height;

  int _streamPointer = 0;
  late List<List<bool>> _frameBuffer;

  // Decoder state
  bool _firstFF = false;
  int _currentLine = 0;
  int _deprecateBytes = 0;

  BadAppleCodec(this._byteStream, {required this.width, required this.height}) {
    _initializeFrameBuffer();
  }

  void _initializeFrameBuffer() {
    // Initialize with white background (true = white, false = black)
    _frameBuffer = List.generate(height, (index) => List.filled(width, true));
  }

  int getTotalFrames() {
    // Count frame markers (0xFF) to estimate total frames
    int frameCount = 0;
    for (int i = 0; i < _byteStream.length; i++) {
      if (_byteStream[i] == 0xFF) frameCount++;
    }
    return frameCount ~/ 2; // Each frame has start and end markers
  }

  bool hasNextFrame() {
    return _streamPointer < _byteStream.length;
  }

  List<List<bool>>? getNextFrame() {
    if (!hasNextFrame()) return null;

    _firstFF = false;
    _deprecateBytes = 0;

    for (int i = _streamPointer; i < _byteStream.length; i++) {
      if (_deprecateBytes > 0) {
        _deprecateBytes--;
        continue;
      }

      final byte = _byteStream[i];

      if (byte == 0xFF) {
        // Frame marker
        if (_firstFF) {
          // End of frame
          _streamPointer = i + 1;
          return _copyFrame();
        } else {
          // Start of frame
          if (i + 1 < _byteStream.length) {
            _currentLine = _byteStream[i + 1];
            _deprecateBytes = 1;
            _firstFF = true;
          }
        }
      } else if (byte == 0xFE) {
        // Line change
        if (i + 1 < _byteStream.length) {
          _currentLine = _byteStream[i + 1];
          _deprecateBytes = 1;
        }
      } else if (byte == 0xFD) {
        // Pixel run
        if (i + 2 < _byteStream.length) {
          final startCol = _byteStream[i + 1];
          final endCol = _byteStream[i + 2];
          _deprecateBytes = 2;

          if (_currentLine < height) {
            for (int j = startCol; j <= endCol && j < width; j++) {
              _frameBuffer[_currentLine][j] = !_frameBuffer[_currentLine][j];
            }
          }
        }
      } else {
        // Single pixel toggle
        if (_currentLine < height && byte < width) {
          _frameBuffer[_currentLine][byte] = !_frameBuffer[_currentLine][byte];
        }
      }
    }

    _streamPointer = _byteStream.length;
    return _copyFrame();
  }

  List<List<bool>> _copyFrame() {
    return _frameBuffer.map((row) => List<bool>.from(row)).toList();
  }

  void reset() {
    _streamPointer = 0;
    _firstFF = false;
    _currentLine = 0;
    _deprecateBytes = 0;
    _initializeFrameBuffer();
  }
}
