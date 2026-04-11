import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../core/storage/preferences.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  static const _kShowOnline = 'privacy_show_online';
  static const _kAllowInvite = 'privacy_allow_invite';
  static const _kShareLocation = 'privacy_share_location';

  bool _loading = true;
  bool _showOnline = true;
  bool _allowInvite = true;
  bool _shareLocation = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final showOnline = await Preferences.getBool(_kShowOnline, fallback: true);
    final allowInvite = await Preferences.getBool(_kAllowInvite, fallback: true);
    final shareLocation = await Preferences.getBool(_kShareLocation, fallback: true);
    if (!mounted) return;
    setState(() {
      _showOnline = showOnline;
      _allowInvite = allowInvite;
      _shareLocation = shareLocation;
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
      appBar: AppBar(title: const Text('隱私設定')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lg,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _showOnline,
                        onChanged: (v) async {
                          setState(() => _showOnline = v);
                          await _saveBool(_kShowOnline, v);
                        },
                        title: const Text('顯示在線狀態'),
                        subtitle: const Text('讓好友看到你是否在線'),
                      ),
                      SwitchListTile(
                        value: _allowInvite,
                        onChanged: (v) async {
                          setState(() => _allowInvite = v);
                          await _saveBool(_kAllowInvite, v);
                        },
                        title: const Text('允許房間邀請'),
                        subtitle: const Text('允許其他玩家邀請你加入房間'),
                      ),
                      SwitchListTile(
                        value: _shareLocation,
                        onChanged: (v) async {
                          setState(() => _shareLocation = v);
                          await _saveBool(_kShareLocation, v);
                        },
                        title: const Text('分享大約位置'),
                        subtitle: const Text('在地圖顯示你的附近區域'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.lg,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Text(
                    '提醒：隱私設定僅影響前端顯示與互動偏好，實際資料授權仍以系統定位權限為準。',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
    );
  }
}
