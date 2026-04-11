import 'package:flutter_test/flutter_test.dart';
import 'package:mahjoin_frontend/core/events/app_event.dart';
import 'package:mahjoin_frontend/core/events/app_event_dispatcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppEventDispatcher', () {
    test('maps known event type correctly', () async {
      final eventFuture = AppEventDispatcher.instance.stream.first;

      AppEventDispatcher.instance
          .dispatchRaw('room.full', {'roomId': 'r1'});

      final event = await eventFuture;
      expect(event.type, AppEventType.roomFull);
      expect(event.data['roomId'], 'r1');
    });

    test('maps unknown event type to unknown', () async {
      final eventFuture = AppEventDispatcher.instance.stream.first;

      AppEventDispatcher.instance
          .dispatchRaw('custom.unknown.type', {'x': 1});

      final event = await eventFuture;
      expect(event.type, AppEventType.unknown);
      expect(event.data['x'], 1);
    });
  });
}
