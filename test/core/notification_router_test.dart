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

    test('blank route is ignored', () {
      expect(
        NotificationRouter.routeFor({'route': '  ', 'type': 'chat_message'}),
        NotificationRoute.chat,
      );
    });
  });
}
