# borogayo

[English](./README.md) | [한국어](./README.ko.md)

집 보러 다닐 때 쓰는 Android 앱입니다. 평가 기준을 한 번 정해두고 보러 간 곳마다 같은 기준으로 점수를 매기면, 방이 점수순으로 정렬됩니다.

- 채광, 소음, 수압, 교통 같은 기본 기준이 미리 들어 있고 수정할 수 있습니다
- 건물 기준은 건물마다 한 번, 방 기준은 방마다 매깁니다
- 기준은 0~10 점수형이나 있음/없음 여부형이고, 중요도를 1~5로 정합니다
- 모든 기준을 매긴 방만 점수가 나오고, 건물과 상관없이 방끼리 순위를 매깁니다
- 사진과 영상을 구역별로 붙이고 공유할 수 있습니다
- 데이터는 기기에만 저장됩니다. 계정이나 네트워크를 쓰지 않습니다

## 빌드

[Flutter SDK](https://docs.flutter.dev/get-started/install)와 Android SDK가 필요합니다.

```bash
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r`로 설치해야 앱 데이터가 유지됩니다. `flutter install`은 기존 앱을 지운 뒤 설치해서 데이터가 사라집니다.

## 테스트

```bash
flutter test
```

## 아이콘과 스플래시

이미지는 `tool/generate_assets.dart`가 그립니다.

```bash
dart run tool/generate_assets.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
