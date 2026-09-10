import 'dart:io';

import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 사진·영상 파일을 앱 전용 저장소에 보관한다.
///
/// 갤러리나 카메라가 준 원본 경로는 임시 파일이거나 나중에 사라질 수 있어서,
/// 앱 문서 폴더로 복사해두고 DB에는 그 경로만 저장한다.
class MediaStore {
  const MediaStore._();

  static Future<Directory> _mediaDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'media'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 원본을 앱 저장소로 복사하고, 복사본 경로를 돌려준다.
  static Future<String> save(String sourcePath) async {
    final dir = await _mediaDir();
    final name = '${DateTime.now().microsecondsSinceEpoch}${p.extension(sourcePath)}';
    final target = p.join(dir.path, name);
    await File(sourcePath).copy(target);
    return target;
  }

  /// 영상의 첫 장면을 뽑아 이미지로 저장한다.
  ///
  /// 목록에서 매번 영상을 열어 프레임을 꺼내면 느리고 배터리도 먹는다.
  /// 추가할 때 한 번만 만들어두고 그 뒤로는 사진처럼 그린다.
  /// 코덱을 못 읽는 파일도 있으므로 실패하면 null — 그때는 재생 아이콘만 보여준다.
  static Future<String?> saveVideoThumbnail(String videoPath) async {
    try {
      final dir = await _mediaDir();
      final file = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 70,
      );
      return file.path;
    } on Exception {
      return null;
    }
  }

  static Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// DB가 더 이상 참조하지 않는 파일을 지운다.
  ///
  /// 방을 지웠다가 '실행취소'로 되살릴 수 있어야 해서, 삭제 시점에 파일까지
  /// 바로 지우지는 않는다. 그래서 되돌리지 않은 경우 파일만 남는데,
  /// 앱을 시작할 때 이 정리를 한 번 돌려서 회수한다.
  static Future<void> cleanupOrphans(Set<String> knownPaths) async {
    try {
      final dir = await _mediaDir();
      await for (final entity in dir.list()) {
        if (entity is File && !knownPaths.contains(entity.path)) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      // 정리는 부가 작업이라 실패해도 앱 실행을 막지 않는다.
    }
  }
}
