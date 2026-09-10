import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../db/database.dart';
import '../../media/media_share.dart';
import '../../media/media_store.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../media_viewer_screen.dart';
import 'confirm_dialog.dart';
import 'media_area_picker.dart';

/// 시트에서 고른 결과. 구역 이름과 어디서 어떤 걸 가져올지.
typedef _AddRequest = ({String label, ImageSource source, MediaKind kind});

/// 사진·영상을 옮길 곳. 건물 자신이거나 그 건물의 방 하나.
typedef _Place = ({int? buildingId, int? roomId, String name});

/// 건물이나 방에 붙는 사진·영상 묶음.
///
/// [room]이 null이면 건물에 붙는 섹션이다. 어느 쪽이든 옮길 후보를 만들어야 해서
/// 건물은 항상 받는다.
class MediaSection extends StatefulWidget {
  const MediaSection({super.key, required this.building, this.room});

  final Building building;
  final Room? room;

  @override
  State<MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<MediaSection> {
  List<MediaItem> _items = [];
  List<Room> _siblings = [];
  String? _filter;
  bool _loading = true;
  bool _busy = false;

  int? get _buildingId => widget.room == null ? widget.building.id : null;
  int? get _roomId => widget.room?.id;

  /// 공유할 때 파일과 함께 보낼 맥락. 예: `대성빌라 302호`
  String get _ownerLabel => widget.room == null
      ? widget.building.name
      : '${widget.building.name} ${widget.room!.name}';

  List<String> get _labels => areaPresetsFor(isBuilding: widget.room == null);

  /// 실제로 쓰인 구역만 필터로 노출한다. 안 찍은 구역까지 보여주면 산만하다.
  /// 직접 적은 구역도 그대로 섞인다.
  List<String> get _usedLabels {
    final used = <String>[];
    for (final item in _items) {
      final label = item.label;
      if (label != null && !used.contains(label)) used.add(label);
    }
    return used;
  }

  List<MediaItem> get _visibleItems =>
      _filter == null ? _items : _items.where((item) => item.label == _filter).toList();

  /// 붙일 수 있는 곳 전부. **지금 있는 곳도 포함한다** — 자리는 맞는데 구역만
  /// 잘못 고른 경우(거실 사진을 주방으로)가 옮기는 것보다 흔하기 때문이다.
  List<_Place> get _places => [
    (buildingId: widget.building.id, roomId: null, name: widget.building.name),
    for (final sibling in _siblings)
      (buildingId: null, roomId: sibling.id, name: sibling.name),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = AppDatabase.instance;
    final items = await db.readMedia(buildingId: _buildingId, roomId: _roomId);
    final siblings = await db.readRooms(widget.building.id!);
    if (!mounted) return;
    setState(() {
      _items = items;
      _siblings = siblings;
      // 필터로 잡아둔 구역의 사진을 모두 지웠다면 필터를 풀어준다.
      if (_filter != null && !items.any((item) => item.label == _filter)) {
        _filter = null;
      }
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (_busy) return;

    final request = await showModalBottomSheet<_AddRequest>(
      context: context,
      backgroundColor: context.palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddMediaSheet(labels: _labels, initialLabel: _filter),
    );
    if (request == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final picked = request.kind == MediaKind.photo
          ? await picker.pickImage(source: request.source, imageQuality: 85)
          : await picker.pickVideo(source: request.source);
      if (picked == null) return;

      final storedPath = await MediaStore.save(picked.path);
      final thumbPath = request.kind == MediaKind.video
          ? await MediaStore.saveVideoThumbnail(storedPath)
          : null;

      await AppDatabase.instance.addMedia(
        buildingId: _buildingId,
        roomId: _roomId,
        path: storedPath,
        kind: request.kind,
        label: request.label,
        thumbPath: thumbPath,
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

  Future<void> _open(MediaItem item) async {
    final items = _visibleItems;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          items: items,
          initialIndex: items.indexOf(item),
          ownerLabel: _ownerLabel,
        ),
      ),
    );
    await _refresh();
  }

  /// 지금 화면에 보이는 것들을 보낸다. 필터를 걸어두면 그게 곧 고르는 도구가 되므로
  /// 여러 장을 고르는 별도 선택 모드를 두지 않는다.
  Future<void> _share() async {
    await shareMedia(context, ownerLabel: _ownerLabel, items: _visibleItems);
  }

  /// 길게 누르면 나오는 메뉴.
  Future<void> _showItemMenu(MediaItem item) async {
    final palette = context.palette;
    final kind = item.kind == MediaKind.photo ? '사진' : '영상';

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: palette.textBody),
              title: Text(
                '위치·구역 수정',
                style: TextStyle(fontSize: 15, color: palette.textBody),
              ),
              subtitle: Text(
                '구역을 잘못 골랐거나 건물↔방이 바뀌었을 때',
                style: TextStyle(fontSize: 12.5, color: palette.textMuted),
              ),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: palette.danger),
              title: Text(
                '$kind 삭제',
                style: TextStyle(fontSize: 15, color: palette.danger),
              ),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == 'edit') {
      await _edit(item);
    } else {
      await _delete(item);
    }
  }

