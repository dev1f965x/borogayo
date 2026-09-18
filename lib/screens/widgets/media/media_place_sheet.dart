import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme.dart';
import '../media_area_picker.dart';

/// Where media can be placed: the building itself or one of its rooms.
typedef MediaPlace = ({int? buildingId, int? roomId, String name});

/// Changes where media is attached and its area. The area names depend on the place,
/// so both are chosen together.
class MediaPlaceSheet extends StatefulWidget {
  const MediaPlaceSheet({
    super.key,
    required this.places,
    required this.current,
    this.currentLabel,
  });

  final List<MediaPlace> places;
  final MediaPlace current;
  final String? currentLabel;

  @override
  State<MediaPlaceSheet> createState() => MediaPlaceSheetState();
}

class MediaPlaceSheetState extends State<MediaPlaceSheet> {
  late MediaPlace _place = widget.current;
  late AreaPickerController _picker = _pickerFor(_place);

  AreaPickerController _pickerFor(MediaPlace place) => AreaPickerController(
    labels: areaPresetsFor(isBuilding: place.buildingId != null),
    initial: widget.currentLabel,
  );

  @override
  void dispose() {
    _picker.dispose();
    super.dispose();
  }

  void _select(MediaPlace place) {
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
              '위치·구역 수정',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: palette.textStrong,
              ),
            ),
            const SizedBox(height: 16),
            label('위치'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final place in widget.places)
                  PillChoice(
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
            AreaPicker(controller: _picker, onChanged: () => setState(() {})),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _picker.label.isEmpty
                    ? null
                    : () => Navigator.pop(context, (
                        place: _place,
                        label: _picker.label,
                      )),
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
