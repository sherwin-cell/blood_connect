/// Features that are built in stages and stay hidden until finished.
///
/// Off by default; turn one on for a build with, for example:
///
///     flutter run --dart-define=ANNOUNCEMENTS_ENABLED=true
abstract final class FeatureFlags {
  /// PRC announcements: the admin portal's announcement pages are still
  /// under development, so the Home "Announcements" tile and its placeholder
  /// screen are hidden. Announcement push notifications (if any) open Home.
  static const bool announcements = bool.fromEnvironment(
    'ANNOUNCEMENTS_ENABLED',
  );
}
