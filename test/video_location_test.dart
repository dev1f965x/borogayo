import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:borogayo/media/video_location.dart';

Uint8List box(String type, List<int> body) {
  final header = ByteData(8)..setUint32(0, 8 + body.length);
  return Uint8List.fromList([
    ...header.buffer.asUint8List(0, 4),
    ...latin1.encode(type),
    ...body,
  ]);
}

void main() {
  test('the recorded location is blanked and everything else kept', () async {
    final location = latin1.encode('+37.5665+126.9780/');
    final frames = List.filled(32, 7);
    final bytes = Uint8List.fromList([
      ...box('ftyp', latin1.encode('isom')),
      ...box('moov', [
        ...box('mvhd', List.filled(12, 1)),
        ...box('udta', box('©xyz', location)),
      ]),
      ...box('mdat', frames),
    ]);
    final file = File('${Directory.systemTemp.createTempSync().path}/a.mp4')
      ..writeAsBytesSync(bytes);

    await removeVideoLocation(file.path);
    final result = file.readAsBytesSync();

    expect(result.length, bytes.length);
    expect(latin1.decode(result).contains('+37.5665'), isFalse);
    expect(latin1.decode(result).contains('©xyz'), isFalse);
    expect(latin1.decode(result).contains('free'), isTrue);
    expect(result.sublist(result.length - frames.length), frames);
  });

  test('files without location boxes are unchanged', () async {
    final bytes = Uint8List.fromList([
      ...box('ftyp', latin1.encode('isom')),
      ...box('mdat', List.filled(16, 3)),
    ]);
    final file = File('${Directory.systemTemp.createTempSync().path}/b.mp4')
      ..writeAsBytesSync(bytes);

    await removeVideoLocation(file.path);

    expect(file.readAsBytesSync(), bytes);
  });
}
