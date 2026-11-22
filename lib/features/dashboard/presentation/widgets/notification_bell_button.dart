import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../screens/notifications_screen.dart';

/// App bar bell that opens NotificationsScreen and shows the unread count.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key, required this.userId});

  final String userId;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  /// Counting stops here; the badge shows "99+".
  static const _maxCounted = 100;

  late Stream<int> _unreadCount;

  @override
  void initState() {
    super.initState();
    _unreadCount = _watchUnread(widget.userId);
  }

  @override
  void didUpdateWidget(NotificationBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _unreadCount = _watchUnread(widget.userId);
    }
  }

  static Stream<int> _watchUnread(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .limit(_maxCounted)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _unreadCount,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return IconButton(
          tooltip: unread == 0
              ? 'Notifications'
              : '$unread unread notification${unread == 1 ? '' : 's'}',
          icon: Badge(
            isLabelVisible: unread > 0,
            backgroundColor: AppColors.primaryRed,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: Icon(
              unread > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              color: Colors.black87,
            ),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        );
      },
    );
  }
}
