import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../media/media_share.dart';
import '../models/models.dart';

/// Full-screen photo and video viewer with horizontal paging.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.ownerLabel,
  });

  final List<MediaItem> items;
  final int initialIndex;

  /// Context sent along when sharing, e.g. `대성빌라 302호`.
  final String ownerLabel;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          [
            '${_index + 1} / ${widget.items.length}',
            ?widget.items[_index].label,
          ].join('  ·  '),
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          IconButton(
            onPressed: () => shareMedia(
              context,
              ownerLabel: widget.ownerLabel,
              items: [widget.items[_index]],
            ),
            icon: const Icon(Icons.ios_share),
            tooltip: '공유',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return item.kind == MediaKind.photo
              ? InteractiveViewer(
                  child: Center(
                    child: Image.file(
                      File(item.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Center(
                        child: Text(
                          '파일을 찾을 수 없어요',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                )
              // Neighboring pages are built ahead, so only the visible one should play.
              : _VideoPage(path: item.path, active: index == _index);
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.path, required this.active});

  final String path;
  final bool active;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(_VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep a video that was swiped away from playing on in the background.
    if (!widget.active) _controller?.pause();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(File(widget.path));
    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on Exception {
      await controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text('영상을 재생할 수 없어요', style: TextStyle(color: Colors.white70)),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          children: [
            Positioned.fill(child: VideoPlayer(controller)),
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                }),
                child: AnimatedOpacity(
                  opacity: controller.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // Unpositioned, the bar would stretch across the middle of the video.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
