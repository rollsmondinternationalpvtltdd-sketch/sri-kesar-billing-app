# Android Build Guide

## Requirements

- Flutter stable SDK
- Android Studio
- Android SDK
- Java 17
- Android device or emulator

Check:

```bash
flutter doctor
```

## First-time setup

If the Android folder is not already generated:

```bash
flutter create . --platforms=android
flutter pub get
```

## Build debug APK

```bash
flutter build apk --debug
```

## Build release APK

```bash
flutter build apk --release
```

APK output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Permissions

Copy `android_permissions_snippet.xml` permissions into:

```text
android/app/src/main/AndroidManifest.xml
```

above the `<application>` tag.

## Google Drive

To activate Drive upload:
1. Create Google Cloud project.
2. Enable Google Drive API.
3. Configure OAuth consent.
4. Create Android OAuth Client ID.
5. Add package name and SHA-1.
6. Rebuild APK.
