/// Blood-Connect backend (blood_connect_backend) location.
///
/// Set at build/run time, never hard-coded:
///
///     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///
/// (10.0.2.2 is the host machine from the Android emulator; use your PC's
/// LAN address on a real phone, or the deployed HTTPS URL in release builds.)
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get isConfigured => baseUrl.trim().isNotEmpty;

  /// [path] must start with `/`.
  static Uri endpoint(String path, {String? base}) {
    final root = (base ?? baseUrl).trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$root$path');
  }
}
