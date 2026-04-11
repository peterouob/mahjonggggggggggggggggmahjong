import 'dart:async';
import 'package:flutter/foundation.dart';
import '../feedback/notification_center.dart';
import 'app_event.dart';

class AppEventDispatcher {
  static final AppEventDispatcher instance = AppEventDispatcher._();
  AppEventDispatcher._();

  final _controller = StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get stream => _controller.stream;

  void dispatchRaw(String type, Map<String, dynamic> data) {
    final event = AppEvent.fromTypeData(type, data);
    _controller.add(event);

    if (event.type == AppEventType.unknown) {
      debugPrint('Unhandled WS event type: $type');
    }

    NotificationCenter.instance.handleEvent(event);
  }
}
