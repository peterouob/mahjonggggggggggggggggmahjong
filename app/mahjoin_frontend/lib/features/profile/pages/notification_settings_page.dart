import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/storage/preferences.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  static const _kPush = 'notif_push_enabled';
  static const _kFriend = 'notif_friend_request_enabled';
  static const _kRoom = 'notif_room_event_enabled';
  static const _kSound = 'notif_sound_enabled';

  bool _loading = true;
  bool _pushEnabled = true;
  bool _friendRequestEnabled = true;
  bool _roomEventEnabled = true;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final push = await Preferences.getBool(_kPush, fallback: true);
    final friend = await Preferences.getBool(_kFriend, fallback: true);
    final room = await Preferences.getBool(_kRoom, fallback: true);
    final sound = await Preferences.getBool(_kSound, fallback: true);
    if (!mounted) return;
    setState(() {
      _pushEnabled = push;
      _friendRequestEnabled = friend;
      _roomEventEnabled = room;
      _soundEnabled = sound;
      _loading = false;
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    await Preferences.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('通知設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _SectionCard(
                  title: '推播',
                  children: [
                    SwitchListTile(
                      title: const Text('啟用推播通知'),
                      subtitle: const Text('關閉後將不接收即時通知'),
                      value: _pushEnabled,
                      onChanged: (v) async {
                        setState(() => _pushEnabled = v);
                        await _saveBool(_kPush, v);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('好友請求通知'),
                      subtitle: const Text('收到好友邀請時通知'),
                      value: _friendRequestEnabled,
                      onChanged: _pushEnabled
                          ? (v) async {
                              setState(() => _friendRequestEnabled = v);
                              await _saveBool(_kFriend, v);
                            }
                          : null,
                    ),
                    SwitchListTile(
                      title: const Text('房間事件通知'),
                      subtitle: const Text('房間滿員、解散等事件通知'),
                      value: _roomEventEnabled,
                      onChanged: _pushEnabled
                          ? (v) async {
                              setState(() => _roomEventEnabled = v);
                              await _saveBool(_kRoom, v);
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: '提醒方式',
                  children: [
                    SwitchListTile(
                      title: const Text('通知音效'),
                      subtitle: const Text('播放提示音與震動'),
                      value: _soundEnabled,
                      onChanged: _pushEnabled
                          ? (v) async {
                              setState(() => _soundEnabled = v);
                              await _saveBool(_kSound, v);
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
