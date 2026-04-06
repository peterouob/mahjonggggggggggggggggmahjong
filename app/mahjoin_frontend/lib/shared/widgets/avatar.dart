import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

class AppAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final Color? backgroundColor;
  final bool showOnlineDot;
  final bool isOnline;
  final bool isPlaying;

  const AppAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.backgroundColor,
    this.showOnlineDot = false,
    this.isOnline = false,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.secondary;
    final dotColor = isPlaying ? AppColors.waiting : AppColors.online;

    return SizedBox(
      width: size + (showOnlineDot ? 6 : 0),
      height: size + (showOnlineDot ? 6 : 0),
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.33,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (showOnlineDot && (isOnline || isPlaying))
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
