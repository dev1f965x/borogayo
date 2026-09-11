# borogayo

[English](./README.md) | [한국어](./README.ko.md)

Android app for house hunting. Set your criteria once, score every place you visit against them, and see the rooms ranked by score. The UI is in Korean.

- Common criteria (light, noise, water pressure, transit…) are preset and editable
- Building criteria are scored once per building; room criteria per room
- Criteria are a 0–10 slider or yes/no, each with a weight from 1 to 5
- Rooms get a score only after every criterion is rated, then rank across all buildings
- Photos and videos tagged by area, with sharing
- Everything stays on the device; no account or network

## Build

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) and the Android SDK.

```bash
flutter pub get
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` keeps app data. `flutter install` uninstalls the app first and wipes it.

## Test

```bash
flutter test
```

## Icon and splash

The images are drawn by `tool/generate_assets.dart`.

```bash
dart run tool/generate_assets.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## License

[MIT](./LICENSE)
