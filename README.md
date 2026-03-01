# DCSS Mobile

Native portrait Flutter client for **Dungeon Crawl Stone Soup (DCSS) Webtiles**.

This project targets sideloaded mobile builds and connects to:

- WebSocket: `wss://crawl.develz.org/socket`
- Game ID: `dcss-web-trunk`
 
<img width="645" height="1398" alt="IMG_1245" src="https://github.com/user-attachments/assets/5dac0a15-fba2-4cb3-b856-c18401ba714d" />

## What is included

- Riverpod state management
- WebSocket protocol/message handling for DCSS
- Flame-based tile viewport rendering
- Custom in-game keyboard panel
- Message log and status bar
- In-game menu overlay
- Login + settings screens

## Requirements

- Flutter 3.x
- Dart 3.x
- Android SDK (for APK/AAB builds)
- Xcode (for iOS local builds)

## Quick start

```bash
flutter pub get
flutter run
```

If platform folders are missing in your local checkout, scaffold them once:

```bash
flutter create --platforms=android,ios .
```

## Local release builds

### Android

```bash
flutter build apk --release
flutter build appbundle --release
```

Outputs:

- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

### iOS (unsigned)

```bash
flutter build ios --release --no-codesign
```

## GitHub Actions CI

Workflow file: `.github/workflows/build.yml`

It runs on pushes to `main`, pull requests, manual dispatch, and version tags (`v*`).

Pipeline steps:

1. Checkout code
2. Setup Java + Flutter
3. Auto-generate missing `android/` and `ios/` folders if needed
4. `flutter pub get`
5. `flutter analyze`
6. Run tests when present
7. Build Android APK + AAB
8. Upload Android artifacts
9. Run iOS validation build (`flutter build ios --release --no-codesign`) on macOS
10. Package an unsigned IPA from `Runner.app`
11. For tag pushes (`v*`), publish a GitHub Release with APK/AAB/IPA attached

### Triggering a release build

Push a tag like:

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow will create a GitHub Release and attach:

- `app-release.apk`
- `app-release.aab`
- `dcss-mobile-unsigned.ipa`

## Notes

- CI validates iOS compilation with `--no-codesign` but does not produce a signed IPA.
- This app is intended for sideloading/testing, not app store submission.
