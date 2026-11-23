/// Push notification switches stored on `users/{uid}.notificationPreferences`.
///
/// blood_connect_backend (notifications/preferences.py) reads the same keys
/// before sending a push; a missing key means "on". Turning a switch off
/// silences the push only: the notification still appears in the bell list.
/// Announcements use an FCM topic, so the app subscribes or unsubscribes the
/// device itself. Verification results are always sent.
class NotificationPreferences {
  const NotificationPreferences({
    this.requestUpdates = true,
    this.donorAlerts = true,
    this.donationUpdates = true,
    this.chatMessages = true,
    this.announcements = true,
  });

  static const field = 'notificationPreferences';

  static const requestUpdatesKey = 'requestUpdates';
  static const donorAlertsKey = 'donorAlerts';
  static const donationUpdatesKey = 'donationUpdates';
  static const chatMessagesKey = 'chatMessages';
  static const announcementsKey = 'announcements';

  final bool requestUpdates;
  final bool donorAlerts;
  final bool donationUpdates;
  final bool chatMessages;
  final bool announcements;

  factory NotificationPreferences.fromMap(dynamic raw) {
    if (raw is! Map) return const NotificationPreferences();
    bool on(String key) => raw[key] != false;
    return NotificationPreferences(
      requestUpdates: on(requestUpdatesKey),
      donorAlerts: on(donorAlertsKey),
      donationUpdates: on(donationUpdatesKey),
      chatMessages: on(chatMessagesKey),
      announcements: on(announcementsKey),
    );
  }

  Map<String, bool> toMap() => {
    requestUpdatesKey: requestUpdates,
    donorAlertsKey: donorAlerts,
    donationUpdatesKey: donationUpdates,
    chatMessagesKey: chatMessages,
    announcementsKey: announcements,
  };

  bool valueOf(String key) => toMap()[key] ?? true;

  NotificationPreferences copyWithKey(String key, bool value) {
    final map = toMap()..[key] = value;
    return NotificationPreferences.fromMap(map);
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.requestUpdates == requestUpdates &&
      other.donorAlerts == donorAlerts &&
      other.donationUpdates == donationUpdates &&
      other.chatMessages == chatMessages &&
      other.announcements == announcements;

  @override
  int get hashCode => Object.hash(
    requestUpdates,
    donorAlerts,
    donationUpdates,
    chatMessages,
    announcements,
  );
}

/// A switch on the Notification Settings screen.
class NotificationPreferenceOption {
  const NotificationPreferenceOption(this.key, this.title, this.subtitle);

  final String key;
  final String title;
  final String subtitle;
}

const notificationPreferenceOptions = [
  NotificationPreferenceOption(
    NotificationPreferences.requestUpdatesKey,
    'My blood requests',
    'Review results, donor offers, fulfilled and expired requests.',
  ),
  NotificationPreferenceOption(
    NotificationPreferences.donorAlertsKey,
    'Matching blood requests',
    'New requests that match your blood type.',
  ),
  NotificationPreferenceOption(
    NotificationPreferences.donationUpdatesKey,
    'Donor and donation updates',
    'Your donor application, appointments, offers and donations.',
  ),
  NotificationPreferenceOption(
    NotificationPreferences.chatMessagesKey,
    'Chat messages',
    'New messages from PRC support.',
  ),
  NotificationPreferenceOption(
    NotificationPreferences.announcementsKey,
    'PRC announcements',
    'News and blood drives from the Philippine Red Cross.',
  ),
];
