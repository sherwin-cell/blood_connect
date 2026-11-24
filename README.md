# blood_connect

Blood-Connect mobile app (Philippine Red Cross, Sorsogon Chapter): blood
requests, donor applications and donor matching.

## Running against the backend

Identity verification (`POST /api/verification/face`) and the private ID /
Blood Request Form uploads (`POST /api/files/{kind}`) go to
`blood_connect_backend`. Its address is set at build time, never hard-coded:

```bash
# Android emulator -> backend on this PC
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Real phone on the same Wi-Fi -> use the PC's LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

Plain `http://` works only in debug and profile builds
(`android/app/src/debug|profile/AndroidManifest.xml`). Release builds are
HTTPS-only (`usesCleartextTraffic="false"`), so they need the deployed
backend's `https://` URL.

Without it the app still runs, but face verification and ID / BRF uploads
report that they are not set up. Verification order is enforced: valid ID
first, then selfie.

## Google Play release

- Application ID: `com.bloodconnect.sorsogon` (permanent once published).
  `google-services.json` and `lib/firebase_options.dart` must be generated
  for this ID (`flutterfire configure`).
- Signing: copy `android/key.properties.example` to `android/key.properties`
  (git-ignored) and point it at your upload keystore. Without it, release
  builds are debug-signed and Play rejects them.
- Add the upload key's and Play App Signing key's SHA-1 / SHA-256 to the
  Android app in Firebase (Google Sign-In), and the SHA-256 values to
  `assetlinks.json` on blood-connect-12ac2.web.app (verified app links).

### Verified app links (`hosting/.well-known/assetlinks.json`)

> **TODO before Google Play rollout:** `assetlinks.json` currently lists
> only the **debug** key's SHA-256 (`78:1A:3B:…:6F:BE`, from
> `~/.android/debug.keystore` on the dev PC), so invite links open the app
> only on locally built debug installs. Add the **upload key** and **Google
> Play App Signing key** SHA-256 values to `sha256_cert_fingerprints` (Play
> Console → Test and release → App integrity → App signing), then
> `firebase deploy --only hosting`. JSON has no comments, so this note lives
> here.

```bash
# SHA-256 of a keystore (use Android Studio's JBR keytool on Windows)
keytool -list -v -keystore <keystore.jks> -alias <alias>
```

Debug keystores differ per PC; a teammate testing app links from their
own machine needs their debug SHA-256 added too. Check verification on a
device with `adb shell pm get-app-links com.bloodconnect.sorsogon`.

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://<backend host>
# -> build/app/outputs/bundle/release/app-release.aab
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
