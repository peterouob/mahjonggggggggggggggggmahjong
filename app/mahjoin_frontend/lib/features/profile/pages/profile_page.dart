import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design/tokens.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/router/router.dart';
import '../../../core/storage/session.dart';
import '../../../data/services/broadcast_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    final displayName = session.userName ?? 'Player';
    final initials = session.avatarInitials;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar with profile header ───────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.primary,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayName,
                        style: AppTypography.headlineLarge
                            .copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      if (session.userId != null)
                        Text(
                          'ID: ${session.userId}',
                          style: AppTypography.bodyMedium
                              .copyWith(color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                color: Colors.white,
                onPressed: () {},
              ),
            ],
          ),

          // ── Broadcast toggle ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _BroadcastToggleTile(),
            ),
          ),

          // ── Menu items ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  _MenuSection(items: [
                    _MenuItem(
                      icon: Icons.history_rounded,
                      label: 'Game History',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.people_rounded,
                      label: 'Friends',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _MenuSection(items: [
                    _MenuItem(
                      icon: Icons.notifications_rounded,
                      label: 'Notifications',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip_rounded,
                      label: 'Privacy',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.help_rounded,
                      label: 'Help & Support',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  _MenuSection(items: [
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      onTap: () async {
                        try { await BroadcastService.instance.stop(); } catch (_) {}
                        WsClient.instance.disconnect();
                        await Session.instance.clear();
                        if (context.mounted) context.go(AppRoutes.onboarding);
                      },
                      destructive: true,
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastToggleTile extends StatefulWidget {
  @override
  State<_BroadcastToggleTile> createState() => _BroadcastToggleTileState();
}

class _BroadcastToggleTileState extends State<_BroadcastToggleTile> {
  bool get _on => BroadcastService.instance.isActive;
  bool _loading = false;

  Future<void> _toggle(bool value) async {
    setState(() => _loading = true);
    try {
      if (value) {
        final location = await LocationService.instance.getCurrentPosition();
        await BroadcastService.instance.start(
          lat: location.latitude,
          lng: location.longitude,
        );
      } else {
        await BroadcastService.instance.stop();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final on = _on;
    return Container(
      decoration: BoxDecoration(
        color: on
            ? AppColors.primary.withOpacity(0.06)
            : AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(
          color: on
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.divider,
        ),
      ),
      child: SwitchListTile(
        value: on,
        onChanged: _loading ? null : _toggle,
        activeColor: AppColors.primary,
        title: Text(
          on ? 'Broadcasting Location' : 'Hidden from Map',
          style: AppTypography.headlineMedium,
        ),
        subtitle: Text(
          on
              ? 'Players nearby can see you on the map'
              : 'Turn on to appear on the map',
          style: AppTypography.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: on
                ? AppColors.primary.withOpacity(0.1)
                : AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  on
                      ? Icons.wifi_tethering_rounded
                      : Icons.wifi_tethering_off_rounded,
                  color: on ? AppColors.primary : AppColors.textMuted,
                  size: 20,
                ),
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1)
                const Divider(
                    height: 1,
                    indent: 52,
                    endIndent: 0,
                    color: AppColors.divider),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final void Function() onTap;
  final bool destructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? AppColors.full : AppColors.textPrimary;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: destructive
              ? AppColors.full.withOpacity(0.1)
              : AppColors.surfaceVariant,
          borderRadius: AppRadius.sm,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: AppTypography.bodyMedium.copyWith(color: color)),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 20),
    );
  }
}
