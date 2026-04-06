import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/design/tokens.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/router/router.dart';
import '../../../data/models/models.dart';
import '../../../core/location/location_service.dart';
import '../../../data/services/broadcast_service.dart';
import '../../../mock/mock_data.dart' show kMockMode;
import '../widgets/player_marker.dart';
import '../widgets/room_marker.dart';
import '../widgets/nearby_panel.dart';
import '../widgets/broadcast_fab.dart';

// Fallback location (Hong Kong) — used in LocationService.
const _nearbyRadiusM = 5000;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _mapController = MapController();
  LatLng _myLocation = LocationService.defaultLocation;
  bool _mapReady = false;
  LatLng? _pendingMove;

  bool _showRooms = true;
  bool _showPlayers = true;

  List<Broadcast> _players = [];
  List<Room> _rooms = [];
  bool _loading = false;
  String? _error;

  Broadcast? _selectedPlayer;
  Room? _selectedRoom;

  StreamSubscription<WsMessage>? _wsSub;
  StreamSubscription<LatLng>? _locationSub;

  @override
  void initState() {
    super.initState();
    _loadNearby();
    _restoreBroadcast();
    _subscribeWs();
    _initLocation();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    if (_pendingMove != null) {
      _mapController.move(_pendingMove!, 14.5);
      _pendingMove = null;
    }
  }

  void _moveMap(LatLng pos) {
    if (_mapReady) {
      _mapController.move(pos, 14.5);
    } else {
      _pendingMove = pos;
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;
    setState(() => _myLocation = pos);
    _moveMap(pos);
    _locationSub = LocationService.instance.watchPosition().listen((pos) {
      if (!mounted) return;
      setState(() => _myLocation = pos);
      BroadcastService.instance.updateLocation(pos.latitude, pos.longitude);
    });
    // Reload nearby data centred on the real location.
    _loadNearby();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadNearby() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (kMockMode) {
      await Future.delayed(const Duration(milliseconds: 300)); // simulate network
      if (!mounted) return;
      setState(() {
        _players = _mockBroadcasts();
        _rooms = _mockRooms();
        _loading = false;
      });
      return;
    }

    try {
      final params = {
        'lat': '${_myLocation.latitude}',
        'lng': '${_myLocation.longitude}',
        'radius': '$_nearbyRadiusM',
      };
      final results = await Future.wait([
        ApiClient.get('/api/v1/broadcasts/nearby', params: params),
        ApiClient.get('/api/v1/rooms/nearby', params: params),
      ]);

      if (!mounted) return;
      setState(() {
        _players = (results[0] as List)
            .map((j) => Broadcast.fromJson(j as Map<String, dynamic>))
            .toList();
        _rooms = (results[1] as List)
            .map((j) => Room.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ── Mock data ─────────────────────────────────────────────────────────────

  List<Broadcast> _mockBroadcasts() => [
        const Broadcast(
          id: 'b-alice',
          userId: 'mock-u1',
          userName: 'Alice Wong',
          position: LatLng(22.3220, 114.1720),
          distanceKm: 0.4,
          rating: 1920,
        ),
        const Broadcast(
          id: 'b-bob',
          userId: 'mock-u2',
          userName: 'Bob Lee',
          position: LatLng(22.3175, 114.1710),
          distanceKm: 0.6,
          rating: 1750,
        ),
        const Broadcast(
          id: 'b-charlie',
          userId: 'mock-u3',
          userName: 'Charlie Liu',
          position: LatLng(22.3210, 114.1660),
          distanceKm: 0.9,
        ),
      ];

  List<Room> _mockRooms() => [
        Room(
          id: 'room-1',
          hostId: 'mock-u1',
          hostName: 'Alice Wong',
          position: const LatLng(22.3220, 114.1720),
          status: RoomStatus.waiting,
          currentPlayers: 2,
          maxPlayers: 4,
          address: 'Mong Kok Community Centre',
          distanceKm: 0.4,
          members: const [
            RoomMember(userId: 'mock-u1', userName: 'Alice Wong'),
            RoomMember(userId: 'mock-u2', userName: 'Bob Lee'),
          ],
        ),
        Room(
          id: 'room-2',
          hostId: 'mock-u4',
          hostName: 'Dave Lee',
          position: const LatLng(22.3160, 114.1740),
          status: RoomStatus.playing,
          currentPlayers: 4,
          maxPlayers: 4,
          address: 'Jordan Recreation Centre',
          distanceKm: 1.5,
          members: const [
            RoomMember(userId: 'mock-u4', userName: 'Dave Lee'),
            RoomMember(userId: 'mock-u5', userName: 'Eve Chen'),
            RoomMember(userId: 'mock-u6', userName: 'Frank Yip'),
            RoomMember(userId: 'mock-u7', userName: 'Grace Lam'),
          ],
        ),
      ];

  Future<void> _restoreBroadcast() async {
    await BroadcastService.instance.restore();
    if (mounted) setState(() {});
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────

  void _subscribeWs() {
    _wsSub = WsClient.instance.stream.listen(_handleWsMessage);
  }

  void _handleWsMessage(WsMessage msg) {
    if (!mounted) return;
    switch (msg.type) {
      case 'broadcast_started':
        final b = Broadcast.fromJson(msg.data);
        setState(() {
          _players = [
            ..._players.where((p) => p.id != b.id),
            b,
          ];
        });
      case 'broadcast_stopped':
        final id = msg.data['id'] as String?;
        if (id != null) {
          setState(() => _players = _players.where((p) => p.id != id).toList());
        }
      case 'broadcast_location_updated':
        final id = msg.data['id'] as String?;
        if (id != null) {
          final updated = Broadcast.fromJson(msg.data);
          setState(() {
            _players = _players.map((p) => p.id == id ? updated : p).toList();
          });
        }
      case 'room_created':
      case 'room_updated':
        final r = Room.fromJson(msg.data);
        setState(() {
          _rooms = [
            ..._rooms.where((x) => x.id != r.id),
            r,
          ];
        });
      case 'room_dissolved':
        final id = msg.data['id'] as String?;
        if (id != null) {
          setState(() => _rooms = _rooms.where((r) => r.id != id).toList());
          if (_selectedRoom?.id == id) {
            setState(() => _selectedRoom = null);
          }
        }
    }
  }

  // ── Broadcast toggle ──────────────────────────────────────────────────────

  Future<void> _toggleBroadcast() async {
    final svc = BroadcastService.instance;
    try {
      if (svc.isActive) {
        await svc.stop();
      } else {
        await svc.start(
          lat: _myLocation.latitude,
          lng: _myLocation.longitude,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Broadcast error: $e')),
      );
    }
    if (mounted) setState(() {});
  }

  // ── Room join ─────────────────────────────────────────────────────────────

  Future<void> _joinRoom(Room room) async {
    try {
      await ApiClient.post('/api/v1/rooms/${room.id}/join', {});
      if (!mounted) return;
      setState(() => _selectedRoom = null);
      context.push(AppRoutes.room(room.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join: $e')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isBroadcasting = BroadcastService.instance.isActive;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation,
              initialZoom: 14.5,
              maxZoom: 18,
              minZoom: 11,
              onMapReady: _onMapReady,
              onTap: (_, __) => setState(() {
                _selectedPlayer = null;
                _selectedRoom = null;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mahjoin.app',
              ),

              // Broadcast range circle
              if (isBroadcasting)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _myLocation,
                      radius: _nearbyRadiusM.toDouble(),
                      useRadiusInMeter: true,
                      color: AppColors.primary.withOpacity(0.06),
                      borderColor: AppColors.primary.withOpacity(0.3),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Room markers
              if (_showRooms)
                MarkerLayer(
                  markers: _rooms
                      .map((r) => Marker(
                            point: r.position,
                            width: 56,
                            height: 56,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedRoom = r;
                                _selectedPlayer = null;
                              }),
                              child: RoomMapMarker(room: r),
                            ),
                          ))
                      .toList(),
                ),

              // Player markers
              if (_showPlayers)
                MarkerLayer(
                  markers: _players
                      .where((p) => p.status == PlayerStatus.online)
                      .map((p) => Marker(
                            point: p.position,
                            width: p.isFriend ? 60 : 44,
                            height: p.isFriend ? 80 : 44,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedPlayer = p;
                                _selectedRoom = null;
                              }),
                              child: PlayerMapMarker(player: p),
                            ),
                          ))
                      .toList(),
                ),

              // My location dot
              MarkerLayer(
                markers: [
                  Marker(
                    point: _myLocation,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.myMarker,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.myMarker.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Loading / Error ────────────────────────────────────────
          if (_loading)
            const Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: _ErrorBanner(
                onRetry: _loadNearby,
              ),
            ),

          // ── Top bar ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadius.full,
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.shadow,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: AppColors.textMuted, size: 20),
                              const SizedBox(width: 8),
                              Text('Search players or locations',
                                  style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _MapIconButton(
                        icon: Icons.tune_rounded,
                        onTap: () => _showFilterSheet(context),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Rooms',
                        icon: Icons.table_restaurant_rounded,
                        active: _showRooms,
                        onTap: () =>
                            setState(() => _showRooms = !_showRooms),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Players',
                        icon: Icons.person_rounded,
                        active: _showPlayers,
                        onTap: () =>
                            setState(() => _showPlayers = !_showPlayers),
                      ),
                      const SizedBox(width: 8),
                      _OnlineCount(count: _players.length),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Player detail card ─────────────────────────────────────
          if (_selectedPlayer != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: PlayerDetailCard(
                player: _selectedPlayer!,
                onClose: () => setState(() => _selectedPlayer = null),
              ),
            ),

          // ── Room detail card ───────────────────────────────────────
          if (_selectedRoom != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: RoomDetailCard(
                room: _selectedRoom!,
                onClose: () => setState(() => _selectedRoom = null),
                onJoin: () => _joinRoom(_selectedRoom!),
              ),
            ),

          // ── Nearby panel ───────────────────────────────────────────
          if (_selectedPlayer == null && _selectedRoom == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: NearbyPanel(
                players: _players,
                rooms: _rooms,
                onPlayerTap: (p) {
                  setState(() {
                    _selectedPlayer = p;
                    _selectedRoom = null;
                  });
                  _mapController.move(p.position, 15.5);
                },
                onRoomTap: (r) {
                  setState(() {
                    _selectedRoom = r;
                    _selectedPlayer = null;
                  });
                  _mapController.move(r.position, 15.5);
                },
              ),
            ),

          // ── FABs ───────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                _MapIconButton(
                  icon: Icons.my_location_rounded,
                  onTap: () => _mapController.move(_myLocation, 14.5),
                  color: AppColors.secondary,
                ),
                const SizedBox(height: 10),
                BroadcastFab(
                  isBroadcasting: isBroadcasting,
                  onToggle: () => _toggleBroadcast(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider, borderRadius: AppRadius.full),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Map Filters', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            _FilterTile(label: 'Show Waiting Rooms', value: true),
            _FilterTile(label: 'Show Online Players', value: true),
            _FilterTile(label: 'Friends Only', value: false),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Map helper widgets ────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: AppRadius.md,
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Could not load nearby data',
                style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Text('Retry',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _MapIconButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: AppRadius.full,
          boxShadow: [
            BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: const Offset(0, 1))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.labelSmall.copyWith(
                  color: active ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

class _OnlineCount extends StatelessWidget {
  final int count;
  const _OnlineCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.online.withOpacity(0.12),
        borderRadius: AppRadius.full,
        border:
            Border.all(color: AppColors.online.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: AppColors.online, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$count online',
              style: AppTypography.labelSmall.copyWith(
                  color: AppColors.online, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FilterTile extends StatefulWidget {
  final String label;
  final bool value;
  const _FilterTile({required this.label, required this.value});

  @override
  State<_FilterTile> createState() => _FilterTileState();
}

class _FilterTileState extends State<_FilterTile> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: _value,
      onChanged: (v) => setState(() => _value = v),
      title: Text(widget.label, style: AppTypography.bodyMedium),
      activeColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
    );
  }
}

// ── Detail cards ──────────────────────────────────────────────────────────────

class PlayerDetailCard extends StatefulWidget {
  final Broadcast player;
  final VoidCallback onClose;

  const PlayerDetailCard(
      {super.key, required this.player, required this.onClose});

  @override
  State<PlayerDetailCard> createState() => _PlayerDetailCardState();
}

class _PlayerDetailCardState extends State<PlayerDetailCard> {
  bool _addingFriend = false;
  bool _friendRequestSent = false;
  bool _blocking = false;

  Future<void> _sendFriendRequest() async {
    setState(() => _addingFriend = true);
    try {
      await ApiClient.post('/api/v1/friends/requests', {
        'to_user_id': widget.player.userId,
      });
      setState(() {
        _addingFriend = false;
        _friendRequestSent = true;
      });
    } catch (e) {
      setState(() => _addingFriend = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  Future<void> _block() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block Player'),
        content: Text(
            'Block ${widget.player.userName}? They won\'t appear on your map.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Block',
                  style: TextStyle(color: AppColors.full))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _blocking = true);
    try {
      await ApiClient.post(
          '/api/v1/users/${widget.player.userId}/block', {});
      if (mounted) widget.onClose();
    } catch (e) {
      setState(() => _blocking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xl,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _AvatarCircle(
                initials: player.avatar,
                color: player.isFriend
                    ? AppColors.friendMarker
                    : AppColors.strangerMarker,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.userName,
                        style: AppTypography.headlineMedium),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: AppColors.online,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${player.distanceKm.toStringAsFixed(1)} km away',
                          style: AppTypography.labelSmall,
                        ),
                        if (player.rating != null) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.star_rounded,
                              size: 13, color: AppColors.waiting),
                          const SizedBox(width: 3),
                          Text('${player.rating}',
                              style: AppTypography.labelSmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Block menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted, size: 20),
                onSelected: (v) {
                  if (v == 'block') _block();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block_rounded,
                            color: AppColors.full, size: 18),
                        SizedBox(width: 10),
                        Text('Block Player',
                            style: TextStyle(color: AppColors.full)),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _blocking
                    ? const SizedBox(
                        height: 44,
                        child: Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))))
                    : _friendRequestSent
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.online),
                              shape: const RoundedRectangleBorder(
                                  borderRadius: AppRadius.md),
                            ),
                            onPressed: null,
                            child: Text('Request Sent',
                                style: AppTypography.labelLarge
                                    .copyWith(color: AppColors.online)),
                          )
                        : OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.divider),
                              shape: const RoundedRectangleBorder(
                                  borderRadius: AppRadius.md),
                            ),
                            onPressed: _addingFriend
                                ? null
                                : _sendFriendRequest,
                            child: _addingFriend
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text('Add Friend',
                                    style: AppTypography.labelLarge
                                        .copyWith(
                                            color: AppColors.secondary)),
                          ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44)),
                  onPressed: () {},
                  child: const Text('Invite to Room'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RoomDetailCard extends StatefulWidget {
  final Room room;
  final VoidCallback onClose;
  final VoidCallback onJoin;

  const RoomDetailCard(
      {super.key,
      required this.room,
      required this.onClose,
      required this.onJoin});

  @override
  State<RoomDetailCard> createState() => _RoomDetailCardState();
}

class _RoomDetailCardState extends State<RoomDetailCard> {
  bool _joining = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final canJoin = room.status == RoomStatus.waiting &&
        room.currentPlayers < room.maxPlayers;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xl,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(Icons.table_restaurant_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.address,
                        style: AppTypography.headlineMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                              '${room.distanceKm.toStringAsFixed(1)} km · Host: ${room.hostName}',
                              style: AppTypography.labelSmall,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Player slots
          Row(
            children: List.generate(room.maxPlayers, (i) {
              final filled = i < room.currentPlayers;
              final avatars = room.playerAvatars;
              final avatar =
                  filled && i < avatars.length ? avatars[i] : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: i < room.maxPlayers - 1 ? 6 : 0),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: filled
                          ? AppColors.secondary.withOpacity(0.1)
                          : AppColors.surfaceVariant,
                      borderRadius: AppRadius.md,
                      border: Border.all(
                          color: filled
                              ? AppColors.secondary.withOpacity(0.3)
                              : AppColors.divider,
                          width: 1),
                    ),
                    child: Center(
                      child: filled
                          ? Text(avatar ?? '?',
                              style: AppTypography.labelLarge
                                  .copyWith(color: AppColors.secondary))
                          : const Icon(Icons.person_add_rounded,
                              size: 18, color: AppColors.textMuted),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // View details button
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.divider),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.md),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () {
                    widget.onClose();
                    context.push(AppRoutes.room(room.id));
                  },
                  child: Text('Details',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor:
                        canJoin ? AppColors.primary : AppColors.textMuted,
                  ),
                  onPressed: canJoin && !_joining
                      ? () async {
                          setState(() => _joining = true);
                          await Future(() => widget.onJoin());
                          if (mounted) setState(() => _joining = false);
                        }
                      : null,
                  child: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(canJoin ? 'Join' : 'Full'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initials;
  final Color color;

  const _AvatarCircle({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initials,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700)),
    );
  }
}
