import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';

/// 사진·영상 전체화면 뷰어. 좌우로 넘겨서 본다.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<MediaItem> items;
  final int initialIndex;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
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
              : _VideoPage(path: item.path);
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.path});

  final String path;

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
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            VideoProgressIndicator(controller, allowScrubbing: true),
            GestureDetector(
              onTap: () => setState(() {
                controller.value.isPlaying ? controller.pause() : controller.play();
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
          ],
        ),
      ),
    );
  }
}
