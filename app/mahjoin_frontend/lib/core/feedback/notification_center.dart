import 'dart:async';
import 'package:flutter/material.dart';
import '../events/app_event.dart';

enum AppNotificationLevel { info, success, warning, error }

class AppNotification {
  final String message;
  final AppNotificationLevel level;
  final DateTime createdAt;

  const AppNotification({
    required this.message,
    required this.level,
    required this.createdAt,
  });
}

class NotificationCenter extends ChangeNotifier {
  static final NotificationCenter instance = NotificationCenter._();
  NotificationCenter._();

  AppNotification? _current;
  int _pendingFriendRequests = 0;
  Timer? _hideTimer;

  AppNotification? get current => _current;
  int get pendingFriendRequests => _pendingFriendRequests;

  void show(
    String message, {
    AppNotificationLevel level = AppNotificationLevel.info,
    Duration ttl = const Duration(seconds: 3),
  }) {
    _hideTimer?.cancel();
    _current = AppNotification(
      message: message,
      level: level,
      createdAt: DateTime.now(),
    );
    notifyListeners();

    _hideTimer = Timer(ttl, clearCurrent);
  }

  void clearCurrent() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _current = null;
    notifyListeners();
  }

  void handleEvent(AppEvent event) {
    switch (event.type) {
      case AppEventType.friendRequest:
        _pendingFriendRequests++;
        show('New friend request received', level: AppNotificationLevel.info);
        break;
      case AppEventType.friendAccepted:
        show('Your friend request was accepted',
            level: AppNotificationLevel.success);
        break;
      case AppEventType.roomFull:
        show('A room is now full', level: AppNotificationLevel.info);
        break;
      case AppEventType.roomDissolved:
        show('A room was dissolved', level: AppNotificationLevel.warning);
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void resetFriendRequestCount() {
    if (_pendingFriendRequests == 0) return;
    _pendingFriendRequests = 0;
    notifyListeners();
  }
}
