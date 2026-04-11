import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';
import '../../data/models/models.dart';

class RoomStatusBadge extends StatelessWidget {
  final RoomStatus status;
  final int current;
  final int max;

  const RoomStatusBadge({
    super.key,
    required this.status,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RoomStatus.waiting => ('$current/$max 等待中', AppColors.waiting),
      RoomStatus.playing => ('進行中', AppColors.secondary),
      RoomStatus.full => ('已滿', AppColors.full),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppRadius.full,
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class PlayerStatusDot extends StatelessWidget {
  final PlayerStatus status;

  const PlayerStatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PlayerStatus.online => AppColors.online,
      PlayerStatus.playing => AppColors.waiting,
      PlayerStatus.offline => AppColors.offline,
    };
    final label = switch (status) {
      PlayerStatus.online => '在線',
      PlayerStatus.playing => '對局中',
      PlayerStatus.offline => '離線',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: AppTypography.labelSmall.copyWith(color: color)),
      ],
    );
  }
}
