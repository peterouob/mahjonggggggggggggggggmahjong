import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/status_badge.dart';

class NearbyPanel extends StatefulWidget {
  final List<Broadcast> players;
  final List<Room> rooms;
  final ValueChanged<Broadcast> onPlayerTap;
  final ValueChanged<Room> onRoomTap;

  const NearbyPanel({
    super.key,
    required this.players,
    required this.rooms,
    required this.onPlayerTap,
    required this.onRoomTap,
  });

  @override
  State<NearbyPanel> createState() => _NearbyPanelState();
}

class _NearbyPanelState extends State<NearbyPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: AppRadius.full,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header + Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Text('附近', style: AppTypography.headlineMedium),
                const Spacer(),
                TabBar(
                  controller: _tab,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: AppTypography.labelLarge,
                  unselectedLabelStyle: AppTypography.labelLarge,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '玩家'),
                    Tab(text: '房間'),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(
            height: 140,
            child: TabBarView(
              controller: _tab,
              children: [
                // Players list
                widget.players.isEmpty
                  ? const Center(child: Text('附近沒有玩家'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: widget.players.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final p = widget.players[i];
                          return _PlayerCard(
                            player: p,
                            onTap: () => widget.onPlayerTap(p),
                          );
                        },
                      ),
                // Rooms list
                widget.rooms.isEmpty
                  ? const Center(child: Text('附近沒有房間'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: widget.rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final r = widget.rooms[i];
                          return _RoomCard(
                            room: r,
                            onTap: () => widget.onRoomTap(r),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Broadcast player;
  final VoidCallback onTap;

  const _PlayerCard({required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.lg,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAvatar(
              initials: player.avatar,
              size: 40,
              backgroundColor: player.isFriend
                  ? AppColors.friendMarker
                  : AppColors.strangerMarker,
              showOnlineDot: true,
              isOnline: player.status == PlayerStatus.online,
              isPlaying: player.status == PlayerStatus.playing,
            ),
            const SizedBox(height: 6),
            Text(
              player.userName.split(' ').first,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${player.distanceKm.toStringAsFixed(1)}km',
              style: AppTypography.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.lg,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.sm,
                  ),
                  child: const Icon(Icons.table_restaurant_rounded,
                      color: AppColors.primary, size: 16),
                ),
                const Spacer(),
                RoomStatusBadge(
                  status: room.status,
                  current: room.currentPlayers,
                  max: room.maxPlayers,
                ),
              ],
            ),
            Text(
              room.address,
              style: AppTypography.labelLarge.copyWith(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '距離 ${room.distanceKm.toStringAsFixed(1)} 公里',
              style: AppTypography.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
