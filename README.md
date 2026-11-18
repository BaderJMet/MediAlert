# MediAlert

MediAlert is an offline-first Android app that helps elderly users and patients with chronic conditions stay on top of their medications and reach an emergency contact quickly. It was developed as a senior project at Saudi Electronic University.

## Features

- Calendar-based medication scheduling with local notification reminders
- Dose confirmation and adherence history (taken, missed)
- Health report dashboard with adherence charts
- PDF health report export
- One-tap SOS that calls the primary emergency contact
- Medical profile and emergency contact management
- App lock using the device's biometric or PIN authentication

## Tech Stack

- Flutter (Dart)
- SQLite (`sqflite`)
- `flutter_local_notifications` and `timezone`
- `local_auth`
- `fl_chart`
- `pdf` and `printing`

### Option 1: Install the APK (recommended)

1. Download `MediAlert.apk` from the [Releases](../../releases) page, or from the project folder.
2. Transfer it to your Android device (Android 10 or higher).
3. On the device, enable **Install from Unknown Sources** in Settings.
4. Open the APK and tap **Install**.
5. Launch the app and grant the requested permissions: notifications, contacts, and phone (needed for SOS calling).

If you're using an emulator, drag the APK file onto the emulator window.

### Option 2: Build from source

Requires Flutter 3.41.4.

```
flutter doctor
flutter pub get
flutter run
```


## Limitations

- Developed and tested on Android only.
- Data is stored locally without database-level encryption. Access is protected by the device's biometric or PIN authentication.
- SOS uses the device's native calling rather than SMS or GPS, so it works without an internet connection.

## Author

[Bader Almetairi] ([LinkedIn](https://linkedin.com/in/BaderJMet))
