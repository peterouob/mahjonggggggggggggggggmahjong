import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

class BroadcastFab extends StatelessWidget {
  final bool isBroadcasting;
  final VoidCallback onToggle;

  const BroadcastFab({
    super.key,
    required this.isBroadcasting,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isBroadcasting ? AppColors.primary : AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isBroadcasting
                  ? AppColors.primary.withOpacity(0.4)
                  : AppColors.shadow,
              blurRadius: isBroadcasting ? 12 : 8,
              spreadRadius: isBroadcasting ? 2 : 0,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Icon(
          isBroadcasting ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
          color: isBroadcasting ? Colors.white : AppColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
