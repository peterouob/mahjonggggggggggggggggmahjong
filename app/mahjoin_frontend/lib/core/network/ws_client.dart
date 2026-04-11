import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_env.dart';
import '../events/app_event_dispatcher.dart';
import 'api_client.dart';

/// A WebSocket event pushed by the server.
///
/// Expected shape: `{"type": "broadcast.started", "data": {...}}`
///
/// Known types:
///   broadcast.started  — a new player appeared nearby
///   broadcast.updated  — a player moved significantly
///   broadcast.stopped  — a player stopped broadcasting
///   room.created       — a new room appeared
///   room.player_joined — a member joined a room
///   room.player_left   — a member left a room
///   room.full          — room reached max capacity
///   room.dissolved     — a room was closed
///   friend.request     — incoming friend request
///   friend.accepted    — outgoing request accepted
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
  final ValueNotifier<int> _healthTick = ValueNotifier<int>(0);
  String? _userId;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  DateTime? _lastPongAt;
  int _reconnectAttempts = 0;

  Stream<WsMessage> get stream => _controller.stream;
  bool get isConnected => _channel != null;
  DateTime? get lastPongAt => _lastPongAt;
  Listenable get healthListenable => _healthTick;

  /// Connect (or reconnect) as [userId]. Safe to call multiple times.
  void connect(String userId) {
    if (kMockMode) return; // Skip WebSocket in mock mode
    _userId = userId;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _bumpHealth();
    _doConnect();
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _userId = null;
    _reconnectAttempts = 0;
    _bumpHealth();
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
      _startPing();
      _bumpHealth();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final msg = WsMessage.fromJson(json);
      _controller.add(msg);
      AppEventDispatcher.instance.dispatchRaw(msg.type, msg.data);
      if (msg.type == 'pong') {
        _lastPongAt = DateTime.now();
        _bumpHealth();
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    // Exponential back-off: 5s, 10s, 20s … capped at 60s.
    final delay = Duration(
        seconds: (_reconnectAttempts < 4)
            ? 5 * (1 << _reconnectAttempts)
            : 60);
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, _doConnect);
    _bumpHealth();
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _sendPing(),
    );
  }

  void _sendPing() {
    final sink = _channel?.sink;
    if (sink == null) return;
    try {
      sink.add(jsonEncode({'type': 'ping'}));
    } catch (_) {}
  }

  void _bumpHealth() {
    _healthTick.value++;
  }
}
