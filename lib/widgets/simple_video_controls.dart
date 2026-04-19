import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// 재생/일시정지 + 시간 + 시크바만 있는 간단한 동영상 컨트롤
class SimpleVideoControls extends StatefulWidget {
  const SimpleVideoControls({super.key});

  @override
  State<SimpleVideoControls> createState() => _SimpleVideoControlsState();
}

class _SimpleVideoControlsState extends State<SimpleVideoControls> {
  late VideoPlayerController _controller;
  late ChewieController _chewieController;
  bool _showControls = true;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chewieController = ChewieController.of(context);
    _controller = _chewieController.videoPlayerController;
    _controller.addListener(_listener);
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_listener);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    final isPlaying = value.isPlaying;
    final position = value.position;
    final duration = value.duration;

    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 가운데 재생/일시정지 버튼
          if (_showControls)
            Center(
              child: GestureDetector(
                onTap: () {
                  if (isPlaying) {
                    _controller.pause();
                  } else {
                    if (position >= duration) {
                      _controller.seekTo(Duration.zero);
                    }
                    _controller.play();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          // 하단 시크바 + 시간
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 시크바
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                      ),
                      child: Slider(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble())
                            : 0,
                        min: 0,
                        max: duration.inMilliseconds > 0
                            ? duration.inMilliseconds.toDouble()
                            : 1,
                        onChangeStart: (_) => _dragging = true,
                        onChanged: (v) {
                          _controller.seekTo(Duration(milliseconds: v.toInt()));
                        },
                        onChangeEnd: (_) => _dragging = false,
                      ),
                    ),
                    // 시간 표시
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
