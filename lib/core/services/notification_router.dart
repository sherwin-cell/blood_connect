import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/blood_request/presentation/screens/blood_request_detail_screen.dart';
import '../../features/chat/presentation/screens/prc_chat_room_screen.dart';
import '../../features/donor/presentation/screens/matched_donor_detail_screen.dart';
import '../../features/donor/presentation/screens/my_offers_screen.dart';

/// Root navigator, so notification taps can navigate from outside a widget.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Where a notification opens. Must match `Route` in
/// blood_connect_backend/notifications/constants.py.
abstract final class NotificationRoute {
  static const activity = 'activity';
  static const request = 'request';
  static const requestOffers = 'request_offers';
  static const myOffers = 'my_offers';
  static const chat = 'chat';
  static const home = 'home';
}

/// Opens the screen a notification points to.
///
/// Used for taps on system notifications (FCM data payload) and on items in
/// the in-app NotificationsScreen (Firestore record); both carry the same
/// fields: `route`, `type`, `requestId`, `offerId`, `chatId`, `chatName`.
class NotificationRouter {
  NotificationRouter._();

  static final NotificationRouter instance = NotificationRouter._();

  /// Dashboard tab requested by a notification (0 Home, 1 Activity, 2 History).
  /// HomeDashboard listens to this.
  final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  Map<String, dynamic>? _pending;
  bool _dashboardReady = false;

  /// Called by HomeDashboard once it is on screen. Opens a notification that
  /// was tapped while the app was starting.
  void dashboardReady() {
    _dashboardReady = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      open(pending);
    }
  }

  void dashboardClosed() => _dashboardReady = false;

  /// Opens [data]. If the user is not on the dashboard yet (cold start,
  /// splash, login), the tap is kept and handled once the dashboard appears.
  Future<void> open(Map<String, dynamic> data) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null ||
        !_dashboardReady ||
        FirebaseAuth.instance.currentUser == null) {
      _pending = data;
      return;
    }

    final route = routeFor(data);
    final requestId = _string(data['requestId']);
    final chatId = _string(data['chatId']);

    // Start from the dashboard so Back always returns there.
    navigator.popUntil((r) => r.isFirst);

    switch (route) {
      case NotificationRoute.request when requestId != null:
        await _openRequest(navigator, requestId);
      // The requester's donor news: the read-only, anonymised Matched Donor
      // view (donor code and blood type only).
      case NotificationRoute.requestOffers when requestId != null:
        _openMatchedDonor(navigator, requestId);
      case NotificationRoute.myOffers:
        navigator.push(
          MaterialPageRoute(builder: (_) => const MyOffersScreen()),
        );
      case NotificationRoute.chat when chatId != null:
        if (isRetiredMatchChat(chatId)) {
          await _openRetiredMatchChat(navigator, chatId);
          return;
        }
        final name = _string(data['chatName']) ?? 'Chat';
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                PrcChatRoomScreen(chatId: chatId, otherUserName: name),
          ),
        );
      case NotificationRoute.activity:
        requestedTab.value = 1;
      default:
        requestedTab.value = 0;
    }
  }

  /// Donor-facing request screen; it reads the anonymised summary itself
  /// and says so when the request is no longer available.
  Future<void> _openRequest(NavigatorState navigator, String requestId) async {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => BloodRequestDetailScreen(requestId: requestId),
      ),
    );
  }

  void _openMatchedDonor(NavigatorState navigator, String requestId) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MatchedDonorDetailScreen(requestId: requestId),
      ),
    );
  }

  /// Requester-donor chats (`match_{requestId}_{offerId}`) are retired:
  /// donors stay anonymous and PRC coordinates. An old chat notification
  /// opens Matched Donor for the requester, My Offers for the donor.
  @visibleForTesting
  static bool isRetiredMatchChat(String chatId) => chatId.startsWith('match_');

  /// `match_{requestId}_{offerId}` → requestId (Firestore auto-ids have no
  /// underscores).
  @visibleForTesting
  static String? requestIdOfMatchChat(String chatId) {
    final parts = chatId.split('_');
    return parts.length == 3 && parts[1].isNotEmpty ? parts[1] : null;
  }

  Future<void> _openRetiredMatchChat(
    NavigatorState navigator,
    String chatId,
  ) async {
    final requestId = requestIdOfMatchChat(chatId);
    // Only the requester may read the request (firestore.rules).
    var isRequester = false;
    if (requestId != null) {
      try {
        isRequester =
            (await FirebaseFirestore.instance
                    .collection('blood_requests')
                    .doc(requestId)
                    .get())
                .exists;
      } catch (_) {
        isRequester = false; // permission denied: the donor
      }
    }
    if (isRequester) {
      _openMatchedDonor(navigator, requestId!);
    } else {
      navigator.push(MaterialPageRoute(builder: (_) => const MyOffersScreen()));
    }
  }

  /// `route` from the backend, or a fallback for records written before
  /// routes existed.
  @visibleForTesting
  static String routeFor(Map<String, dynamic> data) {
    final route = _string(data['route']);
    if (route != null) return route;
    final type = _string(data['type']) ?? '';
    if (type.startsWith('chat')) return NotificationRoute.chat;
    if (type.startsWith('offer_') || type == 'request_closed_for_donor') {
      return NotificationRoute.myOffers;
    }
    if (type == 'request_open') return NotificationRoute.request;
    if (type == 'announcement') return NotificationRoute.home;
    return NotificationRoute.activity;
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
