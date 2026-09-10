// 앱 아이콘과 스플래시 이미지를 코드로 그린다.
//
// 디자인 툴로 만든 PNG를 저장소에 넣어두면 색 하나 바꾸는 데도 원본 파일이 필요해진다.
// 모양이 단순한 김에 스크립트로 두고, 브랜드 색이 바뀌면 여기만 고쳐 다시 돌린다.
//
//   dart run tool/generate_assets.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// 브랜드 보라. lib/theme.dart의 brand와 같은 값.
const _brandTop = (r: 0x8B, g: 0x79, b: 0x9E);
const _brandBottom = (r: 0x6A, g: 0x5A, b: 0x7C);
final _brand = img.ColorRgba8(0x7B, 0x6A, 0x8D, 255);
final _white = img.ColorRgba8(0xFF, 0xFF, 0xFF, 255);

/// 4배로 그린 뒤 줄인다. 도형을 직접 찍으면 경계가 계단처럼 남는데,
/// 축소하면서 평균이 나므로 따로 안티에일리어싱을 걸 필요가 없다.
const _supersample = 4;

void main() {
  _write('assets/icon/icon.png', _icon(1024, withBackground: true, glyphScale: 0.60));
  _write('assets/icon/foreground.png', _icon(1024, withBackground: false, glyphScale: 0.45));
  _write('assets/splash/splash.png', _icon(512, withBackground: false, glyphScale: 0.80));
  // 안드로이드 12 스플래시는 가운데 원 안에만 그림이 남는다. 잘리지 않게 작게 그린다.
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

/// 집 모양 안에 체크가 하나 들어간 그림.
/// "본 집을 확인해서 고른다"는 앱의 일이 그대로 보이는 가장 짧은 형태.
img.Image _icon(int size, {required bool withBackground, required double glyphScale}) {
  final canvas = size * _supersample;
  final image = img.Image(width: canvas, height: canvas, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  if (withBackground) {
    // 단색보다 위아래로 아주 옅은 그라디언트를 주는 편이 홈 화면에서 덜 납작하다.
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

  // ----- 지붕 -----
  img.fillPolygon(
    image,
    vertices: [
      img.Point(cx - s * 0.50, cy - s * 0.08),
      img.Point(cx, cy - s * 0.46),
      img.Point(cx + s * 0.50, cy - s * 0.08),
    ],
    color: _white,
  );

  // ----- 몸통 -----
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

  // ----- 체크 -----
  // 굵은 선(drawLine thickness)은 획이 겹치면서 줄무늬가 생긴다. 사각형 두 개로 직접 그린다.
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

/// 점 [from]에서 [to]까지 두께 [half]*2인 획 하나.
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
