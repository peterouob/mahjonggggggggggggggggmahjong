import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../data/models/models.dart';

class RoomMapMarker extends StatelessWidget {
  final Room room;

  const RoomMapMarker({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final color = switch (room.status) {
      RoomStatus.waiting => AppColors.primary,
      RoomStatus.playing => AppColors.secondary,
      RoomStatus.full => AppColors.textMuted,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.md,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.table_restaurant_rounded,
                  color: Colors.white, size: 22),
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${room.currentPlayers}',
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _SquareTailPainter(color: color),
        ),
      ],
    );
  }
}

class _SquareTailPainter extends CustomPainter {
  final Color color;
  const _SquareTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