  Future<void> _edit(MediaItem item) async {
    final current = _places.firstWhere(
      (place) => item.buildingId != null
          ? place.buildingId == item.buildingId
          : place.roomId == item.roomId,
      orElse: () => _places.first,
    );

    final result = await showModalBottomSheet<({_Place place, String label})>(
      context: context,
      backgroundColor: context.palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditMediaSheet(
        places: _places,
        current: current,
        currentLabel: item.label,
      ),
    );
    if (result == null || !mounted) return;

    final moved = result.place != current;
    await AppDatabase.instance.moveMedia(
      item.id!,
      buildingId: result.place.buildingId,
      roomId: result.place.roomId,
      label: result.label,
    );
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          moved ? '‘${result.place.name}’(으)로 옮겼어요' : '‘${result.label}’(으)로 바꿨어요',
        ),
      ),
    );
  }

  Future<void> _delete(MediaItem item) async {
    final ok = await confirmDestructive(
      context,
      title: '이 ${item.kind == MediaKind.photo ? '사진' : '영상'} 삭제',
      message: '되돌릴 수 없어요.',
    );
    if (!ok || !mounted) return;

    await AppDatabase.instance.deleteMedia(item.id!);
    await MediaStore.delete(item.path);
    final thumbPath = item.thumbPath;
    if (thumbPath != null) await MediaStore.delete(thumbPath);
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
            if (_items.isNotEmpty)
              IconButton(
                onPressed: _share,
                icon: const Icon(Icons.ios_share, size: 19),
                color: palette.textMuted,
                visualDensity: VisualDensity.compact,
                tooltip: _filter == null ? '전부 공유' : '‘$_filter’ 공유',
              ),
            TextButton.icon(
              onPressed: _busy ? null : _add,
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
                onLongPress: () => _showItemMenu(visible[index]),
              ),
            ),
          ),
      ],
    );
  }
}

/// 구역을 먼저 고르고 촬영/선택으로 이어지는 한 장짜리 시트.
///
/// 구역을 나중에 따로 묻는 단계로 만들면 현장에서 귀찮아 안 쓰게 된다.
class _AddMediaSheet extends StatefulWidget {
  const _AddMediaSheet({required this.labels, this.initialLabel});

  final List<String> labels;
  final String? initialLabel;

  @override
  State<_AddMediaSheet> createState() => _AddMediaSheetState();
}

class _AddMediaSheetState extends State<_AddMediaSheet> {
  late final _picker = AreaPickerController(
    labels: widget.labels,
    initial: widget.initialLabel,
  );

  @override
  void dispose() {
    _picker.dispose();
    super.dispose();
  }

  void _pick(ImageSource source, MediaKind kind) {
    final label = _picker.label;
    if (label.isEmpty) return;
    Navigator.pop(context, (label: label, source: source, kind: kind));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ready = _picker.label.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
              child: AreaPicker(
                controller: _picker,
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),
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
                enabled: ready,
                leading: Icon(
                  option.$1,
                  color: ready ? palette.textBody : palette.textMuted,
                ),
                title: Text(
                  option.$2,
                  style: TextStyle(
                    fontSize: 15,
                    color: ready ? palette.textBody : palette.textMuted,
                  ),
                ),
                onTap: () => _pick(option.$3, option.$4),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// 붙은 곳과 구역을 고치는 시트. 자리를 옮기면 구역 이름 체계도 바뀌므로 함께 고른다.
class _EditMediaSheet extends StatefulWidget {
  const _EditMediaSheet({
    required this.places,
    required this.current,
    this.currentLabel,
  });

  final List<_Place> places;
  final _Place current;
  final String? currentLabel;

  @override
  State<_EditMediaSheet> createState() => _EditMediaSheetState();
}

class _EditMediaSheetState extends State<_EditMediaSheet> {
  late _Place _place = widget.current;
  late AreaPickerController _picker = _pickerFor(_place);

  AreaPickerController _pickerFor(_Place place) => AreaPickerController(
    labels: areaPresetsFor(isBuilding: place.buildingId != null),
    // 옮겨도 뜻이 통하는 구역 이름이면 그대로 이어 쓴다.
    initial: widget.currentLabel,
  );

  @override
  void dispose() {
    _picker.dispose();
    super.dispose();
  }

  void _select(_Place place) {
    HapticFeedback.selectionClick();
    setState(() {
      _place = place;
      _picker.dispose();
      _picker = _pickerFor(place);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: palette.textMuted,
        ),
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '위치와 구역',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.textStrong,
              ),
            ),
            const SizedBox(height: 16),
            label('붙일 곳'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final place in widget.places)
                  AreaChoiceChip(
                    label: place.name,
                    icon: place.buildingId != null
                        ? Icons.apartment_outlined
                        : Icons.meeting_room_outlined,
                    selected: _place == place,
                    onTap: () => _select(place),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            label('구역'),
            AreaPicker(
              // 옮길 곳이 바뀌면 구역 후보도 통째로 바뀌므로 위젯을 새로 세운다.
              key: ValueKey(_place),
              controller: _picker,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _picker.label.isEmpty
                  ? null
                  : () => Navigator.pop(context, (
                      place: _place,
                      label: _picker.label,
                    )),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
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
            color: selected ? palette.brand.withValues(alpha: 0.14) : palette.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? palette.brand : palette.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? palette.brand : palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isVideo = item.kind == MediaKind.video;
    final preview = item.previewPath;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: preview == null
                  ? Container(color: palette.textStrong)
                  : Image.file(
                      File(preview),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: palette.border,
                        alignment: Alignment.center,
                        child: Icon(Icons.broken_image_outlined, color: palette.textMuted),
                      ),
                    ),
            ),
            // 썸네일이 생기고 나면 영상도 사진처럼 보인다. 종류는 이 뱃지로 구분한다.
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isVideo ? Icons.videocam : Icons.photo_camera,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
            // 썸네일을 못 뽑은 영상은 그냥 검은 타일이 되므로 재생 표시를 남긴다.
            if (isVideo && preview == null)
              const Center(
                child: Icon(Icons.play_circle_outline, color: Colors.white, size: 30),
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
