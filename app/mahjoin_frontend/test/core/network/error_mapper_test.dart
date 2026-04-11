import 'package:flutter_test/flutter_test.dart';
import 'package:mahjoin_frontend/core/network/api_client.dart';
import 'package:mahjoin_frontend/core/network/error_mapper.dart';

void main() {
  group('mapApiError', () {
    test('maps 401 to session-expired message', () {
      final err = ApiException(401, '{"error":{"message":"unauthorized"}}');
      final msg = mapApiError(err);
      expect(msg, 'Session expired. Please sign in again.');
    });

    test('uses API body message on 409 conflict', () {
      final err = ApiException(
        409,
        '{"error":{"message":"Friend request already pending"}}',
      );
      final msg = mapApiError(err);
      expect(msg, 'Friend request already pending');
    });

    test('falls back for unknown errors', () {
      final msg = mapApiError(Exception('x'), fallback: 'Fallback text');
      expect(msg, 'Fallback text');
    });
  });
}
