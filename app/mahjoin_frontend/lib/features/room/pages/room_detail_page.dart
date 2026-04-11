import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../../core/events/app_event.dart';
import '../../../core/events/app_event_dispatcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/error_mapper.dart';
import '../../../core/router/router.dart';
import '../../../core/storage/session.dart';
import '../../../data/models/models.dart';

class RoomDetailPage extends StatefulWidget {
  final String roomId;
  const RoomDetailPage({super.key, required this.roomId});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  Room? _room;
  bool _loading = true;
  bool _acting = false;
  String? _error;
  StreamSubscription<AppEvent>? _eventSub;
  bool _hasNavigatedToFull = false;

  bool get _isHost => _room?.hostId == Session.instance.userId;
  bool get _isMember => _room?.members.any((m) => m.userId == Session.instance.userId) ?? false;

  @override
  void initState() {
    super.initState();
    _eventSub = AppEventDispatcher.instance.stream.listen(_onEvent);
    _loadRoom();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  void _onEvent(AppEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case AppEventType.roomPlayerJoined:
      case AppEventType.roomPlayerLeft:
      case AppEventType.roomCreated:
      case AppEventType.roomFull:
        final roomData = event.data['room'] as Map<String, dynamic>?;
        if (roomData == null) return;
        if (roomData['id'] != widget.roomId) return;
        final room = Room.fromJson(roomData);
        setState(() => _room = room);

        if (event.type == AppEventType.roomFull && !_hasNavigatedToFull) {
          final me = Session.instance.userId;
          final isInRoom =
              me != null && room.members.any((m) => m.userId == me);
          if (isInRoom) {
            _hasNavigatedToFull = true;
            context.push(AppRoutes.roomFull(room.id));
          }
        }
        break;
      case AppEventType.roomDissolved:
        final roomId = event.data['roomId'] as String?;
        if (roomId != widget.roomId) return;
        _snack('房間已解散');
        context.go(AppRoutes.map);
        break;
      default:
        break;
    }
  }

  Future<void> _loadRoom() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await ApiClient.get('/api/v1/rooms/${widget.roomId}');
      // Backend returns {"room": {...}}
      final roomJson = (json as Map<String, dynamic>)['room'] as Map<String, dynamic>;
      setState(() {
        _room = Room.fromJson(roomJson);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = mapApiError(e, fallback: '無法載入房間資訊。');
      });
    }
  }

  Future<void> _join() async {
    setState(() => _acting = true);
    try {
      await ApiClient.post('/api/v1/rooms/${widget.roomId}/join', {});
      await _loadRoom(); // Refresh to see updated member list
    } catch (e) {
      if (mounted) _snack(mapApiError(e, fallback: '加入房間失敗。'));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _leave() async {
    if (!await _confirm('離開房間', '確定要離開這個房間嗎？')) return;
    setState(() => _acting = true);
    try {
      await ApiClient.post('/api/v1/rooms/${widget.roomId}/leave', {});
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _snack(mapApiError(e, fallback: '離開房間失敗。'));
      setState(() => _acting = false);
    }
  }

  Future<void> _dissolve() async {
    if (!await _confirm('解散房間', '這會關閉所有玩家的房間，確定繼續嗎？')) return;
    setState(() => _acting = true);
    try {
      await ApiClient.delete('/api/v1/rooms/${widget.roomId}');
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        _snack(mapApiError(e, fallback: '解散房間失敗。'));
      }
      setState(() => _acting = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title, style: AppTypography.headlineMedium),
            content: Text(body, style: AppTypography.bodyMedium),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('取消',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(title,
                    style: const TextStyle(color: AppColors.full)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('房間詳情'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : _loadRoom,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadRoom)
              : _Body(
                  room: _room!,
                  isHost: _isHost,
                  isMember: _isMember,
                  acting: _acting,
                  onLeave: _leave,
                  onDissolve: _dissolve,
                  onJoin: _join,
                ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('無法載入房間', style: AppTypography.headlineMedium),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('重試'),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Room room;
  final bool isHost;
  final bool isMember;
  final bool acting;
  final VoidCallback onLeave;
  final VoidCallback onDissolve;
  final VoidCallback onJoin;

  const _Body({
    required this.room,
    required this.isHost,
    required this.isMember,
    required this.acting,
    required this.onLeave,
    required this.onDissolve,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (room.status) {
      RoomStatus.waiting => (AppColors.online, '等待玩家中'),
      RoomStatus.playing => (AppColors.secondary, '對局進行中'),
      RoomStatus.full => (AppColors.waiting, '已滿員'),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status banner ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: AppRadius.lg,
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(statusLabel,
                    style: AppTypography.labelLarge
                        .copyWith(color: statusColor)),
                const Spacer(),
                Text('${room.currentPlayers}/${room.maxPlayers}',
                    style: AppTypography.headlineMedium
                        .copyWith(color: statusColor)),
                Text(' 位玩家', style: AppTypography.bodyMedium),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Room info ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lg,
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.md,
                  ),
                  child: const Icon(Icons.table_restaurant_rounded,
                      color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(room.address,
                          style: AppTypography.headlineMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.person_rounded,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text('房主：${room.hostName}',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '距離 ${room.distanceKm.toStringAsFixed(1)} 公里',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Player slots ───────────────────────────────────────────
          Text('玩家席位', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(room.maxPlayers, (i) {
              final filled = i < room.currentPlayers;
              final avatars = room.playerAvatars;
              final avatar =
                  filled && i < avatars.length ? avatars[i] : null;
              final memberName = filled && i < room.members.length
                  ? room.members[i].userName.split(' ').first
                  : null;

              return Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(right: i < room.maxPlayers - 1 ? 8 : 0),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: filled
                          ? AppColors.secondary.withOpacity(0.08)
                          : AppColors.surfaceVariant,
                      borderRadius: AppRadius.lg,
                      border: Border.all(
                        color: filled
                            ? AppColors.secondary.withOpacity(0.3)
                            : AppColors.divider,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        filled
                            ? Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    avatar ?? '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                            : const Icon(Icons.person_add_rounded,
                                size: 26, color: AppColors.textMuted),
                        if (memberName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            memberName,
                            style: AppTypography.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Action button ──────────────────────────────────────────
          if (acting)
            const Center(child: CircularProgressIndicator())
          else if (isHost)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.full,
              ),
              onPressed: onDissolve,
              icon: const Icon(Icons.delete_rounded),
              label: const Text('解散房間'),
            )
          else if (isMember)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.textMuted,
              ),
              onPressed: onLeave,
              icon: const Icon(Icons.exit_to_app_rounded),
              label: const Text('離開房間'),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.online,
              ),
              onPressed: onJoin,
              icon: const Icon(Icons.login_rounded),
              label: const Text('加入房間'),
            ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
