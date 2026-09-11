import 'dart:io';

import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps photo and video files in app-private storage.
///
/// Paths from the gallery or camera may be temporary, so files are copied into the app's
/// documents directory and only that path goes into the database.
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

  /// Copies the source into app storage and returns the copy's path.
  static Future<String> save(String sourcePath) async {
    final dir = await _mediaDir();
    final name =
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(sourcePath)}';
    final target = p.join(dir.path, name);
    await File(sourcePath).copy(target);
    return target;
  }

  /// Saves a video's first frame as an image.
  ///
  /// Decoding frames every time a list is drawn is slow and drains the battery, so the
  /// thumbnail is made once when the video is added. Returns null for codecs that can't be
  /// read, in which case only a play icon is shown.
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

  /// Deletes files the database no longer references.
  ///
  /// Deleting a room can be undone, so its files aren't removed right away. Files from
  /// deletions that were never undone are reclaimed here on app start.
  static Future<void> cleanupOrphans(Set<String> knownPaths) async {
    try {
      final dir = await _mediaDir();
      await for (final entity in dir.list()) {
        if (entity is File && !knownPaths.contains(entity.path)) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      // Cleanup is best-effort and must never block startup.
    }
  }
}
