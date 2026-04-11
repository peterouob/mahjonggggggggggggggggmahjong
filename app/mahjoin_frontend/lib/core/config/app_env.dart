import 'package:flutter/foundation.dart';

const kMockMode = bool.fromEnvironment('MOCK_MODE', defaultValue: false);
const kAllowMockInRelease =
    bool.fromEnvironment('ALLOW_MOCK_IN_RELEASE', defaultValue: false);

void enforceMockModeSafety() {
  if (kReleaseMode && kMockMode && !kAllowMockInRelease) {
    throw StateError(
      'MOCK_MODE=true is blocked in release builds. '
      'Use --dart-define=ALLOW_MOCK_IN_RELEASE=true only for controlled QA.',
    );
  }
}
