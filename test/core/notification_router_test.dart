import 'package:blood_connect/core/services/notification_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationRouter.routeFor', () {
    test('uses the route sent by the backend', () {
      expect(
        NotificationRouter.routeFor({
          'route': 'chat',
          'type': 'offer_approved',
        }),
        NotificationRoute.chat,
      );
    });

    test('falls back to the notification type', () {
      expect(
        NotificationRouter.routeFor({'type': 'chat_message'}),
        NotificationRoute.chat,
      );
      expect(
        NotificationRouter.routeFor({'type': 'offer_donated'}),
        NotificationRoute.myOffers,
      );
      expect(
        NotificationRouter.routeFor({'type': 'request_closed_for_donor'}),
        NotificationRoute.myOffers,
      );
      expect(
        NotificationRouter.routeFor({'type': 'request_open'}),
        NotificationRoute.request,
      );
      expect(
        NotificationRouter.routeFor({'type': 'announcement'}),
        NotificationRoute.home,
      );
      expect(
        NotificationRouter.routeFor({'type': 'donor_application_approved'}),
        NotificationRoute.activity,
      );
    });

    test('expired request opens the Activity tab', () {
      // The backend sends route `activity`; older records without a route
      // fall back to Activity too. The request card there shows "Expired".
      expect(
        NotificationRouter.routeFor({
          'route': 'activity',
          'type': 'request_expired',
          'requestId': 'req1',
        }),
        NotificationRoute.activity,
      );
      expect(
        NotificationRouter.routeFor({'type': 'request_expired'}),
        NotificationRoute.activity,
      );
    });

    test('blank route is ignored', () {
      expect(
        NotificationRouter.routeFor({'route': '  ', 'type': 'chat_message'}),
        NotificationRoute.chat,
      );
    });
  });

  group('retired requester-donor chats', () {
    test('match chats are recognised; support chats are not', () {
      expect(NotificationRouter.isRetiredMatchChat('match_req1_off1'), isTrue);
      expect(
        NotificationRouter.isRetiredMatchChat('uid123_prc_support'),
        isFalse,
      );
    });

    test('request id is read from the chat id', () {
      expect(
        NotificationRouter.requestIdOfMatchChat('match_req1_off1'),
        'req1',
      );
      expect(NotificationRouter.requestIdOfMatchChat('match_bad'), isNull);
      expect(NotificationRouter.requestIdOfMatchChat('match__off1'), isNull);
    });
  });
}
