import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/database.dart';
import '../../models/models.dart';
import '../../theme.dart';

/// A room to create. [buildingId] is null when [newBuildingName] should be created with it.
typedef RoomEntry = ({int? buildingId, String? newBuildingName, String name});

/// Bottom sheet for adding a room. Returns null when dismissed.
Future<RoomEntry?> showRoomEntrySheet(
  BuildContext context, {
  required int projectId,
  required List<Building> buildings,
}) => showModalBottomSheet<RoomEntry>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _RoomEntrySheet(projectId: projectId, buildings: buildings),
);

class _RoomEntrySheet extends StatefulWidget {
  const _RoomEntrySheet({required this.projectId, required this.buildings});

  final int projectId;

  /// Most recently used first, so the first one is the likely choice.
  final List<Building> buildings;

  @override
  State<_RoomEntrySheet> createState() => _RoomEntrySheetState();
}

class _RoomEntrySheetState extends State<_RoomEntrySheet> {
  final _buildingController = TextEditingController();
  final _nameController = TextEditingController();

  /// Null while "new building" is selected.
  late int? _buildingId = widget.buildings.firstOrNull?.id;
  String? _buildingError;
  String? _nameError;
  bool _checking = false;

  @override
  void dispose() {
    _buildingController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _select(int? buildingId) {
    HapticFeedback.selectionClick();
    setState(() {
      _buildingId = buildingId;
      _buildingError = null;
      _nameError = null;
    });
  }

  Future<void> _submit() async {
    if (_checking) return;
    final db = AppDatabase.instance;
    final newBuilding = _buildingId == null
        ? _buildingController.text.trim()
        : null;
    final name = _nameController.text.trim();

    setState(() {
      _buildingError = newBuilding != null && newBuilding.isEmpty
          ? '건물 이름을 입력해 주세요'
          : null;
      _nameError = name.isEmpty ? '방 이름을 입력해 주세요' : null;
    });
    if (_buildingError != null || _nameError != null) return;

    setState(() => _checking = true);
    final buildingTaken =
        newBuilding != null &&
        await db.buildingNameExists(widget.projectId, newBuilding);
    final roomTaken =
        _buildingId != null && await db.roomNameExists(_buildingId!, name);
    if (!mounted) return;

    if (buildingTaken || roomTaken) {
      setState(() {
        _buildingError = buildingTaken ? '같은 이름의 건물이 있어요' : null;
        _nameError = roomTaken ? '이 건물에 같은 이름의 방이 있어요' : null;
        _checking = false;
      });
      return;
    }
    Navigator.pop(context, (
      buildingId: _buildingId,
      newBuildingName: newBuilding,
      name: name,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final creatingBuilding = _buildingId == null;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '방 추가',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.textStrong,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final building in widget.buildings)
                  PillChoice(
                    label: building.name,
                    icon: Icons.apartment_outlined,
                    selected: _buildingId == building.id,
                    onTap: () => _select(building.id),
                  ),
                PillChoice(
                  label: '새 건물',
                  icon: Icons.add,
                  creates: true,
                  selected: creatingBuilding,
                  onTap: () => _select(null),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (creatingBuilding) ...[
              TextField(
                controller: _buildingController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '건물',
                  hintText: '대성빌라',
                  errorText: _buildingError,
                ),
                onChanged: (_) {
                  if (_buildingError != null) {
                    setState(() => _buildingError = null);
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _nameController,
              autofocus: !creatingBuilding,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '방',
                hintText: '302호',
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _checking ? null : _submit,
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }
}
