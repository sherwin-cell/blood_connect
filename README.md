# blood_connect

A new Flutter project.

## Running against the backend

Identity verification sends the selfie to `blood_connect_backend`
(`POST /api/verification/face`). Its address is set at build time, never
hard-coded:

```bash
# Android emulator -> backend on this PC
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Real phone on the same Wi-Fi -> use the PC's LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Without it the app still runs, but face verification reports that it is
not set up. Verification order is enforced: valid ID first, then selfie.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
