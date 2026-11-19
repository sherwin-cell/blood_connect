import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

/// Handles FCM permissions, device tokens, and incoming push notifications.
///
/// A trusted server/backend is still required to send automatic notifications
/// when PRC updates Firestore.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'blood_connect_notifications',
    'Blood-Connect Notifications',
    description:
        'Updates about donor applications, appointments, and blood donations.',
    importance: Importance.high,
  );

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  String? _registeredUid;
  String? _registeredToken;

  bool _initialized = false;

  /// Initializes local notifications and FCM listeners.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);

    // Request notification permission.
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Show notifications received while the app is open.
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundNotification(message));
    });

    // Handle notifications tapped while the app was in the background.
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageTap,
    );

    // Handle a notification that launched the terminated app.
    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    _initialized = true;
  }

  /// Registers the current device token under the signed-in user's document.
  Future<void> registerTokenForUser(String uid) async {
    if (!_initialized) {
      await initialize();
    }

    final token = await _messaging.getToken();

    if (token == null || token.isEmpty) {
      debugPrint('FCM token is unavailable.');
      return;
    }

    if (_registeredUid == uid && _registeredToken == token) {
      return;
    }

    await _saveToken(uid, token);

    // Listen for token changes only after the initial save succeeds.
    await _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
      unawaited(_saveToken(uid, newToken));
    });
  }

  /// Saves or updates the FCM token in Firestore.
  Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcm_tokens')
          .doc(token)
          .set({
            'token': token,
            'platform': _platformName,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      _registeredUid = uid;
      _registeredToken = token;

      debugPrint('FCM token registered for user: $uid');
    } catch (error, stackTrace) {
      debugPrint('FCM token registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Clears the locally cached user registration when signing out.
  ///
  /// The Firestore token document is intentionally retained. A backend can
  /// still use it to send notifications to this device.
  Future<void> clearRegisteredUser() async {
    await _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = null;
    _registeredUid = null;
    _registeredToken = null;
  }

  /// Displays an incoming FCM notification while the app is foregrounded.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification == null) {
      debugPrint('Foreground data-only message received: ${message.messageId}');
      return;
    }

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Blood-Connect',
      notification.body ?? 'You have a new update.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Handles a notification tapped from the system notification tray.
  void _handleMessageTap(RemoteMessage message) {
    _handleNotificationTap(jsonEncode(message.data));
  }

  /// Notification navigation can be connected here later.
  void _handleNotificationTap(String? payload) {
    debugPrint('Blood-Connect notification opened: $payload');
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }

  /// Releases stream subscriptions.
  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();

    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;

    _initialized = false;
  }
}

/// Called by Firebase Messaging in a background isolate.
///
/// This must be a top-level function and must be registered in main.dart.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Background FCM message received: ${message.messageId}');
}
