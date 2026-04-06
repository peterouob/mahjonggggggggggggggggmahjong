import 'dart:async';
import '../../core/network/api_client.dart';
import '../../mock/mock_data.dart' show kMockMode;

/// Manages the user's own broadcast: start, stop, heartbeat, location update.
/// Must be started before the 30-second server TTL expires.
class BroadcastService {
  static final BroadcastService instance = BroadcastService._();
  BroadcastService._();

  String? broadcastId;
  Timer? _heartbeatTimer;

  /// Backend TTL is typically 60s; send heartbeat every 30s to stay alive.
  static const _heartbeatInterval = Duration(seconds: 30);

  bool get isActive => broadcastId != null;

  /// Start a new broadcast at [lat], [lng].
  /// Throws [ApiException] on server error.
  Future<void> start({required double lat, required double lng}) async {
    if (kMockMode) {
      broadcastId = 'mock-broadcast';
      return;
    }
    final result = await ApiClient.post('/api/v1/broadcasts', {
      'latitude': lat,
      'longitude': lng,
    });
    // Backend returns {"broadcast": {...}}
    final broadcast = result['broadcast'] as Map<String, dynamic>?;
    broadcastId = broadcast?['id'] as String?;
    if (broadcastId != null) _startHeartbeat();
  }

  /// Stop the current broadcast and cancel heartbeat.
  Future<void> stop() async {
    if (kMockMode) {
      broadcastId = null;
      return;
    }
    _stopHeartbeat();
    final id = broadcastId;
    broadcastId = null;
    if (id != null) {
      try {
        await ApiClient.delete('/api/v1/broadcasts/$id');
      } catch (_) {
        // Best-effort; broadcast will expire on its own via TTL.
      }
    }
  }

  /// Call when the device moves to keep the server position in sync.
  Future<void> updateLocation(double lat, double lng) async {
    if (kMockMode || broadcastId == null) return;
    try {
      await ApiClient.patch(
        '/api/v1/broadcasts/$broadcastId/location',
        {'latitude': lat, 'longitude': lng},
      );
    } catch (_) {}
  }

  /// On app startup, check if the server still has an active broadcast for
  /// this user and restore local state + restart heartbeat.
  Future<void> restore() async {
    if (kMockMode) return;
    try {
      final result = await ApiClient.get('/api/v1/broadcasts/me');
      if (result is Map<String, dynamic>) {
        // Backend returns {"broadcast": {...}}
        final broadcast = result['broadcast'] as Map<String, dynamic>?;
        broadcastId = broadcast?['id'] as String?;
        if (broadcastId != null) _startHeartbeat();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) return;
    } catch (_) {}
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer =
        Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _sendHeartbeat() async {
    final id = broadcastId;
    if (id == null) {
      _stopHeartbeat();
      return;
    }
    try {
      await ApiClient.post('/api/v1/broadcasts/$id/heartbeat', {});
    } catch (_) {
      // Heartbeat failed — broadcast likely expired on server.
      broadcastId = null;
      _stopHeartbeat();
    }
  }
}
