# SRI KESAR ENTERPRISES
# Smart Billing & Invoice Management Android App

This package contains the Flutter Android source code for the Sri Kesar Enterprises mobile billing application.

## What is included

- Flutter Android source code
- SQLite offline database
- Product master
- Customer master
- Smart billing screen
- Unlimited invoice rows through dynamic item cards
- Auto invoice number
- Auto GST calculation
- Auto HSN tax summary
- Amount in words
- PDF generation engine
- A4 / Letter / Legal support
- Portrait / Landscape / Auto orientation support
- PDF preview / Android print preview
- PDF save and share
- WhatsApp / Email sharing through Android share sheet
- Google Drive upload service
- Admin password login
- PIN login
- Fingerprint / biometric login support
- Dark mode
- Backup export
- Reports
- Invoice history with edit, duplicate, print and share

## Important

This workspace does not have Flutter SDK or Android Studio installed, so a compiled APK cannot be produced here. This package is the Android source code. To generate the APK, open it on a computer with Flutter and Android Studio.

## Build APK

```bash
flutter pub get
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Default Login

Admin Password:

```text
admin123
```

PIN:

```text
1234
```

Change them before production deployment.

## Invoice Template

The PDF service recreates the approved Sri Kesar Enterprises tax invoice structure with company header, logo, buyer/consignee details, item table, GST summary, HSN tax summary, amount in words, declaration and authorized signatory.
