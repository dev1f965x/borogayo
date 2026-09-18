import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/models.dart';
import '../../../theme.dart';
import '../media_area_picker.dart';

/// Choice made in the add sheet: area, and where to take the media from.
typedef AddMediaRequest = ({String label, ImageSource source, MediaKind kind});

/// Picks the area first, then capture or gallery, in one sheet.
class MediaAddSheet extends StatefulWidget {
  const MediaAddSheet({super.key, required this.labels, this.initialLabel});

  final List<String> labels;
  final String? initialLabel;

  @override
  State<MediaAddSheet> createState() => MediaAddSheetState();
}

class MediaAddSheetState extends State<MediaAddSheet> {
  late final _picker = AreaPickerController(
    labels: widget.labels,
    initial: widget.initialLabel,
  );

  @override
  void dispose() {
    _picker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ready = _picker.label.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                '어디를 찍었나요?',
                style: TextStyle(
                  fontSize: 17,
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
            for (final (icon, label, source, kind) in const [
              (
                Icons.photo_camera_outlined,
                '사진 촬영',
                ImageSource.camera,
                MediaKind.photo,
              ),
              (
                Icons.videocam_outlined,
                '영상 촬영',
                ImageSource.camera,
                MediaKind.video,
              ),
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
                  icon,
                  color: ready ? palette.textBody : palette.textMuted,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: ready ? palette.textBody : palette.textMuted,
                  ),
                ),
                onTap: () => Navigator.pop(context, (
                  label: _picker.label,
                  source: source,
                  kind: kind,
                )),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
