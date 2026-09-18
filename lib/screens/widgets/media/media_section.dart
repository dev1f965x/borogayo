import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'media_add_sheet.dart';
import 'media_place_sheet.dart';
import 'media_tiles.dart';

import '../../../db/database.dart';
import '../../../media/media_store.dart';
import '../../../models/models.dart';
import '../../../text/josa.dart';
import '../../../theme.dart';
import '../../media_viewer_screen.dart';
import '../media_area_picker.dart';
import '../toast.dart';

/// Choice made in the add sheet: area, and where to take the media from.
typedef AddMediaRequest = ({String label, ImageSource source, MediaKind kind});

/// Where media can be placed: the building itself or one of its rooms.
typedef MediaPlace = ({int? buildingId, int? roomId, String name});

/// Photos and videos attached to a building or room.
///
/// A null [room] means the building's own media. Moving media changes both sections on the
/// room screen, so [revision] and [onPlacementChanged] keep them in sync.
class MediaSection extends StatefulWidget {
  const MediaSection({
    super.key,
    required this.building,
    this.room,
    required this.revision,
    required this.onPlacementChanged,
  });

  final Building building;
  final Room? room;
  final int revision;
  final VoidCallback onPlacementChanged;

  @override
  State<MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<MediaSection> {
  /// Last area used for building and room media, preselected on the next add.
  static final _lastLabel = <bool, String>{};

  List<MediaItem> _items = [];
  List<Room> _rooms = [];
  String? _filter;
  bool _loading = true;
  bool _busy = false;

  bool get _isBuilding => widget.room == null;
  int? get _buildingId => _isBuilding ? widget.building.id : null;
  int? get _roomId => widget.room?.id;

  String get _ownerLabel => _isBuilding
      ? widget.building.name
      : '${widget.building.name} ${widget.room!.name}';

  /// Only areas actually in use become filters, custom ones included.
  List<String> get _usedLabels => [
    ...{for (final item in _items) ?item.label},
  ];

  List<MediaItem> get _visibleItems => _filter == null
      ? _items
      : _items.where((item) => item.label == _filter).toList();

  /// Every place media can go, including where it is now: fixing a wrong area is more
  /// common than moving it elsewhere.
  List<MediaPlace> get _places => [
    (buildingId: widget.building.id, roomId: null, name: widget.building.name),
    for (final room in _rooms)
      (buildingId: null, roomId: room.id, name: room.name),
  ];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(MediaSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _refresh();
  }

  Future<void> _refresh() async {
    final db = AppDatabase.instance;
    final items = await db.readMedia(buildingId: _buildingId, roomId: _roomId);
    final rooms = await db.readRooms(widget.building.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _rooms = rooms;
      if (_filter != null && !items.any((item) => item.label == _filter)) {
        _filter = null;
      }
      _loading = false;
    });
  }

  Future<void> _add() async {
    if (_busy) return;

    final request = await showModalBottomSheet<AddMediaRequest>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MediaAddSheet(
        labels: areaPresetsFor(isBuilding: _isBuilding),
        initialLabel: _filter ?? _lastLabel[_isBuilding],
      ),
    );
    if (request == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final isPhoto = request.kind == MediaKind.photo;
      final picked = isPhoto
          ? await picker.pickImage(source: request.source)
          : await picker.pickVideo(source: request.source);
      if (picked == null) return;

      final path = isPhoto
          ? await MediaStore.savePhoto(picked.path)
          : await MediaStore.saveVideo(picked.path);
      final thumbPath = request.kind == MediaKind.video
          ? await MediaStore.saveVideoThumbnail(path)
          : null;
      final id = await AppDatabase.instance.addMedia(
        buildingId: _buildingId,
        roomId: _roomId,
        path: path,
        kind: request.kind,
        label: request.label,
        thumbPath: thumbPath,
      );
      _lastLabel[_isBuilding] = request.label;
      if (!mounted) return;
      HapticFeedback.lightImpact();
      await _refresh();
      if (!mounted) return;

      final kind = mediaKindLabel(request.kind);
      showUndo(
        '$kind${objectJosa(kind)} 추가했어요',
        onUndo: () async {
          await AppDatabase.instance.deleteMedia(id);
          await MediaStore.deleteFiles(path, thumbPath);
          await _refresh();
        },
      );
    } on Exception {
      if (!mounted) return;
      showToast('불러오지 못했어요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(MediaItem item) async {
    final visible = _visibleItems;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          items: visible,
          allItems: _items,
          initialIndex: visible.indexOf(item),
          ownerLabel: _ownerLabel,
        ),
      ),
    );
  }

  Future<void> _showItemMenu(MediaItem item) async {
    final palette = context.palette;

    final action = await showModalBottomSheet<String>(
      context: context,
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
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: palette.danger),
              title: Text(
                '${mediaKindLabel(item.kind)} 삭제',
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
      await _place(item);
    } else {
      _delete(item);
    }
  }

  Future<void> _place(MediaItem item) async {
    final current = _places.firstWhere(
      (place) => item.buildingId != null
          ? place.buildingId == item.buildingId
          : place.roomId == item.roomId,
      orElse: () => _places.first,
    );

    final result =
        await showModalBottomSheet<({MediaPlace place, String label})>(
          context: context,
          isScrollControlled: true,
          builder: (_) => MediaPlaceSheet(
            places: _places,
            current: current,
            currentLabel: item.label,
          ),
        );
    if (result == null || !mounted) return;

    final db = AppDatabase.instance;
    await db.placeMedia(
      item.id,
      buildingId: result.place.buildingId,
      roomId: result.place.roomId,
      label: result.label,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    widget.onPlacementChanged();

    final moved = result.place != current;
    final target = moved ? result.place.name : result.label;
    showUndo(
      '‘$target’${directionJosa(target)} ${moved ? '옮겼어요' : '바꿨어요'}',
      onUndo: () async {
        await db.placeMedia(
          item.id,
          buildingId: item.buildingId,
          roomId: item.roomId,
          label: item.label,
        );
        widget.onPlacementChanged();
      },
    );
  }

  void _delete(MediaItem item) {
    final deletion = AppDatabase.instance.stageMediaDeletion(item.id);
    _refresh();

    final kind = mediaKindLabel(item.kind);
    showDeletionUndo(
      '$kind${objectJosa(kind)} 삭제했어요',
      deletion,
      onUndone: _refresh,
      afterCommit: () => MediaStore.deleteFiles(item.path, item.thumbPath),
    );
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
              '사진·영상',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.textBody,
              ),
            ),
            if (_items.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '${_items.length}',
                style: TextStyle(fontSize: 13, color: palette.textMuted),
              ),
            ],
            const Spacer(),
            TextButton.icon(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
            ),
          ],
        ),
        if (_usedLabels.length > 1) ...[
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                MediaFilterChip(
                  label: '전체',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final label in _usedLabels)
                  MediaFilterChip(
                    label: label,
                    selected: _filter == label,
                    onTap: () => setState(() => _filter = label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_loading)
          const SizedBox(height: 96)
        else if (_items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              '사진이나 영상을 추가해 보세요',
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
              itemBuilder: (context, index) => MediaThumbnail(
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
