// Draws the app icon and splash images.
//
// The shapes are simple enough to keep as code instead of design files;
// change the brand color here and rerun.
//
//   dart run tool/generate_assets.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Brand purple, same as `brand` in lib/theme.dart.
const _brandTop = (r: 0x8B, g: 0x79, b: 0x9E);
const _brandBottom = (r: 0x6A, g: 0x5A, b: 0x7C);
final _brand = img.ColorRgba8(0x7B, 0x6A, 0x8D, 255);
final _white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 255);

/// Drawn at 4x and scaled down, which antialiases the edges.
const _supersample = 4;

void main() {
  _write(
    'assets/icon/icon.png',
    _icon(1024, withBackground: true, glyphScale: 0.60),
  );
  _write(
    'assets/icon/foreground.png',
    _icon(1024, withBackground: false, glyphScale: 0.45),
  );
  _write(
    'assets/splash/splash.png',
    _icon(512, withBackground: false, glyphScale: 0.80),
  );
  // The Android 12 splash crops to a circle, so the glyph is drawn smaller.
  _write(
    'assets/splash/splash_android12.png',
    _icon(1152, withBackground: false, glyphScale: 0.40),
  );
  stdout.writeln('done');
}

void _write(String path, img.Image image) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  stdout.writeln('$path  ${image.width}x${image.height}');
}

/// A house with a check mark: picking a place after checking it out.
img.Image _icon(
  int size, {
  required bool withBackground,
  required double glyphScale,
}) {
  final canvas = size * _supersample;
  final image = img.Image(width: canvas, height: canvas, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  if (withBackground) {
    // A faint vertical gradient looks less flat on the home screen than a solid color.
    for (var y = 0; y < canvas; y++) {
      final t = y / (canvas - 1);
      img.drawLine(
        image,
        x1: 0,
        y1: y,
        x2: canvas - 1,
        y2: y,
        color: img.ColorRgba8(
          _lerp(_brandTop.r, _brandBottom.r, t),
          _lerp(_brandTop.g, _brandBottom.g, t),
          _lerp(_brandTop.b, _brandBottom.b, t),
          255,
        ),
      );
    }
  }

  final s = canvas * glyphScale;
  final cx = canvas / 2;
  final cy = canvas / 2;

  // ----- Roof -----
  img.fillPolygon(
    image,
    vertices: [
      img.Point(cx - s * 0.50, cy - s * 0.08),
      img.Point(cx, cy - s * 0.46),
      img.Point(cx + s * 0.50, cy - s * 0.08),
    ],
    color: _white,
  );

  // ----- Body -----
  final left = cx - s * 0.355;
  final right = cx + s * 0.355;
  final top = cy - s * 0.09;
  final bottom = cy + s * 0.42;
  final radius = s * 0.07;

  img.fillPolygon(
    image,
    vertices: [
      img.Point(left, top),
      img.Point(right, top),
      img.Point(right, bottom - radius),
      img.Point(right - radius, bottom),
      img.Point(left + radius, bottom),
      img.Point(left, bottom - radius),
    ],
    color: _white,
  );
  for (final x in [left + radius, right - radius]) {
    img.fillCircle(
      image,
      x: x.round(),
      y: (bottom - radius).round(),
      radius: radius.round(),
      color: _white,
    );
  }

  // ----- Check -----
  // Thick drawLine strokes band where they overlap, so the check is two rectangles.
  final h = s * 0.055;
  final a = img.Point(cx - s * 0.165, cy + s * 0.130);
  final b = img.Point(cx - s * 0.045, cy + s * 0.245);
  final c = img.Point(cx + s * 0.175, cy + s * 0.030);

  _stroke(image, a, b, h);
  _stroke(image, b, c, h);
  for (final end in [a, b, c]) {
    img.fillCircle(
      image,
      x: end.x.round(),
      y: end.y.round(),
      radius: h.round(),
      color: _brand,
    );
  }

  return img.copyResize(
    image,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
}

/// A stroke from [from] to [to] with thickness [half] * 2.
void _stroke(img.Image image, img.Point from, img.Point to, double half) {
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  final length = math.sqrt(dx * dx + dy * dy);
  final nx = -dy / length * half;
  final ny = dx / length * half;

  img.fillPolygon(
    image,
    vertices: [
      img.Point(from.x + nx, from.y + ny),
      img.Point(to.x + nx, to.y + ny),
      img.Point(to.x - nx, to.y - ny),
      img.Point(from.x - nx, from.y - ny),
    ],
    color: _brand,
  );
}

int _lerp(int from, int to, double t) => (from + (to - from) * t).round();
