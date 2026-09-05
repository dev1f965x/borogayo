import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../db/database.dart';
import '../../media/media_store.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../media_viewer_screen.dart';

/// 건물이나 방에 붙는 사진·영상 묶음. 둘 중 하나의 id만 넘긴다.
class MediaSection extends StatefulWidget {
  const MediaSection({super.key, this.buildingId, this.roomId})
    : assert(
        (buildingId == null) != (roomId == null),
        '건물이나 방 중 하나에만 붙일 수 있다',
      );

  final int? buildingId;
  final int? roomId;

  @override
  State<MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<MediaSection> {
  List<MediaItem> _items = [];
  String? _filter;
  bool _loading = true;
  bool _busy = false;

  List<String> get _labels =>
      widget.buildingId != null ? kBuildingMediaLabels : kRoomMediaLabels;

  /// 실제로 쓰인 구역만 필터로 노출한다. 안 찍은 구역까지 보여주면 산만하다.
  List<String> get _usedLabels {
    final used = _items.map((item) => item.label).whereType<String>().toSet();
    return _labels.where(used.contains).toList();
  }

  List<MediaItem> get _visibleItems =>
      _filter == null ? _items : _items.where((item) => item.label == _filter).toList();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final items = await AppDatabase.instance.readMedia(
      buildingId: widget.buildingId,
      roomId: widget.roomId,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      // 필터로 잡아둔 구역의 사진을 모두 지웠다면 필터를 풀어준다.
      if (_filter != null && !items.any((item) => item.label == _filter)) {
        _filter = null;
      }
      _loading = false;
    });
  }

  Future<void> _pick(ImageSource source, MediaKind kind, String label) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final picker = ImagePicker();
      final picked = kind == MediaKind.photo
          ? await picker.pickImage(source: source, imageQuality: 85)
          : await picker.pickVideo(source: source);
      if (picked == null) return;

      final storedPath = await MediaStore.save(picked.path);
      await AppDatabase.instance.addMedia(
        buildingId: widget.buildingId,
        roomId: widget.roomId,
        path: storedPath,
        kind: kind,
        label: label,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      await _refresh();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('불러오지 못했어요. 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 구역을 먼저 고르고 촬영/선택으로 이어지는 한 장짜리 시트.
  /// 구역을 따로 묻는 단계를 만들면 현장에서 귀찮아 안 쓰게 된다.
  Future<void> _showAddSheet() async {
    final palette = context.palette;
    var label = _filter ?? _labels.first;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  '어디를 찍은 건가요?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final option in _labels)
                      ChoiceChip(
                        label: Text(option),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: label == option ? Colors.white : palette.textMuted,
                        ),
                        selected: label == option,
                        showCheckmark: false,
                        backgroundColor: palette.background,
                        selectedColor: palette.brand,
                        side: BorderSide(color: palette.border),
                        onSelected: (_) => setSheetState(() => label = option),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final option in const [
                (Icons.photo_camera_outlined, '사진 촬영', ImageSource.camera, MediaKind.photo),
                (Icons.videocam_outlined, '영상 촬영', ImageSource.camera, MediaKind.video),
                (
                  Icons.photo_library_outlined,
                  '갤러리에서 사진',
                  ImageSource.gallery,
                  MediaKind.photo,
                ),
                (
                  Icons.video_library_outlined,
                  '갤러리에서 영상',
                  ImageSource.gallery,
                  MediaKind.video,
                ),
              ])
                ListTile(
                  leading: Icon(option.$1, color: palette.textBody),
                  title: Text(
                    option.$2,
                    style: TextStyle(fontSize: 15, color: palette.textBody),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pick(option.$3, option.$4, label);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(MediaItem item) async {
    final items = _visibleItems;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(items: items, initialIndex: items.indexOf(item)),
      ),
    );
    await _refresh();
  }

  Future<void> _delete(MediaItem item) async {
    await AppDatabase.instance.deleteMedia(item.id!);
    await MediaStore.delete(item.path);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final visible = _visibleItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '사진 · 영상',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: palette.textStrong,
              ),
            ),
            const SizedBox(width: 6),
            if (_items.isNotEmpty)
              Text(
                '${_items.length}',
                style: TextStyle(fontSize: 13, color: palette.textMuted),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : _showAddSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
            ),
          ],
        ),
        if (_usedLabels.length > 1) ...[
          const SizedBox(height: 2),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: '전체',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final label in _usedLabels)
                  _FilterChip(
                    label: label,
                    selected: _filter == label,
                    onTap: () => setState(() => _filter = label),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_loading)
          const SizedBox(height: 96)
        else if (_items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              '현장에서 찍어두면 나중에 비교할 때 기억이 안 섞여요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textMuted),
            ),
          )
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _Thumbnail(
                item: visible[index],
                onTap: () => _open(visible[index]),
                onDelete: () => _delete(visible[index]),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? palette.brand : palette.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? palette.brand : palette.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.item, required this.onTap, required this.onDelete});

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.kind == MediaKind.photo
                  ? Image.file(
                      File(item.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: palette.border,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined, color: palette.textMuted),
                      ),
                    )
                  : Container(
                      color: palette.textStrong,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
            ),
            if (item.label != null)
              Positioned(
                left: 5,
                bottom: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    item.label!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
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
