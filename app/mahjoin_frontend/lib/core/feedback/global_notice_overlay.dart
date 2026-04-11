import 'package:flutter/material.dart';
import 'notification_center.dart';

class GlobalNoticeOverlay extends StatelessWidget {
  final Widget child;

  const GlobalNoticeOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationCenter.instance,
      builder: (context, _) {
        final notice = NotificationCenter.instance.current;
        return Stack(
          children: [
            child,
            if (notice != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                child: Material(
                  color: _backgroundColor(notice.level),
                  borderRadius: BorderRadius.circular(10),
                  elevation: 4,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: NotificationCenter.instance.clearCurrent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _icon(notice.level),
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              notice.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _backgroundColor(AppNotificationLevel level) {
    return switch (level) {
      AppNotificationLevel.success => const Color(0xFF16A34A),
      AppNotificationLevel.warning => const Color(0xFFD97706),
      AppNotificationLevel.error => const Color(0xFFDC2626),
      AppNotificationLevel.info => const Color(0xFF1D4ED8),
    };
  }

  IconData _icon(AppNotificationLevel level) {
    return switch (level) {
      AppNotificationLevel.success => Icons.check_circle_rounded,
      AppNotificationLevel.warning => Icons.warning_rounded,
      AppNotificationLevel.error => Icons.error_rounded,
      AppNotificationLevel.info => Icons.info_rounded,
    };
  }
}
