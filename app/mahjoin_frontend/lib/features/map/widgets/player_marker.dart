import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';
import '../../../data/models/models.dart';

class PlayerMapMarker extends StatelessWidget {
  final Broadcast player;

  const PlayerMapMarker({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    if (player.isFriend) {
      return _FriendMarker(player: player);
    }
    return _StrangerMarker(player: player);
  }
}

// Friend: 60×80 pin with avatar
class _FriendMarker extends StatelessWidget {
  final Broadcast player;
  const _FriendMarker({required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.friendMarker,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.friendMarker.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ],
          ),
          child: Center(
            child: Text(
              player.avatar,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _MarkerTailPainter(color: AppColors.friendMarker),
        ),
      ],
    );
  }
}

// Stranger: 40×40 circle
class _StrangerMarker extends StatelessWidget {
  final Broadcast player;
  const _StrangerMarker({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.strangerMarker,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.strangerMarker.withOpacity(0.35),
            blurRadius: 6,
            spreadRadius: 1,
          )
        ],
      ),
      child: Center(
        child: Text(
          player.avatar,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  final Color color;
  const _MarkerTailPainter({required this.color});

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
