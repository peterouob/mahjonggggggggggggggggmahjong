import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mahjoin_frontend/core/storage/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await Session.instance.clear();
    });

    test('save and restore user id and user name', () async {
      Session.instance.userId = 'u-123';
      Session.instance.userName = 'Alice Wang';
      await Session.instance.save();

      // Simulate process restart: reset in-memory values only.
      Session.instance.userId = null;
      Session.instance.userName = null;
      expect(Session.instance.userId, isNull);
      expect(Session.instance.userName, isNull);

      await Session.instance.restore();
      expect(Session.instance.userId, 'u-123');
      expect(Session.instance.userName, 'Alice Wang');
      expect(Session.instance.isLoggedIn, isTrue);
    });

    test('clear removes persisted session data', () async {
      Session.instance.userId = 'u-1';
      Session.instance.userName = 'Bob';
      await Session.instance.save();

      await Session.instance.clear();
      await Session.instance.restore();

      expect(Session.instance.userId, isNull);
      expect(Session.instance.userName, isNull);
      expect(Session.instance.isLoggedIn, isFalse);
    });
  });
}
