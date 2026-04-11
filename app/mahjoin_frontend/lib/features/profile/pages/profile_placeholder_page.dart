import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

class ProfilePlaceholderPage extends StatelessWidget {
  final String title;
  final String description;

  const ProfilePlaceholderPage({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_rounded,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppTypography.headlineLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
