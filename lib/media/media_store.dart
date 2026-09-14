import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'video_location.dart';

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

  static Future<String> _newPath(String extension) async => p.join(
    (await _mediaDir()).path,
    '${DateTime.now().microsecondsSinceEpoch}$extension',
  );

  /// Stores a photo as an upright JPEG with no metadata and returns its path.
  ///
  /// Camera photos carry GPS coordinates, capture time, and the device model, which would
  /// travel along whenever the photo is shared. Re-encoding keeps only the pixels.
  static Future<String> savePhoto(String sourcePath) async {
    final saved = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      await _newPath('.jpg'),
      quality: 85,
    );
    if (saved == null) {
      throw FileSystemException('Unreadable photo', sourcePath);
    }
    return saved.path;
  }

  /// Stores a video without the location it was recorded at and returns its path.
  static Future<String> saveVideo(String sourcePath) async {
    final target = await _newPath(p.extension(sourcePath));
    await File(sourcePath).copy(target);
    await removeVideoLocation(target);
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

  /// Deletes a media file and its video thumbnail, if any.
  static Future<void> deleteFiles(String path, String? thumbPath) async {
    for (final file in [File(path), if (thumbPath != null) File(thumbPath)]) {
      if (await file.exists()) await file.delete();
    }
  }

  /// Deletes files the database no longer references.
  ///
  /// Deleting a room, building, or project removes only rows, so their files are
  /// reclaimed here on app start.
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
