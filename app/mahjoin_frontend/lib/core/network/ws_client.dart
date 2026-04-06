import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';
import '../../mock/mock_data.dart' show kMockMode;

/// A WebSocket event pushed by the server.
///
/// Expected shape: `{"type": "broadcast_started", "data": {...}}`
///
/// Known types:
///   broadcast_started  — a new player appeared nearby
///   broadcast_stopped  — a player stopped broadcasting
///   room_created       — a new room appeared
///   room_updated       — a room changed (players joined/left)
///   room_dissolved     — a room was closed
class WsMessage {
  final String type;
  final Map<String, dynamic> data;

  const WsMessage({required this.type, required this.data});

  factory WsMessage.fromJson(Map<String, dynamic> json) => WsMessage(
        type: json['type'] as String? ?? '',
        data: (json['data'] as Map?)?.cast<String, dynamic>() ?? {},
      );
}

/// Singleton WebSocket client with automatic exponential back-off reconnect.
class WsClient {
  static final WsClient instance = WsClient._();
  WsClient._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _controller = StreamController<WsMessage>.broadcast();
  String? _userId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  Stream<WsMessage> get stream => _controller.stream;
  bool get isConnected => _channel != null;

  /// Connect (or reconnect) as [userId]. Safe to call multiple times.
  void connect(String userId) {
    if (kMockMode) return; // Skip WebSocket in mock mode
    _userId = userId;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _doConnect();
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _userId = null;
    _reconnectAttempts = 0;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _doConnect() {
    final userId = _userId;
    if (userId == null) return;

    final wsBase =
        ApiClient.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final uri = Uri.parse('$wsBase/ws?user_id=$userId');

    try {
      _channel = WebSocketChannel.connect(uri);
      _sub?.cancel();
      _sub = _channel!.stream.listen(
        _onData,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
      _reconnectAttempts = 0;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      _controller.add(WsMessage.fromJson(json));
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _channel = null;
    _reconnectTimer?.cancel();
    // Exponential back-off: 5s, 10s, 20s … capped at 60s.
    final delay = Duration(
        seconds: (_reconnectAttempts < 4)
            ? 5 * (1 << _reconnectAttempts)
            : 60);
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _doConnect);
  }
}
