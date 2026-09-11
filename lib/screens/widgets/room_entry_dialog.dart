import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../theme.dart';

/// Values for creating a room. When a new building is needed, [buildingId] is null
/// and [newBuildingName] holds its name.
typedef RoomEntryResult = ({
  int? buildingId,
  String? newBuildingName,
  String roomName,
  String? memo,
});

/// Adds a room, starting with which building it belongs to.
///
/// The project screen ranks rooms, so adding something means viewing another room.
/// The building is just where it goes, and can be created here if it doesn't exist.
class RoomEntryDialog extends StatefulWidget {
  const RoomEntryDialog({
    super.key,
    required this.projectId,
    required this.buildings,
  });

  final int projectId;
  final List<Building> buildings;

  @override
  State<RoomEntryDialog> createState() => _RoomEntryDialogState();
}

class _RoomEntryDialogState extends State<RoomEntryDialog> {
  final _buildingController = TextEditingController();
  final _nameController = TextEditingController();
  final _memoController = TextEditingController();

  /// Null when "new building" is selected.
  late int? _buildingId = widget.buildings.firstOrNull?.id;

  String? _buildingError;
  String? _nameError;
  bool _checking = false;

  @override
  void dispose() {
    _buildingController.dispose();
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking) return;

    final db = AppDatabase.instance;
    final newBuilding = _buildingId == null
        ? _buildingController.text.trim()
        : null;
    final name = _nameController.text.trim();

    if (newBuilding != null && newBuilding.isEmpty) {
      setState(() => _buildingError = '건물 이름을 입력해주세요.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _nameError = '방 이름을 입력해주세요.');
      return;
    }

    setState(() => _checking = true);

    if (newBuilding != null &&
        await db.buildingNameExists(widget.projectId, newBuilding)) {
      if (!mounted) return;
      setState(() {
        _buildingError = '이 목록에 같은 이름의 건물이 있어요.';
        _checking = false;
      });
      return;
    }
    // A new building has no rooms, so there's nothing to collide with.
    if (_buildingId != null && await db.roomNameExists(_buildingId!, name)) {
      if (!mounted) return;
      setState(() {
        _nameError = '이 건물에 같은 이름의 방이 있어요.';
        _checking = false;
      });
      return;
    }

    if (!mounted) return;
    final memo = _memoController.text.trim();
    Navigator.pop(context, (
      buildingId: _buildingId,
      newBuildingName: newBuilding,
      roomName: name,
      memo: memo.isEmpty ? null : memo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AlertDialog(
      title: const Text('방 추가'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '건물',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final building in widget.buildings)
                  _Choice(
                    label: building.name,
                    selected: _buildingId == building.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _buildingId = building.id;
                        _buildingError = null;
                        _nameError = null;
                      });
                    },
                  ),
                _Choice(
                  label: '새 건물',
                  icon: Icons.add,
                  selected: _buildingId == null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _buildingId = null;
                      _nameError = null;
                    });
                  },
                ),
              ],
            ),
            if (_buildingId == null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _buildingController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: '건물 · 예: 역삼동 대성빌라',
                  errorText: _buildingError,
                ),
                onChanged: (_) {
                  if (_buildingError != null) {
                    setState(() => _buildingError = null);
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '방',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: widget.buildings.isNotEmpty,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '예: 302호',
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _memoController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '메모 (선택) · 예: 65/50, 남향',
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          child: const Text('추가'),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? palette.brand : palette.background,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? palette.brand : palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : palette.textMuted,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
