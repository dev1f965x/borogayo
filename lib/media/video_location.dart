import 'dart:io';
import 'dart:typed_data';

/// Boxes that record where a video was shot: `©xyz` (Android, QuickTime) and `loci` (3GPP).
const _locationBoxes = {'©xyz', 'loci'};

/// Boxes that hold user data, where the location boxes live.
const _containerBoxes = {'moov', 'udta'};

/// Removes the recorded location from an MP4, MOV, or 3GP file in place.
///
/// Each location box is blanked and renamed to `free`, which players skip. Sizes and offsets
/// stay the same, so nothing else in the file has to be rewritten.
/// Other formats are left as they are.
Future<void> removeVideoLocation(String path) async {
  final file = await File(path).open(mode: FileMode.append);
  try {
    await _freeLocationBoxes(file, 0, await file.length());
  } finally {
    await file.close();
  }
}

Future<void> _freeLocationBoxes(
  RandomAccessFile file,
  int start,
  int end,
) async {
  var offset = start;
  while (offset + 8 <= end) {
    await file.setPosition(offset);
    final header = await file.read(16);
    final fields = ByteData.sublistView(header);
    final type = String.fromCharCodes(header, 4, 8);

    var headerSize = 8;
    var size = fields.getUint32(0);
    if (size == 1 && header.length == 16) {
      headerSize = 16;
      size = fields.getUint64(8);
    } else if (size == 0) {
      size = end - offset;
    }
    if (size < headerSize || offset + size > end) return;

    if (_locationBoxes.contains(type)) {
      await file.setPosition(offset + 4);
      await file.writeFrom('free'.codeUnits);
      await file.setPosition(offset + headerSize);
      await file.writeFrom(Uint8List(size - headerSize));
    } else if (_containerBoxes.contains(type)) {
      await _freeLocationBoxes(file, offset + headerSize, offset + size);
    }
    offset += size;
  }
}
